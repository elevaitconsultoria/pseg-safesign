-- ═══════════════════════════════════════════════════════════════════════════════════════
-- PsicoMap — Metodologias além do BS 8800: família GENÉRICA de instrumentos  (etapa S1, v2 genérica)
-- Substitui migration_metodologia_hse_icao35.sql (renomeada). Decisão e razões:
--   .claude/notes/2026-10-19-copsoq-e-arquitetura-multi-metodologia.md §5.1 (opção B) e
--   .claude/notes/2026-10-19-copsoq-avaliacao-documentos-e-generalizacao.md.
--
-- Executar: DEV (szqatgvgghxvyyncsjxl) já tem a versão anterior (tabelas hse_*): aplicar ESTE arquivo e depois
--   migration_dev_converter_hse_para_instrumentos.sql (copia os dados e remove hse_*). PROD
--   (vftyiildukrpgmnbcnao) recebe só este arquivo — nunca teve nada do HSE.
-- ANTES de aplicar em PROD: confirmar PITR ativo no Dashboard (B12) e que não há coleta em curso
-- (select count(*) from respostas where respondido_em > now() - interval '7 days').
--
-- PROBLEMA QUE RESOLVE
--   O sistema tem uma metodologia legada (BS 8800: 27 questões, escala 1–4, tabelas questoes/resposta_itens)
--   e passa a ter outras (HSE/ICAO-35 agora; COPSOQ depois). Em vez de uma família de tabelas por
--   instrumento (que repetiria RLS, GRANT/REVOKE do anon, backup e RPC a cada um), os instrumentos novos
--   usam UMA família genérica; o BS 8800 continua intocado. O cabeçalho `respostas` é compartilhado.
--
-- O QUE FAZ
--   1. instrumentos: catálogo de metodologias (BS8800 legado; HSE_ICAO35 genérico). Adicionar uma metodologia
--      = INSERT aqui + dimensões + itens, sem DDL.
--   2. instrumento_dimensoes: dimensões de cada instrumento, com o SENTIDO NATIVO (alto_melhor | alto_pior),
--      o domínio (agrupamento superior) e a marca de dado sensível.
--   3. ciclos/respostas/questionarios.metodologia com FK para o catálogo (antes: CHECK com a lista fixa).
--   4. Trigger: a metodologia de um ciclo não muda depois que existe link ou resposta nele.
--   5. questionarios ganha metodologia/versao/publicado/config (publicado=false esconde o instrumento).
--   6. instrumento_itens (texto das perguntas) — congelado depois de publicado.
--   7. resposta_itens_instrumento (respostas item a item).
--   8. instrumento_referencias (médias de referência; percentis permanecem NULL quando a fonte não os tem).
--
-- CONVENÇÕES DO INSTRUMENTO (valem para qualquer metodologia nova)
--   • valor guardado = valor BRUTO marcado pelo respondente (1..N, N = nº de rótulos da escala do item);
--     a normalização é feita só no cálculo, item a item, por instrumento_itens.inversa.
--   • inversa = o valor bruto precisa ser espelhado (N+1−v) para ficar "alto = melhor". Vem do sentido nativo
--     da dimensão (alto_pior ⇒ inversa) combinado com a redação do item (item "ao contrário" dentro da dimensão).
--   • rótulos de cada escala: questionarios.config -> 'rotulos' -> <instrumento_itens.escala_labels> (array).
--     O nº de rótulos define o maior valor aceito pelo item; sem rótulo, vale instrumentos.escala_max.
--   • instrumentos.sensivel = coleta DADO DE SAÚDE (LGPD art. 5º, II): exige consentimento específico, RIPD e
--     anonimato reforçado (a camada de apresentação lê esta marca). Nenhuma metodologia atual é sensível.
--
-- O QUE NÃO FAZ (de propósito)
--   Não altera NENHUMA tabela do BS 8800 além de acrescentar colunas com default (resposta_itens, questoes,
--   constraints e o ramo BS da RPC salvar_resposta ficam como estão). Não concede nada ao `anon`: a leitura
--   pública do instrumento é por RPC (obter_instrumento_link).
--
-- IMPACTO EM PRODUÇÃO
--   ADD COLUMN com default constante é só metadado; o FK varre ciclos (~10 linhas) e respostas (~2 mil). Lock breve.
--   Idempotente: pode ser reexecutado.
--
-- ROLLBACK (só enquanto não existir dado de instrumento): ver bloco comentado no fim do arquivo.
-- ═══════════════════════════════════════════════════════════════════════════════════════


