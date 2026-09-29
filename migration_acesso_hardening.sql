-- ============================================================================
-- migration_acesso_hardening.sql                                   2026-09-11
--
-- Auditoria geral de gestao de acessos. Fecha os achados de severidade
-- CRITICA e ALTA que vivem no banco. Ver
-- .claude/notes/2026-09-11-auditoria-gestao-acessos.md para o relatorio
-- completo, incluindo os achados MEDIOS que ficaram de fora.
--
-- Os tres primeiros blocos sao a MESMA classe de gap ja registrada no
-- CLAUDE.md para respostas/resposta_itens e empresa_headcount: tabela ou
-- funcao que nasceu depois da migration de hardening e nunca recebeu a
-- policy/guard correspondente.
--
-- Aplicar em DEV e PROD. Idempotente.
-- ============================================================================


-- ─────────────────────────────────────────────────────────────────────────────
-- C3 — cliente_viewer tinha CRUD completo no catalogo GHE
--
-- `empresa_setores` e `empresa_funcoes` tinham 4 policies cada. A unica
-- PERMISSIVE de escrita (auth_manage_*) exige apenas `tenant_id =
-- get_my_tenant_id()`, que um viewer SATISFAZ; a unica RESTRICTIVE de viewer
-- (viewer_empresa_select_*) cobre so SELECT (polcmd='r'). Resultado: um viewer
-- podia inserir, alterar e APAGAR setores e cargos de todas as empresas do
-- tenant — nao so da sua.
--
-- Pela regra de negocio 3 do CLAUDE.md, GHE e pre-requisito do formulario:
-- apagar o catalogo derruba a coleta publica da EST inteira.
--
-- As duas tabelas foram esquecidas por migration_viewer_write_hardening.sql,
-- que cobriu links_coleta, laudos, empresa_headcount e ciclos.
--
-- TRES policies por comando, nunca uma FOR ALL: FOR ALL aplicaria o USING
-- tambem ao SELECT e o viewer PRECISA ler o catalogo (analise, laudo).
-- ─────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS viewer_no_insert_setores ON public.empresa_setores;
CREATE POLICY viewer_no_insert_setores ON public.empresa_setores
  AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (auth_role() <> 'cliente_viewer');

DROP POLICY IF EXISTS viewer_no_update_setores ON public.empresa_setores;
CREATE POLICY viewer_no_update_setores ON public.empresa_setores
  AS RESTRICTIVE FOR UPDATE TO authenticated
  USING      (auth_role() <> 'cliente_viewer')
  WITH CHECK (auth_role() <> 'cliente_viewer');

DROP POLICY IF EXISTS viewer_no_delete_setores ON public.empresa_setores;
CREATE POLICY viewer_no_delete_setores ON public.empresa_setores
  AS RESTRICTIVE FOR DELETE TO authenticated
  USING (auth_role() <> 'cliente_viewer');

DROP POLICY IF EXISTS viewer_no_insert_funcoes ON public.empresa_funcoes;
CREATE POLICY viewer_no_insert_funcoes ON public.empresa_funcoes
  AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (auth_role() <> 'cliente_viewer');

DROP POLICY IF EXISTS viewer_no_update_funcoes ON public.empresa_funcoes;
CREATE POLICY viewer_no_update_funcoes ON public.empresa_funcoes
  AS RESTRICTIVE FOR UPDATE TO authenticated
  USING      (auth_role() <> 'cliente_viewer')
  WITH CHECK (auth_role() <> 'cliente_viewer');

DROP POLICY IF EXISTS viewer_no_delete_funcoes ON public.empresa_funcoes;
CREATE POLICY viewer_no_delete_funcoes ON public.empresa_funcoes
  AS RESTRICTIVE FOR DELETE TO authenticated
  USING (auth_role() <> 'cliente_viewer');


-- ─────────────────────────────────────────────────────────────────────────────
-- C4 — cliente_viewer podia inserir empresas
--
-- `auth_insert_empresa` e PERMISSIVE com WITH CHECK (tenant_id =
-- get_my_tenant_id()) e NENHUMA restritiva cobria INSERT: a
-- viewer_readonly_empresas e polcmd='w' (so UPDATE) e o DELETE ja exige
-- is_tenant_admin(). Havia ate caminho de UI pronto (botao do empty-state do
-- Dashboard), corrigido em PR separada.
-- ─────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS viewer_no_insert_empresas ON public.empresas;
CREATE POLICY viewer_no_insert_empresas ON public.empresas
  AS RESTRICTIVE FOR INSERT TO authenticated
  WITH CHECK (auth_role() <> 'cliente_viewer');


