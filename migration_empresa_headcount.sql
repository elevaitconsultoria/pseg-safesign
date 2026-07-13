-- ══════════════════════════════════════════════════════════════════════
-- migration_empresa_headcount.sql
-- Headcount de funcionários por setor/função para cálculo de representatividade
-- Aplicar em DEV e PROD
-- ══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS empresa_headcount (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id  uuid NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  tenant_id   uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  setor       text NOT NULL,
  funcao      text,                           -- NULL = headcount total do setor (sem distinção de função)
  quantidade  int  NOT NULL CHECK (quantidade >= 0),
  criado_em   timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_empresa_headcount
  ON empresa_headcount (empresa_id, setor, COALESCE(funcao, ''));

-- RLS
ALTER TABLE empresa_headcount ENABLE ROW LEVEL SECURITY;

-- SELECT: qualquer membro do tenant (inclui viewer — útil para painel de adesão)
CREATE POLICY "auth_select_empresa_headcount" ON empresa_headcount
  FOR SELECT TO authenticated
  USING (tenant_id = get_my_tenant_id());

-- INSERT / UPDATE: admin e consultor do tenant
CREATE POLICY "auth_insert_empresa_headcount" ON empresa_headcount
  FOR INSERT TO authenticated
  WITH CHECK (tenant_id = get_my_tenant_id());

CREATE POLICY "auth_update_empresa_headcount" ON empresa_headcount
  FOR UPDATE TO authenticated
  USING  (tenant_id = get_my_tenant_id())
  WITH CHECK (tenant_id = get_my_tenant_id());

-- DELETE: admin e consultor do tenant
CREATE POLICY "auth_delete_empresa_headcount" ON empresa_headcount
  FOR DELETE TO authenticated
  USING (tenant_id = get_my_tenant_id());

-- Viewer não escreve (RESTRICTIVE, mesmo padrão das outras tabelas)
CREATE POLICY "viewer_readonly_empresa_headcount" ON empresa_headcount
  AS RESTRICTIVE FOR UPDATE TO authenticated
  USING  ((SELECT role FROM public.perfis WHERE id = auth.uid()) <> 'cliente_viewer')
  WITH CHECK ((SELECT role FROM public.perfis WHERE id = auth.uid()) <> 'cliente_viewer');

-- Viewer scoped por empresa_id (RESTRICTIVE SELECT — mesma lógica de ciclos/laudos)
CREATE POLICY "viewer_empresa_select_headcount" ON empresa_headcount
  AS RESTRICTIVE FOR SELECT TO authenticated
  USING (
    (SELECT role FROM public.perfis WHERE id = auth.uid()) <> 'cliente_viewer'
    OR empresa_id = get_my_empresa_id()
  );
