-- ══════════════════════════════════════════════════════════════════
-- PSEG SafeSign — Fase 3: Multitenancy SaaS
-- Execute no SQL Editor do Supabase (projeto vftyiildukrpgmnbcnao)
-- Pré-requisito: phases 1 e 2 já aplicadas
-- ══════════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────────
-- 1. TABELA tenants
--    Entidade raiz: cada consultoria / grande empresa que compra
--    o SafeSign é um tenant independente.
-- ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tenants (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  nome                text        NOT NULL,
  slug                text        UNIQUE NOT NULL,   -- ex: "elevait", "risco-seguro"
  plano               text        NOT NULL DEFAULT 'trial'
                                  CHECK (plano IN ('trial','starter','professional','enterprise')),
  trial_ate           timestamptz,                   -- NULL = sem trial ativo
  ativo               boolean     NOT NULL DEFAULT true,

  -- Limites do plano (NULL = sem limite imposto)
  max_empresas        int,
  max_usuarios        int,
  max_respostas_mes   int,

  -- White-label (Fase futura)
  logo_url            text,
  cor_primaria        text,

  -- Billing
  stripe_customer_id  text,
  asaas_customer_id   text,

  -- Metadados
  criado_por          uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;

-- Trigger updated_at (reutiliza função criada na Fase 1)
DROP TRIGGER IF EXISTS tg_tenants_updated_at ON tenants;
CREATE TRIGGER tg_tenants_updated_at
  BEFORE UPDATE ON tenants
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ──────────────────────────────────────────────────────────────────
-- 2. TENANT PADRÃO para dados pré-existentes
--    UUID fixo: todos os dados atuais ficam associados a este tenant.
-- ──────────────────────────────────────────────────────────────────
INSERT INTO tenants (id, nome, slug, plano, trial_ate, criado_por)
VALUES (
  '00000000-0000-0000-0000-000000000099',
  'PSEG SafeSign — Conta Padrão',
  'pseg-default',
  'enterprise',
  NULL,
  NULL
)
ON CONFLICT (id) DO NOTHING;

-- ──────────────────────────────────────────────────────────────────
-- 3. ADICIONAR tenant_id às tabelas existentes
-- ──────────────────────────────────────────────────────────────────

-- Núcleo: perfis e empresas recebem tenant_id direto
ALTER TABLE perfis
  ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES tenants(id) ON DELETE SET NULL;

ALTER TABLE empresas
  ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE;

-- Tabelas derivadas: tenant_id direto para performance nas políticas RLS
-- (evita JOINs em cada avaliação de policy)
ALTER TABLE ciclos
  ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE;

ALTER TABLE links_coleta
  ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE;

ALTER TABLE respostas
  ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE;

ALTER TABLE laudos
  ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE;

ALTER TABLE riscos_config
  ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE;

ALTER TABLE empresa_setores
  ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE;

ALTER TABLE empresa_funcoes
  ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES tenants(id) ON DELETE CASCADE;

-- ──────────────────────────────────────────────────────────────────
-- 4. MIGRAR DADOS EXISTENTES → tenant padrão
-- ──────────────────────────────────────────────────────────────────
UPDATE perfis          SET tenant_id = '00000000-0000-0000-0000-000000000099' WHERE tenant_id IS NULL;
UPDATE empresas        SET tenant_id = '00000000-0000-0000-0000-000000000099' WHERE tenant_id IS NULL;
UPDATE ciclos          SET tenant_id = '00000000-0000-0000-0000-000000000099' WHERE tenant_id IS NULL;
UPDATE links_coleta    SET tenant_id = '00000000-0000-0000-0000-000000000099' WHERE tenant_id IS NULL;
UPDATE respostas       SET tenant_id = '00000000-0000-0000-0000-000000000099' WHERE tenant_id IS NULL;
UPDATE laudos          SET tenant_id = '00000000-0000-0000-0000-000000000099' WHERE tenant_id IS NULL;
UPDATE riscos_config   SET tenant_id = '00000000-0000-0000-0000-000000000099' WHERE tenant_id IS NULL;
UPDATE empresa_setores SET tenant_id = '00000000-0000-0000-0000-000000000099' WHERE tenant_id IS NULL;
UPDATE empresa_funcoes SET tenant_id = '00000000-0000-0000-0000-000000000099' WHERE tenant_id IS NULL;

-- ──────────────────────────────────────────────────────────────────
-- 5. ÍNDICES de tenant_id (performance nas queries e nas policies RLS)
-- ──────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_perfis_tenant          ON perfis(tenant_id);
CREATE INDEX IF NOT EXISTS idx_empresas_tenant        ON empresas(tenant_id);
CREATE INDEX IF NOT EXISTS idx_ciclos_tenant          ON ciclos(tenant_id);
CREATE INDEX IF NOT EXISTS idx_links_tenant           ON links_coleta(tenant_id);
CREATE INDEX IF NOT EXISTS idx_respostas_tenant       ON respostas(tenant_id);
CREATE INDEX IF NOT EXISTS idx_laudos_tenant          ON laudos(tenant_id);
CREATE INDEX IF NOT EXISTS idx_riscos_tenant          ON riscos_config(tenant_id);
CREATE INDEX IF NOT EXISTS idx_setores_tenant         ON empresa_setores(tenant_id);
CREATE INDEX IF NOT EXISTS idx_funcoes_tenant         ON empresa_funcoes(tenant_id);

-- ──────────────────────────────────────────────────────────────────
-- 5b. Ajuste de UNIQUE constraints para multitenancy
--     riscos_config: a constraint original (empresa_id, cd_risco) permite
--     que dois tenants com empresa_id=NULL colidam no mesmo cd_risco.
--     Precisa incluir tenant_id no índice único.
-- ──────────────────────────────────────────────────────────────────
ALTER TABLE riscos_config DROP CONSTRAINT IF EXISTS riscos_config_empresa_id_cd_risco_key;
ALTER TABLE riscos_config ADD CONSTRAINT riscos_config_tenant_empresa_cd_key
  UNIQUE (tenant_id, empresa_id, cd_risco);

-- ──────────────────────────────────────────────────────────────────
-- 6. FUNÇÕES HELPER para RLS
--    SECURITY DEFINER: executam como o owner (bypassa RLS ao ler
--    perfis internamente — elimina recursão infinita).
-- ──────────────────────────────────────────────────────────────────

-- Retorna o tenant_id do usuário autenticado
CREATE OR REPLACE FUNCTION get_my_tenant_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT tenant_id FROM public.perfis WHERE id = auth.uid() LIMIT 1;
$$;

-- Retorna true se o usuário autenticado é admin do seu tenant
CREATE OR REPLACE FUNCTION is_tenant_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.perfis
    WHERE id = auth.uid()
      AND role = 'admin'
      AND ativo = true
  );
