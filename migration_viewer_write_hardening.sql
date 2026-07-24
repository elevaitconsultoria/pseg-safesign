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

-- ── Verificação pós-aplicação ────────────────────────────────────────────────
-- Confirmar que as 8 novas policies existem:
-- SELECT policyname, tablename, cmd, qual
-- FROM pg_policies
-- WHERE policyname LIKE 'viewer_no_%'
-- ORDER BY tablename, cmd;
