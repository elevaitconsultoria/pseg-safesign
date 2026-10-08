-- ════════════════════════════════════════════════════════════════════════════
-- BASELINE de public.salvar_resposta em DEV (szqatgvgghxvyyncsjxl) — 2026-10-08
-- Obtido com pg_get_functiondef no banco vivo. DEV tem 3 overloads (PROD tem 2) e
-- respostas.session_id é TEXT aqui (uuid em PROD) — por isso as funções NÃO são
-- intercambiáveis entre ambientes (ver o 10-args: compara session_id=p_session_id::text).
--
-- Uso: referência e ROLLBACK da etapa S3 (plano 2026-10-08-plano-implantacao-hse.md).
-- Normalizado para fim de linha LF (o corpo do overload de 7 args vinha com CRLF).
--
-- Estado de privilégios em 2026-10-08 (has_function_privilege):
--   (uuid,uuid,text,text,text,text,jsonb)                       anon=t authenticated=f  (morta, token-idempotente)
--   (uuid,uuid,text,text,text,text,jsonb,text,boolean)          anon=t authenticated=t  (morta)
--   (uuid,uuid,text,text,text,text,jsonb,uuid,boolean,text)     anon=t authenticated=t  (VIVA)
-- ════════════════════════════════════════════════════════════════════════════

-- ── 10 args (VIVA — chamada por psicomap-forms.html) ────────────────────────
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
BEGIN
  IF p_empresa_id IS NULL THEN RAISE EXCEPTION 'empresa_id obrigatorio'; END IF;
  IF p_link_token = '' OR p_link_token IS NULL THEN RAISE EXCEPTION 'link_token obrigatorio'; END IF;
  IF jsonb_array_length(p_itens) = 0 THEN RAISE EXCEPTION 'itens nao podem estar vazios'; END IF;
  IF NOT p_lgpd_aceito THEN RAISE EXCEPTION 'consentimento_lgpd_obrigatorio'; END IF;
  p_setor := left(trim(p_setor),120);
  p_funcao := left(trim(coalesce(p_funcao,'')),120);
  p_escolaridade := left(trim(coalesce(p_escolaridade,'')),60);
  p_device_info := left(trim(coalesce(p_device_info,'')),300);
  v_payload := jsonb_build_object('empresa_id',p_empresa_id,'ciclo_id',p_ciclo_id,
    'link_token',p_link_token,'setor',p_setor,'funcao',p_funcao,
    'escolaridade',p_escolaridade,'itens',p_itens,'session_id',p_session_id,
    'lgpd_aceito',p_lgpd_aceito,'device_info',p_device_info,'recebido_em',now());
  INSERT INTO respostas_raw_backup(session_id,empresa_id,link_token,payload)
    VALUES(p_session_id,p_empresa_id,p_link_token,v_payload);
  SELECT tenant_id,questionario_id INTO v_tenant_id,v_questionario_id
    FROM empresas WHERE id=p_empresa_id LIMIT 1;
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
    escolaridade,link_token,session_id,lgpd_aceito,lgpd_aceito_em,device_info,respondido_em)
  VALUES(p_empresa_id,p_ciclo_id,v_questionario_id,v_tenant_id,p_setor,p_funcao,
    p_escolaridade,p_link_token,p_session_id,p_lgpd_aceito,
    CASE WHEN p_lgpd_aceito THEN now() ELSE NULL END,
    NULLIF(p_device_info,''),now())
  RETURNING id INTO v_resposta_id;
  INSERT INTO resposta_itens(resposta_id,questao_id,valor)
  SELECT v_resposta_id,(item->>'questao_id')::uuid,(item->>'valor')::int
  FROM jsonb_array_elements(p_itens) AS item
  WHERE (item->>'valor')::int BETWEEN 1 AND 4 AND (item->>'questao_id') IS NOT NULL;
  UPDATE respostas_fila SET status='processado',processado_em=now() WHERE id=v_fila_id;
  RETURN v_resposta_id;
EXCEPTION WHEN OTHERS THEN
  IF v_fila_id IS NOT NULL THEN
    UPDATE respostas_fila SET status='erro',erro_msg=SQLERRM,tentativas=tentativas+1 WHERE id=v_fila_id;
  END IF;
  RAISE;
END;
$function$;

-- ── 9 args com session_id TEXT (MORTA) ──────────────────────────────────────
CREATE OR REPLACE FUNCTION public.salvar_resposta(p_empresa_id uuid, p_ciclo_id uuid DEFAULT NULL::uuid, p_link_token text DEFAULT ''::text, p_setor text DEFAULT 'Não informado'::text, p_funcao text DEFAULT NULL::text, p_escolaridade text DEFAULT NULL::text, p_itens jsonb DEFAULT '[]'::jsonb, p_session_id text DEFAULT NULL::text, p_lgpd_aceito boolean DEFAULT false)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_resposta_id  uuid;
  v_link_id      uuid;
  v_link_ativo   bool;
  v_link_expira  timestamptz;
  v_fila_id      uuid;
  v_item         jsonb;
