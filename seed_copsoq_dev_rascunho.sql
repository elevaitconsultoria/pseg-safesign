-- ═══════════════════════════════════════════════════════════════════════════════════════
-- Instrumento COPSOQ — VERSÃO RASCUNHO para simulação — SOMENTE DEV   (2026-10-28)
-- Nota: .claude/notes/2026-10-19-copsoq-avaliacao-documentos-e-generalizacao.md
--
-- ⛔ NÃO APLICAR EM PROD. Os 40 enunciados vêm do formulário "AVALIAÇÃO - COPSOQ II-Br curta" de um terceiro
--    (adaptação livre, NÃO o texto validado de Gonçalves et al., 2021). O mapeamento item → dimensão → direção
--    é PROPOSTA do PsicoMap sobre os 7 "fatores" do documento (o documento não lista as 11 dimensões) e precisa ser
--    refeito a partir da fonte validada. Por isso config.rascunho = true e o laudo sai marcado RASCUNHO.
--    O nome "COPSOQ" só pode aparecer em produção com o texto validado e a licença confirmada por escrito (CC BY-NC-ND).
--
-- Decisões de desenho (todas sobre dado do documento do terceiro):
--   • Escala única de frequência 1–5 (Nunca … Sempre), como no formulário dele.
--   • A direção MISTURA dentro de um mesmo "fator" (em "Saúde e bem-estar": "esgotado" × "satisfeito"), então os fatores foram
--     divididos em dimensões de direção única; inversa (espelhar N+1−v) = dimensão alto_pior.
--   • Itens 31 e 32 ("já sofreu tratamento injusto / já foi desrespeitado") ficam em OFENSAS, não em "segurança no emprego".
--   • Dimensões sensíveis (LGPD art. 5º II): OFENSAS, ESTRESSE, SAUDE_GERAL. A tela e o laudo aplicam n mínimo reforçado.
--   • Ordem de exibição INTERCALADA entre os fatores (como no HSE); os códigos C01..C40 seguem a numeração do documento.
--   • Sem "interpretação das perguntas" no formulário (decisão do usuário: vira glossário do laudo); ajuda = NULL.
-- Idempotente. Rollback: DELETE FROM questionarios WHERE metodologia='COPSOQ_II' (só sem respostas); depois instrumento_dimensoes e instrumentos.
-- ═══════════════════════════════════════════════════════════════════════════════════════

INSERT INTO instrumentos (metodologia, nome, generico, escala_min, escala_max, sensivel)
VALUES ('COPSOQ_II', 'COPSOQ — questionário psicossocial (rascunho)', true, 1, 5, true)
ON CONFLICT (metodologia) DO NOTHING;

INSERT INTO instrumento_dimensoes (metodologia, codigo, nome, dominio, ordem, direcao, sensivel) VALUES
  ('COPSOQ_II', 'DEM_RITMO',       'Ritmo e pressão de tempo',            'Demandas no trabalho',        1, 'alto_pior',   false),
  ('COPSOQ_II', 'DEM_COGNITIVAS',  'Exigências cognitivas',               'Demandas no trabalho',        2, 'alto_pior',   false),
  ('COPSOQ_II', 'DEM_EMOCIONAIS',  'Exigências emocionais',               'Demandas no trabalho',        3, 'alto_pior',   false),
  ('COPSOQ_II', 'INFLUENCIA',      'Influência e autonomia',              'Controle e desenvolvimento',  4, 'alto_melhor', false),
  ('COPSOQ_II', 'DESENVOLVIMENTO', 'Desenvolvimento de habilidades',      'Controle e desenvolvimento',  5, 'alto_melhor', false),
  ('COPSOQ_II', 'SENTIDO',         'Significado e propósito do trabalho', 'Controle e desenvolvimento',  6, 'alto_melhor', false),
  ('COPSOQ_II', 'APOIO_COLEGAS',   'Apoio dos colegas',                   'Relações e liderança',        7, 'alto_melhor', false),
  ('COPSOQ_II', 'LIDERANCA',       'Apoio e qualidade da liderança',      'Relações e liderança',        8, 'alto_melhor', false),
  ('COPSOQ_II', 'CLAREZA_PAPEL',   'Clareza de papel',                    'Organização do trabalho',     9, 'alto_melhor', false),
  ('COPSOQ_II', 'CONFLITO_PAPEL',  'Tarefas contraditórias ou desnecessárias', 'Organização do trabalho', 10, 'alto_pior',  false),
  ('COPSOQ_II', 'JUSTICA',         'Justiça e respeito',                  'Organização do trabalho',    11, 'alto_melhor', false),
  ('COPSOQ_II', 'CONFLITO_VIDA',   'Conflito trabalho–vida',              'Conflito trabalho–vida',     12, 'alto_pior',   false),
  ('COPSOQ_II', 'INSEGURANCA',     'Insegurança no emprego',              'Segurança no emprego',       13, 'alto_pior',   false),
  ('COPSOQ_II', 'OFENSAS',         'Tratamento injusto e desrespeito',    'Comportamentos ofensivos',   14, 'alto_pior',   true),
  ('COPSOQ_II', 'ESTRESSE',        'Estresse, sobrecarga e esgotamento',  'Saúde e bem-estar',          15, 'alto_pior',   true),
  ('COPSOQ_II', 'SATISFACAO',      'Satisfação e motivação',              'Saúde e bem-estar',          16, 'alto_melhor', false),
  ('COPSOQ_II', 'SAUDE_GERAL',     'Saúde geral percebida',               'Saúde e bem-estar',          17, 'alto_melhor', true)
