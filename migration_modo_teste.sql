-- ══════════════════════════════════════════════════════════════════════════
-- PSEG SafeSign — Migração 9: Modo teste em links de coleta
-- Executar no Supabase Dashboard → SQL Editor
-- ══════════════════════════════════════════════════════════════════════════

-- ── 1. Adicionar coluna is_teste em links_coleta ──────────────────────────
ALTER TABLE links_coleta
  ADD COLUMN IF NOT EXISTS is_teste boolean DEFAULT false NOT NULL;

COMMENT ON COLUMN links_coleta.is_teste IS
  'true = link de teste. Respostas deste link são excluídas dos cálculos '
  'e podem ser deletadas junto com o link pelo admin da EST.';

-- ── 2. Índice para filtrar respostas de teste na análise ─────────────────
CREATE INDEX IF NOT EXISTS links_coleta_is_teste_idx
  ON links_coleta (is_teste, tenant_id);

-- ── VERIFICAÇÃO ───────────────────────────────────────────────────────────
SELECT id, token, ativo, is_teste, criado_em
FROM links_coleta
ORDER BY criado_em DESC
LIMIT 5;
