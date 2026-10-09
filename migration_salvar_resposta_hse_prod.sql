-- ═══════════════════════════════════════════════════════════════════════════════════════
-- PsicoMap — salvar_resposta com ramo HSE  (etapa S3) — VERSÃO PROD (vftyiildukrpgmnbcnao)
-- Plano: .claude/notes/2026-10-08-plano-implantacao-hse.md
--
-- ⚠ ESTE ARQUIVO É POR AMBIENTE. PROD tem respostas.session_id UUID e 2 overloads; DEV tem
--   session_id TEXT e 3 overloads. Não aplicar este arquivo em DEV (há migration_..._dev.sql).
--   Base: _dev/baseline/salvar_resposta_prod_2026-10-08.sql (definição VIVA em 2026-10-08).
--   Rollback: reaplicar o baseline e os GRANTs que estão no fim dele.
--   PRÉ-REQUISITOS em PROD (nesta ordem): B12 (PITR) confirmado ·
--     migration_metodologia_hse_icao35.sql · migration_obter_instrumento_link.sql.
--     Sem a coluna respostas.metodologia e as tabelas hse_*, esta função NÃO compila/executa.
--   Antes de aplicar: reconferir a definição viva (pg_get_functiondef) contra o baseline.
--
-- O QUE MUDA em relação ao baseline (10 args, mesma assinatura — NÃO cria overload novo)
--   1. Deriva a metodologia do CICLO (p_ciclo_id NULL ⇒ BS8800). Ciclo informado que não existe
--      ⇒ erro ciclo_inexistente (antes: violação de FK no INSERT; mesmo efeito, mensagem clara).
--   2. Ramo HSE: exige exatamente os itens do questionário HSE publicado (sem faltar, sem
--      duplicar, sem item de outro instrumento) e valor 1..5; grava em resposta_itens_hse e
--      preenche respostas.metodologia / questionario_id.
--   3. Ramo BS 8800: IDÊNTICO ao de hoje (filtro BETWEEN 1 AND 4 incluído — endurecê-lo é
--      decisão separada), mais UMA rejeição nova: item que pertença ao catálogo HSE.
--   4. REVOKE EXECUTE no overload morto (9 args): ele tem
--      EXECUTE para anon e driblaria as validações novas.
--
-- ERROS (prefixo = código; o formulário classifica por prefixo)
--   permanentes: instrumento_incompativel · hse_incompleto · item_duplicado ·
--                valor_fora_da_escala · ciclo_inexistente · instrumento_indisponivel
--   Obs.: o EXCEPTION final dá RAISE, então a transação inteira é desfeita (fila e raw_backup
--   também). Uma rejeição não deixa linha no banco — só log do Postgres.
-- ═══════════════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.salvar_resposta(p_empresa_id uuid, p_ciclo_id uuid, p_link_token text, p_setor text DEFAULT ''::text, p_funcao text DEFAULT ''::text, p_escolaridade text DEFAULT ''::text, p_itens jsonb DEFAULT '[]'::jsonb, p_session_id uuid DEFAULT NULL::uuid, p_lgpd_aceito boolean DEFAULT true, p_device_info text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_link_id uuid; v_link_ativo boolean; v_link_expira timestamptz;
  v_resposta_id uuid; v_fila_id uuid;
  v_tenant_id uuid; v_questionario_id uuid;
  v_payload jsonb;
  v_metodologia text := 'BS8800';
  v_hse_q uuid; v_hse_total int; v_n_itens int; v_n_distintos int; v_n_validos int;
BEGIN
  IF p_empresa_id IS NULL THEN RAISE EXCEPTION 'empresa_id obrigatorio'; END IF;
  IF p_link_token = '' OR p_link_token IS NULL THEN RAISE EXCEPTION 'link_token obrigatorio'; END IF;
  IF jsonb_array_length(p_itens) = 0 THEN RAISE EXCEPTION 'itens nao podem estar vazios'; END IF;
  IF NOT p_lgpd_aceito THEN RAISE EXCEPTION 'consentimento_lgpd_obrigatorio'; END IF;
  p_setor := left(trim(p_setor),120);
  p_funcao := left(trim(coalesce(p_funcao,'')),120);
  p_escolaridade := left(trim(coalesce(p_escolaridade,'')),60);
  p_device_info := left(trim(coalesce(p_device_info,'')),300);

  -- ── NOVO: metodologia derivada do ciclo e validação do instrumento ──────────────────
  IF p_ciclo_id IS NOT NULL THEN
    SELECT metodologia INTO v_metodologia FROM ciclos WHERE id = p_ciclo_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'ciclo_inexistente'; END IF;
  END IF;

  IF v_metodologia = 'HSE_ICAO35' THEN
    SELECT id INTO v_hse_q FROM questionarios
     WHERE metodologia = 'HSE_ICAO35' AND publicado ORDER BY versao DESC LIMIT 1;
    IF v_hse_q IS NULL THEN RAISE EXCEPTION 'instrumento_indisponivel'; END IF;
    SELECT count(*) INTO v_hse_total FROM hse_itens WHERE questionario_id = v_hse_q;

    -- o HSE aceita a chave item_id ou questao_id para o id do item (compatível com o payload do form)
    IF EXISTS (SELECT 1 FROM jsonb_array_elements(p_itens) it
                WHERE COALESCE(it->>'item_id', it->>'questao_id') IS NULL) THEN
      RAISE EXCEPTION 'instrumento_incompativel: item sem id';
    END IF;
    SELECT count(*), count(DISTINCT lower(COALESCE(it->>'item_id', it->>'questao_id')))
      INTO v_n_itens, v_n_distintos FROM jsonb_array_elements(p_itens) it;
    IF v_n_distintos <> v_n_itens THEN RAISE EXCEPTION 'item_duplicado'; END IF;
    IF v_n_itens <> v_hse_total THEN
      RAISE EXCEPTION 'hse_incompleto: esperado %, recebido %', v_hse_total, v_n_itens;
    END IF;
    SELECT count(*) INTO v_n_validos
      FROM jsonb_array_elements(p_itens) it
      JOIN hse_itens h ON h.id::text = lower(COALESCE(it->>'item_id', it->>'questao_id'))
                      AND h.questionario_id = v_hse_q;
    IF v_n_validos <> v_n_itens THEN RAISE EXCEPTION 'instrumento_incompativel'; END IF;
    IF EXISTS (SELECT 1 FROM jsonb_array_elements(p_itens) it
                WHERE (it->>'valor') IS NULL OR (it->>'valor') !~ '^[0-9]+$'
                   OR (it->>'valor')::int NOT BETWEEN 1 AND 5) THEN
      RAISE EXCEPTION 'valor_fora_da_escala';
    END IF;
  ELSE
    -- BS 8800: única rejeição nova — item que pertence ao catálogo HSE
    IF EXISTS (SELECT 1 FROM jsonb_array_elements(p_itens) it
                 JOIN hse_itens h ON h.id::text = lower(it->>'questao_id')) THEN
      RAISE EXCEPTION 'instrumento_incompativel';
    END IF;
  END IF;
  -- ── fim do trecho novo ──────────────────────────────────────────────────────────────

  v_payload := jsonb_build_object('empresa_id',p_empresa_id,'ciclo_id',p_ciclo_id,
    'link_token',p_link_token,'setor',p_setor,'funcao',p_funcao,
    'escolaridade',p_escolaridade,'itens',p_itens,'session_id',p_session_id,
    'lgpd_aceito',p_lgpd_aceito,'device_info',p_device_info,'recebido_em',now());
  INSERT INTO respostas_raw_backup(session_id,empresa_id,link_token,payload)
    VALUES(p_session_id,p_empresa_id,p_link_token,v_payload);
  SELECT tenant_id,questionario_id INTO v_tenant_id,v_questionario_id
    FROM empresas WHERE id=p_empresa_id LIMIT 1;
  IF v_metodologia = 'HSE_ICAO35' THEN v_questionario_id := v_hse_q; END IF;   -- NOVO
  SELECT id,ativo,expira_em INTO v_link_id,v_link_ativo,v_link_expira
    FROM links_coleta WHERE token=p_link_token LIMIT 1;
  IF v_link_id IS NULL THEN RAISE EXCEPTION 'token_invalido'; END IF;
  IF NOT v_link_ativo THEN RAISE EXCEPTION 'token_inativo'; END IF;
  IF v_link_expira IS NOT NULL AND v_link_expira < now() THEN RAISE EXCEPTION 'token_expirado'; END IF;
  IF p_session_id IS NOT NULL THEN
    PERFORM pg_advisory_xact_lock(hashtext(p_session_id::text));
    IF EXISTS(SELECT 1 FROM respostas WHERE session_id=p_session_id LIMIT 1) THEN
      SELECT id INTO v_resposta_id FROM respostas WHERE session_id=p_session_id LIMIT 1;
      RETURN v_resposta_id;
    END IF;
  END IF;
  INSERT INTO respostas_fila(empresa_id,link_token,payload_json,status)
    VALUES(p_empresa_id,p_link_token,v_payload,'pendente') RETURNING id INTO v_fila_id;
  INSERT INTO respostas(empresa_id,ciclo_id,questionario_id,tenant_id,setor,funcao,
    escolaridade,link_token,session_id,lgpd_aceito,lgpd_aceito_em,device_info,respondido_em,metodologia)
  VALUES(p_empresa_id,p_ciclo_id,v_questionario_id,v_tenant_id,p_setor,p_funcao,
    p_escolaridade,p_link_token,p_session_id,p_lgpd_aceito,
    CASE WHEN p_lgpd_aceito THEN now() ELSE NULL END,
    NULLIF(p_device_info,''),now(),v_metodologia)
  RETURNING id INTO v_resposta_id;

  IF v_metodologia = 'HSE_ICAO35' THEN                                            -- NOVO
    INSERT INTO resposta_itens_hse(resposta_id,item_id,valor)
    SELECT v_resposta_id, (lower(COALESCE(it->>'item_id', it->>'questao_id')))::uuid, (it->>'valor')::int
      FROM jsonb_array_elements(p_itens) it;
  ELSE
    INSERT INTO resposta_itens(resposta_id,questao_id,valor)
    SELECT v_resposta_id,(item->>'questao_id')::uuid,(item->>'valor')::int
    FROM jsonb_array_elements(p_itens) AS item
    WHERE (item->>'valor')::int BETWEEN 1 AND 4 AND (item->>'questao_id') IS NOT NULL;
  END IF;

  UPDATE respostas_fila SET status='processado',processado_em=now() WHERE id=v_fila_id;
  RETURN v_resposta_id;
EXCEPTION WHEN OTHERS THEN
  IF v_fila_id IS NOT NULL THEN
    UPDATE respostas_fila SET status='erro',erro_msg=SQLERRM,tentativas=tentativas+1 WHERE id=v_fila_id;
  END IF;
  RAISE;
END;
$function$;

-- ── Overload morto (PROD só tem o de 9 args): driblaria as validações novas ────────────
-- Reversível: os GRANTs originais estão no fim do baseline.
REVOKE ALL ON FUNCTION public.salvar_resposta(uuid,uuid,text,text,text,text,jsonb,uuid,boolean)
  FROM PUBLIC, anon, authenticated;

-- Garantia de que a função viva continua executável pelo formulário e pelo admin:
GRANT EXECUTE ON FUNCTION public.salvar_resposta(uuid,uuid,text,text,text,text,jsonb,uuid,boolean,text)
  TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
