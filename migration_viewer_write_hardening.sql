-- migration_viewer_write_hardening.sql
-- Estende o hardening RBAC do viewer para cobrir INSERT e DELETE,
-- além do UPDATE já coberto por migration_rbac_viewer_hardening.sql.
-- Padrão: RESTRICTIVE FOR <op> USING/WITH CHECK (auth_role() <> 'cliente_viewer')
-- Aplicar em DEV primeiro, depois PROD.

-- ── links_coleta ─────────────────────────────────────────────────────────────
CREATE POLICY viewer_no_insert_links ON links_coleta
  AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (auth_role() <> 'cliente_viewer');

CREATE POLICY viewer_no_delete_links ON links_coleta
  AS RESTRICTIVE FOR DELETE TO authenticated
  USING (auth_role() <> 'cliente_viewer');

-- ── laudos ───────────────────────────────────────────────────────────────────
CREATE POLICY viewer_no_insert_laudos ON laudos
  AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (auth_role() <> 'cliente_viewer');

CREATE POLICY viewer_no_delete_laudos ON laudos
  AS RESTRICTIVE FOR DELETE TO authenticated
  USING (auth_role() <> 'cliente_viewer');

-- ── empresa_headcount ────────────────────────────────────────────────────────
-- UPDATE já coberto por migration_rbac_viewer_hardening; adiciona INSERT e DELETE.
CREATE POLICY viewer_no_insert_headcount ON empresa_headcount
  AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (auth_role() <> 'cliente_viewer');

CREATE POLICY viewer_no_delete_headcount ON empresa_headcount
  AS RESTRICTIVE FOR DELETE TO authenticated
  USING (auth_role() <> 'cliente_viewer');

-- ── ciclos ───────────────────────────────────────────────────────────────────
CREATE POLICY viewer_no_insert_ciclos ON ciclos
  AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (auth_role() <> 'cliente_viewer');

CREATE POLICY viewer_no_delete_ciclos ON ciclos
  AS RESTRICTIVE FOR DELETE TO authenticated
  USING (auth_role() <> 'cliente_viewer');

-- ── empresas: viewer só vê sua própria empresa ───────────────────────────────
-- Sem esta policy, viewer lê todas as empresas do tenant (gap descoberto em teste).
-- get_my_empresa_id() já existe (criada em migration_viewer_empresa_scope.sql).
CREATE POLICY viewer_empresa_select_empresas ON empresas
  AS RESTRICTIVE FOR SELECT TO authenticated
  USING (
    auth_role() <> 'cliente_viewer'
    OR id = get_my_empresa_id()
  );

-- ── Verificação pós-aplicação ────────────────────────────────────────────────
-- Confirmar as 9 novas policies:
-- SELECT policyname, tablename, cmd
-- FROM pg_policies
-- WHERE policyname LIKE 'viewer_no_%' OR policyname = 'viewer_empresa_select_empresas'
-- ORDER BY tablename, cmd;
