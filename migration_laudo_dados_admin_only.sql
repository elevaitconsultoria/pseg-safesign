-- ══════════════════════════════════════════════════════════════════════════
-- PsicoMap — laudo_dados: só o Admin da EST (e super_admin) lê e escreve
-- Ordem: DEV (szqatgvgghxvyyncsjxl) primeiro, PROD (vftyiildukrpgmnbcnao) depois
-- ══════════════════════════════════════════════════════════════════════════
--
-- DECISÃO DO PRODUTO (2026-10-13): o modelo de laudo `padrao_pseg2.0` ("Modelo do laudo") é um
-- recurso do Admin da EST. Consultor e cliente_viewer não o veem na interface; esta migration
-- fecha o mesmo portão no banco — a UI sozinha é cosmética (CLAUDE.md: "o gate client-side não é
-- fronteira de segurança").
--
-- ANTES: SELECT para qualquer membro do tenant; escopos 'empresa' e 'ciclo' graváveis também por consultor.
-- DEPOIS: tudo (leitura e escrita, nos três escopos) só para admin do tenant ou super_admin.
--
-- IMPACTO: tabela criada em 2026-10-13. Se um consultor chegou a gravar algo, esses registros
-- continuam no banco mas ele deixa de ler/alterar; o admin os enxerga normalmente.

DROP POLICY IF EXISTS "laudo_dados_select" ON laudo_dados;
CREATE POLICY "laudo_dados_select" ON laudo_dados
  FOR SELECT TO authenticated
  USING (is_super_admin() OR (tenant_id = get_my_tenant_id() AND auth_role() = 'admin'));

DROP POLICY IF EXISTS "laudo_dados_insert" ON laudo_dados;
CREATE POLICY "laudo_dados_insert" ON laudo_dados
  FOR INSERT TO authenticated
  WITH CHECK (is_super_admin() OR (tenant_id = get_my_tenant_id() AND auth_role() = 'admin'));

DROP POLICY IF EXISTS "laudo_dados_update" ON laudo_dados;
CREATE POLICY "laudo_dados_update" ON laudo_dados
  FOR UPDATE TO authenticated
  USING (is_super_admin() OR (tenant_id = get_my_tenant_id() AND auth_role() = 'admin'))
  WITH CHECK (is_super_admin() OR (tenant_id = get_my_tenant_id() AND auth_role() = 'admin'));

DROP POLICY IF EXISTS "laudo_dados_delete" ON laudo_dados;
CREATE POLICY "laudo_dados_delete" ON laudo_dados
  FOR DELETE TO authenticated
  USING (is_super_admin() OR (tenant_id = get_my_tenant_id() AND auth_role() = 'admin'));
