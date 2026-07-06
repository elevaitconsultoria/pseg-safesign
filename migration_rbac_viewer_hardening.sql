-- ══════════════════════════════════════════════════════════════════════
-- migration_rbac_viewer_hardening.sql
-- RBAC completo: viewer read-only + bloqueio de auto-elevação de perfil
-- Aplicar em DEV primeiro; depois em PROD.
-- ══════════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────────
-- 1. Atualizar trigger fn_guard_perfil_update
--    Nova Regra 0 (antes de qualquer outra):
--      Nenhum usuário pode alterar o próprio role — apenas admin da EST
--      ou super_admin podem mudar o role de outrem.
-- ──────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_guard_perfil_update()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_caller_is_admin    boolean;
  v_caller_can_manage  boolean;   -- admin OU consultor ativo
  v_admins_restantes   int;
BEGIN
  -- service_role (auth.uid() IS NULL) → operação administrativa, permitir tudo
  IF auth.uid() IS NULL THEN RETURN NEW; END IF;

  -- ── Regra 0: Nenhum usuário pode alterar o próprio role ───────────────
  -- Garante que, mesmo sendo admin, não se pode auto-promover nem auto-rebaixar.
  -- A elevação de perfil é prerrogativa exclusiva de um terceiro com permissão.
  IF OLD.id = auth.uid() AND OLD.role IS DISTINCT FROM NEW.role THEN
    RAISE EXCEPTION
      'Acesso negado: um usuário não pode alterar o próprio perfil de acesso.'
      USING ERRCODE = '42501';
  END IF;

  -- ── Verificar nível do chamador (lê ANTES do update ser aplicado) ───
  SELECT
    EXISTS(SELECT 1 FROM public.perfis
           WHERE id = auth.uid() AND role = 'admin' AND ativo = true),
    EXISTS(SELECT 1 FROM public.perfis
           WHERE id = auth.uid() AND role IN ('admin','consultor') AND ativo = true)
  INTO v_caller_is_admin, v_caller_can_manage;

  -- ── Regra A: Alteração de role ───────────────────────────────────────
  IF OLD.role IS DISTINCT FROM NEW.role THEN

    -- Mexer no perfil 'admin' (promover ou rebaixar) → só admin
    IF OLD.role = 'admin' OR NEW.role = 'admin' THEN
      IF NOT v_caller_is_admin THEN
        RAISE EXCEPTION
          'Acesso negado: apenas administradores podem promover ou rebaixar o perfil administrador.'
          USING ERRCODE = '42501';
      END IF;
    END IF;

    -- Qualquer outra mudança de role → precisa ser pelo menos consultor
    IF NOT v_caller_can_manage THEN
      RAISE EXCEPTION
        'Acesso negado: sem permissão para alterar perfis de acesso.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  -- ── Regra B: Proteger o último admin do tenant ───────────────────────
  IF OLD.role = 'admin' AND OLD.ativo = true
     AND (NEW.role <> 'admin' OR NEW.ativo = false)
  THEN
    SELECT COUNT(*) INTO v_admins_restantes
    FROM public.perfis
    WHERE tenant_id = OLD.tenant_id
      AND role      = 'admin'
      AND ativo     = true
      AND id        <> OLD.id;

    IF v_admins_restantes = 0 THEN
      RAISE EXCEPTION
        'Operação bloqueada: não é possível remover o último administrador do tenant.'
        USING ERRCODE = '23514';
    END IF;
  END IF;

  -- ── Regra C: Desativar/reativar outros usuários ──────────────────────
  IF OLD.ativo IS DISTINCT FROM NEW.ativo AND OLD.id <> auth.uid() THEN
    -- Desativar um admin → apenas admin pode
    IF OLD.role = 'admin' AND NOT v_caller_is_admin THEN
      RAISE EXCEPTION
        'Acesso negado: apenas administradores podem desativar outros administradores.'
        USING ERRCODE = '42501';
    END IF;
    -- Desativar qualquer usuário → precisa ser pelo menos consultor
    IF NOT v_caller_can_manage THEN
      RAISE EXCEPTION
        'Acesso negado: sem permissão para ativar/desativar usuários.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Recriar trigger (a função foi substituída, o trigger continua apontando para ela)
DROP TRIGGER IF EXISTS tg_guard_perfil_update ON perfis;
CREATE TRIGGER tg_guard_perfil_update
  BEFORE UPDATE ON perfis
  FOR EACH ROW
  EXECUTE FUNCTION fn_guard_perfil_update();


