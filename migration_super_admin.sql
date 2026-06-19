-- ══════════════════════════════════════════════════════════════════════════
-- PSEG SafeSign — Migração 6: Role super_admin (Eleva IT)
-- Executar no Supabase Dashboard → SQL Editor
-- ══════════════════════════════════════════════════════════════════════════

-- ── 1. Ampliar o CHECK de role para incluir super_admin ──────────────────
ALTER TABLE perfis DROP CONSTRAINT IF EXISTS perfis_role_check;
ALTER TABLE perfis
  ADD CONSTRAINT perfis_role_check
  CHECK (role IN ('super_admin', 'admin', 'consultor', 'cliente_viewer'));

COMMENT ON COLUMN perfis.role IS
  'super_admin: Eleva IT — visão cross-tenant, gerencia todas as ESTs. '
  'admin: gestor da EST — configura metodologia, equipe e conta. '
  'consultor: operador da EST — coleta e análise. '
  'cliente_viewer: leitura apenas (reservado para uso futuro).';

-- ── 2. Atualizar auth_role() para incluir super_admin ────────────────────
CREATE OR REPLACE FUNCTION auth_role()
RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT role FROM perfis WHERE id = auth.uid() LIMIT 1; $$;

-- ── 3. Helper: verificar se o usuário atual é super_admin ─────────────────
CREATE OR REPLACE FUNCTION is_super_admin()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT auth_role() = 'super_admin'; $$;

-- ── 4. RLS: super_admin lê todos os perfis (cross-tenant) ────────────────
DROP POLICY IF EXISTS "perfis_super_admin_all" ON perfis;
CREATE POLICY "perfis_super_admin_all" ON perfis
  FOR ALL TO authenticated
  USING (is_super_admin())
  WITH CHECK (is_super_admin());

-- ── 5. Promover o usuário da Eleva IT a super_admin ─────────────────────
-- IMPORTANTE: substitua o e-mail abaixo pelo e-mail real do usuário Eleva IT
UPDATE perfis
   SET role = 'super_admin'
 WHERE id = (
   SELECT id FROM auth.users WHERE email = 'eleva.it.consultoria@gmail.com' LIMIT 1
 );

-- ── 6. Garantir que super_admin não seja bloqueado por tenant_id vazio ───
-- (super_admin pode ter tenant_id NULL — é intencional)
ALTER TABLE perfis ALTER COLUMN tenant_id DROP NOT NULL;

-- ── VERIFICAÇÃO ───────────────────────────────────────────────────────────
SELECT p.nome, p.role, p.tenant_id,
       u.email
  FROM perfis p
  JOIN auth.users u ON u.id = p.id
 ORDER BY p.role, p.nome;