-- ── 1. instrumentos — catálogo de metodologias ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS instrumentos (
  metodologia  text PRIMARY KEY CHECK (metodologia ~ '^[A-Z0-9_]+$'),
  nome         text NOT NULL,
  generico     boolean NOT NULL,                 -- false = legado (questoes/resposta_itens); true = família instrumento_*
  escala_min   smallint NOT NULL,
  escala_max   smallint NOT NULL CHECK (escala_max > escala_min),
  sensivel     boolean NOT NULL DEFAULT false,
  ativo        boolean NOT NULL DEFAULT true,
  criado_em    timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE instrumentos IS
  'Catálogo de metodologias de avaliação. BS8800 = legado (tabelas próprias); as demais usam instrumento_itens/resposta_itens_instrumento. Nova metodologia = INSERT + dimensões + itens.';

INSERT INTO instrumentos (metodologia, nome, generico, escala_min, escala_max, sensivel) VALUES
  ('BS8800',     'BS 8800 (PsicoMap)',                 false, 1, 4, false),
  ('HSE_ICAO35', 'HSE Management Standards (ICAO-35)', true,  1, 5, false)
ON CONFLICT (metodologia) DO NOTHING;

ALTER TABLE instrumentos ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON instrumentos FROM anon, authenticated;
GRANT SELECT ON instrumentos TO authenticated;
DROP POLICY IF EXISTS instrumentos_select_autenticado ON instrumentos;
CREATE POLICY instrumentos_select_autenticado ON instrumentos FOR SELECT TO authenticated USING (true);


-- ── 2. instrumento_dimensoes ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS instrumento_dimensoes (
  metodologia  text NOT NULL REFERENCES instrumentos(metodologia) ON DELETE RESTRICT,
  codigo       text NOT NULL CHECK (codigo ~ '^[A-Z0-9_]+$'),
  nome         text NOT NULL,
  dominio      text,                              -- agrupamento superior (ex.: os 7 domínios do COPSOQ); NULL = sem domínio
  ordem        smallint NOT NULL,
  direcao      text NOT NULL CHECK (direcao IN ('alto_melhor', 'alto_pior')),   -- sentido NATIVO do construto
  sensivel     boolean NOT NULL DEFAULT false,    -- dimensão de saúde/ofensas: anonimato reforçado na apresentação
  PRIMARY KEY (metodologia, codigo),
  UNIQUE (metodologia, ordem)
);

COMMENT ON TABLE instrumento_dimensoes IS
  'Dimensões de cada instrumento. direcao = sentido nativo do construto (Demandas: alto_pior). A normalização para "alto = melhor" é por item (instrumento_itens.inversa).';

INSERT INTO instrumento_dimensoes (metodologia, codigo, nome, ordem, direcao) VALUES
  ('HSE_ICAO35', 'DEMANDS',         'Demandas',            1, 'alto_pior'),
  ('HSE_ICAO35', 'CONTROL',         'Controle',            2, 'alto_melhor'),
  ('HSE_ICAO35', 'MANAGER_SUPPORT', 'Apoio da gestão',     3, 'alto_melhor'),
  ('HSE_ICAO35', 'PEER_SUPPORT',    'Suporte dos colegas', 4, 'alto_melhor'),
  ('HSE_ICAO35', 'RELATIONSHIPS',   'Relacionamentos',     5, 'alto_pior'),
  ('HSE_ICAO35', 'ROLE',            'Clareza de papel',    6, 'alto_melhor'),
  ('HSE_ICAO35', 'CHANGE',          'Mudanças',            7, 'alto_melhor')
ON CONFLICT (metodologia, codigo) DO NOTHING;

ALTER TABLE instrumento_dimensoes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON instrumento_dimensoes FROM anon, authenticated;
GRANT SELECT ON instrumento_dimensoes TO authenticated;
DROP POLICY IF EXISTS instrumento_dimensoes_select_autenticado ON instrumento_dimensoes;
CREATE POLICY instrumento_dimensoes_select_autenticado ON instrumento_dimensoes FOR SELECT TO authenticated USING (true);


-- ── 3. metodologia no ciclo, na resposta e no questionário (FK para o catálogo) ─────────
ALTER TABLE ciclos    ADD COLUMN IF NOT EXISTS metodologia text NOT NULL DEFAULT 'BS8800';
ALTER TABLE respostas ADD COLUMN IF NOT EXISTS metodologia text NOT NULL DEFAULT 'BS8800';

ALTER TABLE questionarios ADD COLUMN IF NOT EXISTS metodologia text    NOT NULL DEFAULT 'BS8800';
ALTER TABLE questionarios ADD COLUMN IF NOT EXISTS versao      integer NOT NULL DEFAULT 1;
ALTER TABLE questionarios ADD COLUMN IF NOT EXISTS publicado   boolean NOT NULL DEFAULT false;
ALTER TABLE questionarios ADD COLUMN IF NOT EXISTS config      jsonb   NOT NULL DEFAULT '{}'::jsonb;

-- Antes: CHECK (metodologia IN ('BS8800','HSE_ICAO35')). Agora o catálogo manda.
ALTER TABLE ciclos        DROP CONSTRAINT IF EXISTS ciclos_metodologia_check;
ALTER TABLE respostas     DROP CONSTRAINT IF EXISTS respostas_metodologia_check;
ALTER TABLE questionarios DROP CONSTRAINT IF EXISTS questionarios_metodologia_check;
ALTER TABLE ciclos        DROP CONSTRAINT IF EXISTS ciclos_metodologia_fkey;
ALTER TABLE respostas     DROP CONSTRAINT IF EXISTS respostas_metodologia_fkey;
ALTER TABLE questionarios DROP CONSTRAINT IF EXISTS questionarios_metodologia_fkey;
ALTER TABLE ciclos        ADD CONSTRAINT ciclos_metodologia_fkey        FOREIGN KEY (metodologia) REFERENCES instrumentos(metodologia);
ALTER TABLE respostas     ADD CONSTRAINT respostas_metodologia_fkey     FOREIGN KEY (metodologia) REFERENCES instrumentos(metodologia);
ALTER TABLE questionarios ADD CONSTRAINT questionarios_metodologia_fkey FOREIGN KEY (metodologia) REFERENCES instrumentos(metodologia);

-- Alvo do FK composto de instrumento_itens: o item só pode apontar para um questionário DA MESMA metodologia.
ALTER TABLE questionarios DROP CONSTRAINT IF EXISTS questionarios_id_metodologia_key;
ALTER TABLE questionarios ADD  CONSTRAINT questionarios_id_metodologia_key UNIQUE (id, metodologia);

-- Os questionários BS 8800 já existentes continuam valendo: entram como publicados.
UPDATE questionarios SET publicado = true WHERE metodologia = 'BS8800' AND publicado = false;

COMMENT ON COLUMN ciclos.metodologia IS
  'Fonte da verdade da metodologia da campanha. Ciclo existente e link sem ciclo = BS8800. Imutável depois que há link ou resposta.';
COMMENT ON COLUMN respostas.metodologia IS
  'Snapshot da metodologia no momento do envio (respostas.ciclo_id é SET NULL se o ciclo for apagado). Gravado pela RPC salvar_resposta.';
COMMENT ON COLUMN questionarios.publicado IS
  'false = instrumento invisível para o formulário público e para o seletor de metodologia do admin. É a chave geral de cada metodologia por ambiente.';
COMMENT ON COLUMN questionarios.config IS
  'Textos do instrumento além dos itens: instruções, cabeçalho de cada parte, rótulos de escala (config.rotulos.<escala_labels>), texto LGPD, rascunho/origem. Novo texto = novo questionário.';


-- ── 4. imutabilidade da metodologia do ciclo ────────────────────────────────────────────
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


-- ── 5. instrumento_itens — perguntas dos instrumentos genéricos ─────────────────────────
CREATE TABLE IF NOT EXISTS instrumento_itens (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  questionario_id  uuid NOT NULL,
  metodologia      text NOT NULL CHECK (metodologia <> 'BS8800'),   -- BS 8800 tem as tabelas legadas
  codigo           text NOT NULL CHECK (codigo ~ '^[A-Z]{1,4}[0-9]{2,3}$'),
  ordem            smallint NOT NULL CHECK (ordem BETWEEN 1 AND 999),
  parte            smallint NOT NULL DEFAULT 1 CHECK (parte >= 1),   -- agrupamento visual (ex.: frequência / concordância)
  dimensao         text NOT NULL,
  texto            text NOT NULL,
  ajuda            text,                                             -- explicação opcional mostrada ao respondente (ver nota)
  inversa          boolean NOT NULL DEFAULT false,                   -- espelhar (N+1−v) para ficar "alto = melhor"
  escala_labels    text NOT NULL,                                    -- chave em questionarios.config.rotulos
  criado_em        timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (questionario_id, metodologia) REFERENCES questionarios (id, metodologia) ON DELETE RESTRICT,
  FOREIGN KEY (metodologia, dimensao)        REFERENCES instrumento_dimensoes (metodologia, codigo),
  UNIQUE (questionario_id, codigo),
  UNIQUE (questionario_id, ordem)
);

COMMENT ON TABLE instrumento_itens IS
  'Itens dos instrumentos genéricos. Texto congelado após a publicação do questionário: mudou uma palavra, crie outro questionário.';
COMMENT ON COLUMN instrumento_itens.ajuda IS
  'Explicação opcional por item, exibida ao respondente. Em instrumento VALIDADO só entra com revisão do autor/SST: exemplos e paráfrases podem enviesar a resposta. Congelada junto com o texto.';

CREATE OR REPLACE FUNCTION public.fn_instrumento_itens_congelados()
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
    RAISE EXCEPTION 'instrumento_itens_congelados: o questionário já foi publicado; crie uma nova versão';
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$fn$;

REVOKE ALL ON FUNCTION public.fn_instrumento_itens_congelados() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS tg_instrumento_itens_congelados ON instrumento_itens;
CREATE TRIGGER tg_instrumento_itens_congelados
  BEFORE INSERT OR UPDATE OR DELETE ON instrumento_itens
  FOR EACH ROW EXECUTE FUNCTION public.fn_instrumento_itens_congelados();

ALTER TABLE instrumento_itens ENABLE ROW LEVEL SECURITY;
-- O default do schema concede privilégios extras (TRUNCATE, TRIGGER, REFERENCES) a authenticated em
-- tabela nova; zerar antes de conceder só o necessário. Escrita só por migration/seed (dono do banco).
REVOKE ALL ON instrumento_itens FROM anon, authenticated;
GRANT SELECT ON instrumento_itens TO authenticated;

DROP POLICY IF EXISTS instrumento_itens_select_autenticado ON instrumento_itens;
CREATE POLICY instrumento_itens_select_autenticado ON instrumento_itens
  FOR SELECT TO authenticated USING (true);


-- ── 6. resposta_itens_instrumento — respostas item a item ───────────────────────────────
CREATE TABLE IF NOT EXISTS resposta_itens_instrumento (
  resposta_id  uuid NOT NULL REFERENCES respostas(id) ON DELETE CASCADE,
  item_id      uuid NOT NULL REFERENCES instrumento_itens(id) ON DELETE RESTRICT,
  valor        smallint NOT NULL CHECK (valor BETWEEN 0 AND 20),   -- faixa real validada pela RPC contra a escala do item
  PRIMARY KEY (resposta_id, item_id)
);
CREATE INDEX IF NOT EXISTS idx_resposta_itens_instrumento_item ON resposta_itens_instrumento (item_id);

COMMENT ON TABLE resposta_itens_instrumento IS
  'Valor BRUTO marcado pelo respondente; a inversão é feita só no cálculo. Escrita exclusiva da RPC salvar_resposta (SECURITY DEFINER).';

ALTER TABLE resposta_itens_instrumento ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON resposta_itens_instrumento FROM anon, authenticated;
GRANT SELECT ON resposta_itens_instrumento TO authenticated;

-- A subconsulta em `respostas` herda o RLS de `respostas` do próprio chamador (inclusive as
-- restrições do cliente_viewer), então não é preciso repetir regra de papel aqui.
DROP POLICY IF EXISTS resposta_itens_instrumento_tenant_select ON resposta_itens_instrumento;
CREATE POLICY resposta_itens_instrumento_tenant_select ON resposta_itens_instrumento
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM respostas r
     WHERE r.id = resposta_itens_instrumento.resposta_id
       AND r.tenant_id = get_my_tenant_id()
  ));

