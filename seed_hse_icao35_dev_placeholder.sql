-- ═══════════════════════════════════════════════════════════════════════════════════════
-- SEED DE PLACEHOLDER do instrumento HSE / ICAO-35 — SOMENTE DEV  (etapa S4)
-- Plano: .claude/notes/2026-10-08-plano-implantacao-hse.md
--
-- ⛔ NÃO APLICAR EM PROD. O texto dos 35 itens é RASCUNHO de engenharia: cada pergunta carrega
--    "[RASCUNHO]" + o enunciado original em inglês entre parênteses, para que ninguém confunda
--    com o instrumento validado. O texto validado (B1) entra em OUTRO arquivo,
--    seed_hse_icao35_validado.sql, que começa com uma guarda que aborta se existir qualquer
--    "[RASCUNHO]" no banco.
--
-- Mapeamento item → dimensão (numeração do HSE original; conferido com a aba Totals do
-- analysistool.xls e com o formulário impresso de um terceiro, ver nota de referência):
--   DEMANDS 3,6,9,12,16,18,20,22 · CONTROL 2,10,15,19,25,30 · MANAGER_SUPPORT 8,23,29,33,35
--   PEER_SUPPORT 7,24,27,31 · RELATIONSHIPS 5,14,21,34 · ROLE 1,4,11,13,17 · CHANGE 26,28,32
-- Invertidos: toda DEMANDS e toda RELATIONSHIPS (12 itens). Parte 1 = H01–H23 (frequência),
-- parte 2 = H24–H35 (concordância).
--
-- Benchmark: só as médias GERAIS do relatório HSE 2023 (39.484 respondentes). As 13 médias por
-- setor ainda precisam ser transcritas da fonte — NÃO foram inventadas aqui.
--
-- Idempotente: se o questionário já estiver publicado, não toca nos itens (estão congelados).
-- ═══════════════════════════════════════════════════════════════════════════════════════

DO $seed$
DECLARE
  v_q    constant uuid := '00000000-0000-0000-0000-000000000002';
  v_pub  boolean;
BEGIN
  INSERT INTO questionarios (id, nome, empresa_id, ativo, metodologia, versao, publicado, config)
  VALUES (
    v_q,
    'HSE Management Standards — ICAO-35 [RASCUNHO]',
    NULL, true, 'HSE_ICAO35', 1, false,
    jsonb_build_object(
      'rascunho', true,
      'instrucoes', '[RASCUNHO] As perguntas a seguir referem-se aos últimos 6 meses de trabalho.',
      'cabecalho_parte1', '[RASCUNHO] Com que frequência isto acontece com você?',
      'cabecalho_parte2', '[RASCUNHO] Quanto você concorda com cada afirmação?',
      'rotulos_freq',    jsonb_build_array('Nunca','Raramente','Às vezes','Frequentemente','Sempre'),
      'rotulos_concord', jsonb_build_array('Discordo totalmente','Discordo','Neutro','Concordo','Concordo totalmente')
    )
  )
  ON CONFLICT (id) DO NOTHING;

  SELECT publicado INTO v_pub FROM questionarios WHERE id = v_q;

  IF NOT v_pub THEN
    INSERT INTO hse_itens (questionario_id, codigo, ordem, parte, dimensao, texto, inversa, escala_labels)
    SELECT v_q,
           'H' || lpad(n::text, 2, '0'),
           n,
           CASE WHEN n <= 23 THEN 1 ELSE 2 END,
           dim,
           '[RASCUNHO] (original: "' || en || '")',
           dim IN ('DEMANDS', 'RELATIONSHIPS'),
           CASE WHEN n <= 23 THEN 'freq' ELSE 'concord' END
      FROM (VALUES
        ( 1,'ROLE',           'I am clear what is expected of me at work'),
        ( 2,'CONTROL',        'I can decide when to take a break'),
        ( 3,'DEMANDS',        'Different groups at work demand things from me that are hard to combine'),
        ( 4,'ROLE',           'I know how to go about getting my job done'),
        ( 5,'RELATIONSHIPS',  'I am subject to personal harassment in the form of unkind words or behaviour'),
        ( 6,'DEMANDS',        'I have unachievable deadlines'),
        ( 7,'PEER_SUPPORT',   'If work gets difficult, my colleagues will help me'),
        ( 8,'MANAGER_SUPPORT','I am given supportive feedback on the work I do'),
        ( 9,'DEMANDS',        'I have to work very intensively'),
        (10,'CONTROL',        'I have a say in my own work speed'),
        (11,'ROLE',           'I am clear what my duties and responsibilities are'),
        (12,'DEMANDS',        'I have to neglect some tasks because I have too much to do'),
        (13,'ROLE',           'I am clear about the goals and objectives for my department'),
        (14,'RELATIONSHIPS',  'There is friction or anger between colleagues'),
        (15,'CONTROL',        'I have a choice in deciding how I do my work'),
        (16,'DEMANDS',        'I am unable to take sufficient breaks'),
        (17,'ROLE',           'I understand how my work fits into the overall aim of the organisation'),
        (18,'DEMANDS',        'I am pressured to work long hours'),
        (19,'CONTROL',        'I have a choice in deciding what I do at work'),
        (20,'DEMANDS',        'I have to work very fast'),
        (21,'RELATIONSHIPS',  'I am subject to bullying at work'),
        (22,'DEMANDS',        'I have unrealistic time pressures'),
        (23,'MANAGER_SUPPORT','I can rely on my line manager to help me out with a work problem'),
        (24,'PEER_SUPPORT',   'I get the help and support I need from colleagues'),
        (25,'CONTROL',        'I have some say over the way I work'),
        (26,'CHANGE',         'I have sufficient opportunities to question managers about change at work'),
        (27,'PEER_SUPPORT',   'I receive the respect at work I deserve from my colleagues'),
        (28,'CHANGE',         'Staff are always consulted about change at work'),
        (29,'MANAGER_SUPPORT','I can talk to my line manager about something that has upset or annoyed me about work'),
        (30,'CONTROL',        'My working time can be flexible'),
        (31,'PEER_SUPPORT',   'My colleagues are willing to listen to my work-related problems'),
        (32,'CHANGE',         'When changes are made at work, I am clear how they will work out in practice'),
        (33,'MANAGER_SUPPORT','I am supported through emotionally demanding work'),
        (34,'RELATIONSHIPS',  'Relationships at work are strained'),
        (35,'MANAGER_SUPPORT','My line manager encourages me at work')
      ) AS t(n, dim, en)
    ON CONFLICT (questionario_id, codigo) DO NOTHING;

    -- Publica POR ÚLTIMO: depois disto os itens ficam congelados (trigger tg_hse_itens_congelados).
    UPDATE questionarios SET publicado = true WHERE id = v_q;
  END IF;
