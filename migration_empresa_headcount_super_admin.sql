-- ══════════════════════════════════════════════════════════════════════════
-- PsicoMap — Bypass super_admin em empresa_headcount
-- Executar no Supabase Dashboard → SQL Editor (ou via MCP apply_migration)
-- Aplicar em DEV (szqatgvgghxvyyncsjxl) e PROD (vftyiildukrpgmnbcnao)
-- ══════════════════════════════════════════════════════════════════════════
--
-- CONTEXTO: migration_painel_eleva.sql (2026-07-XX) deu bypass de RLS a
-- super_admin em empresas/ciclos/links_coleta/empresa_setores/empresa_funcoes.
-- migration_empresa_headcount.sql criou a tabela DEPOIS dessa migração e
-- nunca recebeu a mesma policy — mesma classe de gap já documentada em
-- CLAUDE.md para respostas/resposta_itens (2026-08-27).
--
-- Sintoma real (2026-08-28, testado em DEV): super_admin em Modo Suporte
-- (entrarComoEST) reimportando a planilha de GHE de uma EST recebia
-- "Erro ao salvar GHE: Quadro de funcionários: new row violates row-level
-- security policy for table \"empresa_headcount\"" — o INSERT usa
-- tenant_id = currentTenantId (o tenant da EST visitada), mas a única
-- policy de INSERT existente exige tenant_id = get_my_tenant_id(), que para
-- super_admin é NULL (perfis.tenant_id do próprio super_admin).
--
-- Confirmado via set_config('request.jwt.claims', ...) em transação com
-- ROLLBACK: super_admin falha, admin/consultor do próprio tenant funciona.

DROP POLICY IF EXISTS "empresa_headcount_super_admin_all" ON empresa_headcount;
CREATE POLICY "empresa_headcount_super_admin_all" ON empresa_headcount
  FOR ALL TO authenticated
  USING (is_super_admin())
  WITH CHECK (is_super_admin());