DROP POLICY IF EXISTS resposta_itens_instrumento_super_admin_select ON resposta_itens_instrumento;
CREATE POLICY resposta_itens_instrumento_super_admin_select ON resposta_itens_instrumento
  FOR SELECT TO authenticated USING (is_super_admin());


-- ── 7. instrumento_referencias — referência externa (não é dado de tenant) ──────────────
CREATE TABLE IF NOT EXISTS instrumento_referencias (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  metodologia text NOT NULL,
  fonte       text NOT NULL,                       -- ex.: 'HSE_2023'
  fonte_ano   integer,
  setor       text NOT NULL DEFAULT 'GERAL',
  dimensao    text NOT NULL,
  media       numeric(6,2),                        -- 6,2: cabe a escala 0–100 de instrumentos futuros
  p20         numeric(6,2),                        -- permanecem NULL quando a fonte oficial não os publica
  p50         numeric(6,2),
  p80         numeric(6,2),
  n_amostra   integer,
  vigente     boolean NOT NULL DEFAULT true,
  observacao  text,
  criado_em   timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (metodologia, dimensao) REFERENCES instrumento_dimensoes (metodologia, codigo),
  UNIQUE (metodologia, fonte, setor, dimensao)
);
CREATE INDEX IF NOT EXISTS idx_instrumento_referencias_lookup ON instrumento_referencias (metodologia, vigente, setor, dimensao);

