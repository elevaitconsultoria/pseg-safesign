-- ============================================================================
-- migration_admin_write_hardening.sql                              2026-09-11
--
-- Fecha tres protecoes que existiam APENAS no frontend (o `restritos` de
-- goScreen + aplicarRestricoesPorRole), sem nenhuma contrapartida no banco.
-- Qualquer consultor autenticado conseguia contorna-las chamando a API REST
-- direto, sem passar pela UI.
--
--   1. est_perfil     — escrita liberada a qualquer usuario do tenant
--   2. riscos_config  — idem, e sem NENHUMA policy de viewer
--   3. perfis         — consultor podia dar UPDATE em perfis de colegas
--
-- Nao ha vazamento de dado de cliente em nenhum dos tres, e nenhum permite
-- escalonar para admin. E defesa em profundidade faltando, na mesma classe
-- dos gaps ja documentados no CLAUDE.md.
--
-- Aplicar em DEV e PROD. Idempotente (DROP IF EXISTS antes de cada CREATE).
-- ============================================================================


-- ─────────────────────────────────────────────────────────────────────────────
-- 1. est_perfil — escrita so pelo admin da EST
--
-- Antes: a unica PERMISSIVE era `est_perfil_tenant_rls` (FOR ALL, so tenant), e
-- a unica RESTRICTIVE era `viewer_readonly_est_perfil`, que cobre apenas UPDATE.
-- Consequencia dupla: consultor gravava normalmente, e cliente_viewer podia
-- INSERT/DELETE (so o UPDATE dele estava barrado).
--
-- A leitura NAO e tocada de proposito: consultor e viewer precisam ler
-- est_perfil para o branding dos exports (_estPerfil.nome_empresa). Por isso
-- sao tres policies por comando, e nao uma FOR ALL — uma RESTRICTIVE FOR ALL
-- aplicaria o USING tambem ao SELECT e quebraria o laudo de todo mundo.
-- ─────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS est_perfil_insert_admin ON public.est_perfil;
CREATE POLICY est_perfil_insert_admin ON public.est_perfil
  AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (is_tenant_admin() OR is_super_admin());

DROP POLICY IF EXISTS est_perfil_update_admin ON public.est_perfil;
CREATE POLICY est_perfil_update_admin ON public.est_perfil
  AS RESTRICTIVE FOR UPDATE TO authenticated
  USING      (is_tenant_admin() OR is_super_admin())
  WITH CHECK (is_tenant_admin() OR is_super_admin());

DROP POLICY IF EXISTS est_perfil_delete_admin ON public.est_perfil;
CREATE POLICY est_perfil_delete_admin ON public.est_perfil
  AS RESTRICTIVE FOR DELETE TO authenticated
  USING (is_tenant_admin() OR is_super_admin());


-- ─────────────────────────────────────────────────────────────────────────────
-- 2. riscos_config — escrita so pelo admin da EST
--
-- Antes: uma unica policy, `auth_all_riscos_config` (PERMISSIVE FOR ALL,
-- so `tenant_id = get_my_tenant_id()`). Sem policy de admin E sem policy de
-- viewer — ou seja, ate cliente_viewer escrevia aqui, o que escapou da
-- migration_viewer_write_hardening.sql.
-- ─────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS riscos_config_insert_admin ON public.riscos_config;
CREATE POLICY riscos_config_insert_admin ON public.riscos_config
  AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (is_tenant_admin() OR is_super_admin());

DROP POLICY IF EXISTS riscos_config_update_admin ON public.riscos_config;
CREATE POLICY riscos_config_update_admin ON public.riscos_config
  AS RESTRICTIVE FOR UPDATE TO authenticated
  USING      (is_tenant_admin() OR is_super_admin())
  WITH CHECK (is_tenant_admin() OR is_super_admin());

DROP POLICY IF EXISTS riscos_config_delete_admin ON public.riscos_config;
CREATE POLICY riscos_config_delete_admin ON public.riscos_config
  AS RESTRICTIVE FOR DELETE TO authenticated
  USING (is_tenant_admin() OR is_super_admin());


-- ─────────────────────────────────────────────────────────────────────────────
-- 3. perfis — consultor nao altera perfil de ninguem
--
-- `consultor_update_member_perfis` permitia a um consultor dar UPDATE em
-- qualquer perfil nao-admin do proprio tenant. Ele nao conseguia se
-- auto-alterar (`id <> auth.uid()`) nem promover alguem a admin (o USING vale
-- como WITH CHECK quando este e nulo), mas podia rebaixar de consultor para
-- cliente_viewer, ou desativar um colega — tudo via API, sem UI.
--
-- Nenhuma funcionalidade legitima depende dela: a tela Equipe ja e bloqueada
-- para consultor em `restritos`, e alterarRoleUsuario/toggleAtivoUsuario tem
-- guard `callerIsAdmin` na propria funcao.
--
-- O consultor CONTINUA podendo:
--   - ler os perfis do tenant  (consultor_select_tenant_perfis, perfis_tenant_select)
--   - editar o proprio perfil  (perfil_self_update — que ja impede trocar
--                               o proprio role ou tenant no WITH CHECK)
--
-- Nome identico em DEV e PROD, apesar de o corpo divergir na funcao helper
-- (DEV: is_active_consultor / PROD: is_tenant_consultor) — o DROP nao depende disso.
-- ─────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS consultor_update_member_perfis ON public.perfis;


-- ============================================================================
-- NAO incluido de proposito (registrado para nao ser redescoberto):
--
-- * REVOKE do `anon` nestas tabelas. Em PROD o schema public tem
--   ALTER DEFAULT PRIVILEGES concedendo ALL ao anon, entao as tres tem CRUD
--   completo para o papel anonimo e dependem so do RLS (que hoje segura: as
--   PERMISSIVE comparam contra `perfis` via auth.uid(), que e NULL no anon).
--   Nao entra aqui porque `est_perfil` E lida pelo formulario publico e o
--   REVOKE precisa ser validado contra esse fluxo antes — assunto separado,
--   ja registrado no CLAUDE.md.
--
-- * Bypass de super_admin em est_perfil/riscos_config. A PERMISSIVE dessas
--   tabelas exige `tenant_id = <tenant do caller>`, e super_admin tem
--   tenant_id NULL — ele ja nao escrevia nelas ANTES desta migration (mesma
--   classe do gap corrigido em respostas/resposta_itens e empresa_headcount).
--   O `OR is_super_admin()` acima nao o habilita, porque RESTRICTIVE so
--   restringe; esta ali para que estas policies nao sejam o bloqueador se o
--   bypass for adicionado depois.
-- ============================================================================
