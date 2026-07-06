-- ══════════════════════════════════════════════════════════════════════
-- migration_viewer_empresa_scope.sql
-- Isolamento de dados do cliente_viewer por empresa_id
-- Aplicado em DEV e PROD em 2026-07-06
-- ══════════════════════════════════════════════════════════════════════

-- Função auxiliar: retorna empresa_id do usuário logado
CREATE OR REPLACE FUNCTION get_my_empresa_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT empresa_id FROM public.perfis WHERE id = auth.uid() LIMIT 1;
$$;

-- ── RESTRICTIVE SELECT para cliente_viewer ────────────────────────────
-- Lógica: se NÃO for viewer → passa (outras policies decidem)
--         se FOR viewer     → só passa se empresa_id = get_my_empresa_id()
--
-- Combina com as policies auth_select_* existentes (AND lógico):
--   auth_select filtra por tenant_id  →  esta filtra por empresa_id
--   resultado: viewer vê apenas dados da sua empresa específica.
-- ─────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "viewer_empresa_select_ciclos" ON ciclos;
CREATE POLICY "viewer_empresa_select_ciclos" ON ciclos
  AS RESTRICTIVE FOR SELECT TO authenticated
  USING (
    (SELECT role FROM public.perfis WHERE id = auth.uid()) <> 'cliente_viewer'
    OR empresa_id = get_my_empresa_id()
  );

DROP POLICY IF EXISTS "viewer_empresa_select_laudos" ON laudos;
CREATE POLICY "viewer_empresa_select_laudos" ON laudos
  AS RESTRICTIVE FOR SELECT TO authenticated
  USING (
    (SELECT role FROM public.perfis WHERE id = auth.uid()) <> 'cliente_viewer'
    OR empresa_id = get_my_empresa_id()
  );

DROP POLICY IF EXISTS "viewer_empresa_select_respostas" ON respostas;
CREATE POLICY "viewer_empresa_select_respostas" ON respostas
  AS RESTRICTIVE FOR SELECT TO authenticated
  USING (
    (SELECT role FROM public.perfis WHERE id = auth.uid()) <> 'cliente_viewer'
    OR empresa_id = get_my_empresa_id()
  );

DROP POLICY IF EXISTS "viewer_empresa_select_links" ON links_coleta;
CREATE POLICY "viewer_empresa_select_links" ON links_coleta
  AS RESTRICTIVE FOR SELECT TO authenticated
  USING (
    (SELECT role FROM public.perfis WHERE id = auth.uid()) <> 'cliente_viewer'
    OR empresa_id = get_my_empresa_id()
  );

DROP POLICY IF EXISTS "viewer_empresa_select_setores" ON empresa_setores;
CREATE POLICY "viewer_empresa_select_setores" ON empresa_setores
  AS RESTRICTIVE FOR SELECT TO authenticated
  USING (
    (SELECT role FROM public.perfis WHERE id = auth.uid()) <> 'cliente_viewer'
    OR empresa_id = get_my_empresa_id()
  );

DROP POLICY IF EXISTS "viewer_empresa_select_funcoes" ON empresa_funcoes;
CREATE POLICY "viewer_empresa_select_funcoes" ON empresa_funcoes
  AS RESTRICTIVE FOR SELECT TO authenticated
  USING (
    (SELECT role FROM public.perfis WHERE id = auth.uid()) <> 'cliente_viewer'
    OR empresa_id = get_my_empresa_id()
  );
