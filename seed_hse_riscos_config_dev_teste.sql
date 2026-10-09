-- ═══════════════════════════════════════════════════════════════════════════════════════
-- SEED DE TESTE da severidade por dimensão HSE — SOMENTE DEV
-- ⛔ NÃO APLICAR EM PROD. Os valores abaixo são ARBITRÁRIOS, só para exercitar o cálculo: a severidade
--    real é decisão de SST/psicólogo (ver migration_hse_riscos_config.sql). Todas as linhas ficam
--    validado = false, o que faz o laudo sair marcado "CRITÉRIO NÃO VALIDADO".
-- O seed de PROD (go-live) é outro arquivo e deve ABORTAR se houver qualquer linha com validado = false.
-- ═══════════════════════════════════════════════════════════════════════════════════════
INSERT INTO hse_riscos_config (dimensao, severidade, danos, versao, validado) VALUES
  ('DEMANDS',         3, '[TESTE] danos possíveis — Demandas',         1, false),
  ('CONTROL',         2, '[TESTE] danos possíveis — Controle',         1, false),
  ('MANAGER_SUPPORT', 2, '[TESTE] danos possíveis — Apoio da gestão',  1, false),
  ('PEER_SUPPORT',    2, '[TESTE] danos possíveis — Suporte dos colegas', 1, false),
  ('RELATIONSHIPS',   3, '[TESTE] danos possíveis — Relacionamentos',  1, false),
  ('ROLE',            2, '[TESTE] danos possíveis — Clareza de papel', 1, false),
  ('CHANGE',          2, '[TESTE] danos possíveis — Mudanças',         1, false)
ON CONFLICT (dimensao) DO NOTHING;