BEGIN
  IF p_empresa_id IS NULL THEN RAISE EXCEPTION 'empresa_id obrigatório'; END IF;
  IF p_link_token = '' OR p_link_token IS NULL THEN RAISE EXCEPTION 'link_token obrigatório'; END IF;

  p_setor        := left(trim(p_setor), 120);
  p_funcao       := left(trim(coalesce(p_funcao, '')), 120);
  p_escolaridade := left(trim(coalesce(p_escolaridade, '')), 60);
  IF p_setor = '' THEN p_setor := 'Não informado'; END IF;
  IF p_funcao = '' THEN p_funcao := NULL; END IF;
  IF p_escolaridade = '' THEN p_escolaridade := NULL; END IF;

  SELECT id, ativo, expira_em INTO v_link_id, v_link_ativo, v_link_expira
    FROM links_coleta WHERE token = p_link_token LIMIT 1;
  IF v_link_id IS NULL THEN RAISE EXCEPTION 'token_invalido: link não encontrado'; END IF;
  IF NOT v_link_ativo THEN RAISE EXCEPTION 'token_inativo: link foi desativado'; END IF;
  IF v_link_expira IS NOT NULL AND v_link_expira < now() THEN RAISE EXCEPTION 'token_expirado'; END IF;

  PERFORM pg_advisory_xact_lock(hashtext(p_link_token));

  IF p_session_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM respostas WHERE session_id = p_session_id LIMIT 1
  ) THEN
    SELECT id INTO v_resposta_id FROM respostas WHERE session_id = p_session_id LIMIT 1;
    RETURN v_resposta_id;
  END IF;

  IF p_session_id IS NULL AND EXISTS (
    SELECT 1 FROM respostas WHERE link_token = p_link_token LIMIT 1
  ) THEN
    SELECT id INTO v_resposta_id FROM respostas WHERE link_token = p_link_token LIMIT 1;
    RETURN v_resposta_id;
  END IF;

  INSERT INTO respostas_fila (empresa_id, link_token, payload_json, status)
  VALUES (p_empresa_id, p_link_token,
    jsonb_build_object('empresa_id',p_empresa_id,'ciclo_id',p_ciclo_id,'setor',p_setor,
      'funcao',p_funcao,'escolaridade',p_escolaridade,'itens',p_itens,'ts',now()), 'pendente')
  RETURNING id INTO v_fila_id;

  INSERT INTO respostas (empresa_id, ciclo_id, setor, funcao, escolaridade,
    link_token, respondido_em, session_id, lgpd_aceito, lgpd_aceito_em)
  VALUES (p_empresa_id, p_ciclo_id, p_setor, NULLIF(p_funcao,''), NULLIF(p_escolaridade,''),
    p_link_token, now(), p_session_id,
    p_lgpd_aceito, CASE WHEN p_lgpd_aceito THEN now() ELSE NULL END)
  RETURNING id INTO v_resposta_id;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_itens) LOOP
    IF (v_item->>'valor')::int BETWEEN 1 AND 4 THEN
      INSERT INTO resposta_itens (resposta_id, questao_id, valor)
      VALUES (v_resposta_id, (v_item->>'questao_id')::uuid, (v_item->>'valor')::int);
    END IF;
  END LOOP;

  UPDATE respostas_fila SET status='processado', processado_em=now() WHERE id=v_fila_id;
  RETURN v_resposta_id;

EXCEPTION WHEN OTHERS THEN
  IF v_fila_id IS NOT NULL THEN
    UPDATE respostas_fila SET status='erro', erro_msg=SQLERRM, tentativas=tentativas+1 WHERE id=v_fila_id;
  END IF;
  RAISE;
END;
$function$;

-- ── 7 args (MORTA — idempotente por link_token; contraria a regra de negócio 1) ──
-- Corpo idêntico ao de supabase_security_migrations.sql:47-180 (único que existe no repo);
-- não reproduzido aqui. Para restaurar, reaplicar aquele arquivo (cria o overload de 7 args).

-- ── GRANTs (rollback do REVOKE EXECUTE do S3) ───────────────────────────────
GRANT EXECUTE ON FUNCTION public.salvar_resposta(uuid,uuid,text,text,text,text,jsonb,uuid,boolean,text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.salvar_resposta(uuid,uuid,text,text,text,text,jsonb,text,boolean) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.salvar_resposta(uuid,uuid,text,text,text,text,jsonb) TO anon;
