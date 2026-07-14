-- ══════════════════════════════════════════════════════════════════════
-- migration_fix_grants_dev.sql
-- Corrige GRANTs de base ausentes em DEV para tabelas criadas via SQL
-- direto (fora do dashboard, que concede GRANT automaticamente).
-- Aplicado em DEV em 2026-07-13.
-- ══════════════════════════════════════════════════════════════════════

-- Problema: tabelas criadas via execute_sql direto (não pelo dashboard)
-- não recebem GRANT automático para authenticated/anon. RLS controla
-- QUAIS LINHAS um role vê, mas sem o GRANT de base a operação é negada
-- antes mesmo do RLS ser avaliado — erro "permission denied for table X",
-- diferente de uma negação normal de RLS.
--
-- Sintoma real: salvarGHE() falhava com "Quadro de funcionários
-- (limpeza): permission denied for table empresa_headcount" ao tentar
-- salvar headcount importado via CSV/Excel em DEV.

GRANT SELECT, INSERT, UPDATE, DELETE ON empresa_headcount TO authenticated, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON respostas_raw_backup TO authenticated, anon;

-- Nota: RLS permanece a camada de enforcement real (empresa_headcount
-- só tem policies para authenticated; respostas_raw_backup só permite
-- SELECT para super_admin). Os GRANTs acima só destravam a checagem de
-- base — não abrem acesso além do que as policies já restringem.
-- Conferido: grants em DEV agora espelham PROD para as duas tabelas.