ON CONFLICT (metodologia, codigo) DO NOTHING;

DO $seed$
DECLARE
  v_q    constant uuid := '00000000-0000-0000-0000-0000000000c1';
  v_pub  boolean;
BEGIN
  INSERT INTO questionarios (id, nome, empresa_id, ativo, metodologia, versao, publicado, config)
  VALUES (
    v_q, 'Questionário psicossocial — 40 itens (rascunho de terceiro) v1', NULL, true, 'COPSOQ_II', 1, false,
    jsonb_build_object(
      'rascunho', true,
      'origem', 'Formulário "AVALIAÇÃO - COPSOQ II-Br curta" de terceiro, recebido em 2026-10-28. Adaptação livre; texto NÃO validado e sem licença confirmada. Dimensões e direções propostas pelo PsicoMap.',
      'instrucoes', 'Considere sua experiência de trabalho nos últimos seis meses e assinale a alternativa que melhor representa a frequência com que cada situação ocorreu. Não existem respostas certas ou erradas. Responda de forma sincera, de acordo com sua percepção.',
      'aviso', 'Algumas perguntas tratam de saúde e bem-estar. Suas respostas são anônimas: o resultado só é exibido para grupos com número suficiente de pessoas, e nunca de forma individual.',
      'rotulos', jsonb_build_object('freq', jsonb_build_array('Nunca','Raramente','Às vezes','Frequentemente','Sempre'))
    )
  )
  ON CONFLICT (id) DO NOTHING;

  SELECT publicado INTO v_pub FROM questionarios WHERE id = v_q;

  IF NOT v_pub THEN
    INSERT INTO instrumento_itens (questionario_id, metodologia, codigo, ordem, parte, dimensao, texto, inversa, escala_labels)
    SELECT v_q, 'COPSOQ_II', 'C' || lpad(n::text, 2, '0'),
           row_number() OVER (ORDER BY pos, fator, n),          -- intercalado entre os fatores
           1, dim, pt,
           dim IN ('DEM_RITMO','DEM_COGNITIVAS','DEM_EMOCIONAIS','CONFLITO_PAPEL','CONFLITO_VIDA','INSEGURANCA','OFENSAS','ESTRESSE'),
           'freq'
      FROM (
        SELECT t.*, row_number() OVER (PARTITION BY fator ORDER BY n) AS pos
          FROM (VALUES
            ( 1,'DEM_RITMO',      1,'Você tem que trabalhar muito rápido?'),
            ( 2,'DEM_RITMO',      1,'Você tem que trabalhar com muita intensidade?'),
            ( 3,'DEM_RITMO',      1,'Você tem prazos difíceis de cumprir?'),
            ( 4,'DEM_COGNITIVAS', 1,'Seu trabalho exige muita concentração?'),
            ( 5,'DEM_COGNITIVAS', 1,'Você precisa tomar decisões difíceis no trabalho?'),
            ( 6,'DEM_EMOCIONAIS', 1,'Seu trabalho exige envolvimento emocional?'),
            ( 7,'DEM_EMOCIONAIS', 1,'Você precisa lidar com situações emocionalmente difíceis?'),
            ( 8,'INFLUENCIA',     2,'Você tem influência sobre como realiza seu trabalho?'),
            ( 9,'INFLUENCIA',     2,'Você pode decidir como organizar seu trabalho?'),
            (10,'DESENVOLVIMENTO',2,'Seu trabalho permite aprender coisas novas?'),
            (11,'DESENVOLVIMENTO',2,'Você pode desenvolver suas habilidades no trabalho?'),
            (12,'SENTIDO',        2,'Seu trabalho é importante para você?'),
            (13,'SENTIDO',        2,'Você sente que seu trabalho tem propósito?'),
            (14,'APOIO_COLEGAS',  3,'Você recebe ajuda dos colegas quando precisa?'),
            (15,'APOIO_COLEGAS',  3,'Você pode contar com seus colegas no trabalho?'),
            (16,'LIDERANCA',      3,'Seu supervisor ajuda quando você precisa?'),
            (17,'LIDERANCA',      3,'Você pode conversar com seu supervisor sobre problemas?'),
            (18,'LIDERANCA',      3,'Seu supervisor organiza bem o trabalho?'),
            (19,'LIDERANCA',      3,'Seu supervisor trata os trabalhadores com respeito?'),
            (20,'CLAREZA_PAPEL',  4,'Você sabe exatamente o que é esperado de você?'),
            (21,'CLAREZA_PAPEL',  4,'Suas responsabilidades estão claras?'),
            (22,'CONFLITO_PAPEL', 4,'Você recebe tarefas contraditórias?'),
            (23,'CONFLITO_PAPEL', 4,'Você precisa fazer coisas que considera desnecessárias?'),
            (24,'JUSTICA',        4,'As decisões na empresa são justas?'),
            (25,'JUSTICA',        4,'Você é tratado de forma justa no trabalho?'),
            (26,'CONFLITO_VIDA',  5,'Seu trabalho interfere na sua vida pessoal?'),
            (27,'CONFLITO_VIDA',  5,'Você chega em casa cansado por causa do trabalho?'),
            (28,'CONFLITO_VIDA',  5,'Você tem dificuldade de equilibrar trabalho e vida pessoal?'),
            (29,'INSEGURANCA',    6,'Você tem medo de perder o emprego?'),
            (30,'INSEGURANCA',    6,'Você se sente inseguro quanto ao futuro no trabalho?'),
            (31,'OFENSAS',        6,'Você já sofreu tratamento injusto no trabalho?'),
            (32,'OFENSAS',        6,'Você já foi desrespeitado no ambiente de trabalho?'),
            (33,'ESTRESSE',       7,'Você se sente estressado no trabalho?'),
            (34,'ESTRESSE',       7,'Você se sente sobrecarregado?'),
            (35,'ESTRESSE',       7,'Você se sente emocionalmente esgotado?'),
            (36,'ESTRESSE',       7,'Você se sente sem energia para trabalhar?'),
            (37,'SATISFACAO',     7,'Você está satisfeito com seu trabalho?'),
            (38,'SATISFACAO',     7,'Você se sente motivado no trabalho?'),
            (39,'SAUDE_GERAL',    7,'Você considera sua saúde boa?'),
            (40,'SAUDE_GERAL',    7,'Você se sente bem física e mentalmente?')
          ) AS t(n, dim, fator, pt)
      ) x
    ON CONFLICT (questionario_id, codigo) DO NOTHING;

    -- Publica POR ÚLTIMO: depois disto os itens ficam congelados.
    UPDATE questionarios SET publicado = true WHERE id = v_q;
  END IF;
END
$seed$;

-- ── Verificação ─────────────────────────────────────────────────────────────────────────
-- SELECT count(*), count(*) FILTER (WHERE inversa), count(DISTINCT dimensao) FROM instrumento_itens WHERE metodologia='COPSOQ_II';  -- 40 | 20 | 17
-- SELECT dimensao, count(*), bool_and(inversa) FROM instrumento_itens WHERE metodologia='COPSOQ_II' GROUP BY 1 ORDER BY 1;
