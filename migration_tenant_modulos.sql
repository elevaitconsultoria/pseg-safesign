-- ══════════════════════════════════════════════════════════════════════════
-- PsicoMap — Módulos habilitados por EST (feature flags por tenant)
-- Executar no Supabase Dashboard → SQL Editor (ou via MCP apply_migration)
-- Ordem: DEV (szqatgvgghxvyyncsjxl) primeiro, PROD (vftyiildukrpgmnbcnao) depois
-- ══════════════════════════════════════════════════════════════════════════
--
-- POR QUE UMA TABELA SEPARADA (e não uma coluna em `tenants`):
-- a policy `tenant_update_admin` (psicomap-phase3-saas-tenants.sql) permite que o
-- admin da própria EST faça UPDATE na linha dela em `tenants`. Se os flags
-- morassem lá, o admin do cliente religaria os módulos via API, por fora da UI.
-- Aqui a escrita é exclusiva de super_admin.
--
-- SEMÂNTICA — ausência de linha = módulo HABILITADO.
-- Só existe linha quando o módulo é desligado (ou foi desligado e religado).
-- Consequências: nenhum seed necessário para as ESTs existentes; EST nova nasce
-- com tudo ligado; módulo novo no código aparece para todos por padrão.
--
-- ESCOPO: o gate no frontend é client-side (visual). Serve para módulos ainda
-- imaturos, não como fronteira de segurança. Bloqueio real exigiria policies
-- RESTRICTIVE nas tabelas de dados de cada módulo.

CREATE TABLE IF NOT EXISTS tenant_modulos (
  tenant_id   uuid    NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  modulo      text    NOT NULL,
  habilitado  boolean NOT NULL DEFAULT true,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  updated_by  uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  PRIMARY KEY (tenant_id, modulo)
);

ALTER TABLE tenant_modulos ENABLE ROW LEVEL SECURITY;

-- ── Leitura: qualquer usuário do tenant ───────────────────────────────────
-- Necessária para o boot do admin aplicar os flags. O `OR is_super_admin()`
-- existe porque super_admin tem tenant_id NULL — sem ele, get_my_tenant_id()
-- retorna NULL e a comparação nunca casa (modal de configuração viria vazio).
DROP POLICY IF EXISTS "modulos_select_tenant" ON tenant_modulos;
CREATE POLICY "modulos_select_tenant" ON tenant_modulos
  FOR SELECT TO authenticated
  USING (tenant_id = get_my_tenant_id() OR is_super_admin());

-- ── Escrita: exclusivamente super_admin ───────────────────────────────────
DROP POLICY IF EXISTS "modulos_write_super_admin" ON tenant_modulos;
CREATE POLICY "modulos_write_super_admin" ON tenant_modulos
  FOR ALL TO authenticated
  USING (is_super_admin())
  WITH CHECK (is_super_admin());

COMMENT ON TABLE tenant_modulos IS
  'Módulos habilitados por EST. Ausência de linha = habilitado. Escrita só por super_admin.';
COMMENT ON COLUMN tenant_modulos.modulo IS
  'Id do módulo, espelha MODULOS_CATALOGO em psicomap-admin.html (laudo, adesao, plano, riscos, comparativo, auditoria, graficos, links).';

-- ── VERIFICAÇÃO ───────────────────────────────────────────────────────────
SELECT tablename, policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'tenant_modulos'
ORDER BY policyname;