-- ─────────────────────────────────────────────────────────────────────────────
-- C2 — super_admin_tenant_details() nao verificava quem chamava
--
-- SECURITY DEFINER + SET row_security='off' + GRANT para authenticated, sem
-- nenhum guard: QUALQUER usuario autenticado (inclusive cliente_viewer) lia
-- nome, slug, nº de usuarios, nº de clientes, links ativos, total de respostas
-- e data da ultima resposta de TODAS as ESTs. Confirmado com o JWT de um
-- consultor comum.
--
-- A funcao irma super_admin_stats(), da MESMA migration, tem o guard. Esta
-- simplesmente nao recebeu.
--
-- Hoje ha uma unica EST em PROD, entao o impacto e latente — ele se
-- materializa integralmente no dia em que a segunda consultoria entrar, que e
-- o modelo de negocio do produto.
--
-- Convertida de LANGUAGE sql para plpgsql (precisa de RAISE). A assinatura de
-- retorno e mantida BYTE A BYTE — carregarGestaoESTs() consome t.nome,
-- t.created_at, t.ultima_resposta, t.ativo. Todas as referencias sao
-- qualificadas com alias para nao colidir com os nomes dos parametros OUT.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.super_admin_tenant_details()
RETURNS TABLE(
  t_id            uuid,
  nome            text,
  slug            text,
  ativo           boolean,
  created_at      timestamp with time zone,
  usuarios        bigint,
  clientes        bigint,
  links_ativos    bigint,
  respostas       bigint,
  ultima_resposta timestamp with time zone
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
SET row_security TO 'off'
AS $function$
BEGIN
  -- Mesmo guard de super_admin_stats().
  IF (SELECT p.role FROM perfis p WHERE p.id = auth.uid() LIMIT 1) <> 'super_admin' THEN
    RAISE EXCEPTION 'Acesso negado' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    t.id,
    t.nome,
    t.slug,
    COALESCE(t.ativo, true),
    t.created_at,
    COUNT(DISTINCT p.id)  FILTER (WHERE p.role IN ('admin','consultor')),
    COUNT(DISTINCT e.id)  FILTER (WHERE e.ativo = true),
    COUNT(DISTINCT lc.id) FILTER (WHERE lc.ativo = true),
    COUNT(DISTINCT r.id),
    MAX(r.respondido_em)
  FROM tenants t
  LEFT JOIN perfis       p  ON p.tenant_id  = t.id
  LEFT JOIN empresas     e  ON e.tenant_id  = t.id
  LEFT JOIN links_coleta lc ON lc.tenant_id = t.id
  LEFT JOIN respostas    r  ON r.link_token IN (
    SELECT lc2.token FROM links_coleta lc2 WHERE lc2.tenant_id = t.id
  )
  GROUP BY t.id, t.nome, t.slug, t.ativo, t.created_at
  ORDER BY t.created_at DESC;
END;
$function$;


-- ─────────────────────────────────────────────────────────────────────────────
-- A1 — verificar_limite_tenant() aceitava QUALQUER tenant por parametro
--
-- SECURITY DEFINER, GRANT para authenticated, sem guard, e o tenant vem por
-- argumento. Confirmado: com o JWT de um consultor, retornou o plano
-- ('enterprise') e as contagens de um tenant informado na chamada. Vazamento
-- de dado comercial entre ESTs concorrentes.
--
-- E chamada legitimamente pelo frontend (verificarLimiteTenant, sempre com
-- currentTenantId), entao a correcao e validar o parametro — nao revogar. A
-- assinatura nao muda.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.verificar_limite_tenant(p_tenant_id uuid, p_recurso text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_tenant  tenants%ROWTYPE;
  v_atual   int := 0;
  v_limite  int;
BEGIN
  -- So o proprio tenant do caller, ou super_admin.
  IF NOT (is_super_admin() OR p_tenant_id = get_my_tenant_id()) THEN
    RAISE EXCEPTION 'Acesso negado' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_tenant FROM tenants WHERE id = p_tenant_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('permitido', false, 'motivo', 'tenant_nao_encontrado');
  END IF;
  IF v_tenant.plano = 'trial'
     AND v_tenant.trial_ate IS NOT NULL
     AND v_tenant.trial_ate < now() THEN
    RETURN jsonb_build_object(
      'permitido', false, 'motivo', 'trial_expirado',
      'mensagem', 'Período de trial encerrado. Faça o upgrade para continuar.',
      'plano', v_tenant.plano, 'trial_ate', v_tenant.trial_ate
    );
  END IF;
  IF p_recurso = 'empresas' THEN
    SELECT COUNT(*) INTO v_atual FROM empresas WHERE tenant_id = p_tenant_id AND ativo = true;
    v_limite := v_tenant.max_empresas;
  ELSIF p_recurso = 'usuarios' THEN
    SELECT COUNT(*) INTO v_atual FROM perfis WHERE tenant_id = p_tenant_id AND ativo = true;
    v_limite := v_tenant.max_usuarios;
  ELSIF p_recurso = 'respostas_mes' THEN
    SELECT COUNT(*) INTO v_atual FROM respostas
    WHERE tenant_id = p_tenant_id AND respondido_em >= date_trunc('month', now());
    v_limite := v_tenant.max_respostas_mes;
  ELSE
    RETURN jsonb_build_object('permitido', true, 'motivo', 'recurso_sem_limite');
  END IF;
  IF v_limite IS NULL THEN
    RETURN jsonb_build_object('permitido', true, 'motivo', 'ilimitado', 'atual', v_atual, 'limite', null, 'plano', v_tenant.plano);
  END IF;
  RETURN jsonb_build_object(
    'permitido',  v_atual < v_limite,
    'motivo',     CASE WHEN v_atual < v_limite THEN 'ok' ELSE 'limite_atingido' END,
    'mensagem',   CASE WHEN v_atual < v_limite THEN null
                       ELSE format('Limite de %s atingido (%s/%s). Faça o upgrade do plano.', p_recurso, v_atual, v_limite) END,
    'atual',      v_atual,
    'limite',     v_limite,
    'pct',        ROUND(v_atual * 100.0 / v_limite, 1),
    'plano',      v_tenant.plano
  );
END;
$function$;


-- ─────────────────────────────────────────────────────────────────────────────
-- A2/A3 — duas RPCs legadas expostas a qualquer autenticado
--
-- convidar_membro(uuid,text): exige is_tenant_admin(), mas faz
--   UPDATE perfis SET tenant_id = get_my_tenant_id() WHERE id = p_user_id
-- SEM verificar o tenant atual do alvo. Um admin da EST A que conheca o UUID
-- de um usuario da EST B o move para a sua EST. Sendo SECURITY DEFINER,
-- ignora RLS.
--
-- reprocessar_fila(): sem guard de role nenhum, opera sobre a fila GLOBAL
-- (todos os tenants). Alem disso ja esta quebrada — chama salvar_resposta com
-- 7 argumentos e so existem overloads de 9 e 10.
--
-- NENHUMA das duas e chamada pelo frontend (as RPCs usadas sao
-- salvar_resposta, verificar_limite_tenant, super_admin_stats,
-- super_admin_tenant_details, perfis_com_status e criar_tenant).
--
-- REVOKE em vez de DROP: preserva a possibilidade de reativar com o guard
-- correto, sem perder o codigo.
-- ─────────────────────────────────────────────────────────────────────────────

-- Condicional: `reprocessar_fila()` existe em PROD mas NAO em DEV (divergencia
-- encontrada ao aplicar esta migration). Um REVOKE direto aborta com 42883 no
-- banco onde a funcao nao existe, entao o mesmo arquivo nao rodaria nos dois.
DO $$
BEGIN
  IF to_regprocedure('public.convidar_membro(uuid, text)') IS NOT NULL THEN
    REVOKE EXECUTE ON FUNCTION public.convidar_membro(uuid, text) FROM authenticated, anon, public;
  END IF;
  IF to_regprocedure('public.reprocessar_fila()') IS NOT NULL THEN
    REVOKE EXECUTE ON FUNCTION public.reprocessar_fila() FROM authenticated, anon, public;
  END IF;
END $$;


-- ============================================================================
-- NAO incluido (achados MEDIOS — ver a nota da auditoria):
--   M1  REVOKE do anon em 23 tabelas (est_perfil e lida pelo formulario publico)
--   M5  criar_tenant() nao valida que o caller ja tem tenant
--   M9  get_my_empresa_id()/fn_guard_perfil_update() sem search_path fixo
--   M10 tenant_modulos nao existe em PROD
--   M11 tenant_contadores com RLS e zero policies
--   M12 salvar_resposta com 2 overloads (risco PGRST203)
-- ============================================================================
