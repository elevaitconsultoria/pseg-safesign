# Auditoria de Gestão de Acessos — PsicoMap

> Relatório da auditoria de 2026-09-11. A seção "Resultado" no fim registra o que
> foi corrigido, o que foi medido e o que ficou pendente.

## Context

Pedido: avaliar de forma geral a gestão de acessos de usuário e garantir conformidade por nível
de acesso. A auditoria cobriu as quatro camadas onde o controle de acesso vive neste sistema:
RLS/policies no Postgres, funções `SECURITY DEFINER`/RPCs, Edge Functions, e o RBAC do frontend
(`psicomap-admin.html`).

O sistema tem 4 roles (`super_admin`, `admin`, `consultor`, `cliente_viewer`) e é multi-tenant:
cada EST é um `tenant`, e o isolamento entre consultorias concorrentes é a premissa central do
produto. A doutrina documentada no CLAUDE.md é "três camadas" (sidebar → `goScreen` → guard na
função) no frontend, com RLS como fronteira real.

**Conclusão geral:** o desenho está correto e a maior parte das proteções funciona. Os problemas
encontrados são de duas naturezas: (a) **tabelas e funções que nasceram depois das migrations de
hardening e nunca receberam a policy correspondente** — exatamente a classe de gap já registrada
no CLAUDE.md para `respostas`/`resposta_itens` e `empresa_headcount`; e (b) **um endpoint de
billing que falha aberto**. Três achados são exploráveis hoje em PROD.

Escopo aprovado pelo usuário: relatório completo + corrigir severidade **crítica e alta**;
aplicar em **DEV primeiro**, PROD só com aprovação explícita.

---

## Achados

Severidade considera o modelo de ameaça real: quem pode explorar, e o que consegue.
"Confirmado" = reproduzido nesta sessão contra PROD com `set_config('request.jwt.claims', …)` +
`ROLLBACK`, ou por leitura direta do catálogo (`pg_policy`, `pg_proc`).

### CRÍTICO

**C1 — `webhook-billing` aceita qualquer requisição se o secret não estiver configurado**
`supabase/functions/webhook-billing/index.ts:49-54` e `:154-158`

```ts
const secret = Deno.env.get('STRIPE_WEBHOOK_SECRET') || ''
if (secret && !await verifyStripeSignature(body, sig, secret)) { return 400 }
```

Se a env var não existir, `secret` é `''` e **a verificação inteira é pulada**. A function está
deployada em PROD com `verify_jwt: false` (confirmado via `list_edge_functions`), ou seja, é um
endpoint público sem autenticação. Nesse estado, qualquer pessoa na internet posta um
`checkout.session.completed` com `metadata.tenant_id` arbitrário e a function chama
`aplicar_plano_tenant` **com `service_role`** — upgrade de plano gratuito, em qualquer tenant.
O caminho de `customer.subscription.deleted` permite o inverso (downgrade destrutivo, com
`trial_ate: null`).

Secundário, no mesmo arquivo (`:191-207`): `verifyStripeSignature` **não valida o timestamp `t`**
(replay ilimitado de um evento válido) e compara com `expected === sig`, que não é constant-time.

*Não consegui verificar se `STRIPE_WEBHOOK_SECRET` está setado em PROD* — o MCP não expõe secrets
de Edge Function. **Isto é o primeiro passo da execução.** Independente do resultado, o padrão
fail-open é o defeito a corrigir.

**C2 — `super_admin_tenant_details()` não verifica role — vazamento cross-tenant** · *confirmado*

`SECURITY DEFINER`, `SET row_security TO 'off'`, `GRANT EXECUTE` para `authenticated`, e
**nenhuma verificação de quem chama**. Retorna, de todas as ESTs: nome, slug, nº de usuários,
nº de clientes, links ativos, total de respostas e data da última resposta.

A função irmã `super_admin_stats()`, da mesma migration, **tem** o guard:
`IF (SELECT role FROM perfis WHERE id = auth.uid()) <> 'super_admin' THEN RAISE EXCEPTION`.
A `tenant_details` simplesmente não recebeu o mesmo tratamento.

