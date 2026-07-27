-- ══════════════════════════════════════════════════════════════════════
-- PSEG SafeSign — Security Patch · Controle de Privilégios
-- Execute no SQL Editor do Supabase (projeto vftyiildukrpgmnbcnao)
-- Pré-requisito: pseg-phase3-saas-tenants.sql já aplicada
--
-- Vulnerabilidades corrigidas:
--   V1 · perfil_self_update não restringia coluna `role`
--          → consultor podia auto-elevar para admin via UPDATE direto
--   V2 · Faltava política UPDATE para admin gerenciar outros usuários
--   V3 · Ausência de trigger como defesa em profundidade (role escalation)
--   V4 · Ausência de proteção contra remoção do último admin do tenant
--   V8 · pub_insert_resposta usava WITH CHECK (true) sem validar token
-- ══════════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────────
-- 1. CORRIGIR perfil_self_update
--    Problema: o WITH CHECK original não restringia a coluna `role`.
--    Correção: substituir por política que também impede tenant_id
--    e role de serem alterados pela própria row (a camada de trigger
--    abaixo é a defesa em profundidade para role, mas a policy fecha
--    o canal direto ao REST API).
-- ──────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "perfil_self_update" ON perfis;

CREATE POLICY "perfil_self_update"
  ON perfis FOR UPDATE TO authenticated
  USING  (id = auth.uid())
  WITH CHECK (
    id        = auth.uid()
    AND tenant_id = get_my_tenant_id()
    -- Impede que o próprio usuário altere seu role via REST direto.
    -- A coluna role só pode ser modificada por admin (via trigger abaixo).
    AND role  = (SELECT p2.role FROM public.perfis p2
                 WHERE p2.id = auth.uid() LIMIT 1)
  );

-- ──────────────────────────────────────────────────────────────────────
-- 2. ADICIONAR política UPDATE para admins gerenciarem OUTROS perfis
--    (Phase 3 só tinha INSERT e DELETE para admin — faltava UPDATE)
-- ──────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "admin_tenant_update_perfis" ON perfis;

CREATE POLICY "admin_tenant_update_perfis"
  ON perfis FOR UPDATE TO authenticated
  USING  (
    tenant_id = get_my_tenant_id()
    AND is_tenant_admin()
    AND id <> auth.uid()   -- Admin usa esta policy para outros; usa perfil_self_update para si
  )
  WITH CHECK (
    tenant_id = get_my_tenant_id()
  );


-- ──────────────────────────────────────────────────────────────────────
-- 3. TRIGGER fn_guard_perfil_update
--    Defesa em profundidade: opera NO NÍVEL DO BANCO, independente de RLS.
--    Garante:
--      a) Apenas admins podem alterar o campo `role` de qualquer row.
--      b) Ninguém pode remover/desativar o último admin de um tenant.
--      c) Apenas admins podem desativar/reativar outros usuários.
-- ──────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_guard_perfil_update()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_caller_is_admin  boolean;
  v_admins_restantes int;
BEGIN
  -- ── Verificar se o chamador é admin (ANTES do update ser aplicado) ──
  SELECT EXISTS (
    SELECT 1 FROM public.perfis
    WHERE id = auth.uid()
      AND role  = 'admin'
      AND ativo = true
  ) INTO v_caller_is_admin;

  -- ── Regra A: Apenas admin pode alterar o campo role ─────────────────
  IF OLD.role IS DISTINCT FROM NEW.role THEN
    IF NOT v_caller_is_admin THEN
      RAISE EXCEPTION
        'Acesso negado: apenas administradores podem alterar o perfil de acesso. '
        'Role atual: %. Tentativa de mudar para: %.',
        OLD.role, NEW.role
        USING ERRCODE = '42501'; -- insufficient_privilege
    END IF;
  END IF;

  -- ── Regra B: Proteger o último admin do tenant ───────────────────────
  --    Bloqueia se o admin está sendo rebaixado (role) ou desativado (ativo).
  IF OLD.role = 'admin' AND OLD.ativo = true
     AND (NEW.role <> 'admin' OR NEW.ativo = false)
  THEN
    SELECT COUNT(*) INTO v_admins_restantes
    FROM public.perfis
    WHERE tenant_id = OLD.tenant_id
      AND role      = 'admin'
      AND ativo     = true
      AND id        <> OLD.id;   -- exclui a row sendo alterada

    IF v_admins_restantes = 0 THEN
      RAISE EXCEPTION
        'Operação bloqueada: não é possível rebaixar ou desativar o último '
        'administrador do tenant. Promova outro usuário a admin antes.'
        USING ERRCODE = '23514'; -- check_violation semântico
    END IF;
  END IF;

  -- ── Regra C: Apenas admin pode desativar/reativar OUTROS usuários ────
  IF OLD.ativo IS DISTINCT FROM NEW.ativo AND OLD.id <> auth.uid() THEN
    IF NOT v_caller_is_admin THEN
      RAISE EXCEPTION
        'Acesso negado: apenas administradores podem ativar/desativar outros usuários.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Remover trigger anterior (se existia) e recriar