END
$seed$;

-- Benchmark HSE 2023 — médias gerais (39.484 respondentes). Percentis ficam NULL de propósito.
INSERT INTO hse_benchmark (fonte, fonte_ano, setor, dimensao, media, n_amostra, vigente, observacao) VALUES
  ('HSE_2023', 2023, 'GERAL', 'DEMANDS',         3.25, 39484, true, 'Média geral, relatório HSE ago/2023; alto = melhor'),
  ('HSE_2023', 2023, 'GERAL', 'CONTROL',         3.72, 39484, true, 'idem'),
  ('HSE_2023', 2023, 'GERAL', 'MANAGER_SUPPORT', 3.80, 39484, true, 'idem'),
  ('HSE_2023', 2023, 'GERAL', 'PEER_SUPPORT',    4.01, 39484, true, 'idem'),
  ('HSE_2023', 2023, 'GERAL', 'RELATIONSHIPS',   4.11, 39484, true, 'idem'),
  ('HSE_2023', 2023, 'GERAL', 'ROLE',            4.16, 39484, true, 'idem'),
  ('HSE_2023', 2023, 'GERAL', 'CHANGE',          3.30, 39484, true, 'idem')
ON CONFLICT (fonte, setor, dimensao) DO NOTHING;

-- ── Verificação ─────────────────────────────────────────────────────────────────────────
-- SELECT count(*) itens, count(*) FILTER (WHERE inversa) invertidos, count(DISTINCT dimensao) dimensoes,
--        count(*) FILTER (WHERE texto LIKE '[RASCUNHO]%') rascunho,
--        count(*) FILTER (WHERE parte=1) parte1, count(*) FILTER (WHERE parte=2) parte2
--   FROM hse_itens WHERE questionario_id='00000000-0000-0000-0000-000000000002';
--   -- esperado: 35 | 12 | 7 | 35 | 23 | 12
-- SELECT dimensao, count(*) FROM hse_itens GROUP BY 1 ORDER BY 1;
--   -- esperado: CHANGE 3, CONTROL 6, DEMANDS 8, MANAGER_SUPPORT 5, PEER_SUPPORT 4, RELATIONSHIPS 4, ROLE 5
