-- ══════════════════════════════════════════════════════════════════════
-- migration_sync_est_perfil_prod.sql
-- Sincroniza colunas extras de DEV → PROD em est_perfil
-- Apliar em PROD (vftyiildukrpgmnbcnao) quando implementar identidade visual da EST
-- ══════════════════════════════════════════════════════════════════════

-- Colunas existentes em DEV mas ausentes em PROD:
--   cor_primaria     — cor hex para identidade visual da EST nos laudos
--   nome_responsavel — nome do responsável técnico (alternativo ao responsavel_padrao)
--   email_responsavel — e-mail do responsável para contato no laudo

ALTER TABLE est_perfil
  ADD COLUMN IF NOT EXISTS cor_primaria      text DEFAULT '#16a34a',
  ADD COLUMN IF NOT EXISTS nome_responsavel  text,
  ADD COLUMN IF NOT EXISTS email_responsavel text;