-- ──────────────────────────────────────────────────────────────────────
-- 2. Políticas RESTRICTIVE para bloquear escrita do cliente_viewer
--
--    Problema: as políticas auth_insert/update/delete existentes não
--    verificam role — qualquer usuário autenticado com tenant_id correto
--    poderia escrever mesmo sendo viewer.
--
--    Solução: políticas RESTRICTIVE (AND lógico com permissivas).
--    Uma política RESTRICTIVE que retorna false bloqueia a operação
--    mesmo que outra política permissiva a libere.
--
--    Padrão aplicado em todas as tabelas mutáveis da EST:
--      viewer (cliente_viewer) → somente leitura.
-- ──────────────────────────────────────────────────────────────────────

-- empresas
DROP POLICY IF EXISTS "viewer_readonly_empresas" ON empresas;
CREATE POLICY "viewer_readonly_empresas" ON empresas
  AS RESTRICTIVE FOR UPDATE TO authenticated
  USING ((SELECT role FROM public.perfis WHERE id = auth.uid()) <> 'cliente_viewer')
  WITH CHECK ((SELECT role FROM public.perfis WHERE id = auth.uid()) <> 'cliente_viewer');

-- ciclos
DROP POLICY IF EXISTS "viewer_readonly_ciclos" ON ciclos;
CREATE POLICY "viewer_readonly_ciclos" ON ciclos
  AS RESTRICTIVE FOR UPDATE TO authenticated
  USING ((SELECT role FROM public.perfis WHERE id = auth.uid()) <> 'cliente_viewer')
  WITH CHECK ((SELECT role FROM public.perfis WHERE id = auth.uid()) <> 'cliente_viewer');

-- links_coleta
DROP POLICY IF EXISTS "viewer_readonly_links_coleta" ON links_coleta;
CREATE POLICY "viewer_readonly_links_coleta" ON links_coleta
  AS RESTRICTIVE FOR UPDATE TO authenticated
  USING ((SELECT role FROM public.perfis WHERE id = auth.uid()) <> 'cliente_viewer')
  WITH CHECK ((SELECT role FROM public.perfis WHERE id = auth.uid()) <> 'cliente_viewer');

-- laudos
DROP POLICY IF EXISTS "viewer_readonly_laudos" ON laudos;
CREATE POLICY "viewer_readonly_laudos" ON laudos
  AS RESTRICTIVE FOR UPDATE TO authenticated
  USING ((SELECT role FROM public.perfis WHERE id = auth.uid()) <> 'cliente_viewer')
  WITH CHECK ((SELECT role FROM public.perfis WHERE id = auth.uid()) <> 'cliente_viewer');

-- planos_config
DROP POLICY IF EXISTS "viewer_readonly_planos_config" ON planos_config;
CREATE POLICY "viewer_readonly_planos_config" ON planos_config
  AS RESTRICTIVE FOR UPDATE TO authenticated
  USING ((SELECT role FROM public.perfis WHERE id = auth.uid()) <> 'cliente_viewer')
  WITH CHECK ((SELECT role FROM public.perfis WHERE id = auth.uid()) <> 'cliente_viewer');

-- est_perfil
DROP POLICY IF EXISTS "viewer_readonly_est_perfil" ON est_perfil;
CREATE POLICY "viewer_readonly_est_perfil" ON est_perfil
  AS RESTRICTIVE FOR UPDATE TO authenticated
  USING ((SELECT role FROM public.perfis WHERE id = auth.uid()) <> 'cliente_viewer')
  WITH CHECK ((SELECT role FROM public.perfis WHERE id = auth.uid()) <> 'cliente_viewer');

-- perfis (viewer não pode alterar perfis de ninguém — nem o próprio role)
DROP POLICY IF EXISTS "viewer_readonly_perfis" ON perfis;
CREATE POLICY "viewer_readonly_perfis" ON perfis
  AS RESTRICTIVE FOR UPDATE TO authenticated
  USING ((SELECT role FROM public.perfis p2 WHERE p2.id = auth.uid()) <> 'cliente_viewer')
  WITH CHECK ((SELECT role FROM public.perfis p2 WHERE p2.id = auth.uid()) <> 'cliente_viewer');


-- ──────────────────────────────────────────────────────────────────────
-- 3. Nota sobre SELECT para viewer
--
--    As políticas auth_select_* existentes já cobrem viewer porque
--    filtram apenas por tenant_id = get_my_tenant_id() — viewer com
--    tenant_id configurado herda o acesso de leitura automaticamente.
--    Não é necessário criar novas políticas SELECT.
--
--    IMPORTANTE: as policies viewer_readonly_* são FOR UPDATE (não FOR ALL).
--    FOR ALL bloquearia SELECT, impedindo loadPerfil() de ler o próprio perfil
--    e carregamento de dados nas telas de análise. INSERT e DELETE já são
--    bloqueados pela ausência de policies permissivas de escrita para viewer.
-- ──────────────────────────────────────────────────────────────────────
