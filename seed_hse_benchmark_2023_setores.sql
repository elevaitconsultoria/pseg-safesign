-- ═══════════════════════════════════════════════════════════════════════════════════════
-- Benchmark HSE 2023 — médias por SETOR (13 grupos de comparação)
-- Fonte: "Stress Indicator Tool (SIT) — Benchmarking report", HSE, agosto/2023, págs. 6–18
--   https://books.hse.gov.uk/gempdf/HSE_Stress_Indicator_Tool_Benchmarking_Report_2023.pdf
--   Dados públicos de referência (não são dados de tenant) — vale para DEV e PROD. Idempotente.
--
-- COMO FOI GERADO: extraído do texto do PDF por script (sem digitação) e validado: 13 setores × 7
--   dimensões = 91 médias; em cada célula min ≤ média ≤ máx e todos dentro de 1..5; o mapeamento
--   página → setor foi conferido visualmente (p.7 = Business Process Outsourcing).
-- O QUE FICA GRAVADO: só a MÉDIA (coluna media) e o tamanho do grupo (n_amostra = respondentes).
--   Mínimo, máximo e nº de avaliações (organizações) ficam em `observacao`. Percentis permanecem NULL.
-- ⚠ Comparar com o setor só faz sentido com cautela: os grupos são de ORGANIZAÇÕES BRITÂNICAS que
--   escolheram usar a ferramenta (o próprio relatório avisa que não se pode inferir bom/ruim
--   desempenho), e vários têm poucos respondentes (Healthcare 242, Retail 263, Energy 252).
--   O app hoje usa APENAS setor='GERAL' (_hseCarregarBenchmark); estas linhas são referência
--   guardada, sem efeito em nenhuma tela até existir seleção de setor (fase 1.1, depende de CNAE).
-- Rollback: DELETE FROM hse_benchmark WHERE fonte='HSE_2023' AND setor <> 'GERAL';
-- ═══════════════════════════════════════════════════════════════════════════════════════
INSERT INTO hse_benchmark (fonte, fonte_ano, setor, dimensao, media, n_amostra, vigente, observacao) VALUES
  ('HSE_2023', 2023, 'BLUE_LIGHT', 'DEMANDS', 3.24, 1976, true, 'Blue light / emergency services · mín 2.94 · máx 3.58 · 4 avaliações; relatório HSE ago/2023 p.6; alto = melhor'),
  ('HSE_2023', 2023, 'BLUE_LIGHT', 'CONTROL', 3.27, 1976, true, 'Blue light / emergency services · mín 3.11 · máx 3.45 · 4 avaliações; relatório HSE ago/2023 p.6; alto = melhor'),
  ('HSE_2023', 2023, 'BLUE_LIGHT', 'MANAGER_SUPPORT', 3.74, 1976, true, 'Blue light / emergency services · mín 3.46 · máx 3.92 · 4 avaliações; relatório HSE ago/2023 p.6; alto = melhor'),
  ('HSE_2023', 2023, 'BLUE_LIGHT', 'PEER_SUPPORT', 3.93, 1976, true, 'Blue light / emergency services · mín 3.85 · máx 4.04 · 4 avaliações; relatório HSE ago/2023 p.6; alto = melhor'),
  ('HSE_2023', 2023, 'BLUE_LIGHT', 'RELATIONSHIPS', 4.02, 1976, true, 'Blue light / emergency services · mín 3.87 · máx 4.16 · 4 avaliações; relatório HSE ago/2023 p.6; alto = melhor'),
  ('HSE_2023', 2023, 'BLUE_LIGHT', 'ROLE', 4.13, 1976, true, 'Blue light / emergency services · mín 4.01 · máx 4.26 · 4 avaliações; relatório HSE ago/2023 p.6; alto = melhor'),
  ('HSE_2023', 2023, 'BLUE_LIGHT', 'CHANGE', 3.06, 1976, true, 'Blue light / emergency services · mín 2.76 · máx 3.30 · 4 avaliações; relatório HSE ago/2023 p.6; alto = melhor'),
  ('HSE_2023', 2023, 'BPO', 'DEMANDS', 3.34, 297, true, 'Business Process Outsourcing · mín 3.26 · máx 3.50 · 3 avaliações; relatório HSE ago/2023 p.7; alto = melhor'),
  ('HSE_2023', 2023, 'BPO', 'CONTROL', 3.73, 297, true, 'Business Process Outsourcing · mín 3.68 · máx 3.84 · 3 avaliações; relatório HSE ago/2023 p.7; alto = melhor'),
  ('HSE_2023', 2023, 'BPO', 'MANAGER_SUPPORT', 4.02, 297, true, 'Business Process Outsourcing · mín 3.84 · máx 4.15 · 3 avaliações; relatório HSE ago/2023 p.7; alto = melhor'),
  ('HSE_2023', 2023, 'BPO', 'PEER_SUPPORT', 4.14, 297, true, 'Business Process Outsourcing · mín 4.08 · máx 4.20 · 3 avaliações; relatório HSE ago/2023 p.7; alto = melhor'),
  ('HSE_2023', 2023, 'BPO', 'RELATIONSHIPS', 4.34, 297, true, 'Business Process Outsourcing · mín 4.21 · máx 4.45 · 3 avaliações; relatório HSE ago/2023 p.7; alto = melhor'),
  ('HSE_2023', 2023, 'BPO', 'ROLE', 4.32, 297, true, 'Business Process Outsourcing · mín 4.21 · máx 4.41 · 3 avaliações; relatório HSE ago/2023 p.7; alto = melhor'),
  ('HSE_2023', 2023, 'BPO', 'CHANGE', 3.48, 297, true, 'Business Process Outsourcing · mín 3.21 · máx 3.64 · 3 avaliações; relatório HSE ago/2023 p.7; alto = melhor'),
  ('HSE_2023', 2023, 'CHARITY', 'DEMANDS', 3.44, 1041, true, 'Charity / Not for Profit · mín 3.09 · máx 3.80 · 10 avaliações; relatório HSE ago/2023 p.8; alto = melhor'),
  ('HSE_2023', 2023, 'CHARITY', 'CONTROL', 3.71, 1041, true, 'Charity / Not for Profit · mín 3.37 · máx 4.03 · 10 avaliações; relatório HSE ago/2023 p.8; alto = melhor'),
  ('HSE_2023', 2023, 'CHARITY', 'MANAGER_SUPPORT', 3.82, 1041, true, 'Charity / Not for Profit · mín 3.43 · máx 4.29 · 10 avaliações; relatório HSE ago/2023 p.8; alto = melhor'),
  ('HSE_2023', 2023, 'CHARITY', 'PEER_SUPPORT', 4.02, 1041, true, 'Charity / Not for Profit · mín 3.63 · máx 4.29 · 10 avaliações; relatório HSE ago/2023 p.8; alto = melhor'),
  ('HSE_2023', 2023, 'CHARITY', 'RELATIONSHIPS', 4.04, 1041, true, 'Charity / Not for Profit · mín 3.36 · máx 4.36 · 10 avaliações; relatório HSE ago/2023 p.8; alto = melhor'),
  ('HSE_2023', 2023, 'CHARITY', 'ROLE', 4.33, 1041, true, 'Charity / Not for Profit · mín 3.87 · máx 4.64 · 10 avaliações; relatório HSE ago/2023 p.8; alto = melhor'),
  ('HSE_2023', 2023, 'CHARITY', 'CHANGE', 3.36, 1041, true, 'Charity / Not for Profit · mín 3.01 · máx 3.88 · 10 avaliações; relatório HSE ago/2023 p.8; alto = melhor'),
  ('HSE_2023', 2023, 'CONSTRUCTION', 'DEMANDS', 3.32, 999, true, 'Construction · mín 2.94 · máx 3.64 · 5 avaliações; relatório HSE ago/2023 p.9; alto = melhor'),
  ('HSE_2023', 2023, 'CONSTRUCTION', 'CONTROL', 3.86, 999, true, 'Construction · mín 3.75 · máx 4.05 · 5 avaliações; relatório HSE ago/2023 p.9; alto = melhor'),
  ('HSE_2023', 2023, 'CONSTRUCTION', 'MANAGER_SUPPORT', 3.82, 999, true, 'Construction · mín 3.54 · máx 4.02 · 5 avaliações; relatório HSE ago/2023 p.9; alto = melhor'),
  ('HSE_2023', 2023, 'CONSTRUCTION', 'PEER_SUPPORT', 3.98, 999, true, 'Construction · mín 3.78 · máx 4.15 · 5 avaliações; relatório HSE ago/2023 p.9; alto = melhor'),
  ('HSE_2023', 2023, 'CONSTRUCTION', 'RELATIONSHIPS', 4.24, 999, true, 'Construction · mín 3.90 · máx 4.48 · 5 avaliações; relatório HSE ago/2023 p.9; alto = melhor'),
  ('HSE_2023', 2023, 'CONSTRUCTION', 'ROLE', 4.20, 999, true, 'Construction · mín 4.06 · máx 4.46 · 5 avaliações; relatório HSE ago/2023 p.9; alto = melhor'),
  ('HSE_2023', 2023, 'CONSTRUCTION', 'CHANGE', 3.38, 999, true, 'Construction · mín 3.05 · máx 3.62 · 5 avaliações; relatório HSE ago/2023 p.9; alto = melhor'),
  ('HSE_2023', 2023, 'EDUCATION', 'DEMANDS', 3.08, 3481, true, 'Education · mín 2.29 · máx 3.53 · 15 avaliações; relatório HSE ago/2023 p.10; alto = melhor'),
  ('HSE_2023', 2023, 'EDUCATION', 'CONTROL', 3.44, 3481, true, 'Education · mín 2.97 · máx 3.84 · 15 avaliações; relatório HSE ago/2023 p.10; alto = melhor'),
  ('HSE_2023', 2023, 'EDUCATION', 'MANAGER_SUPPORT', 3.66, 3481, true, 'Education · mín 2.58 · máx 4.27 · 15 avaliações; relatório HSE ago/2023 p.10; alto = melhor'),
  ('HSE_2023', 2023, 'EDUCATION', 'PEER_SUPPORT', 3.97, 3481, true, 'Education · mín 3.06 · máx 4.49 · 15 avaliações; relatório HSE ago/2023 p.10; alto = melhor'),
  ('HSE_2023', 2023, 'EDUCATION', 'RELATIONSHIPS', 4.04, 3481, true, 'Education · mín 3.61 · máx 4.35 · 15 avaliações; relatório HSE ago/2023 p.10; alto = melhor'),
  ('HSE_2023', 2023, 'EDUCATION', 'ROLE', 4.13, 3481, true, 'Education · mín 3.38 · máx 4.75 · 15 avaliações; relatório HSE ago/2023 p.10; alto = melhor'),
  ('HSE_2023', 2023, 'EDUCATION', 'CHANGE', 3.10, 3481, true, 'Education · mín 2.43 · máx 3.90 · 15 avaliações; relatório HSE ago/2023 p.10; alto = melhor'),
  ('HSE_2023', 2023, 'ENERGY', 'DEMANDS', 3.53, 252, true, 'Energy · mín 3.24 · máx 3.89 · 5 avaliações; relatório HSE ago/2023 p.11; alto = melhor'),
  ('HSE_2023', 2023, 'ENERGY', 'CONTROL', 3.96, 252, true, 'Energy · mín 3.84 · máx 4.06 · 5 avaliações; relatório HSE ago/2023 p.11; alto = melhor'),
  ('HSE_2023', 2023, 'ENERGY', 'MANAGER_SUPPORT', 3.92, 252, true, 'Energy · mín 3.87 · máx 4.06 · 5 avaliações; relatório HSE ago/2023 p.11; alto = melhor'),
  ('HSE_2023', 2023, 'ENERGY', 'PEER_SUPPORT', 4.11, 252, true, 'Energy · mín 4.02 · máx 4.31 · 5 avaliações; relatório HSE ago/2023 p.11; alto = melhor'),
  ('HSE_2023', 2023, 'ENERGY', 'RELATIONSHIPS', 4.40, 252, true, 'Energy · mín 4.23 · máx 4.54 · 5 avaliações; relatório HSE ago/2023 p.11; alto = melhor'),
  ('HSE_2023', 2023, 'ENERGY', 'ROLE', 4.33, 252, true, 'Energy · mín 4.14 · máx 4.65 · 5 avaliações; relatório HSE ago/2023 p.11; alto = melhor'),
  ('HSE_2023', 2023, 'ENERGY', 'CHANGE', 3.59, 252, true, 'Energy · mín 3.29 · máx 4.00 · 5 avaliações; relatório HSE ago/2023 p.11; alto = melhor'),
  ('HSE_2023', 2023, 'HEALTHCARE', 'DEMANDS', 2.90, 242, true, 'Healthcare · mín 2.33 · máx 3.51 · 5 avaliações; relatório HSE ago/2023 p.12; alto = melhor'),
  ('HSE_2023', 2023, 'HEALTHCARE', 'CONTROL', 3.54, 242, true, 'Healthcare · mín 2.88 · máx 4.15 · 5 avaliações; relatório HSE ago/2023 p.12; alto = melhor'),
  ('HSE_2023', 2023, 'HEALTHCARE', 'MANAGER_SUPPORT', 3.80, 242, true, 'Healthcare · mín 3.64 · máx 3.99 · 5 avaliações; relatório HSE ago/2023 p.12; alto = melhor'),
  ('HSE_2023', 2023, 'HEALTHCARE', 'PEER_SUPPORT', 3.90, 242, true, 'Healthcare · mín 3.79 · máx 3.98 · 5 avaliações; relatório HSE ago/2023 p.12; alto = melhor'),
  ('HSE_2023', 2023, 'HEALTHCARE', 'RELATIONSHIPS', 4.02, 242, true, 'Healthcare · mín 3.75 · máx 4.18 · 5 avaliações; relatório HSE ago/2023 p.12; alto = melhor'),
  ('HSE_2023', 2023, 'HEALTHCARE', 'ROLE', 4.43, 242, true, 'Healthcare · mín 4.28 · máx 4.71 · 5 avaliações; relatório HSE ago/2023 p.12; alto = melhor'),
  ('HSE_2023', 2023, 'HEALTHCARE', 'CHANGE', 3.67, 242, true, 'Healthcare · mín 3.51 · máx 3.90 · 5 avaliações; relatório HSE ago/2023 p.12; alto = melhor'),
  ('HSE_2023', 2023, 'HOUSING', 'DEMANDS', 3.49, 670, true, 'Housing · mín 3.20 · máx 3.78 · 3 avaliações; relatório HSE ago/2023 p.13; alto = melhor'),
  ('HSE_2023', 2023, 'HOUSING', 'CONTROL', 3.92, 670, true, 'Housing · mín 3.62 · máx 4.19 · 3 avaliações; relatório HSE ago/2023 p.13; alto = melhor'),
  ('HSE_2023', 2023, 'HOUSING', 'MANAGER_SUPPORT', 3.92, 670, true, 'Housing · mín 3.77 · máx 4.17 · 3 avaliações; relatório HSE ago/2023 p.13; alto = melhor'),
  ('HSE_2023', 2023, 'HOUSING', 'PEER_SUPPORT', 4.06, 670, true, 'Housing · mín 3.93 · máx 4.31 · 3 avaliações; relatório HSE ago/2023 p.13; alto = melhor'),
  ('HSE_2023', 2023, 'HOUSING', 'RELATIONSHIPS', 4.15, 670, true, 'Housing · mín 4.11 · máx 4.22 · 3 avaliações; relatório HSE ago/2023 p.13; alto = melhor'),
  ('HSE_2023', 2023, 'HOUSING', 'ROLE', 4.35, 670, true, 'Housing · mín 4.12 · máx 4.57 · 3 avaliações; relatório HSE ago/2023 p.13; alto = melhor'),
  ('HSE_2023', 2023, 'HOUSING', 'CHANGE', 3.57, 670, true, 'Housing · mín 3.18 · máx 4.14 · 3 avaliações; relatório HSE ago/2023 p.13; alto = melhor'),
  ('HSE_2023', 2023, 'LOCAL_AUTHORITY', 'DEMANDS', 3.36, 380, true, 'Local Authority · mín 3.07 · máx 3.57 · 4 avaliações; relatório HSE ago/2023 p.14; alto = melhor'),
  ('HSE_2023', 2023, 'LOCAL_AUTHORITY', 'CONTROL', 3.73, 380, true, 'Local Authority · mín 3.23 · máx 4.02 · 4 avaliações; relatório HSE ago/2023 p.14; alto = melhor'),
  ('HSE_2023', 2023, 'LOCAL_AUTHORITY', 'MANAGER_SUPPORT', 3.96, 380, true, 'Local Authority · mín 3.61 · máx 4.20 · 4 avaliações; relatório HSE ago/2023 p.14; alto = melhor'),
  ('HSE_2023', 2023, 'LOCAL_AUTHORITY', 'PEER_SUPPORT', 4.12, 380, true, 'Local Authority · mín 3.93 · máx 4.24 · 4 avaliações; relatório HSE ago/2023 p.14; alto = melhor'),
  ('HSE_2023', 2023, 'LOCAL_AUTHORITY', 'RELATIONSHIPS', 4.18, 380, true, 'Local Authority · mín 3.90 · máx 4.37 · 4 avaliações; relatório HSE ago/2023 p.14; alto = melhor'),
  ('HSE_2023', 2023, 'LOCAL_AUTHORITY', 'ROLE', 4.41, 380, true, 'Local Authority · mín 4.14 · máx 4.60 · 4 avaliações; relatório HSE ago/2023 p.14; alto = melhor'),
  ('HSE_2023', 2023, 'LOCAL_AUTHORITY', 'CHANGE', 3.50, 380, true, 'Local Authority · mín 2.96 · máx 3.80 · 4 avaliações; relatório HSE ago/2023 p.14; alto = melhor'),
  ('HSE_2023', 2023, 'MANUFACTURING', 'DEMANDS', 3.28, 514, true, 'Manufacturing · mín 2.86 · máx 3.84 · 6 avaliações; relatório HSE ago/2023 p.15; alto = melhor'),
  ('HSE_2023', 2023, 'MANUFACTURING', 'CONTROL', 3.79, 514, true, 'Manufacturing · mín 3.42 · máx 4.25 · 6 avaliações; relatório HSE ago/2023 p.15; alto = melhor'),
  ('HSE_2023', 2023, 'MANUFACTURING', 'MANAGER_SUPPORT', 3.69, 514, true, 'Manufacturing · mín 2.97 · máx 4.03 · 6 avaliações; relatório HSE ago/2023 p.15; alto = melhor'),
  ('HSE_2023', 2023, 'MANUFACTURING', 'PEER_SUPPORT', 4.01, 514, true, 'Manufacturing · mín 3.57 · máx 4.42 · 6 avaliações; relatório HSE ago/2023 p.15; alto = melhor'),
  ('HSE_2023', 2023, 'MANUFACTURING', 'RELATIONSHIPS', 4.15, 514, true, 'Manufacturing · mín 3.49 · máx 4.49 · 6 avaliações; relatório HSE ago/2023 p.15; alto = melhor'),
  ('HSE_2023', 2023, 'MANUFACTURING', 'ROLE', 4.30, 514, true, 'Manufacturing · mín 3.85 · máx 4.69 · 6 avaliações; relatório HSE ago/2023 p.15; alto = melhor'),
  ('HSE_2023', 2023, 'MANUFACTURING', 'CHANGE', 3.39, 514, true, 'Manufacturing · mín 2.83 · máx 3.88 · 6 avaliações; relatório HSE ago/2023 p.15; alto = melhor'),
  ('HSE_2023', 2023, 'PUBLIC_SECTOR', 'DEMANDS', 3.10, 26261, true, 'Public Sector · mín 2.16 · máx 3.55 · 33 avaliações; relatório HSE ago/2023 p.16; alto = melhor'),
  ('HSE_2023', 2023, 'PUBLIC_SECTOR', 'CONTROL', 3.77, 26261, true, 'Public Sector · mín 3.12 · máx 4.06 · 33 avaliações; relatório HSE ago/2023 p.16; alto = melhor'),
  ('HSE_2023', 2023, 'PUBLIC_SECTOR', 'MANAGER_SUPPORT', 3.78, 26261, true, 'Public Sector · mín 3.55 · máx 4.03 · 33 avaliações; relatório HSE ago/2023 p.16; alto = melhor'),
  ('HSE_2023', 2023, 'PUBLIC_SECTOR', 'PEER_SUPPORT', 3.97, 26261, true, 'Public Sector · mín 3.72 · máx 4.24 · 33 avaliações; relatório HSE ago/2023 p.16; alto = melhor'),
  ('HSE_2023', 2023, 'PUBLIC_SECTOR', 'RELATIONSHIPS', 4.05, 26261, true, 'Public Sector · mín 1.75 · máx 4.40 · 33 avaliações; relatório HSE ago/2023 p.16; alto = melhor'),
  ('HSE_2023', 2023, 'PUBLIC_SECTOR', 'ROLE', 3.94, 26261, true, 'Public Sector · mín 3.55 · máx 4.29 · 33 avaliações; relatório HSE ago/2023 p.16; alto = melhor'),
  ('HSE_2023', 2023, 'PUBLIC_SECTOR', 'CHANGE', 3.14, 26261, true, 'Public Sector · mín 2.64 · máx 3.55 · 33 avaliações; relatório HSE ago/2023 p.16; alto = melhor'),
  ('HSE_2023', 2023, 'RETAIL', 'DEMANDS', 3.55, 263, true, 'Retail · mín 3.48 · máx 3.75 · 5 avaliações; relatório HSE ago/2023 p.17; alto = melhor'),
  ('HSE_2023', 2023, 'RETAIL', 'CONTROL', 3.74, 263, true, 'Retail · mín 3.40 · máx 3.84 · 5 avaliações; relatório HSE ago/2023 p.17; alto = melhor'),
  ('HSE_2023', 2023, 'RETAIL', 'MANAGER_SUPPORT', 3.85, 263, true, 'Retail · mín 3.77 · máx 3.96 · 5 avaliações; relatório HSE ago/2023 p.17; alto = melhor'),
  ('HSE_2023', 2023, 'RETAIL', 'PEER_SUPPORT', 4.13, 263, true, 'Retail · mín 4.02 · máx 4.23 · 5 avaliações; relatório HSE ago/2023 p.17; alto = melhor'),
  ('HSE_2023', 2023, 'RETAIL', 'RELATIONSHIPS', 4.21, 263, true, 'Retail · mín 3.90 · máx 4.48 · 5 avaliações; relatório HSE ago/2023 p.17; alto = melhor'),
  ('HSE_2023', 2023, 'RETAIL', 'ROLE', 4.32, 263, true, 'Retail · mín 4.16 · máx 4.46 · 5 avaliações; relatório HSE ago/2023 p.17; alto = melhor'),
  ('HSE_2023', 2023, 'RETAIL', 'CHANGE', 3.48, 263, true, 'Retail · mín 3.32 · máx 3.67 · 5 avaliações; relatório HSE ago/2023 p.17; alto = melhor'),
  ('HSE_2023', 2023, 'WATER', 'DEMANDS', 3.19, 752, true, 'Water · mín 2.84 · máx 3.81 · 6 avaliações; relatório HSE ago/2023 p.18; alto = melhor'),
  ('HSE_2023', 2023, 'WATER', 'CONTROL', 3.68, 752, true, 'Water · mín 3.17 · máx 3.85 · 6 avaliações; relatório HSE ago/2023 p.18; alto = melhor'),
  ('HSE_2023', 2023, 'WATER', 'MANAGER_SUPPORT', 3.65, 752, true, 'Water · mín 3.12 · máx 3.84 · 6 avaliações; relatório HSE ago/2023 p.18; alto = melhor'),
  ('HSE_2023', 2023, 'WATER', 'PEER_SUPPORT', 3.91, 752, true, 'Water · mín 3.51 · máx 4.17 · 6 avaliações; relatório HSE ago/2023 p.18; alto = melhor'),
  ('HSE_2023', 2023, 'WATER', 'RELATIONSHIPS', 4.11, 752, true, 'Water · mín 3.46 · máx 4.35 · 6 avaliações; relatório HSE ago/2023 p.18; alto = melhor'),
  ('HSE_2023', 2023, 'WATER', 'ROLE', 4.11, 752, true, 'Water · mín 3.50 · máx 4.59 · 6 avaliações; relatório HSE ago/2023 p.18; alto = melhor'),
  ('HSE_2023', 2023, 'WATER', 'CHANGE', 3.12, 752, true, 'Water · mín 2.09 · máx 3.60 · 6 avaliações; relatório HSE ago/2023 p.18; alto = melhor')
ON CONFLICT (fonte, setor, dimensao) DO NOTHING;

-- ── Verificação ─────────────────────────────────────────────────────────────────────────
-- SELECT count(*) AS setores_x_dimensoes, count(DISTINCT setor) AS setores
--   FROM hse_benchmark WHERE fonte='HSE_2023' AND setor <> 'GERAL';          -- esperado: 91 | 13
-- SELECT setor, round(avg(media),2) FROM hse_benchmark WHERE fonte='HSE_2023' GROUP BY 1 ORDER BY 1;
-- O GERAL (7 linhas) NÃO é tocado por este arquivo.
