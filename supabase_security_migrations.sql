-- ══════════════════════════════════════════════════════════════════════════
-- PsicoMap — Migrações de Segurança e Performance
-- Executar no Supabase Dashboard → SQL Editor
-- Ordem: 1 → 2 → 3 → 4
-- ══════════════════════════════════════════════════════════════════════════


-- ── MIGRAÇÃO 1: Tabela de fila de backup (respostas_fila) ────────────────
-- Propósito: armazenar o payload bruto ANTES de processar no salvar_resposta.
-- Se o processamento falhar por qualquer motivo, o dado não se perde.
-- Um pg_cron job ou chamada manual pode reprocessar entradas com status 'pendente'.
-- ─────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS respostas_fila (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id   uuid        NOT NULL,
  link_token   text        NOT NULL,
  payload_json jsonb       NOT NULL,       -- rpcParams completo
  status       text        NOT NULL DEFAULT 'pendente'
                            CHECK (status IN ('pendente','processado','erro')),
  tentativas   int         NOT NULL DEFAULT 0,
  erro_msg     text,
  criado_em    timestamptz NOT NULL DEFAULT now(),
  processado_em timestamptz
);

-- Índice para reprocessamento: buscar entradas pendentes por data
CREATE INDEX IF NOT EXISTS idx_respostas_fila_status
  ON respostas_fila(status, criado_em);

-- RLS: apenas service_role lê/escreve (a fila é interna)
ALTER TABLE respostas_fila ENABLE ROW LEVEL SECURITY;

-- Permitir INSERT pelo anon (via SECURITY DEFINER function abaixo)
-- Não criar policy de SELECT/UPDATE para anon — somente service_role acessa

COMMENT ON TABLE respostas_fila IS
  'Fila de backup de respostas recebidas. '
  'status=pendente: aguardando processamento. '
  'status=processado: salvo com sucesso em respostas+resposta_itens. '
  'status=erro: falhou após N tentativas — requer revisão manual.';


-- ── MIGRAÇÃO 2: Função salvar_resposta com deduplicação + fila ───────────
-- Substitui a função existente.
-- Garante: 1 resposta por token (server-side), registra na fila antes de processar.
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION salvar_resposta(
  p_empresa_id   uuid,
  p_ciclo_id     uuid    DEFAULT NULL,
  p_link_token   text    DEFAULT '',
  p_setor        text    DEFAULT 'Não informado',
  p_funcao       text    DEFAULT NULL,
  p_escolaridade text    DEFAULT NULL,
  p_itens        jsonb   DEFAULT '[]'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_resposta_id  uuid;
  v_link_id      uuid;
  v_link_ativo   bool;
  v_link_expira  timestamptz;
  v_fila_id      uuid;
  v_item         jsonb;
BEGIN
  -- ── 1. Validações básicas ──────────────────────────────────────────────
  IF p_empresa_id IS NULL THEN
    RAISE EXCEPTION 'empresa_id obrigatório';
  END IF;

  IF p_link_token = '' OR p_link_token IS NULL THEN
    RAISE EXCEPTION 'link_token obrigatório';
  END IF;

  -- Sanitizar strings (limitar comprimento — defesa em profundidade)
  p_setor        := left(trim(p_setor), 120);
  p_funcao       := left(trim(coalesce(p_funcao, '')), 120);
  p_escolaridade := left(trim(coalesce(p_escolaridade, '')), 60);

  IF p_setor = '' THEN p_setor := 'Não informado'; END IF;
  IF p_funcao = '' THEN p_funcao := NULL; END IF;
  IF p_escolaridade = '' THEN p_escolaridade := NULL; END IF;

  -- ── 2. Validar o link (ativo, não expirado) ───────────────────────────
  SELECT id, ativo, expira_em
    INTO v_link_id, v_link_ativo, v_link_expira
    FROM links_coleta
   WHERE token = p_link_token
   LIMIT 1;

  IF v_link_id IS NULL THEN
    RAISE EXCEPTION 'token_invalido: link não encontrado';
  END IF;

  IF NOT v_link_ativo THEN
    RAISE EXCEPTION 'token_inativo: link foi desativado';
  END IF;

  IF v_link_expira IS NOT NULL AND v_link_expira < now() THEN
    RAISE EXCEPTION 'token_expirado: link expirou em %', v_link_expira;
  END IF;

  -- ── 3. Deduplicação server-side: 1 resposta por token ─────────────────
  -- Usar advisory lock para evitar race condition em envios simultâneos
  PERFORM pg_advisory_xact_lock(hashtext(p_link_token));

  IF EXISTS (
    SELECT 1 FROM respostas
     WHERE link_token = p_link_token
     LIMIT 1
  ) THEN
    -- Retornar o ID existente sem erro (idempotente)
    SELECT id INTO v_resposta_id FROM respostas WHERE link_token = p_link_token LIMIT 1;
    RETURN v_resposta_id;
  END IF;

  -- ── 4. Registrar na fila de backup ANTES de processar ─────────────────
  INSERT INTO respostas_fila (empresa_id, link_token, payload_json, status)
  VALUES (
    p_empresa_id,
    p_link_token,
    jsonb_build_object(
      'empresa_id',   p_empresa_id,
      'ciclo_id',     p_ciclo_id,
      'setor',        p_setor,
      'funcao',       p_funcao,
      'escolaridade', p_escolaridade,
      'itens',        p_itens,
      'ts',           now()
    ),
    'pendente'
  )
  RETURNING id INTO v_fila_id;

  -- ── 5. Inserir resposta principal ──────────────────────────────────────
  INSERT INTO respostas (
    empresa_id, ciclo_id, setor, funcao, escolaridade,
    link_token, respondido_em
  )
  VALUES (
    p_empresa_id, p_ciclo_id, p_setor,
    NULLIF(p_funcao, ''), NULLIF(p_escolaridade, ''),
    p_link_token, now()
  )
  RETURNING id INTO v_resposta_id;

  -- ── 6. Inserir itens (respostas individuais por questão) ───────────────
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_itens)
  LOOP
    -- Validar que valor está no range esperado
    IF (v_item->>'valor')::int BETWEEN 1 AND 4 THEN
      INSERT INTO resposta_itens (resposta_id, questao_id, valor)
      VALUES (
        v_resposta_id,
        (v_item->>'questao_id')::uuid,
        (v_item->>'valor')::int
      );
    END IF;
  END LOOP;

  -- ── 7. Marcar fila como processado ────────────────────────────────────
  UPDATE respostas_fila
     SET status = 'processado', processado_em = now()
   WHERE id = v_fila_id;

  RETURN v_resposta_id;

