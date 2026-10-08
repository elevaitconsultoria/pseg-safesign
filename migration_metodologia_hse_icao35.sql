-- ═══════════════════════════════════════════════════════════════════════════════════════
-- PsicoMap — Segunda metodologia (HSE / ICAO-35): esquema (etapa S1)
-- Plano: .claude/notes/2026-10-08-plano-implantacao-hse.md
--
-- Executar no Supabase Dashboard → SQL Editor (ou via MCP).
-- Ordem: DEV (szqatgvgghxvyyncsjxl) primeiro, validar, PROD (vftyiildukrpgmnbcnao) depois.
-- ANTES de aplicar em PROD: confirmar PITR ativo no Dashboard (B12) e que não há coleta em curso
-- (select count(*) from respostas where respondido_em > now() - interval '7 days').
--
-- PROBLEMA QUE RESOLVE
--   O sistema tem uma única metodologia (BS 8800: 27 questões, escala 1–4). Para oferecer o HSE
--   (35 itens, escala 1–5) sem arriscar o pipeline de coleta em produção, o HSE vive em
--   TABELAS PRÓPRIAS. O cabeçalho `respostas` é compartilhado; os itens, não.
--
-- O QUE FAZ
--   1. ciclos.metodologia e respostas.metodologia ('BS8800' por padrão; CHECK extensível).
--   2. Trigger: a metodologia de um ciclo não muda depois que existe link ou resposta nele.
--   3. questionarios ganha metodologia/versao/publicado/config (publicado=false esconde o
--      instrumento: é a "chave geral" do HSE em cada ambiente).
--   4. hse_itens (texto das 35 perguntas) — congelado depois de publicado.
--   5. resposta_itens_hse (respostas item a item, valor 1..5).
--   6. hse_benchmark (médias de referência; percentis permanecem NULL — não existem na fonte).
--
-- O QUE NÃO FAZ (de propósito)
--   Não altera NENHUMA tabela do BS 8800 além de acrescentar colunas com default
--   (resposta_itens, questoes, constraints e a RPC salvar_resposta ficam intocados).
--   Não concede nada ao `anon`. A leitura pública do instrumento virá por RPC (etapa S2).
--
-- IMPACTO EM PRODUÇÃO
--   ADD COLUMN com default constante é só metadado; a validação do CHECK varre ciclos (~10 linhas)
--   e respostas (~2 mil). Lock breve. Idempotente: pode ser reexecutado.
--
-- ROLLBACK (só enquanto não existir dado HSE): ver bloco comentado no fim do arquivo.
-- ═══════════════════════════════════════════════════════════════════════════════════════


-- ── 1. metodologia no ciclo e na resposta ───────────────────────────────────────────────
ALTER TABLE ciclos    ADD COLUMN IF NOT EXISTS metodologia text NOT NULL DEFAULT 'BS8800';
ALTER TABLE respostas ADD COLUMN IF NOT EXISTS metodologia text NOT NULL DEFAULT 'BS8800';

-- Constraint nomeada e recriável: ao entrar um terceiro valor (ex.: combo) basta trocar a lista.
ALTER TABLE ciclos    DROP CONSTRAINT IF EXISTS ciclos_metodologia_check;
ALTER TABLE ciclos    ADD  CONSTRAINT ciclos_metodologia_check
  CHECK (metodologia IN ('BS8800', 'HSE_ICAO35'));
ALTER TABLE respostas DROP CONSTRAINT IF EXISTS respostas_metodologia_check;
ALTER TABLE respostas ADD  CONSTRAINT respostas_metodologia_check
  CHECK (metodologia IN ('BS8800', 'HSE_ICAO35'));

COMMENT ON COLUMN ciclos.metodologia IS
  'Fonte da verdade da metodologia da campanha. Ciclo existente e link sem ciclo = BS8800. Imutável depois que há link ou resposta.';