DROP TRIGGER IF EXISTS tg_guard_perfil_update ON perfis;

CREATE TRIGGER tg_guard_perfil_update
  BEFORE UPDATE ON perfis
  FOR EACH ROW
  EXECUTE FUNCTION fn_guard_perfil_update();


-- ──────────────────────────────────────────────────────────────────────
-- 4. CORRIGIR pub_insert_resposta (V8)
--    Phase 3 reverteu para WITH CHECK (true) como simplificação, mas
--    isso permite que qualquer anônimo insira respostas para qualquer
--    empresa_id — sem precisar de um token válido.
--    Restaurar a validação de token da Phase 1.
-- ──────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "pub_insert_resposta"   ON respostas;
DROP POLICY IF EXISTS "pub_insert_resposta_validada" ON respostas;

CREATE POLICY "pub_insert_resposta_validada"
  ON respostas FOR INSERT
  WITH CHECK (
    -- Token deve existir, estar ativo, não expirado e pertencer à empresa
    EXISTS (
      SELECT 1 FROM public.links_coleta lc
      WHERE lc.token      = respostas.link_token
        AND lc.empresa_id = respostas.empresa_id
        AND lc.ativo      = true
        AND (lc.expira_em IS NULL OR lc.expira_em > now())
    )
  );

-- ──────────────────────────────────────────────────────────────────────
-- 5. Manter resposta_itens compatível com a policy acima
--    (pub_insert_item permanece WITH CHECK (true) porque a
--    validação do link já foi feita na inserção da resposta pai —
--    e o resposta_id é uma FK garantida.)
-- ──────────────────────────────────────────────────────────────────────
-- Nenhuma alteração necessária em resposta_itens.


-- ══════════════════════════════════════════════════════════════════════
-- VERIFICAÇÃO PÓS-EXECUÇÃO
-- ══════════════════════════════════════════════════════════════════════

-- 1. Listar políticas em vigência na tabela perfis:
-- SELECT policyname, cmd, qual, with_check
-- FROM pg_policies
-- WHERE schemaname = 'public' AND tablename = 'perfis'
-- ORDER BY cmd, policyname;

-- 2. Confirmar que o trigger foi criado:
-- SELECT tgname, tgtype, proname
-- FROM pg_trigger t JOIN pg_proc p ON p.oid = t.tgfoid
-- WHERE tgrelid = 'perfis'::regclass;

-- 3. Testar escalada de privilégio (deve lançar exceção):
-- -- Faça login como consultor e execute:
-- UPDATE public.perfis SET role = 'admin' WHERE id = auth.uid();
-- -- Esperado: ERROR 42501 "Acesso negado: apenas administradores..."

-- 4. Testar remoção do último admin (deve lançar exceção):
-- UPDATE public.perfis SET role = 'consultor'
-- WHERE id = '<id-do-unico-admin>' AND role = 'admin';
-- -- Esperado: ERROR 23514 "Operação bloqueada: não é possível..."

-- 5. Testar inserção de resposta sem token válido (deve falhar):
-- INSERT INTO respostas (empresa_id, setor, link_token)
-- VALUES ('<qualquer-uuid>', 'Teste', 'token-invalido');
-- -- Esperado: new row violates row-level security policy

-- ══════════════════════════════════════════════════════════════════════
-- FIM DO SECURITY PATCH
-- ══════════════════════════════════════════════════════════════════════