$$;

-- ──────────────────────────────────────────────────────────────────
-- 7. RLS — tenants
--    Cada usuário enxerga apenas o próprio tenant.
--    Apenas admin do tenant pode atualizar os dados do tenant.
-- ──────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "tenant_select_own"    ON tenants;
DROP POLICY IF EXISTS "tenant_update_admin"  ON tenants;

CREATE POLICY "tenant_select_own"
  ON tenants FOR SELECT TO authenticated
  USING (id = get_my_tenant_id());

CREATE POLICY "tenant_update_admin"
  ON tenants FOR UPDATE TO authenticated
  USING  (id = get_my_tenant_id() AND is_tenant_admin())
  WITH CHECK (id = get_my_tenant_id());

-- ──────────────────────────────────────────────────────────────────
-- 8. RLS — perfis (reescrever com isolamento por tenant)
-- ──────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "perfil_self_select"          ON perfis;
DROP POLICY IF EXISTS "perfil_self_update"          ON perfis;
DROP POLICY IF EXISTS "admin_all_perfis"            ON perfis;
DROP POLICY IF EXISTS "admin_tenant_select_perfis"  ON perfis;
DROP POLICY IF EXISTS "admin_tenant_insert_perfis"  ON perfis;
DROP POLICY IF EXISTS "admin_tenant_delete_perfis"  ON perfis;

-- Usuário sempre vê o próprio perfil
CREATE POLICY "perfil_self_select"
  ON perfis FOR SELECT TO authenticated
  USING (id = auth.uid());

