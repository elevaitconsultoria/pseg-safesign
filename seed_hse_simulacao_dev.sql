-- ═══════════════════════════════════════════════════════════════════════════════════════
-- Ambiente de SIMULAÇÃO do HSE — SOMENTE DEV
-- Cria uma empresa fictícia com catálogo GHE, quadro de funcionários, um ciclo HSE e um link de coleta
-- (NÃO é link de teste: respostas de link de teste são excluídas das análises).
-- As respostas simuladas entram pelo script _dev/simular-hse.js, que chama a RPC real salvar_resposta
-- (mesma validação do formulário público), então o caminho completo é exercitado.
--
-- ⛔ NÃO APLICAR EM PROD (empresa fictícia no tenant da Eleva IT). Para remover tudo:
--     DELETE FROM empresas WHERE id = 'aaaa0000-0000-4000-8000-0000000000a1';   -- CASCADE leva o resto
-- Idempotente.
-- ═══════════════════════════════════════════════════════════════════════════════════════
DO $sim$
DECLARE
  v_emp    constant uuid := 'aaaa0000-0000-4000-8000-0000000000a1';
  v_ciclo  constant uuid := 'aaaa0000-0000-4000-8000-0000000000c1';
  v_tenant constant uuid := 'fe756d06-f953-42eb-b13b-c20512d63a61';   -- Eleva IT (DEV)
BEGIN
  INSERT INTO empresas (id, nome, tenant_id)
  VALUES (v_emp, 'SIMULAÇÃO HSE (fictícia)', v_tenant)
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO empresa_setores (empresa_id, nome, tenant_id)
  SELECT v_emp, s, v_tenant FROM unnest(ARRAY['Produção','Administrativo','Logística']) s
  WHERE NOT EXISTS (SELECT 1 FROM empresa_setores WHERE empresa_id = v_emp AND nome = s);

  INSERT INTO empresa_funcoes (empresa_id, nome, tenant_id)
  SELECT v_emp, f, v_tenant FROM unnest(ARRAY['Operador','Analista','Supervisor','Auxiliar']) f
  WHERE NOT EXISTS (SELECT 1 FROM empresa_funcoes WHERE empresa_id = v_emp AND nome = f);

  -- Quadro: 120 pessoas (denominador da taxa de resposta). Produção 60, Administrativo 30, Logística 30.
  INSERT INTO empresa_headcount (empresa_id, tenant_id, setor, funcao, quantidade)
  SELECT v_emp, v_tenant, s, f, q FROM (VALUES
    ('Produção','Operador',45), ('Produção','Supervisor',15),
    ('Administrativo','Analista',30),
    ('Logística','Auxiliar',30)
  ) AS t(s, f, q)
  WHERE NOT EXISTS (SELECT 1 FROM empresa_headcount h WHERE h.empresa_id = v_emp AND h.setor = t.s AND h.funcao = t.f);

  INSERT INTO ciclos (id, empresa_id, nome, tenant_id, metodologia, ano_referencia, mes_referencia, tipo_ciclo)
  VALUES (v_ciclo, v_emp, 'Avaliação HSE — Simulação', v_tenant, 'HSE_ICAO35', 2026, 10, 'Não classificado')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO links_coleta (empresa_id, ciclo_id, token, tenant_id, ativo, is_teste)
  SELECT v_emp, v_ciclo, 'simhse000001', v_tenant, true, false
  WHERE NOT EXISTS (SELECT 1 FROM links_coleta WHERE token = 'simhse000001');
END
$sim$;

-- ── Verificação ─────────────────────────────────────────────────────────────────────────
-- SELECT (SELECT count(*) FROM empresa_setores WHERE empresa_id='aaaa0000-0000-4000-8000-0000000000a1') setores,
--        (SELECT sum(quantidade) FROM empresa_headcount WHERE empresa_id='aaaa0000-0000-4000-8000-0000000000a1') quadro,
--        (SELECT metodologia FROM ciclos WHERE id='aaaa0000-0000-4000-8000-0000000000c1') metodologia,
--        (SELECT ativo||'/'||is_teste FROM links_coleta WHERE token='simhse000001') link;        -- 3 | 120 | HSE_ICAO35 | true/false
