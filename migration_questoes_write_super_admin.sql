-- ══════════════════════════════════════════════════════════════════════════
-- PsicoMap — Restringir escrita do catálogo global de questões a super_admin
-- Executar no Supabase Dashboard → SQL Editor (ou via MCP apply_migration)
-- Aplicar em DEV (szqatgvgghxvyyncsjxl) e PROD (vftyiildukrpgmnbcnao)
-- ══════════════════════════════════════════════════════════════════════════
--
-- CONTEXTO: `questoes`, `questionarios` e `questionario_questoes` não são
-- tenant-scoped — são o catálogo global de questões usado por TODAS as EST.
-- `psicomap-admin-rls-policies.sql` (baseline pré-multitenant) criou
-- "admin_all_questoes"/"admin_all_questionarios"/"admin_all_qq" com
-- `USING (true)` para qualquer usuário `authenticated` — ou seja, qualquer
-- admin/consultor de qualquer EST podia editar ou apagar o catálogo
-- compartilhado de todas as outras.
--
-- Isso foi corrigido em PROD em algum momento (policies renomeadas para
-- super_admin_write_*, USING (is_super_admin())), mas SEM migration file —
-- a mudança nunca foi versionada e DEV nunca recebeu a mesma correção.
-- Esta migration formaliza e sincroniza os dois bancos.

DROP POLICY IF EXISTS "admin_all_questoes" ON questoes;
DROP POLICY IF EXISTS "super_admin_write_questoes" ON questoes;
CREATE POLICY "super_admin_write_questoes" ON questoes
  FOR ALL TO authenticated
  USING (is_super_admin())
  WITH CHECK (is_super_admin());

DROP POLICY IF EXISTS "admin_all_questionarios" ON questionarios;
DROP POLICY IF EXISTS "super_admin_write_questionarios" ON questionarios;
CREATE POLICY "super_admin_write_questionarios" ON questionarios
  FOR ALL TO authenticated
  USING (is_super_admin())
  WITH CHECK (is_super_admin());

DROP POLICY IF EXISTS "admin_all_qq" ON questionario_questoes;
DROP POLICY IF EXISTS "super_admin_write_qq" ON questionario_questoes;
CREATE POLICY "super_admin_write_qq" ON questionario_questoes
  FOR ALL TO authenticated
  USING (is_super_admin())
  WITH CHECK (is_super_admin());

-- ── VERIFICAÇÃO ───────────────────────────────────────────────────────────
SELECT tablename, policyname, cmd, qual
FROM pg_policies
WHERE tablename IN ('questoes','questionarios','questionario_questoes')
ORDER BY tablename, policyname;