-- Admin do tenant vê todos os perfis do mesmo tenant
CREATE POLICY "admin_tenant_select_perfis"
  ON perfis FOR SELECT TO authenticated
  USING (tenant_id = get_my_tenant_id() AND is_tenant_admin());

-- Usuário atualiza apenas o próprio perfil (não pode mudar tenant_id)
CREATE POLICY "perfil_self_update"
  ON perfis FOR UPDATE TO authenticated
  USING  (id = auth.uid())
  WITH CHECK (id = auth.uid() AND tenant_id = get_my_tenant_id());

-- Admin cria membros no mesmo tenant
CREATE POLICY "admin_tenant_insert_perfis"
  ON perfis FOR INSERT TO authenticated
  WITH CHECK (tenant_id = get_my_tenant_id() AND is_tenant_admin());

-- Admin remove membros do mesmo tenant (não pode remover a si mesmo)
CREATE POLICY "admin_tenant_delete_perfis"
  ON perfis FOR DELETE TO authenticated
  USING (tenant_id = get_my_tenant_id() AND is_tenant_admin() AND id <> auth.uid());

-- ──────────────────────────────────────────────────────────────────
-- 9. RLS — empresas (substituir políticas genéricas USING(true))
-- ──────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "admin_all_empresas"     ON empresas;
DROP POLICY IF EXISTS "pub_read_empresa"       ON empresas;
DROP POLICY IF EXISTS "pub_read_empresa_ativa" ON empresas;
DROP POLICY IF EXISTS "auth_select_empresas"   ON empresas;
DROP POLICY IF EXISTS "auth_insert_empresa"    ON empresas;
DROP POLICY IF EXISTS "auth_update_empresa"    ON empresas;
DROP POLICY IF EXISTS "auth_delete_empresa"    ON empresas;

-- Leitura pública: formulário de coleta acessa empresa pelo token (sem auth)
CREATE POLICY "pub_read_empresa_ativa"
  ON empresas FOR SELECT
  USING (ativo = true);

-- Autenticado: apenas empresas do próprio tenant
CREATE POLICY "auth_select_empresas"
  ON empresas FOR SELECT TO authenticated
  USING (tenant_id = get_my_tenant_id());

CREATE POLICY "auth_insert_empresa"
  ON empresas FOR INSERT TO authenticated
  WITH CHECK (tenant_id = get_my_tenant_id());

CREATE POLICY "auth_update_empresa"
  ON empresas FOR UPDATE TO authenticated
  USING  (tenant_id = get_my_tenant_id() AND (is_tenant_admin() OR criado_por = auth.uid()))
  WITH CHECK (tenant_id = get_my_tenant_id());

CREATE POLICY "auth_delete_empresa"
  ON empresas FOR DELETE TO authenticated
  USING (tenant_id = get_my_tenant_id() AND is_tenant_admin());

-- ──────────────────────────────────────────────────────────────────
-- 10. RLS — ciclos
-- ──────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "admin_all_ciclos"  ON ciclos;
DROP POLICY IF EXISTS "pub_read_ciclos"   ON ciclos;

-- Leitura pública (formulário pode precisar do ciclo ativo)
CREATE POLICY "pub_read_ciclos"
  ON ciclos FOR SELECT
  USING (true);

-- Autenticado: apenas ciclos do próprio tenant
CREATE POLICY "auth_select_ciclos"
  ON ciclos FOR SELECT TO authenticated
  USING (tenant_id = get_my_tenant_id());

CREATE POLICY "auth_insert_ciclos"
  ON ciclos FOR INSERT TO authenticated
  WITH CHECK (tenant_id = get_my_tenant_id());

CREATE POLICY "auth_update_ciclos"
  ON ciclos FOR UPDATE TO authenticated
  USING  (tenant_id = get_my_tenant_id())
  WITH CHECK (tenant_id = get_my_tenant_id());

CREATE POLICY "auth_delete_ciclos"
  ON ciclos FOR DELETE TO authenticated
  USING (tenant_id = get_my_tenant_id() AND is_tenant_admin());