ALTER TABLE instrumento_referencias ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON instrumento_referencias FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON instrumento_referencias TO authenticated;   -- as policies restringem a escrita a super_admin

DROP POLICY IF EXISTS instrumento_referencias_select_autenticado ON instrumento_referencias;
CREATE POLICY instrumento_referencias_select_autenticado ON instrumento_referencias
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS instrumento_referencias_super_admin_write ON instrumento_referencias;
CREATE POLICY instrumento_referencias_super_admin_write ON instrumento_referencias
  FOR ALL TO authenticated USING (is_super_admin()) WITH CHECK (is_super_admin());


-- ── Verificação (rodar depois de aplicar) ───────────────────────────────────────────────
-- Colunas novas existem e todo o histórico ficou BS8800:
--   SELECT 'ciclos' t, metodologia, count(*) FROM ciclos GROUP BY 2
--   UNION ALL SELECT 'respostas', metodologia, count(*) FROM respostas GROUP BY 2
--   UNION ALL SELECT 'questionarios', metodologia||' publicado='||publicado, count(*) FROM questionarios GROUP BY 2;
-- Catálogo e dimensões:
--   SELECT * FROM instrumentos;   SELECT metodologia, count(*) FROM instrumento_dimensoes GROUP BY 1;   -- HSE_ICAO35 | 7
-- Nenhum privilégio para anon nas tabelas novas (esperado: 0 linhas):
--   SELECT table_name, privilege_type FROM information_schema.role_table_grants
--    WHERE grantee='anon' AND table_name IN ('instrumentos','instrumento_dimensoes','instrumento_itens','resposta_itens_instrumento','instrumento_referencias');
-- Policies:
--   SELECT tablename, policyname, cmd FROM pg_policies
--    WHERE tablename IN ('instrumentos','instrumento_dimensoes','instrumento_itens','resposta_itens_instrumento','instrumento_referencias') ORDER BY 1,2;
-- Teste da trava (em transação com ROLLBACK):
--   BEGIN; INSERT INTO ciclos(empresa_id,nome,tenant_id) SELECT id,'t',tenant_id FROM empresas LIMIT 1 RETURNING id; ...
--   -- depois: UPDATE ciclos SET metodologia='HSE_ICAO35' WHERE id=<id>;  (ok, sem link) ... ROLLBACK;