Reproduzido com o JWT de um `consultor` comum: a RPC executou e devolveu a linha da EST. Hoje só
existe **uma** EST em PROD, então o impacto está **latente** — ele se materializa integralmente no
dia em que a segunda consultoria entrar, que é o modelo de negócio do produto. Qualquer usuário
autenticado de qualquer EST (inclusive `cliente_viewer`) lê os números de todas as concorrentes.

**C3 — `cliente_viewer` tem CRUD completo no catálogo GHE** · *confirmado por catálogo*

`empresa_setores` e `empresa_funcoes` têm 4 policies cada. A única PERMISSIVE de escrita é
`auth_manage_empresa_setores` / `auth_manage_empresa_funcoes`, ambas `FOR ALL` com apenas
`tenant_id = get_my_tenant_id()`. A única RESTRICTIVE de viewer (`viewer_empresa_select_*`) cobre
**somente SELECT** (`polcmd = 'r'`).

Um `cliente_viewer` satisfaz `tenant_id = get_my_tenant_id()`, portanto pode **inserir, alterar e
apagar setores e cargos de todas as empresas do tenant** — não só da sua. Pela regra de negócio 3
do CLAUDE.md, GHE é pré-requisito do formulário: apagar o catálogo **derruba a coleta pública de
toda a EST**. É o achado de maior impacto destrutivo imediato.

Estas duas tabelas foram esquecidas pela `migration_viewer_write_hardening.sql`, que cobriu
`links_coleta`, `laudos`, `empresa_headcount` e `ciclos`.

**C4 — `cliente_viewer` pode inserir empresas** · *confirmado por catálogo*

`empresas` tem 8 policies. `auth_insert_empresa` é PERMISSIVE com `WITH CHECK (tenant_id =
get_my_tenant_id())` e **nenhuma RESTRICTIVE cobre INSERT** (`viewer_readonly_empresas` é
`polcmd='w'`, só UPDATE; o DELETE é protegido por `is_tenant_admin()`).

Há inclusive um caminho de UI pronto: o botão do empty-state do Dashboard
(`psicomap-admin.html:14255`) não é ocultado para viewer e usa
`goScreen('empresas'); setTimeout(() => abrirModalClientePerfil(null), 100)` — o `goScreen` é
bloqueado com toast, mas o `setTimeout` abre o modal de cadastro mesmo assim, e
`salvarPerfilCliente` não tem guard. Aparece justamente quando `_empresas` está vazio — o estado
do viewer sem vínculo, o bug que abriu esta sessão.

### ALTO

**A1 — `verificar_limite_tenant(p_tenant_id, …)` aceita qualquer tenant** · *confirmado*
`SECURITY DEFINER`, `GRANT` para `authenticated`, sem guard, e o tenant vem por **parâmetro**.
Com o JWT de um consultor, retornou plano (`enterprise`) e contagens de um tenant informado na
chamada. Vazamento de dado comercial entre ESTs. É chamada legitimamente pelo frontend
(`verificarLimiteTenant`), então a correção é validar o parâmetro, não revogar.

**A2 — `convidar_membro()` permite sequestrar usuário de outra EST**
Exige `is_tenant_admin()`, mas faz `UPDATE perfis SET tenant_id = get_my_tenant_id(), role =
p_role WHERE id = p_user_id` **sem verificar o tenant atual do alvo**. Um admin da EST A que
conheça o UUID de um usuário da EST B o move para a sua EST. Como é `SECURITY DEFINER`, ignora
RLS. **Não é chamada pelo frontend** (verificado: as RPCs usadas são `salvar_resposta`,
`verificar_limite_tenant`, `super_admin_stats`, `super_admin_tenant_details`, `perfis_com_status`,
`criar_tenant`) — é código legado ainda exposto.

**A3 — `reprocessar_fila()` exposta a qualquer autenticado, e quebrada**
`GRANT` para `authenticated`, sem guard de role, opera sobre a fila **global** (todos os tenants).
Além disso chama `salvar_resposta` com **7 argumentos**, e só existem overloads de 9 e 10 — ou
seja, já está quebrada. Também não é chamada pelo frontend.

