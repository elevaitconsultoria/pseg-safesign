-- ═══════════════════════════════════════════════════════════════════════════════════════
-- SIMULAÇÃO do COPSOQ (rascunho) — SOMENTE DEV   (2026-10-28)
-- Pré-requisitos: seed_hse_simulacao_dev.sql (empresa fictícia) e seed_copsoq_dev_rascunho.sql (instrumento publicado).
-- Cria a campanha "Avaliação COPSOQ — Simulação", um link (simcopsoq001) e 40 respostas enviadas pela RPC REAL salvar_resposta
-- (mesma validação do formulário público). Dados FICTÍCIOS, determinísticos: Produção com pior exposição e estresse,
-- Administrativo melhor, Logística intermediária.
-- ⛔ NÃO APLICAR EM PROD. Remover: DELETE FROM respostas WHERE ciclo_id='aaaa0000-0000-4000-8000-0000000000c2';
--    DELETE FROM links_coleta WHERE token='simcopsoq001'; DELETE FROM ciclos WHERE id='aaaa0000-0000-4000-8000-0000000000c2';
-- Idempotente: só envia respostas se a campanha ainda não tiver nenhuma.
-- ═══════════════════════════════════════════════════════════════════════════════════════
DO $sim$
DECLARE
  v_emp    constant uuid := 'aaaa0000-0000-4000-8000-0000000000a1';
  v_ciclo  constant uuid := 'aaaa0000-0000-4000-8000-0000000000c2';
  v_tenant constant uuid := 'fe756d06-f953-42eb-b13b-c20512d63a61';   -- Eleva IT (DEV)
  v_q      constant uuid := '00000000-0000-0000-0000-0000000000c1';
  i int; v_setor text; v_funcao text; itens jsonb;
BEGIN
  INSERT INTO ciclos (id, empresa_id, nome, tenant_id, metodologia, ano_referencia, mes_referencia, tipo_ciclo)
  VALUES (v_ciclo, v_emp, 'Avaliação COPSOQ — Simulação', v_tenant, 'COPSOQ_II', 2026, 10, 'Não classificado')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO links_coleta (empresa_id, ciclo_id, token, tenant_id, ativo, is_teste)
  SELECT v_emp, v_ciclo, 'simcopsoq001', v_tenant, true, false
  WHERE NOT EXISTS (SELECT 1 FROM links_coleta WHERE token = 'simcopsoq001');

  IF NOT EXISTS (SELECT 1 FROM respostas WHERE ciclo_id = v_ciclo) THEN
    FOR i IN 1..40 LOOP
      v_setor  := CASE WHEN i <= 18 THEN 'Produção' WHEN i <= 30 THEN 'Administrativo' ELSE 'Logística' END;
      v_funcao := CASE v_setor WHEN 'Produção' THEN CASE WHEN i % 4 = 0 THEN 'Supervisor' ELSE 'Operador' END
                               WHEN 'Administrativo' THEN 'Analista' ELSE 'Auxiliar' END;
      SELECT jsonb_agg(jsonb_build_object('item_id', it.id, 'valor',
               least(5, greatest(1,
                 CASE v_setor
                   WHEN 'Produção'       THEN CASE WHEN it.inversa THEN 4 ELSE 3 END
                   WHEN 'Administrativo' THEN CASE WHEN it.inversa THEN 2 ELSE 4 END
                   ELSE 3 END
                 + (abs(hashtext(i::text || it.codigo)) % 3) - 1
                 + CASE WHEN v_setor = 'Produção' AND it.dimensao = 'ESTRESSE' THEN 1 ELSE 0 END)))
               ORDER BY it.ordem)
        INTO itens FROM instrumento_itens it WHERE it.questionario_id = v_q;
      PERFORM salvar_resposta(v_emp, v_ciclo, 'simcopsoq001', v_setor, v_funcao, 'Ensino Médio', itens, gen_random_uuid(), true, 'simulacao');
    END LOOP;
  END IF;
END
$sim$;

-- ── Verificação ─────────────────────────────────────────────────────────────────────────
-- SELECT count(*), count(DISTINCT setor) FROM respostas WHERE ciclo_id='aaaa0000-0000-4000-8000-0000000000c2';   -- 40 | 3
-- SELECT count(*) FROM resposta_itens_instrumento r JOIN respostas x ON x.id=r.resposta_id WHERE x.ciclo_id='aaaa0000-0000-4000-8000-0000000000c2';   -- 1600
