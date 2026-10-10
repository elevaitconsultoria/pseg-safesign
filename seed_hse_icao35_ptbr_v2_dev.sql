-- ═══════════════════════════════════════════════════════════════════════════════════════
-- Instrumento HSE — VERSÃO 2: textos em PT-BR do formulário impresso do outro player (F1) — SOMENTE DEV
-- Plano: .claude/notes/2026-10-08-plano-implantacao-hse.md · Referência: ...-referencia-hse-player-avalia-nr01.md
--
-- ⛔ NÃO APLICAR EM PROD. Os textos vêm do formulário impresso "AVALIAÇÃO - IMPRESSA HSE" de um terceiro,
--    enviado pelo usuário em 2026-10-09 como base para simulação. NÃO são o texto validado (B1): falta
--    (a) validação de SST/psicólogo e (b) confirmar com o usuário/jurídico a permissão de uso da redação.
--    Por isso `config.origem` registra a procedência e `config.rascunho` continua true.
--
-- POR QUE UMA VERSÃO NOVA (e não UPDATE na v1): os itens congelam ao publicar (tg_hse_itens_congelados) e
--   a v1 já tem respostas. Regra B21: mudou uma palavra → questionário novo. A v1 continua publicada para que
--   as respostas antigas sigam analisáveis; `obter_instrumento_link` e `salvar_resposta` usam a MAIOR versão
--   publicada, então links novos já recebem a v2.
--
-- O QUE MUDA em relação à v1
--   • Texto: 35 itens em PT-BR (verbatim do F1), no lugar dos "[RASCUNHO] (original: …)".
--   • Escala: UMA só (frequência: Nunca · Raramente · Às vezes · Frequentemente · Sempre), todos parte=1/'freq'.
--     O F1 reescreve os itens de concordância como pergunta de frequência ("Eu entendo claramente o que é
--     esperado de mim?"), então a escala de concordância deixa de existir nesta versão.
--   • Mantidos de propósito: códigos H01..H35 = numeração do HSE ORIGINAL, ordem original (itens intercalados,
--     não agrupados por dimensão como no F1, para não induzir a resposta), dimensão e inversão (Demandas e
--     Relacionamentos). Só o texto mudou, então o cálculo e o mapeamento seguem idênticos.
--
-- ⚠ DEFEITOS DE TRADUÇÃO NO F1, MANTIDOS AQUI POR INSTRUÇÃO DO USUÁRIO (decidir antes de qualquer uso real):
--   • H22 "Tenho pausas temporárias impossíveis de cumprir?" corresponde a "I have unrealistic time pressures"
--     (pressão de tempo irreal). Perde o construto e repete o tema "pausas" do H16.
--   • H08 "Recebo informações e suporte que me ajudam…" corresponde a "I am given supportive FEEDBACK on the
--     work I do" — perde "feedback".
--   • H26 no F1 diz "pedir explicações ao chefe"; o relatório F2 do mesmo player diz "questionar os gestores".
--   • H05/H21: o F1 traduz "personal harassment…unkind words" como "Falam ou se comportam comigo de forma
--     dura" e "bullying" como "Sou perseguido" — redações mais fracas que o original.
--   • Itens de concordância reescritos como pergunta de frequência alteram o construto (H01, H04, H11, H13…).
--
-- Idempotente. Rollback: DELETE FROM questionarios WHERE id='00000000-0000-0000-0000-000000000003'
--   (só se ainda não houver respostas nele — hse_itens é ON DELETE RESTRICT para resposta_itens_hse).
-- ═══════════════════════════════════════════════════════════════════════════════════════

DO $seed$
DECLARE
  v_q    constant uuid := '00000000-0000-0000-0000-000000000003';
  v_pub  boolean;
BEGIN
  INSERT INTO questionarios (id, nome, empresa_id, ativo, metodologia, versao, publicado, config)
  VALUES (
    v_q,
    'HSE Management Standards — texto PT-BR (formulário do player) v2',
    NULL, true, 'HSE_ICAO35', 2, false,
    jsonb_build_object(
      'rascunho', true,
      'origem', 'Formulário impresso "AVALIAÇÃO - IMPRESSA HSE" de terceiro (F1), recebido em 2026-10-09. Texto NÃO validado por SST nem autorizado para uso comercial (B1).',
      'instrucoes', 'As perguntas a seguir referem-se aos últimos seis meses de trabalho. Para cada afirmativa, selecione com que frequência ela acontece com você.',
      'cabecalho_parte1', 'Considerando os últimos seis meses, com que frequência isto acontece?',
      'rotulos_freq', jsonb_build_array('Nunca','Raramente','Às vezes','Frequentemente','Sempre')
    )
  )
  ON CONFLICT (id) DO NOTHING;

  SELECT publicado INTO v_pub FROM questionarios WHERE id = v_q;

  IF NOT v_pub THEN
    INSERT INTO hse_itens (questionario_id, codigo, ordem, parte, dimensao, texto, inversa, escala_labels)
    SELECT v_q,
           'H' || lpad(n::text, 2, '0'),
           n,
           1,
           dim,
           pt,
           dim IN ('DEMANDS', 'RELATIONSHIPS'),
           'freq'
      FROM (VALUES
        ( 1,'ROLE',            'Eu entendo claramente o que é esperado de mim no trabalho?'),
        ( 2,'CONTROL',         'Posso decidir quando fazer uma pausa?'),
        ( 3,'DEMANDS',         'Diferentes setores/áreas no trabalho exigem coisas de mim que são difíceis de conciliar?'),
        ( 4,'ROLE',            'Sei como realizar meu trabalho?'),
        ( 5,'RELATIONSHIPS',   'Falam ou se comportam comigo de forma dura?'),
        ( 6,'DEMANDS',         'Tenho prazos impossíveis de cumprir?'),
        ( 7,'PEER_SUPPORT',    'Se o trabalho ficar difícil, meus colegas podem me ajudar?'),
        ( 8,'MANAGER_SUPPORT', 'Recebo informações e suporte que me ajudam no trabalho que eu faço?'),
        ( 9,'DEMANDS',         'Preciso trabalhar com muita intensidade?'),
        (10,'CONTROL',         'Tenho voz para decidir a velocidade do meu próprio trabalho?'),
        (11,'ROLE',            'Sei claramente quais são minhas funções e responsabilidades?'),
        (12,'DEMANDS',         'Preciso deixar algumas tarefas de lado porque tenho muitas demandas?'),
        (13,'ROLE',            'Compreendo os objetivos e metas do meu departamento?'),
        (14,'RELATIONSHIPS',   'Há atritos ou desentendimentos entre colegas?'),
        (15,'CONTROL',         'Tenho autonomia para decidir como faço meu trabalho?'),
        (16,'DEMANDS',         'Não tenho possibilidade de fazer pausas suficientes?'),
        (17,'ROLE',            'Compreendo como o meu trabalho contribui para o objetivo geral da organização?'),
        (18,'DEMANDS',         'Sofro pressão para trabalhar longas horas?'),
        (19,'CONTROL',         'Tenho autonomia para decidir o que faço no trabalho?'),
        (20,'DEMANDS',         'Preciso trabalhar muito rápido?'),
        (21,'RELATIONSHIPS',   'Sou perseguido no trabalho?'),
        (22,'DEMANDS',         'Tenho pausas temporárias impossíveis de cumprir?'),
        (23,'MANAGER_SUPPORT', 'Posso contar com meu supervisor direto para me ajudar com problemas no trabalho?'),
        (24,'PEER_SUPPORT',    'Recebo o apoio de que preciso dos meus colegas?'),
        (25,'CONTROL',         'Tenho alguma influência sobre a forma como realizo meu trabalho?'),
        (26,'CHANGE',          'Tenho oportunidades para pedir explicações ao chefe sobre as mudanças no trabalho?'),
        (27,'PEER_SUPPORT',    'Recebo o respeito que mereço dos meus colegas?'),
        (28,'CHANGE',          'Os funcionários são sempre consultados sobre mudanças no trabalho?'),
        (29,'MANAGER_SUPPORT', 'Posso conversar com meu supervisor direto sobre algo que me incomodou no trabalho?'),
        (30,'CONTROL',         'Meu horário de trabalho pode ser flexível?'),
        (31,'PEER_SUPPORT',    'Meus colegas estão dispostos a ouvir meus problemas relacionados ao trabalho?'),
        (32,'CHANGE',          'Quando há mudanças no trabalho, compreendo claramente como elas serão aplicadas na prática?'),
        (33,'MANAGER_SUPPORT', 'Recebo apoio em trabalhos emocionalmente exigentes?'),
        (34,'RELATIONSHIPS',   'Os relacionamentos no trabalho estão desgastados?'),
        (35,'MANAGER_SUPPORT', 'Meu supervisor direto me incentiva no trabalho?')
      ) AS t(n, dim, pt)
    ON CONFLICT (questionario_id, codigo) DO NOTHING;

    -- Publica POR ÚLTIMO: depois disto os itens ficam congelados.
    UPDATE questionarios SET publicado = true WHERE id = v_q;
  END IF;
END
$seed$;

-- ── Verificação ─────────────────────────────────────────────────────────────────────────
-- SELECT versao, publicado, (SELECT count(*) FROM hse_itens i WHERE i.questionario_id=q.id) itens
--   FROM questionarios q WHERE metodologia='HSE_ICAO35' ORDER BY versao;          -- v1: 35 · v2: 35 (ambas publicadas)
-- SELECT dimensao, count(*), bool_and(inversa) FROM hse_itens
--   WHERE questionario_id='00000000-0000-0000-0000-000000000003' GROUP BY 1 ORDER BY 1;
--   -- CHANGE 3 · CONTROL 6 · DEMANDS 8 (inversa) · MANAGER_SUPPORT 5 · PEER_SUPPORT 4 · RELATIONSHIPS 4 (inversa) · ROLE 5
-- SELECT count(*) FROM hse_itens WHERE questionario_id='00000000-0000-0000-0000-000000000003' AND texto LIKE '[RASCUNHO]%';  -- 0