-- ──────────────────────────────────────────────────────────────────
-- 11. RLS — links_coleta
-- ──────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "pub_read_link"    ON links_coleta;
DROP POLICY IF EXISTS "admin_all_links"  ON links_coleta;

-- Leitura pública: formulário valida token sem autenticação
CREATE POLICY "pub_read_link"
  ON links_coleta FOR SELECT
  USING (ativo = true);

-- Autenticado: apenas links do próprio tenant
CREATE POLICY "auth_select_links"
  ON links_coleta FOR SELECT TO authenticated
  USING (tenant_id = get_my_tenant_id());

CREATE POLICY "auth_insert_links"
  ON links_coleta FOR INSERT TO authenticated
  WITH CHECK (tenant_id = get_my_tenant_id());

CREATE POLICY "auth_update_links"
  ON links_coleta FOR UPDATE TO authenticated
  USING  (tenant_id = get_my_tenant_id())
  WITH CHECK (tenant_id = get_my_tenant_id());

CREATE POLICY "auth_delete_links"
  ON links_coleta FOR DELETE TO authenticated
  USING (tenant_id = get_my_tenant_id());

-- ──────────────────────────────────────────────────────────────────
-- 12. RLS — respostas
-- ──────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "pub_insert_resposta"           ON respostas;
DROP POLICY IF EXISTS "pub_insert_resposta_validada"  ON respostas;
DROP POLICY IF EXISTS "admin_select_respostas"        ON respostas;
DROP POLICY IF EXISTS "admin_delete_respostas"        ON respostas;

-- Inserção pública: formulário anônimo insere respostas
-- (validação de token feita no lado JS — fase anterior simplificou para WITH CHECK (true))
CREATE POLICY "pub_insert_resposta"
  ON respostas FOR INSERT
  WITH CHECK (true);

-- Leitura / deleção: apenas autenticados do mesmo tenant
CREATE POLICY "auth_select_respostas"
  ON respostas FOR SELECT TO authenticated
  USING (tenant_id = get_my_tenant_id());

CREATE POLICY "auth_delete_respostas"
  ON respostas FOR DELETE TO authenticated
  USING (tenant_id = get_my_tenant_id() AND is_tenant_admin());

-- ──────────────────────────────────────────────────────────────────
-- 13. RLS — resposta_itens
--     Não tem tenant_id diretamente; deriva via respostas.
-- ──────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "pub_insert_item"      ON resposta_itens;
DROP POLICY IF EXISTS "admin_select_itens"   ON resposta_itens;
DROP POLICY IF EXISTS "admin_delete_itens"   ON resposta_itens;

-- Inserção pública (formulário anônimo)
CREATE POLICY "pub_insert_item"
  ON resposta_itens FOR INSERT
  WITH CHECK (true);

-- Leitura: filtra via tenant da resposta pai
CREATE POLICY "auth_select_itens"
  ON resposta_itens FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM respostas r
      WHERE r.id = resposta_itens.resposta_id
        AND r.tenant_id = get_my_tenant_id()
    )
  );

-- Deleção: admin do tenant via resposta pai
CREATE POLICY "auth_delete_itens"
  ON resposta_itens FOR DELETE TO authenticated
  USING (
    is_tenant_admin()
    AND EXISTS (
      SELECT 1 FROM respostas r
      WHERE r.id = resposta_itens.resposta_id
        AND r.tenant_id = get_my_tenant_id()
    )
  );

-- ──────────────────────────────────────────────────────────────────
-- 14. RLS — laudos
-- ──────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "admin_all_laudos" ON laudos;

CREATE POLICY "auth_select_laudos"
  ON laudos FOR SELECT TO authenticated
  USING (tenant_id = get_my_tenant_id());

CREATE POLICY "auth_insert_laudos"
  ON laudos FOR INSERT TO authenticated
  WITH CHECK (tenant_id = get_my_tenant_id());

CREATE POLICY "auth_update_laudos"
  ON laudos FOR UPDATE TO authenticated
  USING  (tenant_id = get_my_tenant_id())
  WITH CHECK (tenant_id = get_my_tenant_id());

CREATE POLICY "auth_delete_laudos"
  ON laudos FOR DELETE TO authenticated
  USING (tenant_id = get_my_tenant_id() AND is_tenant_admin());

