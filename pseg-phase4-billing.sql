-- ══════════════════════════════════════════════════════════════════
-- PSEG SafeSign — Fase 4: Billing (Subscriptions & Pagamentos)
-- Execute no SQL Editor do Supabase (projeto vftyiildukrpgmnbcnao)
-- Pré-requisito: pseg-phase3-saas-tenants.sql já aplicada
-- ══════════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────────
-- 1. TABELA subscriptions
--    Histórico de assinaturas por tenant. Um tenant pode ter várias
--    (canceladas + ativa). A ativa é status = 'active' | 'trialing'.
-- ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS subscriptions (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        uuid        NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  provider         text        NOT NULL
                               CHECK (provider IN ('stripe','asaas','manual')),
  provider_sub_id  text,                   -- Stripe subscription_id / Asaas sub id
  plano            text        NOT NULL
                               CHECK (plano IN ('trial','starter','professional','enterprise')),
  status           text        NOT NULL DEFAULT 'trialing'
                               CHECK (status IN ('trialing','active','past_due','canceled','unpaid')),
  periodo_inicio   timestamptz,
  periodo_fim      timestamptz,
  valor_centavos   int,                    -- valor em centavos BRL
  moeda            text        NOT NULL DEFAULT 'BRL',
  cancelado_em     timestamptz,
  motivo_cancel    text,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

DROP TRIGGER IF EXISTS tg_subscriptions_updated_at ON subscriptions;
CREATE TRIGGER tg_subscriptions_updated_at
  BEFORE UPDATE ON subscriptions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- RLS: tenant só vê as próprias assinaturas
CREATE POLICY "auth_select_subscriptions"
  ON subscriptions FOR SELECT TO authenticated
  USING (tenant_id = get_my_tenant_id());

-- Apenas service_role (webhook) escreve — front nunca escreve diretamente
-- Admin pode cancelar via função
CREATE POLICY "admin_insert_subscriptions"
  ON subscriptions FOR INSERT TO authenticated
  WITH CHECK (tenant_id = get_my_tenant_id() AND is_tenant_admin());

-- ──────────────────────────────────────────────────────────────────
-- 2. TABELA pagamentos
--    Cada cobrança / invoice gerada (PIX, boleto, cartão).
-- ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS pagamentos (
  id                   uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id            uuid        NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  subscription_id      uuid        REFERENCES subscriptions(id) ON DELETE SET NULL,
  provider             text        NOT NULL
                                   CHECK (provider IN ('stripe','asaas','manual')),
  provider_payment_id  text,                -- Stripe PaymentIntent id / Asaas payment id
  valor_centavos       int         NOT NULL,
  moeda                text        NOT NULL DEFAULT 'BRL',
  status               text        NOT NULL DEFAULT 'pending'
                                   CHECK (status IN ('pending','paid','failed','refunded','expired')),
  metodo               text,                -- 'pix', 'boleto', 'cartao_credito', 'cartao_debito'
  -- PIX
  pix_qr_code          text,
  pix_qr_code_base64   text,
  pix_expira_em        timestamptz,
  -- Boleto
  boleto_url           text,
  boleto_linha         text,
  boleto_expira_em     timestamptz,
  -- Cartão (sem dados sensíveis — apenas referência)
  cartao_ultimos4      text,
  cartao_bandeira      text,
  -- Datas
  pago_em              timestamptz,
  created_at           timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE pagamentos ENABLE ROW LEVEL SECURITY;

-- RLS: tenant vê os próprios pagamentos
CREATE POLICY "auth_select_pagamentos"
  ON pagamentos FOR SELECT TO authenticated
  USING (tenant_id = get_my_tenant_id());

-- ──────────────────────────────────────────────────────────────────
-- 3. ÍNDICES
-- ──────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_subscriptions_tenant   ON subscriptions(tenant_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status   ON subscriptions(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_pagamentos_tenant      ON pagamentos(tenant_id);
CREATE INDEX IF NOT EXISTS idx_pagamentos_status      ON pagamentos(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_pagamentos_provider    ON pagamentos(provider, provider_payment_id);

-- ──────────────────────────────────────────────────────────────────
-- 4. LIMITES POR PLANO
--    Tabela de referência usada em verificar_limite_tenant() e
--    aplicar_plano_tenant().
--    Manter aqui facilita ajustes sem alterar código.
-- ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS planos_config (
  plano            text PRIMARY KEY
                   CHECK (plano IN ('trial','starter','professional','enterprise')),
  nome_exibicao    text NOT NULL,
  valor_mensal_brl numeric(10,2),         -- NULL = sob consulta
  max_empresas     int,                   -- NULL = ilimitado
  max_usuarios     int,
  max_respostas_mes int,
  features         jsonb NOT NULL DEFAULT '[]',
  ordem            int NOT NULL DEFAULT 0
);

INSERT INTO planos_config (plano, nome_exibicao, valor_mensal_brl, max_empresas, max_usuarios, max_respostas_mes, features, ordem)
VALUES
  ('trial',        'Trial',        NULL,   1,    5,    100,
   '["1 empresa","5 usuários","100 respostas/mês","Todos os módulos por 30 dias"]', 0),
  ('starter',      'Starter',      197.00, 1,    10,   500,
   '["1 empresa","10 usuários","500 respostas/mês","Relatórios PDF","Suporte por e-mail"]', 1),
  ('professional', 'Professional', 497.00, 5,    25,   2000,
   '["5 empresas","25 usuários","2.000 respostas/mês","Múltiplos consultores","Prioridade no suporte"]', 2),
  ('enterprise',   'Enterprise',   997.00, NULL, NULL, NULL,
   '["Empresas ilimitadas","Usuários ilimitados","Respostas ilimitadas","White-label","SLA dedicado","Onboarding personalizado"]', 3)
ON CONFLICT (plano) DO NOTHING;

-- ──────────────────────────────────────────────────────────────────
-- 5. FUNÇÃO aplicar_plano_tenant
--    Atualiza o tenant para um novo plano e define os limites.
--    Chamada pelo webhook de pagamento (service_role) ou manualmente.
-- ──────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION aplicar_plano_tenant(
  p_tenant_id      uuid,
  p_plano          text,
  p_provider       text DEFAULT 'manual',
  p_provider_sub   text DEFAULT NULL,
  p_periodo_fim    timestamptz DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_cfg planos_config%ROWTYPE;
BEGIN
  SELECT * INTO v_cfg FROM planos_config WHERE plano = p_plano;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Plano inválido: %', p_plano;
  END IF;

  -- Atualizar tenant
  UPDATE tenants SET
    plano             = p_plano,
    max_empresas      = v_cfg.max_empresas,
    max_usuarios      = v_cfg.max_usuarios,
    max_respostas_mes = v_cfg.max_respostas_mes,
    -- Limpar trial_ate se passou para plano pago
    trial_ate         = CASE WHEN p_plano = 'trial' THEN trial_ate ELSE NULL END,
    updated_at        = now()
  WHERE id = p_tenant_id;

  -- Registrar subscription
  INSERT INTO subscriptions (tenant_id, provider, provider_sub_id, plano, status, periodo_inicio, periodo_fim)
  VALUES (
    p_tenant_id,
    p_provider,
    p_provider_sub,
    p_plano,
    CASE WHEN p_plano = 'trial' THEN 'trialing' ELSE 'active' END,
    now(),
    p_periodo_fim
  );
END;
$$;

-- ──────────────────────────────────────────────────────────────────
-- 6. FUNÇÃO verificar_limite_tenant
--    Retorna JSON com status do limite de um recurso.
--    Usada no front antes de criar empresa/usuário.
--    Usada em triggers para bloquear ações se limite atingido.
-- ──────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION verificar_limite_tenant(
  p_tenant_id  uuid,
  p_recurso    text   -- 'empresas' | 'usuarios' | 'respostas_mes'
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tenant  tenants%ROWTYPE;
  v_atual   int := 0;
  v_limite  int;
BEGIN
  SELECT * INTO v_tenant FROM tenants WHERE id = p_tenant_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('permitido', false, 'motivo', 'tenant_nao_encontrado');
  END IF;

  -- Trial expirado?
  IF v_tenant.plano = 'trial'
     AND v_tenant.trial_ate IS NOT NULL
     AND v_tenant.trial_ate < now() THEN
    RETURN jsonb_build_object(
      'permitido',  false,
      'motivo',     'trial_expirado',
      'mensagem',   'Período de trial encerrado. Faça o upgrade para continuar.',
      'plano',      v_tenant.plano,
      'trial_ate',  v_tenant.trial_ate
    );
  END IF;

  -- Contar uso atual
  IF p_recurso = 'empresas' THEN
    SELECT COUNT(*) INTO v_atual FROM empresas WHERE tenant_id = p_tenant_id AND ativo = true;
    v_limite := v_tenant.max_empresas;
  ELSIF p_recurso = 'usuarios' THEN
    SELECT COUNT(*) INTO v_atual FROM perfis WHERE tenant_id = p_tenant_id AND ativo = true;
    v_limite := v_tenant.max_usuarios;
  ELSIF p_recurso = 'respostas_mes' THEN
    SELECT COUNT(*) INTO v_atual FROM respostas
    WHERE tenant_id = p_tenant_id
      AND respondido_em >= date_trunc('month', now());
    v_limite := v_tenant.max_respostas_mes;
  ELSE
    RETURN jsonb_build_object('permitido', true, 'motivo', 'recurso_sem_limite');
  END IF;

  -- NULL = ilimitado
  IF v_limite IS NULL THEN
    RETURN jsonb_build_object(
      'permitido', true,
      'motivo',    'ilimitado',
      'atual',     v_atual,
      'limite',    null,
      'plano',     v_tenant.plano
    );
  END IF;

  RETURN jsonb_build_object(
    'permitido',  v_atual < v_limite,
    'motivo',     CASE WHEN v_atual < v_limite THEN 'ok' ELSE 'limite_atingido' END,
    'mensagem',   CASE WHEN v_atual < v_limite THEN null
                       ELSE format('Limite de %s atingido (%s/%s). Faça o upgrade do plano.', p_recurso, v_atual, v_limite)
                  END,
    'atual',      v_atual,
    'limite',     v_limite,
    'pct',        ROUND(v_atual * 100.0 / v_limite, 1),
    'plano',      v_tenant.plano
  );
END;
$$;

-- ──────────────────────────────────────────────────────────────────
-- 7. Atualizar criar_tenant para definir limites do trial
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
  v_cfg        planos_config%ROWTYPE;
BEGIN
  -- Normalizar slug
  v_slug := lower(regexp_replace(trim(p_slug), '[^a-z0-9\-]', '-', 'g'));
  v_slug := regexp_replace(v_slug, '-+', '-', 'g');
  v_slug := btrim(v_slug, '-');

  IF length(v_slug) < 3 THEN
    RAISE EXCEPTION 'Slug muito curto após normalização (mínimo 3 caracteres): "%"', v_slug;
  END IF;

  -- Buscar limites do plano trial
  SELECT * INTO v_cfg FROM planos_config WHERE plano = 'trial';

  -- Criar tenant com limites do trial
  INSERT INTO tenants (
    nome, slug, plano, trial_ate, criado_por,
    max_empresas, max_usuarios, max_respostas_mes
  )
  VALUES (
    trim(p_nome), v_slug, 'trial',
    now() + interval '30 days',
    auth.uid(),
    v_cfg.max_empresas,
    v_cfg.max_usuarios,
    v_cfg.max_respostas_mes
  )
  RETURNING id INTO v_tenant_id;

  -- Registrar subscription de trial
  INSERT INTO subscriptions (tenant_id, provider, plano, status, periodo_inicio, periodo_fim)
  VALUES (v_tenant_id, 'manual', 'trial', 'trialing', now(), now() + interval '30 days');

  -- Vincular usuário como admin
  UPDATE perfis
  SET tenant_id = v_tenant_id, role = 'admin', updated_at = now()
  WHERE id = auth.uid();

  IF NOT FOUND THEN
    SELECT COALESCE(raw_user_meta_data->>'nome', split_part(email, '@', 1))
    INTO v_user_nome FROM auth.users WHERE id = auth.uid();
    INSERT INTO perfis (id, nome, role, tenant_id)
    VALUES (auth.uid(), COALESCE(v_user_nome, 'Admin'), 'admin', v_tenant_id);
  END IF;

  RETURN v_tenant_id;
END;
$$;

-- ──────────────────────────────────────────────────────────────────
-- 8. VIEW ativa_subscription — assinatura ativa de cada tenant
-- ──────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_subscription_ativa AS
SELECT DISTINCT ON (s.tenant_id)
  s.tenant_id,
  s.id           AS subscription_id,
  s.plano,
  s.status,
  s.provider,
  s.periodo_fim,
  t.trial_ate,
  t.nome         AS tenant_nome,
  CASE
    WHEN t.plano = 'trial' AND t.trial_ate >= now() THEN
      EXTRACT(DAY FROM t.trial_ate - now())::int
    ELSE NULL
  END            AS trial_dias_restantes,
  t.plano = 'trial' AND (t.trial_ate IS NULL OR t.trial_ate < now())
                 AS trial_expirado
FROM subscriptions s
JOIN tenants t ON t.id = s.tenant_id
WHERE s.status IN ('trialing','active','past_due')
ORDER BY s.tenant_id, s.created_at DESC;

-- ══════════════════════════════════════════════════════════════════
-- FIM DA MIGRATION
-- Próximos passos:
-- 1. Deploy das Edge Functions (criar-checkout, webhook-billing)
-- 2. Configurar STRIPE_SECRET_KEY e ASAAS_API_KEY no Supabase Vault
-- 3. Registrar webhook URL no painel Stripe e Asaas
-- 4. Testar: SELECT verificar_limite_tenant('<tenant_id>', 'empresas');
-- ══════════════════════════════════════════════════════════════════
