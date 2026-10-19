-- ═══════════════════════════════════════════════════════════════════════════════════════
-- PsicoMap — SÓ DEV: converte as tabelas hse_* na família genérica instrumento_*  (generalização, 2026-10-19)
-- ⛔ NÃO APLICAR EM PROD: PROD nunca teve as tabelas hse_* (recebe só migration_metodologias_instrumentos.sql).
-- ✅ APLICADO EM DEV em 2026-10-19 (partes A e B). Conferido antes do DROP: contagens iguais (70 itens, 2625 respostas-item,
--    98 referências, 7 severidades) e MÉDIA POR DIMENSÃO idêntica nas 7 dimensões; 13 cenários da RPC sob o papel anon
--    (token ruim, 34 itens, duplicado, valor 0/6/texto, item BS em ciclo HSE e o inverso, idempotência) com ROLLBACK.
--    Fica só como registro: DEV já está na família genérica e este arquivo não deve ser reexecutado.
--
-- ORDEM EM DEV (cada passo testado antes do seguinte):
--   1. migration_metodologias_instrumentos.sql           (cria as tabelas novas, EM PARALELO às antigas)
--   2. migration_instrumento_riscos_config.sql           (arquivo separado, idempotente; precisa de instrumento_dimensoes do passo 1)
--   3. PARTE A deste arquivo                             (copia dados, com verificação de contagem — aborta se divergir)
--   4. migration_obter_instrumento_link.sql e migration_salvar_resposta_instrumento_dev.sql  (RPCs passam às tabelas novas)
--   5. validar: mesmas médias por dimensão, RPC com payload bom e ruim (SET LOCAL ROLE anon + ROLLBACK)
--   6. PARTE B deste arquivo                             (remove hse_*; só depois de 4 e 5)
--
-- Os ids são preservados (instrumento_itens.id = hse_itens.id), então as respostas já gravadas continuam
-- apontando para os mesmos itens. O trigger de congelamento é desligado só durante a cópia: os questionários
-- já estão publicados e o trigger bloquearia o INSERT.
-- ═══════════════════════════════════════════════════════════════════════════════════════

-- ── PARTE A — copiar e conferir ─────────────────────────────────────────────────────────
BEGIN;

-- rótulos de escala no formato genérico (config.rotulos.<escala_labels>); remove as chaves antigas
UPDATE questionarios
   SET config = (config - 'rotulos_freq' - 'rotulos_concord')
                || jsonb_build_object('rotulos', jsonb_strip_nulls(jsonb_build_object(
                     'freq',    config->'rotulos_freq',
                     'concord', config->'rotulos_concord')))
 WHERE metodologia = 'HSE_ICAO35' AND NOT (config ? 'rotulos');

ALTER TABLE instrumento_itens DISABLE TRIGGER tg_instrumento_itens_congelados;
INSERT INTO instrumento_itens (id, questionario_id, metodologia, codigo, ordem, parte, dimensao, texto, inversa, escala_labels, criado_em)
SELECT id, questionario_id, 'HSE_ICAO35', codigo, ordem, parte, dimensao, texto, inversa, escala_labels, criado_em
  FROM hse_itens
ON CONFLICT (id) DO NOTHING;
ALTER TABLE instrumento_itens ENABLE TRIGGER tg_instrumento_itens_congelados;

INSERT INTO resposta_itens_instrumento (resposta_id, item_id, valor)
SELECT resposta_id, item_id, valor FROM resposta_itens_hse
ON CONFLICT (resposta_id, item_id) DO NOTHING;

INSERT INTO instrumento_referencias (id, metodologia, fonte, fonte_ano, setor, dimensao, media, p20, p50, p80, n_amostra, vigente, observacao, criado_em)
SELECT id, 'HSE_ICAO35', fonte, fonte_ano, setor, dimensao, media, p20, p50, p80, n_amostra, vigente, observacao, criado_em
  FROM hse_benchmark
ON CONFLICT (id) DO NOTHING;

INSERT INTO instrumento_riscos_config (metodologia, dimensao, severidade, danos, versao, validado, validado_por, validado_em, atualizado_em)
SELECT 'HSE_ICAO35', dimensao, severidade, danos, versao, validado, validado_por, validado_em, atualizado_em
  FROM hse_riscos_config
ON CONFLICT (metodologia, dimensao) DO NOTHING;

-- Confere: o que existe nas tabelas novas tem de ser, no mínimo, o que existia nas antigas (linhas gravadas pela
-- RPC nova entre os passos 4 e 6 só aumentam o lado novo).
DO $chk$
DECLARE a int; b int;
BEGIN
  SELECT count(*) INTO a FROM hse_itens;                 SELECT count(*) INTO b FROM instrumento_itens WHERE metodologia = 'HSE_ICAO35';
  IF b < a THEN RAISE EXCEPTION 'itens: antigo % novo %', a, b; END IF;
  SELECT count(*) INTO a FROM resposta_itens_hse;        SELECT count(*) INTO b FROM resposta_itens_instrumento;
  IF b < a THEN RAISE EXCEPTION 'respostas: antigo % novo %', a, b; END IF;
  SELECT count(*) INTO a FROM hse_benchmark;             SELECT count(*) INTO b FROM instrumento_referencias WHERE metodologia = 'HSE_ICAO35';
  IF b < a THEN RAISE EXCEPTION 'referências: antigo % novo %', a, b; END IF;
  SELECT count(*) INTO a FROM hse_riscos_config;         SELECT count(*) INTO b FROM instrumento_riscos_config WHERE metodologia = 'HSE_ICAO35';
  IF b < a THEN RAISE EXCEPTION 'riscos: antigo % novo %', a, b; END IF;
END
$chk$;

COMMIT;

-- ── PARTE B — remover o antigo (rodou SÓ depois dos passos 4 e 5; já aplicada em DEV) ───
DROP TABLE IF EXISTS resposta_itens_hse;
DROP TABLE IF EXISTS hse_riscos_config;
DROP TABLE IF EXISTS hse_benchmark;
DROP TABLE IF EXISTS hse_itens;
DROP FUNCTION IF EXISTS public.fn_hse_itens_congelados();