-- ──────────────────────────────────────────────────────────────────
-- 15. RLS — riscos_config
-- ──────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "auth_all_riscos_config" ON riscos_config;

CREATE POLICY "auth_all_riscos_config"
  ON riscos_config FOR ALL TO authenticated
  USING  (tenant_id = get_my_tenant_id())
  WITH CHECK (tenant_id = get_my_tenant_id());

-- ──────────────────────────────────────────────────────────────────
-- 16. RLS — empresa_setores e empresa_funcoes
-- ──────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "pub_read_empresa_setores"     ON empresa_setores;
DROP POLICY IF EXISTS "auth_manage_empresa_setores"  ON empresa_setores;
DROP POLICY IF EXISTS "pub_read_empresa_funcoes"     ON empresa_funcoes;
DROP POLICY IF EXISTS "auth_manage_empresa_funcoes"  ON empresa_funcoes;

CREATE POLICY "pub_read_empresa_setores"
  ON empresa_setores FOR SELECT
  USING (ativo = true);

CREATE POLICY "auth_manage_empresa_setores"
  ON empresa_setores FOR ALL TO authenticated
  USING  (tenant_id = get_my_tenant_id())
  WITH CHECK (tenant_id = get_my_tenant_id());

CREATE POLICY "pub_read_empresa_funcoes"
  ON empresa_funcoes FOR SELECT
  USING (ativo = true);

CREATE POLICY "auth_manage_empresa_funcoes"
  ON empresa_funcoes FOR ALL TO authenticated
  USING  (tenant_id = get_my_tenant_id())
  WITH CHECK (tenant_id = get_my_tenant_id());

-- ──────────────────────────────────────────────────────────────────
-- 17. questoes / questionarios / questionario_questoes
--     Permanecem públicos (conteúdo compartilhado entre tenants).
--     As políticas admin já existem e não precisam de tenant filter
--     porque os templates de questão são globais / da PSEG.
--     (Revisitar quando houver questões 100% privadas por tenant.)
-- ──────────────────────────────────────────────────────────────────
-- Nenhuma alteração neste release.

-- ──────────────────────────────────────────────────────────────────
-- 18. FUNÇÃO criar_tenant — self-service onboarding
--     Cria o tenant e promove o usuário atual a admin desse tenant.
--     SECURITY DEFINER: bypass de RLS necessário para INSERT em
--     tenants e UPDATE em perfis sem conflito de políticas.
-- ──────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION criar_tenant(
  p_nome  text,
  p_slug  text
)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tenant_id  uuid;
  v_slug       text;
  v_user_nome  text;
BEGIN
  -- 1. Normalizar slug
  v_slug := lower(regexp_replace(trim(p_slug), '[^a-z0-9\-]', '-', 'g'));
  v_slug := regexp_replace(v_slug, '-+', '-', 'g');   -- múltiplos hífens → 1
  v_slug := btrim(v_slug, '-');                        -- remover hífens das bordas

  IF length(v_slug) < 3 THEN
    RAISE EXCEPTION 'Slug muito curto após normalização (mínimo 3 caracteres): "%"', v_slug;
  END IF;

  -- 2. Criar tenant (30 dias de trial)
  INSERT INTO tenants (nome, slug, plano, trial_ate, criado_por)
  VALUES (
    trim(p_nome),
    v_slug,
    'trial',
    now() + interval '30 days',
    auth.uid()
  )
  RETURNING id INTO v_tenant_id;

  -- 3. Vincular usuário ao novo tenant como admin
  UPDATE perfis
  SET
    tenant_id  = v_tenant_id,
    role       = 'admin',
    updated_at = now()
  WHERE id = auth.uid();

  -- 4. Se o perfil ainda não existir, criá-lo
  IF NOT FOUND THEN
    SELECT COALESCE(
      raw_user_meta_data->>'nome',
      split_part(email, '@', 1)
    ) INTO v_user_nome
    FROM auth.users
    WHERE id = auth.uid();

    INSERT INTO perfis (id, nome, role, tenant_id)
    VALUES (auth.uid(), COALESCE(v_user_nome, 'Admin'), 'admin', v_tenant_id);
  END IF;

  RETURN v_tenant_id;
