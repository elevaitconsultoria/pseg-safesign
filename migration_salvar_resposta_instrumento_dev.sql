-- ═══════════════════════════════════════════════════════════════════════════════════════
-- PsicoMap — salvar_resposta com ramo de INSTRUMENTO GENÉRICO  (etapa S3, v2 genérica) — VERSÃO DEV (szqatgvgghxvyyncsjxl)
-- Substitui migration_salvar_resposta_hse_prod.sql (renomeada). Plano: .claude/notes/2026-10-08-plano-implantacao-hse.md
--
-- ⚠ ESTE ARQUIVO É POR AMBIENTE. DEV tem respostas.session_id TEXT e 3 overloads; PROD tem
--   session_id UUID e 2 overloads. Não aplicar este arquivo em PROD (há um migration_..._prod.sql).
--   Base: _dev/baseline/salvar_resposta_dev_2026-10-08.sql (definição VIVA em 2026-10-08).
--   Rollback: reaplicar o baseline e os GRANTs que estão no fim dele.
--
-- O QUE MUDA em relação ao baseline (10 args, mesma assinatura — NÃO cria overload novo)
--   1. Deriva a metodologia do CICLO (p_ciclo_id NULL ⇒ BS8800). Ciclo informado que não existe
--      ⇒ erro ciclo_inexistente (antes: violação de FK no INSERT; mesmo efeito, mensagem clara).
--   2. Ramo de INSTRUMENTO GENÉRICO (qualquer metodologia ≠ BS8800 do catálogo `instrumentos`): exige exatamente
--      os itens do questionário publicado de maior versão (sem faltar, sem duplicar, sem item de outro
--      instrumento) e, para cada item, valor inteiro dentro da escala DELE (1..nº de rótulos em
--      questionarios.config.rotulos.<escala_labels>; sem rótulo, instrumentos.escala_min..escala_max).
--      Grava em resposta_itens_instrumento e preenche respostas.metodologia / questionario_id.
--      NENHUMA metodologia é citada pelo nome aqui: uma nova (COPSOQ…) entra só com linhas de catálogo.
--   3. Ramo BS 8800: IDÊNTICO ao de hoje (filtro BETWEEN 1 AND 4 incluído — endurecê-lo é
--      decisão separada), mais UMA rejeição nova: item que pertença ao catálogo de instrumentos.
--   4. REVOKE EXECUTE nos overloads mortos (7 args e 9 args com session_id text): eles têm
--      EXECUTE para anon e driblariam as validações novas.
--
-- ERROS (prefixo = código; o formulário classifica por prefixo)
--   permanentes: instrumento_incompativel · instrumento_incompleto · item_duplicado ·
--                valor_fora_da_escala · ciclo_inexistente · instrumento_indisponivel
--   (instrumento_incompleto era hse_incompleto antes da generalização; o formulário aceita os dois nomes.)
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
  v_ins instrumentos%ROWTYPE;
  v_gq uuid; v_gcfg jsonb; v_g_total int; v_n_itens int; v_n_distintos int; v_n_validos int;
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

  IF v_metodologia <> 'BS8800' THEN
    SELECT * INTO v_ins FROM instrumentos WHERE metodologia = v_metodologia;
    IF NOT FOUND OR NOT v_ins.generico OR NOT v_ins.ativo THEN RAISE EXCEPTION 'instrumento_indisponivel'; END IF;
    SELECT id, config INTO v_gq, v_gcfg FROM questionarios
     WHERE metodologia = v_metodologia AND publicado ORDER BY versao DESC LIMIT 1;
    IF v_gq IS NULL THEN RAISE EXCEPTION 'instrumento_indisponivel'; END IF;
    SELECT count(*) INTO v_g_total FROM instrumento_itens WHERE questionario_id = v_gq;

    -- aceita a chave item_id ou questao_id para o id do item (compatível com o payload do formulário)
    IF EXISTS (SELECT 1 FROM jsonb_array_elements(p_itens) it
                WHERE COALESCE(it->>'item_id', it->>'questao_id') IS NULL) THEN
      RAISE EXCEPTION 'instrumento_incompativel: item sem id';
    END IF;
    SELECT count(*), count(DISTINCT lower(COALESCE(it->>'item_id', it->>'questao_id')))
      INTO v_n_itens, v_n_distintos FROM jsonb_array_elements(p_itens) it;
    IF v_n_distintos <> v_n_itens THEN RAISE EXCEPTION 'item_duplicado'; END IF;
    IF v_n_itens <> v_g_total THEN
      RAISE EXCEPTION 'instrumento_incompleto: esperado %, recebido %', v_g_total, v_n_itens;
    END IF;
    SELECT count(*) INTO v_n_validos
      FROM jsonb_array_elements(p_itens) it
      JOIN instrumento_itens h ON h.id::text = lower(COALESCE(it->>'item_id', it->>'questao_id'))
                              AND h.questionario_id = v_gq;
    IF v_n_validos <> v_n_itens THEN RAISE EXCEPTION 'instrumento_incompativel'; END IF;
    -- Valor: inteiro dentro da escala DO ITEM. O CASE evita o cast de texto não numérico (a ordem de avaliação
    -- do OR/AND no WHERE não é garantida e um "abc"::int viraria erro transitório em vez de valor_fora_da_escala).
    IF EXISTS (SELECT 1 FROM jsonb_array_elements(p_itens) it
                 JOIN instrumento_itens h ON h.id::text = lower(COALESCE(it->>'item_id', it->>'questao_id'))
                                         AND h.questionario_id = v_gq
                WHERE NOT COALESCE(
                  (CASE WHEN (it->>'valor') ~ '^[0-9]{1,3}$' THEN (it->>'valor')::int END)
                    BETWEEN v_ins.escala_min AND COALESCE(
                      CASE WHEN jsonb_typeof(v_gcfg->'rotulos'->h.escala_labels) = 'array'
                           THEN jsonb_array_length(v_gcfg->'rotulos'->h.escala_labels) END,
                      v_ins.escala_max), false)) THEN
      RAISE EXCEPTION 'valor_fora_da_escala';
    END IF;
  ELSE
    -- BS 8800: única rejeição nova — item que pertence ao catálogo de instrumentos genéricos
    IF EXISTS (SELECT 1 FROM jsonb_array_elements(p_itens) it
                 JOIN instrumento_itens h ON h.id::text = lower(it->>'questao_id')) THEN
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
  IF v_metodologia <> 'BS8800' THEN v_questionario_id := v_gq; END IF;   -- NOVO
  SELECT id,ativo,expira_em INTO v_link_id,v_link_ativo,v_link_expira
    FROM links_coleta WHERE token=p_link_token LIMIT 1;
  IF v_link_id IS NULL THEN RAISE EXCEPTION 'token_invalido'; END IF;
  IF NOT v_link_ativo THEN RAISE EXCEPTION 'token_inativo'; END IF;
  IF v_link_expira IS NOT NULL AND v_link_expira < now() THEN RAISE EXCEPTION 'token_expirado'; END IF;
  IF p_session_id IS NOT NULL THEN
    PERFORM pg_advisory_xact_lock(hashtext(p_session_id::text));
    IF EXISTS(SELECT 1 FROM respostas WHERE session_id=p_session_id::text LIMIT 1) THEN
      SELECT id INTO v_resposta_id FROM respostas WHERE session_id=p_session_id::text LIMIT 1;
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

  IF v_metodologia <> 'BS8800' THEN                                               -- NOVO
    INSERT INTO resposta_itens_instrumento(resposta_id,item_id,valor)
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

-- ── Overloads mortos (só em DEV): impedem o uso direto sem as validações novas ──────────
REVOKE ALL ON FUNCTION public.salvar_resposta(uuid,uuid,text,text,text,text,jsonb)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.salvar_resposta(uuid,uuid,text,text,text,text,jsonb,text,boolean)
  FROM PUBLIC, anon, authenticated;

-- Garantia de que a função viva continua executável pelo formulário e pelo admin:
GRANT EXECUTE ON FUNCTION public.salvar_resposta(uuid,uuid,text,text,text,text,jsonb,uuid,boolean,text)
  TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
