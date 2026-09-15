-- ══════════════════════════════════════════════════════════════════════════
-- PsicoMap — GHE absorvidos (cobertura declarada de GHE do PGR)
-- Executar no Supabase Dashboard → SQL Editor (ou via MCP apply_migration)
-- Ordem: DEV (szqatgvgghxvyyncsjxl) primeiro, PROD (vftyiildukrpgmnbcnao) depois
-- ══════════════════════════════════════════════════════════════════════════
--
-- PROBLEMA QUE RESOLVE (achado real, Inovadoor, 2026-09-15):
-- A matriz do PGR tinha 17 GHE; a importação gravou 9. Os 8 ausentes não se
-- perderam por bug: eles declaram EXATAMENTE os mesmos pares (setor, função) de
-- um GHE que ficou. O PGR os separa por NORMA — NR-10, NR-11, NR-35 —, e norma
-- não é um eixo do modelo de par.
--
--   GHE 03, 04, 05 (Logística NR11/NR35)  → mesmos pares do GHE 02
--   GHE 08 (Lonas NR35)                   → mesmos pares do GHE 07
--   GHE 10, 17 (Rápidas NR35/NR11)        → mesmos pares do GHE 09
--   GHE 14 (Painel NR11)                  → mesmos pares do GHE 13
--   GHE 16 (Painel/Externo NR10+NR35)     → pares dos GHE 11 e 12
--
-- Colapsar está CERTO para risco psicossocial: o auxiliar de expedição tem a
-- mesma exposição psicossocial trabalhando ou não em altura, e mantê-los
-- separados contaria a mesma pessoa duas vezes no laudo (a invariante
-- Σ n(grupo) === total da capa deixaria de valer). Mas o laudo precisa DECLARAR
-- essa cobertura: um auditor que leia "GHE 02" tem de saber que ali também estão
-- as pessoas que o PGR chama de 03, 04 e 05.
--
-- POR QUE COLUNA E NÃO SUFIXO NO `nome`:
-- O nome é a chave de reconciliação da reimportação (índice único parcial em
-- lower(nome) e o diff criar/atualizar/remover). Renomear "02" para
-- "02 — Logística (cobre 03,04,05)" faria a importação seguinte não reconhecer o
-- GHE: ela veria um "02" a criar e um "02 — Logística…" a remover, a cada
-- importação. A cobertura é METADADO, e metadado não pode morar na chave.
--
-- ORDEM DE DEPLOY: indiferente. O frontend degrada nos dois sentidos — a leitura
-- tenta a coluna e cai para a lista sem ela; a gravação repete o insert sem o
-- campo se o PostgREST não o conhecer. Sem a migration, tudo funciona como antes
-- e apenas a cobertura não é registrada.
--
-- IMPACTO EM PRODUÇÃO: zero. Coluna aditiva com DEFAULT — linhas existentes
-- passam a ter '{}' e nenhum caminho de leitura muda de comportamento.

ALTER TABLE grupos_setor
  ADD COLUMN IF NOT EXISTS absorvidos text[] NOT NULL DEFAULT '{}';

COMMENT ON COLUMN grupos_setor.absorvidos IS
  'Somente tipo=''ghe''. Nomes de GHE do PGR cujos pares foram integralmente '
  'reivindicados por este GHE (mesma matriz de setor × função, diferindo apenas '
  'por norma: NR-10/11/35). Preenchido pela importação a partir dos conflitos de '
  'par e declarado no laudo, para que a cobertura real do grupo fique explícita '
  'no documento entregue. Não participa de nenhum matching.';

-- ── Verificação ──────────────────────────────────────────────────────────────
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_name = 'grupos_setor' AND column_name = 'absorvidos';

-- Nenhuma linha deve ter valor ainda (a importação preenche):
SELECT count(*) AS linhas_ghe, count(*) FILTER (WHERE absorvidos <> '{}') AS com_absorvidos
FROM grupos_setor WHERE tipo = 'ghe';
