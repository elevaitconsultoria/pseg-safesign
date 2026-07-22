-- ══════════════════════════════════════════════════════════════════════
-- migration_ciclos_referencia_temporal.sql
-- Referencia temporal estruturada (ano/mes) + classificacao opcional de
-- ciclos de avaliacao. Separa "quando o ciclo se refere" (fato objetivo,
-- obrigatorio) de "como classificar esse ciclo" (interpretacao, opcional).
-- criado_em permanece so para auditoria tecnica, nunca para logica de
-- periodo. Aplicar em DEV, validar, depois PROD.
-- ══════════════════════════════════════════════════════════════════════

ALTER TABLE ciclos
  ADD COLUMN IF NOT EXISTS ano_referencia integer,
  ADD COLUMN IF NOT EXISTS mes_referencia integer CHECK (mes_referencia BETWEEN 1 AND 12),
  ADD COLUMN IF NOT EXISTS tipo_ciclo text DEFAULT 'Não classificado',
  ADD COLUMN IF NOT EXISTS referencia_estimada boolean DEFAULT false;

-- Backfill: infere ano/mes dos ciclos ja existentes a partir de data_inicio
-- (mais preciso) com fallback para criado_em. Marca como "estimado" para o
-- consultor identificar visualmente que pode precisar de correcao manual.
UPDATE ciclos
SET ano_referencia = EXTRACT(YEAR  FROM COALESCE(data_inicio, criado_em))::int,
    mes_referencia = EXTRACT(MONTH FROM COALESCE(data_inicio, criado_em))::int,
    referencia_estimada = true
WHERE ano_referencia IS NULL;