**A4 — `goScreen()` lê `currentUser.role` cru — camada 2 desliga na janela de boot**
`psicomap-admin.html:17433` → `const role = currentUser?.role;`. Até `loadPerfil()` sobrescrever,
esse campo vale `'authenticated'` (role do JWT), então `restritos['authenticated']` é `undefined`
e **nenhuma tela é bloqueada**. É exatamente o vetor do bug já corrigido nesta sessão no botão de
pacote, só que na camada de navegação. Existe `_roleAtual()` (`:6658`), que normaliza com fallback
seguro, mas é usada em apenas 2 lugares.

O mesmo padrão afeta o scoping de dados do viewer (`:5582`, `:5595`, `:5622`, `:9012`) e a
ocultação dos botões de escrita por linha em `renderLinks` (`:9210`).

**A5 — `aplicarRestricoesPorRole()` é assimétrica para 3 elementos**
`usuarios-new-btn-area` (`:13398`, `:13419`), `links-action-btns` e `dash-hdr-actions` (`:13419`)
são escondidos nos branches de consultor/viewer e **nunca restaurados** por nenhum branch — não
são cobertos pelo `forEach` global de `.nav-item, .sidebar-section`. Mesmo padrão do bug do botão
de pacote: qualquer transição de role na mesma aba (`sairModoSuporte`, `entrarComoEST`) deixa os
botões de escrita permanentemente ocultos para um admin. É bug de usabilidade, não de segurança,
mas é a regra geral já registrada no CLAUDE.md ("guard de visibilidade que só esconde trava a UI
no estado restritivo").

### MÉDIO — backlog documentado, fora do escopo aprovado

| # | Achado |
|---|---|
| M1 | `anon` tem CRUD completo em 23 das 24 tabelas (`ALTER DEFAULT PRIVILEGES` de PROD); só o RLS segura. `empresa_apelidos` é a única fechada. Já no CLAUDE.md; o REVOKE precisa ser validado contra o formulário público, que lê `est_perfil` |
| M2 | `excluirUsuario` (`:14031`) e `reenviarConviteUsuario` (`:14009`) não têm guard de role no client — **mas as Edge Functions correspondentes têm** (`excluir-usuario:37-64`). Defesa em profundidade, não vulnerabilidade |
| M3 | `salvarNovoUsuario` (`:14092`) não tem `return` de negação; o guard vive só em `abrirModalNovoUsuario`. Mesma mitigação de M2 |
| M4 | Painel Eleva IT sem guard de função: `toggleAtivoEST`, `salvarModulosEST`, `entrarComoEST` (que define `currentTenantId` arbitrário). Mitigado por `tenants_super_admin_all` e pelas policies de tenant |
| M5 | `criar_tenant()` não valida que o caller já tem tenant — um admin existente pode migrar a si mesmo para um tenant novo e abandonar a EST. Consultor/viewer são barrados pelo trigger `tg_guard_perfil_update` |
| M6 | `criar-checkout:52` lê `perfis` com `service_role` em vez do JWT do caller — desvio da regra da casa; hoje inócuo pelo `.eq('id', user.id)` |
| M7 | `criar-checkout:94-98` — price IDs de **test mode** hardcoded como fallback |
| M8 | `_limparEstadoSessao()` (`:12590`) não limpa `_headcountPorEmpresa`, `_cicloAtivo`, `_supportMode`, `window._analiseData`, nem `localStorage['psicomap_laudo_resp_*']` (nome e registro profissional do responsável — dado pessoal que sobrevive à troca de conta na mesma aba). `sairModoSuporte()` não a chama, duplicando a lista |
| M9 | `get_my_empresa_id()` e `fn_guard_perfil_update()` sem `search_path` fixo |
| M10 | `tenant_modulos` **não existe em PROD** — o gate de módulos por EST não opera em produção (falha aberto, por design) |
| M11 | `tenant_contadores`: RLS ligada com **zero policies** — inacessível a todos |
| M12 | `salvar_resposta` com 2 overloads (9 e 10 args) — risco `PGRST203`, já no CLAUDE.md |
| M13 | `convidar-est:36-38` passa `role:'admin'` em metadata, que o trigger ignora — convidado vira `consultor` sem tenant |

### Verificado e correto (não são achados)

- **As 5 views têm `security_invoker=on`** — herdam RLS das tabelas base. Cheguei a suspeitar do
  contrário; o `reloptions` cru desmentiu.
- RLS habilitada em **24/24** tabelas.
- `super_admin_stats()` tem o guard de role correto.
- Trigger `tg_guard_perfil_update` ativo e robusto: impede auto-alteração de role, protege o
  último admin do tenant, exige admin para promover/rebaixar admin.
- `convidar-usuario` e `excluir-usuario`: padrão correto (JWT do caller → `perfis` com esse JWT →
  guard), sem escalonamento vertical nem cross-tenant.
- `laudos`, `ciclos`, `links_coleta`, `empresa_headcount`: viewer bloqueado em INSERT/UPDATE/DELETE.
- `questoes`/`questionarios`/`questionario_questoes`: escrita restrita a `is_super_admin()` — o
  `sincronizarQuestoes()` do boot falha por RLS para todos os outros.
- Nenhuma `service_role` key fora das Edge Functions; `psicomap-forms.html:332-333` expõe só a
  **anon key** (payload do JWT confirma `"role":"anon"`).

---

## Correções a implementar

### Etapa 1 — verificar o webhook (antes de tudo)
Determinar se `STRIPE_WEBHOOK_SECRET` existe em PROD (Dashboard → Edge Functions → Secrets; não
alcançável por MCP). Isso define se C1 é exposição **ativa** ou latente, e é a única informação
que falta para priorizar.

### Etapa 2 — `migration_acesso_hardening.sql` (novo arquivo, raiz do repo)

Seguir o padrão de `migration_admin_write_hardening.sql` criado nesta sessão: idempotente,
comentado com o porquê de cada bloco.

1. **C3** — RESTRICTIVE de escrita em `empresa_setores` e `empresa_funcoes`, uma por comando
   (INSERT/UPDATE/DELETE), com `auth_role() <> 'cliente_viewer'`. Mesma forma de
   `viewer_no_insert_laudos`. **Três policies por tabela, nunca uma `FOR ALL`** — `FOR ALL`
   aplicaria o `USING` ao SELECT e quebraria a leitura do catálogo, que o viewer precisa.
2. **C4** — RESTRICTIVE `FOR INSERT` em `empresas` com `auth_role() <> 'cliente_viewer'`.
3. **C2** — `CREATE OR REPLACE FUNCTION super_admin_tenant_details()` adicionando o guard idêntico
   ao de `super_admin_stats()`. Como é `LANGUAGE sql`, converter para `plpgsql` ou embutir a
   checagem numa subconsulta que levante exceção. Preservar a assinatura de retorno exata
   (`RETURNS TABLE(...)`), senão o `.rpc()` do frontend quebra.
4. **A1** — `verificar_limite_tenant`: exigir que `p_tenant_id = get_my_tenant_id()` ou
   `is_super_admin()`, senão `RAISE EXCEPTION`. Não mudar a assinatura (é usada pelo frontend).
5. **A2/A3** — `REVOKE EXECUTE ON FUNCTION convidar_membro(uuid,text), reprocessar_fila() FROM
   authenticated, anon;`. Ambas comprovadamente não usadas pelo frontend. Revogar em vez de
   dropar preserva a possibilidade de reativação.

### Etapa 3 — frontend (`psicomap-admin.html`)

6. **A4** — trocar `currentUser?.role` por `_roleAtual()` em `goScreen():17433` e nos pontos de
   scoping do viewer (`:5582`, `:5595`, `:5622`, `:9012`, `:9210`). `_roleAtual()` (`:6658`) já
   existe e já faz o fallback seguro — é reuso, não código novo.
7. **A5** — no branch de `admin` e no de `super_admin` de `aplicarRestricoesPorRole()`, restaurar
   explicitamente `usuarios-new-btn-area`, `links-action-btns` e `dash-hdr-actions`. Escrever a
   restauração **simétrica**, como `_sincronizarBotaoPacote()` (`:6674`) já faz.
8. **C4 (UI)** — remover o `setTimeout(() => abrirModalClientePerfil(null), 100)` do botão
   `:14255`, ou condicionar o botão inteiro a `_roleAtual() !== 'cliente_viewer'`. O mesmo padrão
   existe em `:1872` e `:3824`, mas esses dois já são ocultados.

### Etapa 4 — `webhook-billing/index.ts`

9. **C1** — inverter o fail-open: se `STRIPE_WEBHOOK_SECRET` estiver ausente, **recusar com 500**
   em vez de processar. Validar o timestamp `t` com janela de tolerância (5 min, padrão Stripe).
   Trocar `expected === sig` por comparação constant-time. Mesmo tratamento no ramo Asaas
   (`:154-158`).

---

## Verificação

Cada item tem prova objetiva. Reusar o método já empregado nesta sessão — `set_config
('request.jwt.claims', json_build_object('sub', <uuid>, 'role','authenticated')) + SET LOCAL ROLE
authenticated`, tudo dentro de `BEGIN … ROLLBACK`, sem sessão HTTP.

1. **Antes de corrigir**, capturar o estado atual de cada achado (o "antes" da tabela) — inclusive
   criando um `cliente_viewer` de teste dentro da transação, já que hoje não existe nenhum em PROD
   (o Phelipe virou `consultor`). O trigger `handle_new_user()` cria o perfil junto com o
   `auth.users`, então basta um `UPDATE` para ajustar role/tenant.
2. **C3/C4**: como viewer, tentar INSERT/UPDATE/DELETE em `empresa_setores`, `empresa_funcoes` e
   `empresas` → esperado **42501** depois da migration. Confirmar que o **SELECT continua
   funcionando** (o viewer precisa ler o catálogo) e que `admin` e `consultor` seguem com escrita.
3. **C2/A1**: chamar as duas RPCs como `consultor` → esperado `RAISE EXCEPTION 'Acesso negado'`;
   como `super_admin` → continua retornando as linhas. Conferir que a assinatura de retorno de
   `super_admin_tenant_details()` não mudou (`pg_get_function_result`).
4. **A2/A3**: `has_function_privilege('authenticated', 'convidar_membro(uuid,text)', 'EXECUTE')`
   deve virar `false`.
5. **A4/A5/C4-UI**: validar a sintaxe do JS inline com o script `new Function()` já usado nesta
   sessão; abrir o painel no Browser pane e conferir que o sidebar do admin mostra os botões de
   escrita após entrar e sair do Modo Suporte.
6. **C1**: com o secret configurado, um POST sem header `stripe-signature` deve receber 400. Com
   o secret ausente, deve receber 500 (e não 200). Testar em DEV.
7. **Ao final**: comparar `pg_policy` e `pg_proc` entre DEV e PROD e confirmar que ficaram
   idênticos — o passo que já pegou divergência real duas vezes neste projeto.
8. Rodar `/validar-formulario` — C3 mexe em `empresa_setores`/`empresa_funcoes`, que o formulário
   público lê via `pub_read_*`. Confirmar que a coleta anônima não foi afetada.

## Entrega

Uma PR por natureza, contra `develop`, para poderem ser revisadas e revertidas separadamente:
- **PR A** — migration (C2, C3, C4, A1, A2, A3)
- **PR B** — frontend (A4, A5, C4-UI)
- **PR C** — webhook (C1)

Aplicar em **DEV** e validar; **PROD só após aprovação explícita** — exceto C1, cuja urgência
depende do resultado da Etapa 1 e deve ser reavaliada com o usuário nesse momento.

Os achados MÉDIOS vão para uma nota em `.claude/notes/2026-09-11-auditoria-gestao-acessos.md`,
com a prova de cada um, para não serem redescobertos.


---

## Resultado da execução (2026-09-11)

### C1 — reclassificado ao verificar: o aberto era o Asaas, não o Stripe

A Etapa 1 (probe do gate, com um tipo de evento inexistente) mediu em PROD:

| | resposta | leitura |
|---|---|---|
| `?provider=stripe` | `400 Assinatura inválida` | `STRIPE_WEBHOOK_SECRET` **configurado** — protegido |
| `?provider=asaas` | **`200 ok`** | `ASAAS_WEBHOOK_TOKEN` **ausente** — **fail-open ativo** |

Ou seja, a hipótese do relatório (fail-open) estava certa, mas o ramo exposto era o
**Asaas**, não o Stripe. `handleAsaas` aceitava POST anônimo e, em `PAYMENT_RECEIVED`,
extraía `tenant_id::plano` do próprio payload para chamar `aplicar_plano_tenant` com
`service_role`. Não foi explorado — a prova é o 200 no lugar de 401 mais o caminho no
código.

Fechar não quebra cobrança: `pagamentos` está **vazia** e as 2 `subscriptions` são
`provider = 'manual'`. O fluxo Asaas nunca foi usado.

Corrigido em **PR #72**: fail-closed nos dois provedores, validação de timestamp
(replay) e comparação constant-time. Testado com Deno — assinatura válida e recente
continua sendo aceita, então o Stripe em PROD não quebra.

### C3 — o achado de maior impacto, confirmado com número

Medido em DEV antes da correção: o `cliente_viewer` de teste **apagou 52 setores**
(revertido por `ROLLBACK`), além de inserir setor, função e empresa. Como GHE é
pré-requisito do formulário, isso derruba a coleta pública da EST inteira.

Corrigido em **PR #73**, junto com C4, C2, A1, A2 e A3.

### Correções de rota durante a auditoria

Duas coisas que quase entraram no relatório como achado e **não eram**:

1. **As 5 views**: uma primeira query comparou `reloptions` com `'security_invoker=true'`
   e não casou, sugerindo que fossem `SECURITY DEFINER`. O valor real é
   `security_invoker=on` — elas **herdam RLS corretamente**. Falso positivo evitado por
   ler o `reloptions` cru.
2. **Mapa heurístico de escrita do viewer**: uma query que cruzava PERMISSIVE × RESTRICTIVE
   marcou como vulneráveis várias tabelas protegidas por `is_tenant_admin()` (que também
   barra viewer). O resultado foi descartado e os achados confirmados por leitura direta
   do catálogo de policies, tabela por tabela.

Vale como método: **heurística sobre `pg_policy` gera falso positivo**; a confirmação
tem que ser leitura do catálogo completo daquela tabela, ou teste com `set_config`.

### Divergências DEV↔PROD encontradas

- `reprocessar_fila()` existe em **PROD** e não em DEV — os `REVOKE` da migration
  viraram condicionais (`to_regprocedure`) para o mesmo arquivo rodar nos dois.
- `webhook-billing` está com `verify_jwt: true` em **DEV** e `false` em **PROD**.
  Webhook não envia JWT, então em DEV o gateway barra o provedor antes de a function
  rodar — o ambiente nunca exercitaria esse fluxo de verdade. Não alterado.
- `tenant_modulos` **não existe em PROD** (M10) — o gate de módulos por EST não opera
  em produção.

### Estado das correções

| PR | Escopo | DEV | PROD |
|---|---|---|---|
| [#72](https://github.com/elevaitconsultoria/pseg-safesign/pull/72) | webhook-billing (C1) | aplicado | **pendente** |
| [#73](https://github.com/elevaitconsultoria/pseg-safesign/pull/73) | migration (C2,C3,C4,A1,A2,A3) | aplicado | **pendente** |
| [#74](https://github.com/elevaitconsultoria/pseg-safesign/pull/74) | frontend (A4,A5,C4-UI) | — | **pendente (merge)** |

Os achados **MÉDIOS** da tabela acima seguem abertos e não foram tocados.
