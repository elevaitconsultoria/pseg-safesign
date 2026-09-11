-- ══════════════════════════════════════════════════════════════════════════
-- PsicoMap — Agrupamentos GHE por PAR (setor × função)
-- Executar no Supabase Dashboard → SQL Editor (ou via MCP apply_migration)
-- Ordem: DEV (szqatgvgghxvyyncsjxl) primeiro, PROD (vftyiildukrpgmnbcnao) depois
--
-- ⚠️ ORDEM DE DEPLOY — OBRIGATÓRIA:
--    Este SQL precisa estar aplicado nos DOIS bancos ANTES do HTML novo subir.
--    carregarGruposSetor() usa lista explícita de colunas no .select(); pedir
--    `pares` antes da coluna existir devolve 42703, cai no catch e ZERA
--    gruposSetor E gruposFuncao — toda empresa perderia os agrupamentos em
--    Resultados/Gráficos/Laudo silenciosamente.
-- ══════════════════════════════════════════════════════════════════════════
--
-- POR QUÊ UM TERCEIRO TIPO:
-- Até aqui `grupos_setor` modelava dois EIXOS INDEPENDENTES: um grupo é uma
-- lista de setores (tipo='setor') OU uma lista de funções (tipo='funcao').
-- A matriz de GHE que as empresas mantêm no PGR é outra coisa: um conjunto de
-- PARES (setor, função). Ex.: GHE "Administrativo" = {(RH, Analista),
-- (Financeiro, Auxiliar)}.
--
-- Os dois eixos não conseguem representar isso:
--   1. Vira produto cartesiano — (RH, Auxiliar) passaria a pertencer ao GHE
--      sem nunca ter sido declarado.
--   2. agruparPorGrupos() coloca cada setor no PRIMEIRO grupo que casar. Num
--      PGR real "Produção" aparece no GHE dos operadores E no da supervisão;
--      um dos dois seria esvaziado sem aviso, e o laudo sairia errado sem erro.
--
-- SEMÂNTICA DE `pares`:
-- - Array JSON de objetos {"s": setor, "f": funcao}. Chaves nomeadas (e não
--   tuplas ["RH","Analista"]) para caber metadado depois sem migrar dado.
-- - `f` nulo ou vazio = CORINGA DO SETOR: a linha do PGR não especificou
--   função, então o par casa qualquer função daquele setor que nenhum par
--   exato tenha reclamado.
-- - Texto CRU (a grafia canônica do catálogo), nunca normalizado. A
--   normalização é assunto de LEITURA (_gheNormStrong no frontend). Gravar
--   normalizado tornaria impossível imprimir "Produção" no laudo.
-- - Mesmo motivo de `itens` para não haver FK: salvarGHE() apaga e recria
--   empresa_setores/empresa_funcoes a cada reimportação de estrutura e
--   regenera todos os id. O vínculo por texto é o que sobrevive.
--
-- RETROCOMPATIBILIDADE:
-- carregarGruposSetor() separa com dois .filter() POSITIVOS (tipo==='setor' e
-- tipo==='funcao'). Uma linha tipo='ghe' lida por um build antigo em cache é
-- descartada pelos dois — nenhum agrupamento existente é afetado, sem crash.
-- Por isso dá para gravar GHE na fase 1 antes do laudo saber lê-los.
--
-- IMPACTO EM PRODUÇÃO: zero — nenhuma linha existente é tocada.

-- ── 1. Relaxar o CHECK de tipo ───────────────────────────────────────────────
ALTER TABLE grupos_setor DROP CONSTRAINT IF EXISTS grupos_setor_tipo_check;
ALTER TABLE grupos_setor ADD CONSTRAINT grupos_setor_tipo_check
  CHECK (tipo IN ('setor', 'funcao', 'ghe'));

-- ── 2. Coluna de pares ───────────────────────────────────────────────────────
ALTER TABLE grupos_setor ADD COLUMN IF NOT EXISTS pares jsonb NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE grupos_setor DROP CONSTRAINT IF EXISTS grupos_setor_pares_array_check;
ALTER TABLE grupos_setor ADD CONSTRAINT grupos_setor_pares_array_check
  CHECK (jsonb_typeof(pares) = 'array');

-- ── 3. Unicidade do nome do GHE dentro da empresa ────────────────────────────
-- Índice PARCIAL (WHERE tipo='ghe') de propósito: os tipos legados nunca
-- tiveram UNIQUE e podem ter duplicatas em produção — um índice global falharia
-- na criação.
CREATE UNIQUE INDEX IF NOT EXISTS uq_grupos_setor_ghe_nome
  ON grupos_setor (empresa_id, lower(nome)) WHERE tipo = 'ghe';

-- ── 4. Comentários ───────────────────────────────────────────────────────────
COMMENT ON COLUMN grupos_setor.tipo IS
  '''setor'' | ''funcao'' | ''ghe''. setor/funcao: itens[] guarda nomes de '
  'respostas.setor ou respostas.funcao. ghe: pares[] guarda os pares (setor, funcao) '
  'importados da matriz de GHE do PGR.';

COMMENT ON COLUMN grupos_setor.pares IS
  'Só para tipo=''ghe''. Array JSON [{"s": setor, "f": funcao}] com a grafia CRUA do '
  'catálogo (nunca normalizada — normalização é feita na leitura por _gheNormStrong). '
  '"f" nulo ou vazio = coringa do setor: casa qualquer função daquele setor que nenhum '
  'par exato tenha reclamado. Vazio ([]) para os tipos setor/funcao.';

-- ── Verificação ──────────────────────────────────────────────────────────────
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'grupos_setor'::regclass AND contype = 'c'
ORDER BY conname;

SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'grupos_setor'
ORDER BY ordinal_position;
