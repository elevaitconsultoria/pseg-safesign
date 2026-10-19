-- ═══════════════════════════════════════════════════════════════════════════════════════
-- PsicoMap — Critério de risco para o PGR derivado de um instrumento: severidade por dimensão  (etapa S8b, v2 genérica)
-- Substitui migration_hse_riscos_config.sql (renomeada; a tabela hse_riscos_config vira instrumento_riscos_config).
-- Plano: .claude/notes/2026-10-09-hse-andamento-pendencias-e-risco.md (§6)
--
-- Executar: DEV primeiro, PROD depois. Pré-requisito: migration_metodologias_instrumentos.sql.
--
-- POR QUE EXISTE
--   O NR-01 exige riscos psicossociais no inventário do PGR; o HSE, sozinho, só diz a condição de cada
--   dimensão (4 faixas), não um nível de risco. O critério adotado: P (1–4) vem da FAIXA da dimensão
--   (calculada pelo sistema) e S (1–4) é FIXA por dimensão e vem desta tabela; o nível sai da mesma
--   matriz 4×4 do BS 8800. Este critério NÃO faz parte do instrumento e precisa ser declarado no laudo.
--   A tabela é por (metodologia, dimensão): só dimensões de EXPOSIÇÃO entram — dimensões de desfecho (saúde,
--   burnout) de um instrumento futuro não alimentam P×S e simplesmente não têm linha aqui.
--
-- QUEM PREENCHE
--   A severidade é decisão de profissional de SST/psicólogo (ela decide quase todo o nível final, já
--   que P tem só 4 valores). A migration cria a tabela VAZIA: sem severidade preenchida e VALIDADA, o
--   laudo não emite a seção de risco e a checagem pré-geração barra o documento.
--   Em DEV o seed de teste (seed_hse_riscos_config_dev_teste.sql) usa valores marcados como TESTE.
--
-- ESCRITA: só super_admin (mesmo padrão de questoes/instrumento_referencias). Leitura: authenticated.
-- ROLLBACK: DROP TABLE instrumento_riscos_config; (nada mais depende dela)
-- ═══════════════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS instrumento_riscos_config (
  metodologia   text NOT NULL,
  dimensao      text NOT NULL,
  severidade    smallint CHECK (severidade BETWEEN 1 AND 4),   -- mesma escala S1–S4 do BS 8800
  danos         text,                                          -- "possíveis danos" impresso no inventário
  versao        integer NOT NULL DEFAULT 1,
  validado      boolean NOT NULL DEFAULT false,
  validado_por  text,                                          -- nome + registro do profissional
  validado_em   timestamptz,
  atualizado_em timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (metodologia, dimensao),
  FOREIGN KEY (metodologia, dimensao) REFERENCES instrumento_dimensoes (metodologia, codigo),
  -- "validado" sem severidade ou sem responsável é contradição: o laudo imprimiria um critério sem dono.
  CONSTRAINT instrumento_riscos_validado_completo CHECK (
    NOT validado OR (severidade IS NOT NULL AND validado_por IS NOT NULL AND validado_em IS NOT NULL))
);

COMMENT ON TABLE instrumento_riscos_config IS
  'Severidade fixa (S1–S4) por dimensão de um instrumento, usada para derivar nível de risco no PGR. Definida e assinada por SST; não faz parte do instrumento.';

ALTER TABLE instrumento_riscos_config ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON instrumento_riscos_config FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON instrumento_riscos_config TO authenticated;   -- as policies restringem a escrita a super_admin

DROP POLICY IF EXISTS instrumento_riscos_select_autenticado ON instrumento_riscos_config;
CREATE POLICY instrumento_riscos_select_autenticado ON instrumento_riscos_config
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS instrumento_riscos_super_admin_write ON instrumento_riscos_config;
CREATE POLICY instrumento_riscos_super_admin_write ON instrumento_riscos_config
  FOR ALL TO authenticated USING (is_super_admin()) WITH CHECK (is_super_admin());

-- Verificação:
--   SELECT count(*) FROM instrumento_riscos_config;               -- 0 em PROD até SST preencher
--   SELECT grantee, privilege_type FROM information_schema.role_table_grants
--    WHERE table_name='instrumento_riscos_config' AND grantee='anon';   -- 0 linhas
