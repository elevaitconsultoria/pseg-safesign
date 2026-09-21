-- ══════════════════════════════════════════════════════════════════════════
-- PsicoMap — Presets de filtro por empresa e tela
-- Executar no Supabase Dashboard → SQL Editor (ou via MCP apply_migration)
-- Ordem: DEV (szqatgvgghxvyyncsjxl) primeiro, PROD (vftyiildukrpgmnbcnao) depois
-- ══════════════════════════════════════════════════════════════════════════
--
-- PROBLEMA QUE RESOLVE:
-- O consultor monta um recorte na tela (setores, funções, níveis, agrupamentos,
-- GHE, ciclo, segmentação, granularidade) para produzir uma entrega específica —
-- e não há como guardá-lo. Para repetir, refaz tudo à mão. O histórico de laudos
-- cobre o caso "reaplicar o que eu gerei"; isto cobre "guardar um recorte que eu
-- uso sempre", inclusive nas telas de Resultados e Gráficos, que não geram laudo.
--
-- ESCOPO POR EMPRESA:
-- Mesma decisão de empresa_apelidos e grupos_setor. Os valores guardados são
-- nomes de setor/cargo/agrupamento daquela empresa; aplicá-los em outra não
-- selecionaria nada, e o preset apareceria como quebrado.
--
-- POR QUE `config` É JSONB E NÃO COLUNAS:
-- O conjunto de filtros de cada tela muda com frequência (três combos novos
-- entraram em 2026-08 e 2026-09). Uma coluna por filtro exigiria migration a
-- cada combo. O frontend já trata config ausente ou parcial: aplicar um preset
-- só seleciona o que ainda existe na tela e NOMEIA o que não pôde restaurar.
--
-- ORDEM DE DEPLOY: esta migration pode ir antes ou depois do HTML.
-- `carregarPresets()` falha aberto (tabela ausente → lista vazia, nenhum erro
-- visível), e o card de presets só aparece quando há algo a mostrar ou salvar.
--
-- IMPACTO EM PRODUÇÃO: zero — tabela nova, sem dados.

CREATE TABLE IF NOT EXISTS filtro_presets (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id    uuid        NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  tenant_id     uuid        NOT NULL REFERENCES tenants(id)  ON DELETE CASCADE,
  tela          text        NOT NULL CHECK (tela IN ('resultados', 'graficos', 'laudo')),
  nome          text        NOT NULL,
  config        jsonb       NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(config) = 'object'),
  criado_por    text,
  criado_em     timestamptz NOT NULL DEFAULT now(),
  atualizado_em timestamptz NOT NULL DEFAULT now()
);

-- Um nome por tela por empresa. lower() e não uma normalização mais forte porque,
-- ao contrário de empresa_apelidos, aqui o nome é digitado pelo próprio consultor
-- nesta tela — não vem de planilha de terceiro — e o frontend faz o upsert pelo
-- mesmo critério (comparação case-insensitive antes de gravar).
CREATE UNIQUE INDEX IF NOT EXISTS uq_filtro_presets_nome
  ON filtro_presets (empresa_id, tela, lower(nome));

CREATE INDEX IF NOT EXISTS idx_filtro_presets_tenant ON filtro_presets (tenant_id);

ALTER TABLE filtro_presets ENABLE ROW LEVEL SECURITY;

-- GRANT: sem isso o Postgres bloqueia antes de checar RLS e as policies ficam
-- invisíveis (achado real na criação de grupos_setor).
GRANT SELECT, INSERT, UPDATE, DELETE ON filtro_presets TO authenticated;

-- REVOKE explícito do anon — NÃO é redundante em PROD: o schema public de PROD
-- tem ALTER DEFAULT PRIVILEGES concedendo ALL ao anon em toda tabela nova (DEV
-- não tem). Sem isto a tabela nasce em PROD com CRUD completo para o papel
-- anônimo e o RLS vira a única linha de defesa. Nenhum consumidor anônimo
-- existe: o formulário público não lê esta tabela.
REVOKE ALL ON filtro_presets FROM anon;

-- SELECT: qualquer membro autenticado do tenant (inclui cliente_viewer, que usa
-- as telas de análise e laudo em modo leitura).
-- OR is_super_admin(): super_admin tem tenant_id NULL — sem isso a comparação falha.
DROP POLICY IF EXISTS "filtro_presets_select" ON filtro_presets;
CREATE POLICY "filtro_presets_select" ON filtro_presets
  FOR SELECT TO authenticated
  USING (tenant_id = get_my_tenant_id() OR is_super_admin());

-- WRITE: admin, consultor e super_admin. Viewer lê e aplica, não cria nem apaga
-- — mesma fronteira de grupos_setor.
DROP POLICY IF EXISTS "filtro_presets_write" ON filtro_presets;
CREATE POLICY "filtro_presets_write" ON filtro_presets
  FOR ALL TO authenticated
  USING (
    (tenant_id = get_my_tenant_id() AND auth_role() IN ('admin', 'consultor'))
    OR is_super_admin()
  )
  WITH CHECK (
    (tenant_id = get_my_tenant_id() AND auth_role() IN ('admin', 'consultor'))
    OR is_super_admin()
  );

COMMENT ON TABLE filtro_presets IS
  'Recortes de filtro nomeados, por empresa e por tela (resultados/graficos/laudo). '
  'Apenas configuração de UI: não afeta respostas, catálogo nem laudos gerados.';
COMMENT ON COLUMN filtro_presets.config IS
  'Objeto com as chaves que a tela sabe restaurar: filtros (id do combo → array de '
  'valores selecionados), ciclo_id, e o que for específico da tela (segmentacao em '
  'resultados; granularidade e secoes em laudo). Aplicar só seleciona o que ainda '
  'existe na tela — o frontend nomeia o que não pôde restaurar.';

-- ── Verificação ──────────────────────────────────────────────────────────────
SELECT tablename, policyname, cmd FROM pg_policies
WHERE tablename = 'filtro_presets' ORDER BY policyname;

SELECT grantee, privilege_type FROM information_schema.role_table_grants
WHERE table_name = 'filtro_presets' ORDER BY grantee, privilege_type;
