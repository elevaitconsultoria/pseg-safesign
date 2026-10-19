-- ══════════════════════════════════════════════════════════════════════════
-- PsicoMap — Dados editáveis do laudo `padrao_pseg2.0` (3 escopos numa tabela)
-- Executar no Supabase Dashboard → SQL Editor (ou via MCP apply_migration)
-- Ordem: DEV (szqatgvgghxvyyncsjxl) primeiro, PROD (vftyiildukrpgmnbcnao) depois
-- ══════════════════════════════════════════════════════════════════════════
--
-- PROBLEMA QUE RESOLVE:
-- O novo modelo de laudo (padrao_pseg2.0) pede informações que não têm cadastro:
-- CNAE, grau de risco, ramo de atuação, descrição do local, controle de revisões,
-- elaboradores com mini-currículo, telefone/e-mail/site do rodapé. Sem onde
-- guardá-las o consultor redigitaria tudo a cada geração.
--
-- POR QUE UMA TABELA E NÃO COLUNAS EM `empresas` / `est_perfil`:
-- `empresas` é legível pelo papel `anon` (embed do formulário público) e GRANT é
-- por tabela, não por coluna — qualquer coluna nova ali ficaria exposta à chave
-- pública. Dados de elaboradores (CREA/CRP, contatos, currículos) e da empresa
-- não devem ter essa superfície. Esta tabela nasce sem nenhum GRANT para anon.
--
-- ESCOPOS (`escopo`):
--   'est'     → por consultoria (tenant): cabeçalho/rodapé, elaboradores, currículos.
--   'empresa' → por empresa: CNAE, grau de risco, ramo, local, título de cada GES.
--   'ciclo'   → por empresa + ciclo: revisões, período, textos padrão editados.
--
-- POR QUE `dados` É JSONB: o conjunto de campos do laudo muda com o modelo
-- (mesma decisão de filtro_presets.config). O frontend trata ausência e
-- campos parciais.
--
-- ORDEM DE DEPLOY: esta migration pode ir antes ou depois do HTML.
-- carregarLaudoDados() falha aberto (tabela ausente → defaults, sem erro visível)
-- e o salvar avisa "ainda não disponível neste ambiente".
--
-- IMPACTO EM PRODUÇÃO: zero — tabela nova, sem dados.

CREATE TABLE IF NOT EXISTS laudo_dados (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id      uuid        NOT NULL REFERENCES tenants(id)  ON DELETE CASCADE,
  escopo         text        NOT NULL CHECK (escopo IN ('est', 'empresa', 'ciclo')),
  empresa_id     uuid        REFERENCES empresas(id) ON DELETE CASCADE,
  ciclo_id       uuid        REFERENCES ciclos(id)   ON DELETE CASCADE,
  template       text        NOT NULL DEFAULT 'padrao_pseg2.0',
  dados          jsonb       NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(dados) = 'object'),
  atualizado_por text,
  atualizado_em  timestamptz NOT NULL DEFAULT now(),
  -- Coerência escopo × chaves: impede um registro 'est' pendurado numa empresa, ou
  -- um 'ciclo' sem empresa, que nenhuma leitura encontraria.
  CONSTRAINT ck_laudo_dados_escopo CHECK (
    (escopo = 'est'     AND empresa_id IS NULL     AND ciclo_id IS NULL) OR
    (escopo = 'empresa' AND empresa_id IS NOT NULL AND ciclo_id IS NULL) OR
    (escopo = 'ciclo'   AND empresa_id IS NOT NULL AND ciclo_id IS NOT NULL)
  )
);

-- Uma linha por (tenant, escopo, empresa, ciclo, template). COALESCE porque NULL não
-- colide em índice único comum e o escopo 'est' tem os dois nulos.
CREATE UNIQUE INDEX IF NOT EXISTS uq_laudo_dados_chave
  ON laudo_dados (
    tenant_id, escopo, template,
    COALESCE(empresa_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(ciclo_id,   '00000000-0000-0000-0000-000000000000'::uuid)
  );

CREATE INDEX IF NOT EXISTS idx_laudo_dados_empresa ON laudo_dados (empresa_id);

ALTER TABLE laudo_dados ENABLE ROW LEVEL SECURITY;

-- GRANT: sem isso o Postgres bloqueia antes de checar RLS (achado real em grupos_setor).
GRANT SELECT, INSERT, UPDATE, DELETE ON laudo_dados TO authenticated;

-- REVOKE explícito do anon — NÃO é redundante em PROD (ALTER DEFAULT PRIVILEGES concede
-- ALL ao anon em toda tabela nova; DEV não tem). O formulário público não lê esta tabela.
REVOKE ALL ON laudo_dados FROM anon;

-- SELECT: qualquer membro do tenant (inclui cliente_viewer, que gera/visualiza o laudo).
-- OR is_super_admin(): super_admin tem tenant_id NULL.
DROP POLICY IF EXISTS "laudo_dados_select" ON laudo_dados;
CREATE POLICY "laudo_dados_select" ON laudo_dados
  FOR SELECT TO authenticated
  USING (tenant_id = get_my_tenant_id() OR is_super_admin());

-- ESCRITA, três policies (nunca FOR ALL num caso restritivo — aqui são PERMISSIVE, então
-- viewer simplesmente não casa nenhuma e fica bloqueado).
--   · escopo 'est' (cabeçalho, rodapé, elaboradores): só admin da EST e super_admin —
--     mesma fronteira de est_perfil.
--   · escopos 'empresa' e 'ciclo': admin e consultor (quem monta o laudo).
DROP POLICY IF EXISTS "laudo_dados_insert" ON laudo_dados;
CREATE POLICY "laudo_dados_insert" ON laudo_dados
  FOR INSERT TO authenticated
  WITH CHECK (
    is_super_admin()
    OR (tenant_id = get_my_tenant_id() AND (
         (escopo = 'est' AND auth_role() = 'admin')
         OR (escopo IN ('empresa', 'ciclo') AND auth_role() IN ('admin', 'consultor'))
       ))
  );

DROP POLICY IF EXISTS "laudo_dados_update" ON laudo_dados;
CREATE POLICY "laudo_dados_update" ON laudo_dados
  FOR UPDATE TO authenticated
  USING (
    is_super_admin()
    OR (tenant_id = get_my_tenant_id() AND (
         (escopo = 'est' AND auth_role() = 'admin')
         OR (escopo IN ('empresa', 'ciclo') AND auth_role() IN ('admin', 'consultor'))
       ))
  )
  WITH CHECK (
    is_super_admin()
    OR (tenant_id = get_my_tenant_id() AND (
         (escopo = 'est' AND auth_role() = 'admin')
         OR (escopo IN ('empresa', 'ciclo') AND auth_role() IN ('admin', 'consultor'))
       ))
  );

DROP POLICY IF EXISTS "laudo_dados_delete" ON laudo_dados;
CREATE POLICY "laudo_dados_delete" ON laudo_dados
  FOR DELETE TO authenticated
  USING (
    is_super_admin()
    OR (tenant_id = get_my_tenant_id() AND (
         (escopo = 'est' AND auth_role() = 'admin')
         OR (escopo IN ('empresa', 'ciclo') AND auth_role() IN ('admin', 'consultor'))
       ))
  );

-- VERIFICAÇÃO (rodar após aplicar):
--   SELECT has_table_privilege('anon', 'laudo_dados', 'SELECT');   -- esperado: false
--   SELECT polname FROM pg_policy WHERE polrelid = 'laudo_dados'::regclass;  -- 4 policies
