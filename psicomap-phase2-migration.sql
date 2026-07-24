-- ══════════════════════════════════════════════════════════════
-- PSEG SafeSign — Fase 2: GHE (Setores & Funções por Empresa)
-- Execute no SQL Editor do Supabase (projeto vftyiildukrpgmnbcnao)
-- Pré-requisito: pseg-phase1-migration.sql já aplicada
-- ══════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- 1. TABELA empresa_setores
--    Grupos Homogêneos de Exposição (GHE) por empresa
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS empresa_setores (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id  uuid        NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  nome        text        NOT NULL,
  ordem       int         NOT NULL DEFAULT 0,
  ativo       boolean     NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (empresa_id, nome)
);

ALTER TABLE empresa_setores ENABLE ROW LEVEL SECURITY;

-- ─────────────────────────────────────────────────────────────
-- 2. TABELA empresa_funcoes
--    Funções/Cargos cadastrados por empresa
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS empresa_funcoes (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id  uuid        NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  nome        text        NOT NULL,
  ordem       int         NOT NULL DEFAULT 0,
  ativo       boolean     NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (empresa_id, nome)
);

ALTER TABLE empresa_funcoes ENABLE ROW LEVEL SECURITY;

-- ─────────────────────────────────────────────────────────────
-- 3. RLS — empresa_setores
-- ─────────────────────────────────────────────────────────────

-- Leitura pública: o formulário de coleta precisa ler os setores da empresa
-- sem autenticação (via token anon)
CREATE POLICY "pub_read_empresa_setores"
  ON empresa_setores FOR SELECT
  USING (ativo = true);

-- Autenticado: admin pode tudo; consultor só gerencia empresas que criou
CREATE POLICY "auth_manage_empresa_setores"
  ON empresa_setores FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM perfis p
      WHERE p.id = auth.uid()
      AND (
        p.role = 'admin'
        OR EXISTS (
          SELECT 1 FROM empresas e
          WHERE e.id = empresa_setores.empresa_id
          AND (e.criado_por = auth.uid() OR p.empresa_id = e.id)
        )
      )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM perfis p
      WHERE p.id = auth.uid()
      AND (
        p.role = 'admin'
        OR EXISTS (
          SELECT 1 FROM empresas e
          WHERE e.id = empresa_setores.empresa_id
          AND (e.criado_por = auth.uid() OR p.empresa_id = e.id)
        )
      )
    )
  );

-- ─────────────────────────────────────────────────────────────
-- 4. RLS — empresa_funcoes
-- ─────────────────────────────────────────────────────────────

CREATE POLICY "pub_read_empresa_funcoes"
  ON empresa_funcoes FOR SELECT
  USING (ativo = true);

CREATE POLICY "auth_manage_empresa_funcoes"
  ON empresa_funcoes FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM perfis p
      WHERE p.id = auth.uid()
      AND (
        p.role = 'admin'
        OR EXISTS (
          SELECT 1 FROM empresas e
          WHERE e.id = empresa_funcoes.empresa_id
          AND (e.criado_por = auth.uid() OR p.empresa_id = e.id)
        )
      )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM perfis p
      WHERE p.id = auth.uid()
      AND (
        p.role = 'admin'
        OR EXISTS (
          SELECT 1 FROM empresas e
          WHERE e.id = empresa_funcoes.empresa_id
          AND (e.criado_por = auth.uid() OR p.empresa_id = e.id)
        )
      )
    )
  );

-- ─────────────────────────────────────────────────────────────
-- 5. Índices de performance
-- ─────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_empresa_setores_empresa_id
  ON empresa_setores (empresa_id, ordem);

CREATE INDEX IF NOT EXISTS idx_empresa_funcoes_empresa_id
  ON empresa_funcoes (empresa_id, ordem);

-- ─────────────────────────────────────────────────────────────
-- 6. (Opcional) Migrar setores/funções hardcodados existentes
--    Execute apenas se já houver dados em respostas e quiser
--    popular as tabelas com os valores históricos únicos.
-- ─────────────────────────────────────────────────────────────

-- Popula empresa_setores a partir de respostas existentes (deduplica)
-- Descomente e adapte o empresa_id antes de executar:
/*
INSERT INTO empresa_setores (empresa_id, nome, ordem)
SELECT DISTINCT
  r.empresa_id,
  r.setor,
  ROW_NUMBER() OVER (PARTITION BY r.empresa_id ORDER BY r.setor) - 1
FROM respostas r
WHERE r.setor IS NOT NULL AND r.setor <> ''
  AND r.empresa_id = '<SEU_EMPRESA_ID>'
ON CONFLICT (empresa_id, nome) DO NOTHING;
*/

-- Popula empresa_funcoes a partir de respostas existentes
/*
INSERT INTO empresa_funcoes (empresa_id, nome, ordem)
SELECT DISTINCT
  r.empresa_id,
  r.funcao,
  ROW_NUMBER() OVER (PARTITION BY r.empresa_id ORDER BY r.funcao) - 1
FROM respostas r
WHERE r.funcao IS NOT NULL AND r.funcao <> ''
  AND r.empresa_id = '<SEU_EMPRESA_ID>'
ON CONFLICT (empresa_id, nome) DO NOTHING;
*/

-- ══════════════════════════════════════════════════════════════
-- FIM DA MIGRATION
-- Após executar:
-- 1. Verifique as tabelas em Table Editor → empresa_setores / empresa_funcoes
-- 2. No painel admin, abra Links → "Setores & Funções" e cadastre GHEs
-- 3. Gere um novo link e verifique que o select de setor aparece no formulário
-- 4. Teste o formulário em /form?token=<token> e confirme setor/função dinâmicos
-- ══════════════════════════════════════════════════════════════
