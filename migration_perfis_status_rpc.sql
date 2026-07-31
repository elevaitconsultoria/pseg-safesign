-- ══════════════════════════════════════════════════════════════════════════
-- PsicoMap — Migração: RPC perfis_com_status()
-- Expõe auth.users.last_sign_in_at (não consultável pelo client via RLS)
-- para distinguir convite pendente (nunca logou) de usuário ativo.
-- Executar no Supabase Dashboard → SQL Editor (DEV e PROD).
-- ══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION perfis_com_status()
RETURNS TABLE (
  id             uuid,
  nome           text,
  role           text,
  ativo          boolean,
  empresa_id     uuid,
  tenant_id      uuid,
  created_at     timestamptz,
  empresa_nome   text,
  tenant_nome    text,
  last_sign_in_at timestamptz
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT
    p.id, p.nome, p.role, p.ativo, p.empresa_id, p.tenant_id, p.created_at,
    e.nome AS empresa_nome, t.nome AS tenant_nome,
    u.last_sign_in_at
  FROM perfis p
  JOIN auth.users u ON u.id = p.id
  LEFT JOIN empresas e ON e.id = p.empresa_id
  LEFT JOIN tenants  t ON t.id = p.tenant_id
  WHERE p.role <> 'super_admin'
    AND (
      is_super_admin()
      OR (auth_role() IN ('admin', 'consultor') AND p.tenant_id = get_my_tenant_id())
    );
$$;

-- Mantém a mesma superfície de acesso que a leitura direta em `perfis` já
-- tinha (RLS de `perfis` restringia por tenant; aqui a filtragem é feita
-- dentro da função, que roda como owner e por isso não é bloqueada por RLS).
GRANT EXECUTE ON FUNCTION perfis_com_status() TO authenticated;