COMMENT ON COLUMN respostas.metodologia IS
  'Snapshot da metodologia no momento do envio (respostas.ciclo_id é SET NULL se o ciclo for apagado). Gravado pela RPC salvar_resposta.';


-- ── 2. imutabilidade da metodologia do ciclo ────────────────────────────────────────────
-- SECURITY DEFINER: precisa enxergar links/respostas de qualquer tenant; sem isso o RLS do
-- chamador esconderia linhas e a trava poderia ser contornada.
CREATE OR REPLACE FUNCTION public.fn_ciclo_metodologia_imutavel()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $fn$
BEGIN
  IF NEW.metodologia IS DISTINCT FROM OLD.metodologia THEN
    IF EXISTS (SELECT 1 FROM links_coleta WHERE ciclo_id = OLD.id)
       OR EXISTS (SELECT 1 FROM respostas WHERE ciclo_id = OLD.id) THEN
      RAISE EXCEPTION 'metodologia_imutavel: o ciclo já tem link ou resposta; crie um novo ciclo';
    END IF;
  END IF;
  RETURN NEW;
END;
$fn$;

REVOKE ALL ON FUNCTION public.fn_ciclo_metodologia_imutavel() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS tg_ciclo_metodologia_imutavel ON ciclos;
CREATE TRIGGER tg_ciclo_metodologia_imutavel
  BEFORE UPDATE OF metodologia ON ciclos
  FOR EACH ROW EXECUTE FUNCTION public.fn_ciclo_metodologia_imutavel();


-- ── 3. questionarios: versão, publicação e configuração do instrumento ──────────────────
ALTER TABLE questionarios ADD COLUMN IF NOT EXISTS metodologia text    NOT NULL DEFAULT 'BS8800';
ALTER TABLE questionarios ADD COLUMN IF NOT EXISTS versao      integer NOT NULL DEFAULT 1;
ALTER TABLE questionarios ADD COLUMN IF NOT EXISTS publicado   boolean NOT NULL DEFAULT false;
ALTER TABLE questionarios ADD COLUMN IF NOT EXISTS config      jsonb   NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE questionarios DROP CONSTRAINT IF EXISTS questionarios_metodologia_check;
ALTER TABLE questionarios ADD  CONSTRAINT questionarios_metodologia_check
  CHECK (metodologia IN ('BS8800', 'HSE_ICAO35'));

-- Os questionários BS 8800 já existentes continuam valendo: entram como publicados.
UPDATE questionarios SET publicado = true WHERE metodologia = 'BS8800' AND publicado = false;

COMMENT ON COLUMN questionarios.publicado IS
  'false = instrumento invisível para o formulário público e para o seletor de metodologia do admin. É a chave geral do HSE por ambiente.';
COMMENT ON COLUMN questionarios.config IS
  'Textos do instrumento além dos itens: instruções, cabeçalho de cada parte, rótulos de escala, texto LGPD. Congelado junto com hse_itens ao publicar (novo texto = novo questionário).';


-- ── 4. hse_itens — perguntas do HSE ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS hse_itens (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  questionario_id  uuid NOT NULL REFERENCES questionarios(id) ON DELETE RESTRICT,
  codigo           text NOT NULL CHECK (codigo ~ '^H[0-9]{2}$'),
  ordem            smallint NOT NULL CHECK (ordem BETWEEN 1 AND 99),
  parte            smallint NOT NULL CHECK (parte IN (1, 2)),   -- 1 = frequência, 2 = concordância
  dimensao         text NOT NULL CHECK (dimensao IN
    ('DEMANDS','CONTROL','MANAGER_SUPPORT','PEER_SUPPORT','RELATIONSHIPS','ROLE','CHANGE')),
  texto            text NOT NULL,
  inversa          boolean NOT NULL DEFAULT false,              -- verdadeiro em TODA a dimensão DEMANDS e RELATIONSHIPS
  escala_labels    text NOT NULL CHECK (escala_labels IN ('freq', 'concord')),
  criado_em        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (questionario_id, codigo),
  UNIQUE (questionario_id, ordem)
);