END;
$$;

-- ──────────────────────────────────────────────────────────────────
-- 19. Atualizar handle_new_user
--     Novos usuários registrados ficam com tenant_id = NULL e
--     role = 'consultor' até completar o onboarding via criar_tenant().
-- ──────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.perfis (id, nome, role, tenant_id)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'nome', split_part(NEW.email, '@', 1)),
    'consultor',
    NULL   -- tenant_id definido durante onboarding via criar_tenant()
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- ──────────────────────────────────────────────────────────────────
-- 20. FUNÇÃO convidar_membro — adiciona usuário existente ao tenant
--     Apenas admin do tenant pode convidar.
-- ──────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION convidar_membro(
  p_user_id  uuid,
  p_role     text DEFAULT 'consultor'
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- Verificar que o chamador é admin do seu tenant
  IF NOT is_tenant_admin() THEN
    RAISE EXCEPTION 'Apenas admins podem convidar membros.';
  END IF;

  IF p_role NOT IN ('admin', 'consultor', 'cliente_viewer') THEN
    RAISE EXCEPTION 'Role inválido: %', p_role;
  END IF;

  UPDATE perfis
  SET
    tenant_id  = get_my_tenant_id(),
    role       = p_role,
    updated_at = now()
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Usuário não encontrado: %', p_user_id;
  END IF;
END;
$$;

-- ──────────────────────────────────────────────────────────────────
-- 21. VIEW tenant_usage — métricas de uso para dashboard e billing
-- ──────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW tenant_usage AS
SELECT
  t.id                                                              AS tenant_id,
  t.nome                                                            AS tenant_nome,
  t.slug,
  t.plano,
  t.trial_ate,
  t.ativo,
  t.max_empresas,
  t.max_usuarios,
  t.max_respostas_mes,
  COUNT(DISTINCT e.id)::int                                         AS total_empresas,
  COUNT(DISTINCT p.id)::int                                         AS total_usuarios,
  COUNT(DISTINCT r.id)::int                                         AS total_respostas,
  COUNT(DISTINCT CASE
    WHEN r.respondido_em >= date_trunc('month', now())
    THEN r.id END)::int                                             AS respostas_mes_atual,
  -- Percentuais de uso em relação ao limite do plano
  CASE WHEN t.max_empresas IS NOT NULL
    THEN ROUND(COUNT(DISTINCT e.id) * 100.0 / t.max_empresas, 1)
    ELSE NULL
  END                                                               AS pct_empresas,
  CASE WHEN t.max_usuarios IS NOT NULL
    THEN ROUND(COUNT(DISTINCT p.id) * 100.0 / t.max_usuarios, 1)
    ELSE NULL
  END                                                               AS pct_usuarios
FROM tenants t
LEFT JOIN empresas  e ON e.tenant_id = t.id AND e.ativo = true
LEFT JOIN perfis    p ON p.tenant_id = t.id AND p.ativo = true
LEFT JOIN respostas r ON r.tenant_id = t.id
GROUP BY
  t.id, t.nome, t.slug, t.plano, t.trial_ate, t.ativo,
  t.max_empresas, t.max_usuarios, t.max_respostas_mes;

-- ══════════════════════════════════════════════════════════════════
-- FIM DA MIGRATION — CHECKLIST PÓS-EXECUÇÃO
-- ══════════════════════════════════════════════════════════════════
-- 1. Table Editor → tenants: deve ter 1 linha (pseg-default, enterprise)
-- 2. perfis: todas as linhas com tenant_id = 00000000-...-0099
-- 3. empresas: idem
-- 4. Teste a função: SELECT criar_tenant('Minha Consultoria', 'minha-consultoria');
--    → retorna UUID do novo tenant criado
--    → usuário corrente passa a ter role='admin' e tenant_id=<novo UUID>
-- 5. Confirme em tenant_usage: SELECT * FROM tenant_usage;
-- 6. Próximo passo: atualizar pseg-admin-questionario.html para passar
--    tenant_id nos INSERTs de empresas, ciclos, links e respostas.
-- ══════════════════════════════════════════════════════════════════