EXCEPTION WHEN OTHERS THEN
  -- Marcar fila como erro para revisão manual
  IF v_fila_id IS NOT NULL THEN
    UPDATE respostas_fila
       SET status = 'erro', erro_msg = SQLERRM, tentativas = tentativas + 1
     WHERE id = v_fila_id;
  END IF;
  RAISE;
END;
$$;

-- Garante que apenas o role anon (através do SDK) pode chamar a função
REVOKE ALL ON FUNCTION salvar_resposta FROM PUBLIC;
GRANT EXECUTE ON FUNCTION salvar_resposta TO anon;

COMMENT ON FUNCTION salvar_resposta IS
  'Salva uma resposta de forma idempotente (1 por token). '
  'Registra em respostas_fila antes de processar — serve como backup. '
  'Usa advisory lock para prevenir race condition em envios simultâneos.';


-- ── MIGRAÇÃO 3: Índices de performance ───────────────────────────────────
-- Para suportar alto volume de respostas e análises
-- ─────────────────────────────────────────────────────────────────────────

-- Lookup de token (deduplicação + validação do link)
CREATE INDEX IF NOT EXISTS idx_links_coleta_token
  ON links_coleta(token);

-- Lookup de resposta por token (deduplicação server-side)
CREATE INDEX IF NOT EXISTS idx_respostas_link_token
  ON respostas(link_token);

-- Análise por empresa + ciclo (query mais comum do painel)
CREATE INDEX IF NOT EXISTS idx_respostas_empresa_ciclo
  ON respostas(empresa_id, ciclo_id, respondido_em DESC);

-- Itens por resposta (JOIN na leitura de análise)
CREATE INDEX IF NOT EXISTS idx_resposta_itens_resposta
  ON resposta_itens(resposta_id);

-- Questões ativas (carregadas no boot do formulário)
CREATE INDEX IF NOT EXISTS idx_questoes_is_oficial
  ON questoes(is_oficial) WHERE is_oficial = true;


-- ── MIGRAÇÃO 4: RLS Policies recomendadas ────────────────────────────────
-- VERIFICAR: abrir Supabase → Authentication → Policies e confirmar
-- que as políticas abaixo (ou equivalentes) estão ativas.
-- ─────────────────────────────────────────────────────────────────────────

-- respostas: apenas usuários autenticados do mesmo tenant lêem
-- (anon não lê — o RPC salvar_resposta usa SECURITY DEFINER)
ALTER TABLE respostas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "respostas_tenant_select" ON respostas;
CREATE POLICY "respostas_tenant_select" ON respostas
  FOR SELECT TO authenticated
  USING (
    empresa_id IN (
      SELECT e.id FROM empresas e
       WHERE e.tenant_id = (
         SELECT tenant_id FROM perfis WHERE id = auth.uid() LIMIT 1
       )
    )
  );

-- resposta_itens: somente via JOIN com respostas (autenticado)
ALTER TABLE resposta_itens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "resposta_itens_tenant_select" ON resposta_itens;
CREATE POLICY "resposta_itens_tenant_select" ON resposta_itens
  FOR SELECT TO authenticated
  USING (
    resposta_id IN (
      SELECT r.id FROM respostas r
      JOIN empresas e ON e.id = r.empresa_id
      WHERE e.tenant_id = (
        SELECT tenant_id FROM perfis WHERE id = auth.uid() LIMIT 1
      )
    )
  );

-- links_coleta: anon só lê colunas necessárias para validar o token
-- (empresa_id, setor_sugerido, ciclo_id, ativo, expira_em)
ALTER TABLE links_coleta ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "links_coleta_anon_select" ON links_coleta;
CREATE POLICY "links_coleta_anon_select" ON links_coleta
  FOR SELECT TO anon
  USING (ativo = true);

DROP POLICY IF EXISTS "links_coleta_tenant_all" ON links_coleta;
CREATE POLICY "links_coleta_tenant_all" ON links_coleta
  FOR ALL TO authenticated
  USING (
    tenant_id = (SELECT tenant_id FROM perfis WHERE id = auth.uid() LIMIT 1)
  );


-- ── VERIFICAÇÕES FINAIS ───────────────────────────────────────────────────
-- Executar após as migrações para confirmar estado:

-- 1. Tabelas com RLS habilitado:
SELECT tablename, rowsecurity
  FROM pg_tables
 WHERE schemaname = 'public'
   AND tablename IN ('respostas','resposta_itens','links_coleta','empresas','perfis')
 ORDER BY tablename;

-- 2. Índices criados:
SELECT indexname, tablename
  FROM pg_indexes
 WHERE schemaname = 'public'
   AND indexname LIKE 'idx_%'
 ORDER BY tablename, indexname;

-- 3. Fila de backup (deve estar vazia inicialmente):
SELECT status, count(*) FROM respostas_fila GROUP BY status;
