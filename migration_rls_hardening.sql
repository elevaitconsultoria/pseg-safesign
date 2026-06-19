-- ══════════════════════════════════════════════════════════════════════════
-- PSEG SafeSign — Migração 8: Hardening de RLS
-- Executar no Supabase Dashboard → SQL Editor
-- ══════════════════════════════════════════════════════════════════════════

-- ── 1. Restringir políticas públicas ao escopo de links ativos ────────────
--
-- As policies pub_read_* foram criadas para o formulário público (respondentes).
-- Antes: expunham TODOS os dados de TODOS os tenants via API anon.
-- Depois: expõem apenas dados vinculados a um link ativo — sem cruzar tenants.

-- ciclos: antes era "true" (todos os ciclos de todos os tenants)
DROP POLICY IF EXISTS "pub_read_ciclos" ON ciclos;
CREATE POLICY "pub_read_ciclos" ON ciclos
  FOR SELECT
  USING (
    id IN (
      SELECT ciclo_id FROM links_coleta
      WHERE ativo = true AND ciclo_id IS NOT NULL
    )
  );

-- empresas: antes era "ativo = true" (todas as empresas ativas de todos os tenants)
DROP POLICY IF EXISTS "pub_read_empresa_ativa" ON empresas;
CREATE POLICY "pub_read_empresa_ativa" ON empresas
  FOR SELECT
  USING (
    ativo = true
    AND id IN (SELECT empresa_id FROM links_coleta WHERE ativo = true)
  );

-- empresa_setores: antes era "ativo = true" (todos os setores de todos os tenants)
DROP POLICY IF EXISTS "pub_read_empresa_setores" ON empresa_setores;
CREATE POLICY "pub_read_empresa_setores" ON empresa_setores
  FOR SELECT
  USING (
    ativo = true
    AND empresa_id IN (SELECT empresa_id FROM links_coleta WHERE ativo = true)
  );

-- empresa_funcoes: antes era "ativo = true" (todas as funções de todos os tenants)
DROP POLICY IF EXISTS "pub_read_empresa_funcoes" ON empresa_funcoes;
CREATE POLICY "pub_read_empresa_funcoes" ON empresa_funcoes
  FOR SELECT
  USING (
    ativo = true
    AND empresa_id IN (SELECT empresa_id FROM links_coleta WHERE ativo = true)
  );

-- ── 2. super_admin bypass na tabela tenants ───────────────────────────────
-- Sem isso, toggleAtivoEST() retorna 0 linhas (super_admin tem tenant_id NULL)

DROP POLICY IF EXISTS "tenants_super_admin_all" ON tenants;
CREATE POLICY "tenants_super_admin_all" ON tenants
  FOR ALL TO authenticated
  USING (is_super_admin())
  WITH CHECK (is_super_admin());

-- ── VERIFICAÇÃO ───────────────────────────────────────────────────────────
-- Confirmar policies atualizadas
SELECT tablename, policyname, cmd, qual
FROM pg_policies
WHERE tablename IN ('ciclos','empresas','empresa_setores','empresa_funcoes','tenants')
  AND policyname IN (
    'pub_read_ciclos','pub_read_empresa_ativa',
    'pub_read_empresa_setores','pub_read_empresa_funcoes',
    'tenants_super_admin_all'
  )
ORDER BY tablename, policyname;
