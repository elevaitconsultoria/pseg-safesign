-- ══════════════════════════════════════════════════════════════
-- PSEG SafeSign — Fase 1: Migration de Estabilização
-- Execute no SQL Editor do Supabase (projeto vftyiildukrpgmnbcnao)
-- ══════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- 1. TABELA perfis
--    Vincula auth.users a roles e empresa opcional
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS perfis (
  id          uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nome        text        NOT NULL DEFAULT '',
  role        text        NOT NULL DEFAULT 'consultor'
                          CHECK (role IN ('admin', 'consultor', 'cliente_viewer')),
  empresa_id  uuid        REFERENCES empresas(id) ON DELETE SET NULL,
  ativo       boolean     NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE perfis ENABLE ROW LEVEL SECURITY;

-- Trigger: updated_at automático
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

DROP TRIGGER IF EXISTS tg_perfis_updated_at ON perfis;
CREATE TRIGGER tg_perfis_updated_at
  BEFORE UPDATE ON perfis
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ─────────────────────────────────────────────────────────────
-- 2. COLUNA criado_por em empresas
--    Rastreia qual usuário cadastrou a empresa
-- ─────────────────────────────────────────────────────────────
ALTER TABLE empresas
  ADD COLUMN IF NOT EXISTS criado_por uuid REFERENCES auth.users(id) ON DELETE SET NULL;

-- ─────────────────────────────────────────────────────────────
-- 3. COLUNAS de período em ciclos
-- ─────────────────────────────────────────────────────────────
ALTER TABLE ciclos
  ADD COLUMN IF NOT EXISTS data_inicio date,
  ADD COLUMN IF NOT EXISTS data_fim    date,
  ADD COLUMN IF NOT EXISTS descricao   text;

-- ─────────────────────────────────────────────────────────────
-- 4. TABELA riscos_config
--    Riscos por empresa (substitui localStorage)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS riscos_config (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id    uuid        REFERENCES empresas(id) ON DELETE CASCADE,
  cd_risco      int         NOT NULL,
  nome          text        NOT NULL,
  categoria     text,
  severidade    int         CHECK (severidade BETWEEN 1 AND 4),
  consequencias text,
  updated_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (empresa_id, cd_risco)
);

ALTER TABLE riscos_config ENABLE ROW LEVEL SECURITY;

-- ─────────────────────────────────────────────────────────────
-- 5. RLS — perfis
-- ─────────────────────────────────────────────────────────────

-- Usuário vê e edita apenas o próprio perfil
CREATE POLICY "perfil_self_select"
  ON perfis FOR SELECT TO authenticated
  USING (id = auth.uid());

CREATE POLICY "perfil_self_update"
  ON perfis FOR UPDATE TO authenticated
  USING (id = auth.uid());

-- Admin vê todos os perfis
CREATE POLICY "admin_all_perfis"
  ON perfis FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM perfis p WHERE p.id = auth.uid() AND p.role = 'admin')
  );

-- ─────────────────────────────────────────────────────────────
-- 6. RLS — empresas (substitui a política genérica anterior)
-- ─────────────────────────────────────────────────────────────

-- Remover políticas antigas (se existirem)
DROP POLICY IF EXISTS "admin_all_empresas"    ON empresas;
DROP POLICY IF EXISTS "pub_read_empresa"      ON empresas;

-- Leitura pública: formulário precisa ler empresa pelo link_coleta
CREATE POLICY "pub_read_empresa_ativa"
  ON empresas FOR SELECT
  USING (ativo = true);

-- Autenticado: admin vê tudo; consultor vê apenas empresas criadas por ele
-- (após criar perfis, esta política pode ser refinada por empresa_id)
CREATE POLICY "auth_select_empresas"
  ON empresas FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM perfis p
      WHERE p.id = auth.uid()
      AND (
        p.role = 'admin'
        OR p.empresa_id = empresas.id
        OR empresas.criado_por = auth.uid()
      )
    )
  );

CREATE POLICY "auth_insert_empresa"
  ON empresas FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "auth_update_empresa"
  ON empresas FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM perfis p
      WHERE p.id = auth.uid()
      AND (p.role = 'admin' OR empresas.criado_por = auth.uid())
    )
  );

-- ─────────────────────────────────────────────────────────────
-- 7. RLS — respostas (corrige o WITH CHECK (true) inseguro)
-- ─────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "pub_insert_resposta" ON respostas;

-- Só insere se o token existir, estiver ativo e não expirado
CREATE POLICY "pub_insert_resposta_validada"
  ON respostas FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM links_coleta lc
      WHERE lc.token      = link_token
        AND lc.empresa_id = respostas.empresa_id
        AND lc.ativo      = true
        AND (lc.expira_em IS NULL OR lc.expira_em > now())
    )
  );

-- ─────────────────────────────────────────────────────────────
-- 8. RLS — riscos_config
-- ─────────────────────────────────────────────────────────────

CREATE POLICY "auth_all_riscos_config"
  ON riscos_config FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM perfis p
      WHERE p.id = auth.uid()
      AND (
        p.role = 'admin'
        OR p.empresa_id = riscos_config.empresa_id
      )
    )
  );

-- ─────────────────────────────────────────────────────────────
-- 9. Função utilitária: criar perfil automaticamente no signup
--    (opcional — facilita onboarding de novos usuários)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.perfis (id, nome, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'nome', split_part(NEW.email, '@', 1)),
    'consultor'  -- role padrão; admin promove manualmente
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ─────────────────────────────────────────────────────────────
-- 10. Criar perfil para usuários existentes (retroativo)
--     Execute uma vez após rodar a migration
-- ─────────────────────────────────────────────────────────────
INSERT INTO perfis (id, nome, role)
SELECT
  id,
  COALESCE(raw_user_meta_data->>'nome', split_part(email, '@', 1)),
  'admin'  -- primeiros usuários assumem role admin
FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- ══════════════════════════════════════════════════════════════
-- FIM DA MIGRATION
-- Após executar:
-- 1. Verifique em Authentication → Users que os usuários têm perfil
-- 2. No painel admin, teste login e logout
-- 3. Verifique que DEV_BYPASS_AUTH = false no HTML antes do deploy
-- ══════════════════════════════════════════════════════════════
