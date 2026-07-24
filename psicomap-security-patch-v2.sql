-- ══════════════════════════════════════════════════════════════════════
-- PSEG SafeSign — Security Patch v2 · Hierarquia de Perfis
-- Execute no SQL Editor do Supabase APÓS pseg-security-patch.sql
--
-- Mudança: consultor agora pode gerenciar consultor/cliente_viewer,
-- mas NUNCA pode criar, promover ou rebaixar o perfil admin.
--
-- Hierarquia:
--   admin        → gerencia todos
--   consultor    → gerencia consultor e cliente_viewer apenas
--   cliente_viewer → sem acesso a gerenciamento
-- ══════════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────────
-- 1. Atualizar trigger fn_guard_perfil_update
--    Regra A original: qualquer mudança de role exigia admin.
--    Nova Regra A: mudança de/para 'admin' exige admin;
--                 mudança entre consultor ↔ cliente_viewer permite consultor.
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
-- 2. Adicionar política RLS: consultor pode atualizar perfis
--    consultor/cliente_viewer do mesmo tenant
--    (admin_tenant_update_perfis já cobre admins)
-- ──────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "consultor_update_member_perfis" ON perfis;

CREATE POLICY "consultor_update_member_perfis"
  ON perfis FOR UPDATE TO authenticated
  USING (
    -- Linha alvo: não-admin, mesmo tenant, não é o próprio usuário
    tenant_id = get_my_tenant_id()
    AND role  <> 'admin'
    AND id    <> auth.uid()
    -- Chamador: deve ser consultor ativo no mesmo tenant
    AND EXISTS (
      SELECT 1 FROM public.perfis caller
      WHERE caller.id        = auth.uid()
        AND caller.role      = 'consultor'
        AND caller.ativo     = true
        AND caller.tenant_id = get_my_tenant_id()
    )
  )
  WITH CHECK (
    -- Resultado: não pode virar admin e deve permanecer no mesmo tenant
    tenant_id = get_my_tenant_id()
    AND role  <> 'admin'
  );


-- ──────────────────────────────────────────────────────────────────────
-- 3. Adicionar política SELECT: consultor pode ver todos do tenant
--    (para listar usuários na tela de gerenciamento)
-- ──────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "consultor_select_tenant_perfis" ON perfis;

CREATE POLICY "consultor_select_tenant_perfis"
  ON perfis FOR SELECT TO authenticated
  USING (
    tenant_id = get_my_tenant_id()
    AND EXISTS (
      SELECT 1 FROM public.perfis caller
      WHERE caller.id        = auth.uid()
        AND caller.role      = 'consultor'
        AND caller.ativo     = true
        AND caller.tenant_id = get_my_tenant_id()
    )
  );


-- ══════════════════════════════════════════════════════════════════════
-- VERIFICAÇÃO PÓS-EXECUÇÃO
-- ══════════════════════════════════════════════════════════════════════

-- 1. Listar políticas ativas na tabela perfis:
-- SELECT policyname, cmd, roles FROM pg_policies
-- WHERE schemaname = 'public' AND tablename = 'perfis'
-- ORDER BY cmd, policyname;

-- 2. Testar: consultor tentando promover para admin (deve falhar):
-- UPDATE public.perfis SET role = 'admin'
-- WHERE id = '<id-de-um-consultor>' AND role = 'consultor';
-- → ERROR 42501 "apenas administradores podem promover..."

-- 3. Testar: consultor promovendo cliente_viewer para consultor (deve funcionar):
-- (via frontend logado como consultor — DB deve permitir)

-- ══════════════════════════════════════════════════════════════════════