-- ── ROLLBACK (só enquanto não existir dado de instrumento) ──────────────────────────────
-- DROP TABLE IF EXISTS resposta_itens_instrumento;
-- DROP TABLE IF EXISTS instrumento_itens;
-- DROP TABLE IF EXISTS instrumento_referencias;
-- DROP FUNCTION IF EXISTS public.fn_instrumento_itens_congelados();
-- DROP TRIGGER IF EXISTS tg_ciclo_metodologia_imutavel ON ciclos;
-- DROP FUNCTION IF EXISTS public.fn_ciclo_metodologia_imutavel();
-- ALTER TABLE questionarios DROP CONSTRAINT IF EXISTS questionarios_id_metodologia_key,
--   DROP CONSTRAINT IF EXISTS questionarios_metodologia_fkey;
-- ALTER TABLE respostas DROP CONSTRAINT IF EXISTS respostas_metodologia_fkey;
-- ALTER TABLE ciclos    DROP CONSTRAINT IF EXISTS ciclos_metodologia_fkey;
-- DROP TABLE IF EXISTS instrumento_dimensoes;
-- DROP TABLE IF EXISTS instrumentos;
-- ALTER TABLE questionarios DROP COLUMN IF EXISTS config, DROP COLUMN IF EXISTS publicado,
--   DROP COLUMN IF EXISTS versao, DROP COLUMN IF EXISTS metodologia;
-- ALTER TABLE respostas DROP COLUMN IF EXISTS metodologia;
-- ALTER TABLE ciclos    DROP COLUMN IF EXISTS metodologia;
