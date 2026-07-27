-- ══════════════════════════════════════════════════════════════════════════
-- PsicoMap — Migração 5: Roles internos (admin | consultor)
-- Executar no Supabase Dashboard → SQL Editor
-- ══════════════════════════════════════════════════════════════════════════

-- ── 1. Adicionar coluna role em perfis ───────────────────────────────────
ALTER TABLE perfis
  ADD COLUMN IF NOT EXISTS role text NOT NULL DEFAULT 'admin'
  CHECK (role IN ('admin', 'consultor'));

COMMENT ON COLUMN perfis.role IS
  'admin: gestor da EST — gerencia equipe, clientes e configurações globais. '
  'consultor: acesso à coleta e análise, sem gestão de conta ou equipe.';

-- ── 2. Garantir que o primeiro usuário de cada tenant seja admin ──────────
-- (já é o default, mas explicitamos para registros existentes)
UPDATE perfis SET role = 'admin' WHERE role IS NULL OR role = '';

-- ── 3. Função helper: retorna o role do usuário autenticado ───────────────
CREATE OR REPLACE FUNCTION auth_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM perfis WHERE id = auth.uid() LIMIT 1;
$$;

-- ── 4. RLS: apenas admins gerenciam perfis de outros usuários ────────────
-- Todos do tenant vêem todos (necessário para listar equipe no painel)
DROP POLICY IF EXISTS "perfis_tenant_select" ON perfis;
CREATE POLICY "perfis_tenant_select" ON perfis
  FOR SELECT TO authenticated
  USING (
    tenant_id = (SELECT tenant_id FROM perfis WHERE id = auth.uid() LIMIT 1)
  );

-- Admins inserem novos usuários no próprio tenant
DROP POLICY IF EXISTS "perfis_admin_insert" ON perfis;
CREATE POLICY "perfis_admin_insert" ON perfis
  FOR INSERT TO authenticated
  WITH CHECK (
    auth_role() = 'admin'
    AND tenant_id = (SELECT tenant_id FROM perfis WHERE id = auth.uid() LIMIT 1)
  );

-- Admins atualizam qualquer perfil do tenant; consultor só o próprio (exceto role)
DROP POLICY IF EXISTS "perfis_update" ON perfis;
CREATE POLICY "perfis_update" ON perfis
  FOR UPDATE TO authenticated
  USING (
    -- admin pode editar qualquer perfil do tenant
    (auth_role() = 'admin'
     AND tenant_id = (SELECT tenant_id FROM perfis WHERE id = auth.uid() LIMIT 1))
    OR
    -- consultor edita apenas o próprio (mas não pode mudar o role)
    id = auth.uid()
  )
  WITH CHECK (
    -- impede qualquer usuário de se auto-promover a admin
    (auth_role() = 'admin')
    OR
    (id = auth.uid() AND role = (SELECT role FROM perfis WHERE id = auth.uid() LIMIT 1))
  );

-- Apenas admin deleta usuários do tenant
DROP POLICY IF EXISTS "perfis_admin_delete" ON perfis;
CREATE POLICY "perfis_admin_delete" ON perfis
  FOR DELETE TO authenticated
  USING (
    auth_role() = 'admin'
    AND tenant_id = (SELECT tenant_id FROM perfis WHERE id = auth.uid() LIMIT 1)
    AND id <> auth.uid() -- não pode deletar a si mesmo
  );

-- ── VERIFICAÇÃO ───────────────────────────────────────────────────────────
SELECT id, nome, role, tenant_id, ativo FROM perfis ORDER BY tenant_id, role;
