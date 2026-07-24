-- ══════════════════════════════════════════════════════════════════════════
-- PsicoMap — Migração 10: Perfil de identidade visual da EST
-- Executar no Supabase Dashboard → SQL Editor (ou via MCP apply_migration)
-- ══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS est_perfil (
  id                    uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  tenant_id             uuid UNIQUE NOT NULL,
  nome_empresa          text,
  cnpj                  text,
  endereco              text,
  responsavel_padrao    text,
  registro_profissional text,
  logo_base64           text,   -- data URL (PNG/JPG, máx ~300 KB)
  atualizado_em         timestamptz DEFAULT now()
);

ALTER TABLE est_perfil ENABLE ROW LEVEL SECURITY;

CREATE POLICY "est_perfil_tenant_rls" ON est_perfil
  USING (tenant_id = (
    SELECT tenant_id FROM perfis WHERE id = auth.uid() LIMIT 1
  ));

COMMENT ON TABLE est_perfil IS
  'Configurações de identidade visual da EST por tenant — usadas no cabeçalho dos laudos.';
