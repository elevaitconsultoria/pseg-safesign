-- ═══════════════════════════════════════════════════════════════════════════════════════
-- PsicoMap — Critério de risco para o PGR derivado do HSE: severidade por dimensão  (etapa S8b)
-- Plano: .claude/notes/2026-10-09-hse-andamento-pendencias-e-risco.md (§6)
--
-- Executar: DEV primeiro, PROD depois. Pré-requisito: migration_metodologia_hse_icao35.sql.
--
-- POR QUE EXISTE
--   O NR-01 exige riscos psicossociais no inventário do PGR; o HSE, sozinho, só diz a condição de cada
--   dimensão (4 faixas), não um nível de risco. O critério adotado: P (1–4) vem da FAIXA da dimensão
--   (calculada pelo sistema) e S (1–4) é FIXA por dimensão e vem desta tabela; o nível sai da mesma
--   matriz 4×4 do BS 8800. Este critério NÃO faz parte do instrumento HSE e precisa ser declarado no
--   laudo.
--
-- QUEM PREENCHE
--   A severidade é decisão de profissional de SST/psicólogo (ela decide quase todo o nível final, já
--   que P tem só 4 valores). A migration cria a tabela VAZIA: sem severidade preenchida e VALIDADA, o
--   laudo HSE não emite a seção de risco e a checagem pré-geração barra o documento.
--   Em DEV o seed de teste (seed_hse_riscos_config_dev_teste.sql) usa valores marcados como TESTE.
--
-- ESCRITA: só super_admin (mesmo padrão de questoes/hse_benchmark). Leitura: authenticated.
-- ROLLBACK: DROP TABLE hse_riscos_config; (nada mais depende dela)
-- ═══════════════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS hse_riscos_config (
  dimensao      text PRIMARY KEY CHECK (dimensao IN
    ('DEMANDS','CONTROL','MANAGER_SUPPORT','PEER_SUPPORT','RELATIONSHIPS','ROLE','CHANGE')),
  severidade    smallint CHECK (severidade BETWEEN 1 AND 4),   -- mesma escala S1–S4 do BS 8800
  danos         text,                                          -- "possíveis danos" impresso no inventário
  versao        integer NOT NULL DEFAULT 1,
  validado      boolean NOT NULL DEFAULT false,
  validado_por  text,                                          -- nome + registro do profissional
  validado_em   timestamptz,
  atualizado_em timestamptz NOT NULL DEFAULT now(),
  -- "validado" sem severidade ou sem responsável é contradição: o laudo imprimiria um critério sem dono.
  CONSTRAINT hse_riscos_validado_completo CHECK (
    NOT validado OR (severidade IS NOT NULL AND validado_por IS NOT NULL AND validado_em IS NOT NULL))
);

COMMENT ON TABLE hse_riscos_config IS
  'Severidade fixa (S1–S4) por dimensão HSE usada para derivar nível de risco no PGR. Definida e assinada por SST; não faz parte do instrumento HSE.';

ALTER TABLE hse_riscos_config ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON hse_riscos_config FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON hse_riscos_config TO authenticated;   -- as policies restringem a escrita a super_admin

DROP POLICY IF EXISTS hse_riscos_select_autenticado ON hse_riscos_config;
CREATE POLICY hse_riscos_select_autenticado ON hse_riscos_config
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS hse_riscos_super_admin_write ON hse_riscos_config;
CREATE POLICY hse_riscos_super_admin_write ON hse_riscos_config
  FOR ALL TO authenticated USING (is_super_admin()) WITH CHECK (is_super_admin());

-- Verificação:
--   SELECT count(*) FROM hse_riscos_config;                       -- 0 em PROD até SST preencher
--   SELECT grantee, privilege_type FROM information_schema.role_table_grants
--    WHERE table_name='hse_riscos_config' AND grantee='anon';      -- 0 linhas
