-- ══════════════════════════════════════════════════════════════════════
-- migration_links_multi_resposta.sql
-- Adiciona flag por link para permitir múltiplas respostas no mesmo
-- dispositivo (ex.: notebook compartilhado por trabalhadores de campo)
-- Aplicar em DEV primeiro, validar, depois em PROD
-- ══════════════════════════════════════════════════════════════════════

ALTER TABLE links_coleta
  ADD COLUMN IF NOT EXISTS permite_multi_resposta boolean DEFAULT false;
