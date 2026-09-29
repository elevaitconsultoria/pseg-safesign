-- ============================================================================
-- migration_revoke_anon.sql                                        2026-09-11
--
-- M1 da auditoria de gestao de acessos.
--
-- O papel `anon` tinha CRUD COMPLETO em praticamente todas as tabelas. Em PROD
-- isso vem de um `ALTER DEFAULT PRIVILEGES` no schema `public` concedendo ALL
-- ao anon: toda tabela criada nasce assim, e passa a depender EXCLUSIVAMENTE
-- do RLS.
--
-- Nada vazava — as policies comparam contra `perfis` via `auth.uid()`, que e
-- NULL no anon, entao ele recebia `[]`. Mas so o RLS segurava: uma policy nova
-- mal escrita (um `USING (true)` distraido) viraria exposicao publica direta,
-- sem nenhuma segunda barreira. Isto e defesa em profundidade.
--
-- ── O QUE O FORMULARIO PUBLICO REALMENTE USA ────────────────────────────────
-- Levantado lendo psicomap-forms.html (as unicas chamadas ao Supabase la):
--
--   .from('questoes')         SELECT id, codigo            WHERE is_oficial
--   .from('links_coleta')     SELECT ..., empresas(id, nome, logo_base64)
--                             ^ o embed e o motivo de `empresas` entrar na lista
--   .from('empresa_setores')  SELECT id, nome              WHERE ativo
--   .from('empresa_funcoes')  SELECT id, nome, setor_id    WHERE ativo
--   .rpc('salvar_resposta')
--
-- `salvar_resposta` e SECURITY DEFINER: grava em respostas, resposta_itens,
-- respostas_fila e respostas_raw_backup como OWNER. O anon nao precisa — e nao
-- deve ter — GRANT nenhum nessas quatro.
--
-- Nao entram: est_perfil, ciclos, questionarios, questionario_questoes nem as
-- views. Nenhuma e referenciada pelo formulario.
--
-- ⚠️ ARMADILHA (erro cometido na primeira tentativa): nao basta pular as 5
-- tabelas publicas no loop de REVOKE — pular significa que elas MANTEM o ALL
-- original, e o GRANT SELECT seguinte vira redundante em vez de corretivo. O
-- anon continuava podendo INSERT em `empresas`. Elas tambem levam REVOKE ALL,
-- e so depois o GRANT SELECT.
--
-- Aplicar em DEV e PROD. Idempotente.
-- ============================================================================

-- 1. Revogar tudo do anon em todas as tabelas e views do schema public.
DO $$
DECLARE
  t text;
BEGIN
  FOR t IN
    SELECT c.relname
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relkind IN ('r','v')
  LOOP
    EXECUTE format('REVOKE ALL ON public.%I FROM anon', t);
  END LOOP;
END $$;

-- 2. Devolver SOMENTE o SELECT das 5 tabelas que o formulario publico le.
GRANT SELECT ON public.questoes        TO anon;
GRANT SELECT ON public.links_coleta    TO anon;
GRANT SELECT ON public.empresas        TO anon;
GRANT SELECT ON public.empresa_setores TO anon;
GRANT SELECT ON public.empresa_funcoes TO anon;

-- ── VERIFICACAO ─────────────────────────────────────────────────────────────
-- Deve retornar exatamente 5 linhas, todas com privs = 'SELECT'.
--
--   SELECT table_name, string_agg(privilege_type::text, ',') AS privs
--   FROM information_schema.role_table_grants
--   WHERE table_schema='public' AND grantee='anon'
--   GROUP BY table_name ORDER BY table_name;
--
-- E o fluxo do formulario, como anon, tem de continuar inteiro:
--
--   BEGIN;
--   SET LOCAL ROLE anon;
--   SELECT count(*) FROM questoes WHERE is_oficial;        -- 27
--   SELECT count(*) FROM empresa_setores WHERE ativo;      -- > 0
--   SELECT salvar_resposta(<empresa>, <ciclo>, '<token>',
--            'Producao','Operador','Medio',
--            (SELECT jsonb_agg(jsonb_build_object('questao_id', q.id, 'valor', 3))
--               FROM questoes q WHERE q.is_oficial),
--            gen_random_uuid(), true, 'probe');
--   ROLLBACK;
--
-- ATENCAO ao montar o payload do teste: `salvar_resposta` casa os itens por
-- **questao_id (uuid)**, nao por `codigo`. O INSERT final tem
-- `WHERE (item->>'valor')::int BETWEEN 1 AND 4 AND (item->>'questao_id') IS NOT NULL`,
-- que e filtro e nao validacao: um payload com `codigo` grava a resposta com
-- ZERO itens, sem erro nenhum. (Bug pre-existente ja registrado no CLAUDE.md;
-- reproduzido sem querer ao escrever este teste.)
-- ============================================================================