COMMENT ON TABLE hse_itens IS
  'Itens do instrumento HSE/ICAO-35. Texto congelado após a publicação do questionário: mudou uma palavra, crie outro questionário.';

CREATE OR REPLACE FUNCTION public.fn_hse_itens_congelados()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $fn$
DECLARE
  v_qid uuid;
BEGIN
  -- INSERT não tem OLD; DELETE não tem NEW (referenciar o ausente dá erro em plpgsql).
  IF TG_OP = 'INSERT' THEN v_qid := NEW.questionario_id; ELSE v_qid := OLD.questionario_id; END IF;
  IF EXISTS (SELECT 1 FROM questionarios WHERE id = v_qid AND publicado) THEN
    RAISE EXCEPTION 'hse_itens_congelados: o questionário já foi publicado; crie uma nova versão';
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$fn$;

REVOKE ALL ON FUNCTION public.fn_hse_itens_congelados() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS tg_hse_itens_congelados ON hse_itens;
CREATE TRIGGER tg_hse_itens_congelados
  BEFORE INSERT OR UPDATE OR DELETE ON hse_itens
  FOR EACH ROW EXECUTE FUNCTION public.fn_hse_itens_congelados();

ALTER TABLE hse_itens ENABLE ROW LEVEL SECURITY;
-- O default do schema concede privilégios extras (TRUNCATE, TRIGGER, REFERENCES) a authenticated em
-- tabela nova; zerar antes de conceder só o necessário. Escrita só por migration/seed (dono do banco).
REVOKE ALL ON hse_itens FROM anon, authenticated;
GRANT SELECT ON hse_itens TO authenticated;

DROP POLICY IF EXISTS hse_itens_select_autenticado ON hse_itens;
CREATE POLICY hse_itens_select_autenticado ON hse_itens
  FOR SELECT TO authenticated USING (true);


-- ── 5. resposta_itens_hse — respostas item a item (1..5) ────────────────────────────────
CREATE TABLE IF NOT EXISTS resposta_itens_hse (
  resposta_id  uuid NOT NULL REFERENCES respostas(id) ON DELETE CASCADE,
  item_id      uuid NOT NULL REFERENCES hse_itens(id) ON DELETE RESTRICT,
  valor        smallint NOT NULL CHECK (valor BETWEEN 1 AND 5),
  PRIMARY KEY (resposta_id, item_id)
);
CREATE INDEX IF NOT EXISTS idx_resposta_itens_hse_item ON resposta_itens_hse (item_id);

COMMENT ON TABLE resposta_itens_hse IS
  'Valor BRUTO (1..5) marcado pelo respondente; a inversão é feita só no cálculo. Escrita exclusiva da RPC salvar_resposta (SECURITY DEFINER).';

ALTER TABLE resposta_itens_hse ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON resposta_itens_hse FROM anon, authenticated;
GRANT SELECT ON resposta_itens_hse TO authenticated;

-- A subconsulta em `respostas` herda o RLS de `respostas` do próprio chamador (inclusive as
-- restrições do cliente_viewer), então não é preciso repetir regra de papel aqui.
DROP POLICY IF EXISTS resposta_itens_hse_tenant_select ON resposta_itens_hse;
CREATE POLICY resposta_itens_hse_tenant_select ON resposta_itens_hse
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM respostas r
     WHERE r.id = resposta_itens_hse.resposta_id
       AND r.tenant_id = get_my_tenant_id()
  ));

DROP POLICY IF EXISTS resposta_itens_hse_super_admin_select ON resposta_itens_hse;
CREATE POLICY resposta_itens_hse_super_admin_select ON resposta_itens_hse
  FOR SELECT TO authenticated USING (is_super_admin());


