-- ═══════════════════════════════════════════════════════════════════════════════════════
-- PsicoMap — RPC pública obter_instrumento_link(token)  (etapa S2)
-- Plano: .claude/notes/2026-10-08-plano-implantacao-hse.md
--
-- Executar: DEV primeiro, PROD depois. Pré-requisito: migration_metodologia_hse_icao35.sql.
-- ⚠ ORDEM DE DEPLOY: aplicar em PROD ANTES de promover o psicomap-forms.html que a chama.
--   O formulário passa a depender desta função para saber qual instrumento exibir.
--
-- PROBLEMA QUE RESOLVE
--   O formulário público precisa saber a metodologia do ciclo do link. Mas `anon` NÃO tem SELECT
--   em `ciclos` (revogado de propósito em migration_revoke_anon.sql — superfície do anon = 5
--   tabelas). Embutir `ciclos(metodologia)` no select de links_coleta faria o PostgREST recusar a
--   requisição INTEIRA e todo link mostraria "Token inválido".
--
-- DESENHO
--   • SECURITY DEFINER: lê ciclos/questionarios/hse_itens como dono; o anon só recebe o JSON.
--   • Token inexistente, inativo ou expirado devolvem o MESMO erro (token_invalido) — a função
--     não vira oráculo de tokens. (O token já é legível via links_coleta, então nada vaza a mais.)
--   • Link sem ciclo, ou ciclo BS 8800 → {"metodologia":"BS8800","ciclo_id":...} (nada mais).
--   • Ciclo HSE → instrumento completo. NÃO devolve `inversa` nem `dimensao`: o respondente não
--     precisa saber como será pontuado (e a dimensão enviesaria a resposta).
--   • Instrumento HSE não publicado neste ambiente → erro instrumento_indisponivel (a chave
--     geral do HSE é questionarios.publicado).
--
-- LIMITAÇÃO CONHECIDA (v1): usa o questionário HSE publicado de MAIOR versão. Se um dia houver
--   duas versões publicadas e um ciclo já em andamento, as respostas novas cairiam na versão
--   nova. Antes de publicar uma 2ª versão, pinar o questionário no ciclo (ciclos.questionario_id).
--
-- ROLLBACK: DROP FUNCTION public.obter_instrumento_link(text);   (nada depende dela até o S5)
-- ═══════════════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.obter_instrumento_link(p_token text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $fn$
DECLARE
  v_ciclo_id   uuid;
  v_ativo      boolean;
  v_expira     timestamptz;
  v_encontrado boolean := false;
  v_metod      text := 'BS8800';
  v_q          questionarios%ROWTYPE;
  v_itens      jsonb;
BEGIN
  IF p_token IS NULL OR p_token = '' THEN
    RAISE EXCEPTION 'token_invalido';
  END IF;

  SELECT true, ciclo_id, ativo, expira_em
    INTO v_encontrado, v_ciclo_id, v_ativo, v_expira
    FROM links_coleta
   WHERE token = p_token
   LIMIT 1;

  IF NOT COALESCE(v_encontrado, false)
     OR NOT COALESCE(v_ativo, false)
     OR (v_expira IS NOT NULL AND v_expira < now()) THEN
    RAISE EXCEPTION 'token_invalido';
  END IF;

  IF v_ciclo_id IS NOT NULL THEN
    SELECT metodologia INTO v_metod FROM ciclos WHERE id = v_ciclo_id;
    v_metod := COALESCE(v_metod, 'BS8800');
  END IF;

  IF v_metod <> 'HSE_ICAO35' THEN
    RETURN jsonb_build_object('metodologia', v_metod, 'ciclo_id', v_ciclo_id);
  END IF;

  SELECT * INTO v_q
    FROM questionarios
   WHERE metodologia = 'HSE_ICAO35' AND publicado
   ORDER BY versao DESC
   LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'instrumento_indisponivel';
  END IF;

  SELECT jsonb_agg(jsonb_build_object(
           'id', i.id, 'codigo', i.codigo, 'ordem', i.ordem, 'parte', i.parte,
           'texto', i.texto, 'escala_labels', i.escala_labels) ORDER BY i.ordem)
    INTO v_itens
    FROM hse_itens i
   WHERE i.questionario_id = v_q.id;

  RETURN jsonb_build_object(
    'metodologia',     v_metod,
    'ciclo_id',        v_ciclo_id,
    'questionario_id', v_q.id,
    'versao',          v_q.versao,
    'config',          v_q.config,
    'itens',           COALESCE(v_itens, '[]'::jsonb)
  );
END;
$fn$;

REVOKE ALL ON FUNCTION public.obter_instrumento_link(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_instrumento_link(text) TO anon, authenticated;

COMMENT ON FUNCTION public.obter_instrumento_link(text) IS
  'RPC pública: metodologia (e, se HSE, o instrumento) do ciclo do link. Erro token_invalido para token inexistente/inativo/expirado.';

-- Faz o PostgREST enxergar a função nova sem esperar o ciclo de recarga do schema.
NOTIFY pgrst, 'reload schema';

-- ── Verificação (SET LOCAL ROLE anon; em transação com ROLLBACK) ────────────────────────
--   select obter_instrumento_link('token-que-nao-existe');          -- erro token_invalido
--   select obter_instrumento_link(<token de link ativo BS>);          -- {"metodologia":"BS8800",...}
--   select obter_instrumento_link(<token de link ativo HSE>);         -- instrumento completo (35 itens)
--   select * from ciclos;                                             -- permission denied (continua)
