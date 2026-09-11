# Handoff — Auditoria de gestão de acessos (2026-09-11)

Documento de continuação. O relatório completo de achados está em
`.claude/notes/2026-09-11-auditoria-gestao-acessos.md` (vem na PR #74).

---

## ⚠️ LEIA PRIMEIRO — o banco está À FRENTE do código

Todas as migrations e Edge Functions **já foram aplicadas em DEV e PROD**, mas
**nenhuma PR de HTML foi mergeada**. Isso cria um estado inconsistente com uma
consequência concreta:

> **Convidar um Viewer pelo painel de PRODUÇÃO falha agora.**
> A Edge Function `convidar-usuario` (v3, PROD) passou a **exigir** `empresa_id`
> quando `role = 'cliente_viewer'`, mas o `psicomap-admin.html` que está no ar
> (via `main`) é o antigo e **não tem o campo Empresa** — ele envia o body sem
> `empresa_id` e recebe `400 empresa_id é obrigatório para o perfil Viewer`.
>
> Convite de **consultor** e **admin** não é afetado (para esses roles o
> `empresa_id` é `null` por design).
>
> **Resolve mergeando a PR #70 e promovendo para `main`.** Enquanto isso, o
> contorno é o super_admin criar o usuário e depois usar o botão
> **"Reconfigurar"** na tela Equipe para vincular a empresa.

Nenhuma outra funcionalidade ficou degradada por esse descompasso — as outras
mudanças de banco só **restringem** quem já não deveria escrever, e o frontend
antigo não exercita nenhuma delas.

---

## Estado verificado do banco (DEV e PROD idênticos)

Conferido por `pg_policy` / `pg_proc` / `information_schema`, não pelos arquivos:

| Item | DEV | PROD |
|---|---|---|
| 6 policies `est_perfil_*_admin` / `riscos_config_*_admin` | ✅ | ✅ |
| 7 policies `viewer_no_*` (setores, funções, empresas) | ✅ | ✅ |
| `anon` com grants em **5 tabelas, só SELECT** | ✅ | ✅ |
| `tenant_modulos` existe, com GRANT | ✅ | ✅ |
| `consultor_update_member_perfis` removida | ✅ | ✅ |
| `super_admin_tenant_details()` com guard de role | ✅ | ✅ |
| `verificar_limite_tenant()` valida o tenant | ✅ | ✅ |
| `convidar_membro` / `reprocessar_fila` revogadas de `authenticated` | ✅ | ✅ |
| Edge Function `convidar-usuario` | v3 | v3 |
| Edge Function `webhook-billing` (fail-closed) | v2 | v7 |

**Divergências DEV↔PROD que continuam existindo** (não foram alteradas):
- `reprocessar_fila()` existe só em **PROD**.
- `webhook-billing` tem `verify_jwt: true` em **DEV** e `false` em **PROD**.
  Webhook não manda JWT, então em DEV o gateway barra antes da function rodar —
  aquele ambiente nunca exercita o fluxo. **Vale alinhar** (o correto é `false`).
- `is_active_consultor()` (DEV) × `is_tenant_consultor()` (PROD) — já era conhecida.

---

## PRs abertas, todas contra `develop`

Ordem sugerida de merge. São independentes entre si, mas #70 é a mais urgente
pelo motivo do topo.

| PR | Branch | Conteúdo | Toca |
|---|---|---|---|
| **#70** | `fix/acesso-viewer-empresa-id` | Campo Empresa no convite de Viewer + badge + Edge Function | HTML + `.ts` |
| #71 | `fix/hardening-escrita-admin` | `migration_admin_write_hardening.sql` | só `.sql` |
| #72 | `fix/webhook-billing-fail-open` | webhook fail-closed, replay, constant-time | só `.ts` |
| #73 | `fix/acesso-hardening-rls` | `migration_acesso_hardening.sql` | só `.sql` |
| #74 | `fix/rbac-frontend-role` | `goScreen` com `_roleAtual()`, `irParaNovaEmpresa()`, simetria + **relatório da auditoria** | HTML + nota |
| #75 | `fix/backlog-auditoria-acessos` | `migration_revoke_anon.sql`, GRANT em `tenant_modulos`, `_limparEstadoTenant()` | HTML + `.sql` |

**#70, #74 e #75 tocam `psicomap-admin.html`.** Como é um arquivo único de ~950KB
e há outra sessão trabalhando nele em paralelo, espere conflito se mergear fora
de ordem. Mergear uma de cada vez e conferir o diff resultante.

`develop` está **13 commits à frente de `main`** — e nem todos são desta
auditoria. Antes de promover, rodar
`git log origin/main..origin/develop --oneline` e validar **cada** commit do
intervalo, não só os meus (regra do CLAUDE.md).

---

## Depois do merge

1. **Promover `develop` → `main`** para o painel corrigido chegar em produção.
   Só isso destrava o convite de Viewer.
2. **Rodar `/validar-formulario`.** A migration do REVOKE do `anon` e as policies
   de `empresa_setores`/`empresa_funcoes` tocam o caminho do formulário público.
   Validei por SQL (submissão anônima real: 1 resposta + 27 itens, nos dois
   bancos), mas falta o teste end-to-end pelo HTTP real.
3. **Testar o convite de Viewer ponta a ponta em DEV**: convidar → e-mail →
   definir senha → login → ver os dados da empresa vinculada. Não consegui fazer
   (o harness não permite gerar sessão autenticada).
4. **Alinhar `verify_jwt` do `webhook-billing` em DEV** para `false`.

---

## Backlog que sobrou (10 achados médios)

Todos com a prova no relatório (`2026-09-11-auditoria-gestao-acessos.md`).
Nenhum é exposição ativa.

| # | Achado | Nota |
|---|---|---|
| M2 | `excluirUsuario` e `reenviarConviteUsuario` sem guard de role no client | As Edge Functions **têm** o guard — é defesa em profundidade |
| M3 | `salvarNovoUsuario` sem `return` de negação (guard só no abridor do modal) | idem |
| M4 | Painel Eleva IT sem guard de função (`toggleAtivoEST`, `salvarModulosEST`, `entrarComoEST`) | Mitigado pelas policies de `tenants` |
| M5 | `criar_tenant()` não valida que o caller já tem tenant — um admin pode migrar a si mesmo e abandonar a EST | Consultor/viewer são barrados pelo trigger `tg_guard_perfil_update` |
| M6 | `criar-checkout:52` lê `perfis` com `service_role` em vez do JWT do caller | Hoje inócuo pelo `.eq('id', user.id)`; **revisar antes do billing entrar em uso** |
| M7 | `criar-checkout:94-98` — price IDs de **test mode** hardcoded como fallback | **Revisar antes do billing entrar em uso** |
| M9 | `get_my_empresa_id()` e `fn_guard_perfil_update()` sem `search_path` fixo | Hardening de `SECURITY DEFINER` |
| M11 | `tenant_contadores`: RLS ligada com **zero policies** — inacessível a todos | Feature morta ou quebrada; decidir |
| M12 | `salvar_resposta` com 2 overloads (9 e 10 args) | Risco `PGRST203`; já no CLAUDE.md |
| M13 | `convidar-est` passa `role:'admin'` em metadata, que o trigger ignora | Convidado de EST vira `consultor` sem tenant — **gap funcional real** |

**Sugestão de próximo alvo:** M13 (o convite de EST não funciona como se espera)
e M5, que são bugs de comportamento, não só hardening. M6 e M7 viram prioridade
no momento em que o billing sair do papel.

---

## Armadilhas aprendidas nesta auditoria

Coisas que custaram tempo ou quase viraram erro. Valem para qualquer trabalho
futuro de RLS neste projeto.

**1. Heurística sobre `pg_policy` gera falso positivo.** Montei uma query que
cruzava PERMISSIVE × RESTRICTIVE para mapear a escrita do viewer; ela marcou como
vulneráveis várias tabelas protegidas por `is_tenant_admin()` (que também barra
viewer). Descartei o resultado. **Confirmação tem que ser leitura do catálogo
completo daquela tabela, ou teste com `set_config`.**

**2. `reloptions` de view usa `security_invoker=on`, não `=true`.** Comparar com
`'security_invoker=true'` dá falso negativo e faz parecer que as views são
`SECURITY DEFINER`. Elas não são — herdam RLS corretamente.

**3. `REVOKE` com lista de exceção: pular ≠ corrigir.** Ao revogar o `anon` de
todas as tabelas menos as públicas, *pular* as públicas no loop faz com que elas
**mantenham o ALL original**; o `GRANT SELECT` seguinte vira redundante em vez de
corretivo. O `anon` continuava podendo `INSERT` em `empresas`. **Revogue de
todas e devolva só o que precisa.** Só apareceu porque testei
`has_table_privilege` em vez de confiar no `success: true`.

**4. Ao testar `salvar_resposta`, o payload casa por `questao_id` (uuid), não por
`codigo`.** O `INSERT` final filtra com
`WHERE ... AND (item->>'questao_id') IS NOT NULL` — um payload com `codigo` grava
a resposta com **zero itens e sem erro nenhum**. Reproduzi isso sem querer e
levei um tempo achando que era regressão do meu REVOKE. (É o bug pré-existente já
registrado no CLAUDE.md: ali é filtro, não validação.)

**5. RESTRICTIVE `FOR ALL` quebra o SELECT.** Para restringir só escrita, são
**três policies** (INSERT/UPDATE/DELETE). Uma `FOR ALL` aplica o `USING` também
ao SELECT — em `est_perfil` isso derrubaria o branding do laudo para consultor e
viewer; em `empresa_setores` derrubaria a análise inteira do viewer.

**6. Testar com `dangerouslyDisableSandbox` + `curl` é o único jeito de saber se
um secret de Edge Function está configurado.** O MCP não expõe secrets. Um probe
com tipo de evento inexistente é seguro (nenhum `case` do switch casa, e não há
`default`) e distingue `400` (configurado) de `200` (fail-open).

---

## Como eu validei tudo (para reproduzir)

Sem nunca precisar de sessão HTTP autenticada — o harness não permite gerar uma.

```sql
BEGIN;
SELECT set_config('request.jwt.claims',
  json_build_object('sub','<uuid do perfil>','role','authenticated')::text, true);
SET LOCAL ROLE authenticated;
--  ... as queries que se quer testar ...
ROLLBACK;
```

Para testar o `anon`, `SET LOCAL ROLE anon;` direto. Para criar um usuário-alvo
descartável, inserir em `auth.users` dentro da transação — o trigger
`handle_new_user()` cria o perfil junto, então basta um `UPDATE` para ajustar
`role`/`tenant_id`, e o `ROLLBACK` desfaz tudo.

**DEV já tem um usuário de cada role**, prontos para esse tipo de teste — ver
`.claude/notes/usuarios-teste-dev.md`. E tem **2 tenants**, o que torna DEV o
lugar certo para testar isolamento multi-tenant (PROD tem só 1 EST hoje, o que
mascara vazamento cross-tenant).

Para o frontend, o teste que vale é carregar o app de verdade:
`npx http-server . -p 8765` + Browser pane, e chamar as funções no console. Foi
assim que confirmei que `_limparEstadoSessao()` não tem TDZ — validar só a
sintaxe com `new Function()` **não pegaria** esse caso.
