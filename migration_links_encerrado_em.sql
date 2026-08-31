-- ══════════════════════════════════════════════════════════════════════════
-- PsicoMap — Migração: Finalização de campanha em links de coleta
-- Executar no Supabase Dashboard → SQL Editor
-- ══════════════════════════════════════════════════════════════════════════

-- ── 1. Adicionar coluna encerrado_em em links_coleta ──────────────────────
-- Aditiva e puramente informativa: `ativo` continua sendo o único campo lido
-- por RLS, pela RPC salvar_resposta e pelo formulário público para decidir
-- se o link aceita novas respostas. `encerrado_em` só distingue, na UI, um
-- link desativado por pausa temporária (encerrado_em NULL) de um link cuja
-- campanha foi finalizada intencionalmente (encerrado_em preenchido).
ALTER TABLE links_coleta
  ADD COLUMN IF NOT EXISTS encerrado_em timestamptz DEFAULT NULL;

COMMENT ON COLUMN links_coleta.encerrado_em IS
  'Preenchido quando o admin finaliza a campanha deste link (ação '
  '"Finalizar campanha"). NULL = link ativo ou apenas pausado. Não afeta '
  'RLS/RPC — ativo=false continua sendo o único gate de novas respostas; '
  'esta coluna é só metadado de UI para distinguir pausa de conclusão.';

-- ── VERIFICAÇÃO ───────────────────────────────────────────────────────────
SELECT id, token, ativo, encerrado_em, is_teste, criado_em
FROM links_coleta
ORDER BY criado_em DESC
LIMIT 5;
