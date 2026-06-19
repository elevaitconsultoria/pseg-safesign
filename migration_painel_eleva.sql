-- ══════════════════════════════════════════════════════════════════════════
-- PSEG SafeSign — Migração 7: Painel Eleva IT (super_admin cross-tenant)
-- Executar no Supabase Dashboard → SQL Editor
-- ══════════════════════════════════════════════════════════════════════════

-- ── 1. RLS bypass super_admin nas tabelas principais ─────────────────────

-- empresas
DROP POLICY IF EXISTS "empresas_super_admin_all" ON empresas;
CREATE POLICY "empresas_super_admin_all" ON empresas
  FOR ALL TO authenticated
  USING (is_super_admin())
  WITH CHECK (is_super_admin());

-- ciclos
DROP POLICY IF EXISTS "ciclos_super_admin_all" ON ciclos;
CREATE POLICY "ciclos_super_admin_all" ON ciclos
  FOR ALL TO authenticated
  USING (is_super_admin())
  WITH CHECK (is_super_admin());

-- links_coleta
DROP POLICY IF EXISTS "links_super_admin_all" ON links_coleta;
CREATE POLICY "links_super_admin_all" ON links_coleta
  FOR ALL TO authenticated
  USING (is_super_admin())
  WITH CHECK (is_super_admin());

-- empresa_setores
DROP POLICY IF EXISTS "setores_super_admin_all" ON empresa_setores;
CREATE POLICY "setores_super_admin_all" ON empresa_setores
  FOR ALL TO authenticated
  USING (is_super_admin())
  WITH CHECK (is_super_admin());

-- empresa_funcoes
DROP POLICY IF EXISTS "funcoes_super_admin_all" ON empresa_funcoes;
CREATE POLICY "funcoes_super_admin_all" ON empresa_funcoes
  FOR ALL TO authenticated
  USING (is_super_admin())
  WITH CHECK (is_super_admin());

-- ── 2. RPC: estatísticas agregadas cross-tenant para o painel Eleva IT ───
CREATE OR REPLACE FUNCTION super_admin_stats()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
DECLARE
  result jsonb;
BEGIN
  -- Apenas super_admin pode chamar esta função
  IF (SELECT role FROM perfis WHERE id = auth.uid() LIMIT 1) <> 'super_admin' THEN
    RAISE EXCEPTION 'Acesso negado';
  END IF;

  SELECT jsonb_build_object(
    'total_ests',       (SELECT COUNT(*) FROM tenants),
    'ests_ativas',      (SELECT COUNT(*) FROM tenants WHERE ativo = true),
    'total_usuarios',   (SELECT COUNT(*) FROM perfis WHERE role IN ('admin','consultor')),
    'total_clientes',   (SELECT COUNT(*) FROM empresas WHERE ativo = true),
    'total_respostas',  (SELECT COUNT(*) FROM respostas),
    'respostas_mes',    (SELECT COUNT(*) FROM respostas
                          WHERE respondido_em >= date_trunc('month', now())),
    'links_ativos',     (SELECT COUNT(*) FROM links_coleta WHERE ativo = true)
  ) INTO result;

  RETURN result;
END;
$$;

-- ── 3. RPC: dados detalhados por tenant para o painel ────────────────────
DROP FUNCTION IF EXISTS super_admin_tenant_details();

CREATE OR REPLACE FUNCTION super_admin_tenant_details()
RETURNS TABLE (
  t_id             uuid,
  nome             text,
  slug             text,
  ativo            boolean,
  created_at       timestamptz,
  usuarios         bigint,
  clientes         bigint,
  links_ativos     bigint,
  respostas        bigint,
  ultima_resposta  timestamptz
)
LANGUAGE sql SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
  SELECT
    t.id,
    t.nome,
    t.slug,
    COALESCE(t.ativo, true),
    t.created_at,
    COUNT(DISTINCT p.id)  FILTER (WHERE p.role IN ('admin','consultor')),
    COUNT(DISTINCT e.id)  FILTER (WHERE e.ativo = true),
    COUNT(DISTINCT lc.id) FILTER (WHERE lc.ativo = true),
    COUNT(DISTINCT r.id),
    MAX(r.respondido_em)
  FROM tenants t
  LEFT JOIN perfis         p  ON p.tenant_id = t.id
  LEFT JOIN empresas       e  ON e.tenant_id = t.id
  LEFT JOIN links_coleta   lc ON lc.tenant_id = t.id
  LEFT JOIN respostas      r  ON r.link_token IN (
    SELECT lc2.token FROM links_coleta lc2 WHERE lc2.tenant_id = t.id
  )
  GROUP BY t.id, t.nome, t.slug, t.ativo, t.created_at
  ORDER BY t.created_at DESC;
$$;

-- ── VERIFICAÇÃO ───────────────────────────────────────────────────────────
SELECT super_admin_stats();