-- ── 6. hse_benchmark — referência externa (não é dado de tenant) ────────────────────────
CREATE TABLE IF NOT EXISTS hse_benchmark (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fonte       text NOT NULL,                       -- ex.: 'HSE_2023'
  fonte_ano   integer,
  setor       text NOT NULL DEFAULT 'GERAL',
  dimensao    text NOT NULL CHECK (dimensao IN
    ('DEMANDS','CONTROL','MANAGER_SUPPORT','PEER_SUPPORT','RELATIONSHIPS','ROLE','CHANGE')),
  media       numeric(4,2),
  p20         numeric(4,2),                        -- permanecem NULL: percentis não existem na fonte oficial
  p50         numeric(4,2),
  p80         numeric(4,2),
  n_amostra   integer,
  vigente     boolean NOT NULL DEFAULT true,
  observacao  text,
  criado_em   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (fonte, setor, dimensao)
);
CREATE INDEX IF NOT EXISTS idx_hse_benchmark_lookup ON hse_benchmark (vigente, setor, dimensao);

ALTER TABLE hse_benchmark ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON hse_benchmark FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON hse_benchmark TO authenticated;

DROP POLICY IF EXISTS hse_benchmark_select_autenticado ON hse_benchmark;
CREATE POLICY hse_benchmark_select_autenticado ON hse_benchmark
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS hse_benchmark_super_admin_write ON hse_benchmark;
CREATE POLICY hse_benchmark_super_admin_write ON hse_benchmark
  FOR ALL TO authenticated USING (is_super_admin()) WITH CHECK (is_super_admin());


-- ── Verificação (rodar depois de aplicar) ───────────────────────────────────────────────
-- Colunas novas existem e todo o histórico ficou BS8800:
--   SELECT 'ciclos' t, metodologia, count(*) FROM ciclos GROUP BY 2
--   UNION ALL SELECT 'respostas', metodologia, count(*) FROM respostas GROUP BY 2
--   UNION ALL SELECT 'questionarios', metodologia||' publicado='||publicado, count(*) FROM questionarios GROUP BY 2;
-- Nenhum privilégio para anon nas tabelas novas (esperado: 0 linhas):
--   SELECT table_name, privilege_type FROM information_schema.role_table_grants
--    WHERE grantee='anon' AND table_name IN ('hse_itens','resposta_itens_hse','hse_benchmark');
-- Policies:
--   SELECT tablename, policyname, cmd FROM pg_policies
--    WHERE tablename IN ('hse_itens','resposta_itens_hse','hse_benchmark') ORDER BY 1,2;
-- Teste da trava (em transação com ROLLBACK):
--   BEGIN; INSERT INTO ciclos(empresa_id,nome,tenant_id) SELECT id,'t',tenant_id FROM empresas LIMIT 1 RETURNING id; ...
--   -- depois: UPDATE ciclos SET metodologia='HSE_ICAO35' WHERE id=<id>;  (ok, sem link) ... ROLLBACK;

-- ── ROLLBACK (só enquanto não existir dado HSE) ─────────────────────────────────────────
-- DROP TABLE IF EXISTS resposta_itens_hse;
-- DROP TABLE IF EXISTS hse_itens;
-- DROP TABLE IF EXISTS hse_benchmark;
-- DROP FUNCTION IF EXISTS public.fn_hse_itens_congelados();
-- DROP TRIGGER IF EXISTS tg_ciclo_metodologia_imutavel ON ciclos;
-- DROP FUNCTION IF EXISTS public.fn_ciclo_metodologia_imutavel();
-- ALTER TABLE questionarios DROP COLUMN IF EXISTS config, DROP COLUMN IF EXISTS publicado,
--   DROP COLUMN IF EXISTS versao, DROP COLUMN IF EXISTS metodologia;
-- ALTER TABLE respostas DROP COLUMN IF EXISTS metodologia;
-- ALTER TABLE ciclos    DROP COLUMN IF EXISTS metodologia;
