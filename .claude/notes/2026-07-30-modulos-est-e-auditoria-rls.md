# Módulos por EST + Auditoria RLS DEV×PROD + Sincronização develop (2026-07-30)

## Contexto

Pedido original: um jeito de o super_admin ocultar recursos ainda em desenvolvimento
(ex.: Laudo, Adesão) de uma EST específica, sem criar um perfil de usuário novo para isso.
No meio do caminho, o usuário pediu para revisar as URLs de DEV — suspeita de problema
pós-rebrand — e essa revisão descobriu duas falhas de RLS não relacionadas.

---

## 1. Feature: módulos por EST (`tenant_modulos`)

**Decisão de design:** eixo independente do role. Role responde "quem é você"; módulo
responde "o que está ligado para esta EST". Rejeitado deliberadamente: criar um 5º role —
as policies RESTRICTIVE existentes testam literalmente `<> 'cliente_viewer'`, então um role
novo nasceria com escrita liberada em tudo até cada policy ser reescrita.

**Escopo definido com o usuário:** por EST (vale para todos os perfis daquela EST), não por
role dentro da EST.

**Implementação:**
- `migration_tenant_modulos.sql` — tabela `tenant_modulos(tenant_id, modulo, habilitado,
  updated_at, updated_by)`. RLS: SELECT do próprio tenant (+ super_admin), escrita
  **exclusiva** `is_super_admin()`. Ausência de linha = habilitado (nenhum seed necessário).
- **Por que tabela separada e não coluna em `tenants`:** a policy `tenant_update_admin`
  deixa o admin da própria EST fazer UPDATE naquela linha — se os flags morassem lá, o
  cliente religaria os módulos via API, por fora da UI.
- `psicomap-admin.html`: `MODULOS_CATALOGO`, `MODULO_POR_TELA`, `carregarModulosTenant()`,
  `moduloOn()`, `aplicarModulos()` — aplica classe `.modulo-off` (`display:none!important`)
  em `[data-modulo]`. **Ordem crítica:** sempre depois de `aplicarRestricoesPorRole()`, que
  começa resetando `display=''` em todos os `.nav-item`.
- Modal de configuração na tela Gestão de ESTs (botão "Módulos" ao lado de "Entrar como").
- Caso especial: módulo `adesao` não é uma tela — é um guard em `carregarAdesaoGHE()` +
  `data-modulo` espalhado em `#ghe-adesao-row`, colunas da tabela GHE e botão "Ver adesão".
- `carregarModulosTenant()` falha aberto: erro de leitura só loga warn, mantém tudo visível
  (não trava o app se a migration não estiver aplicada).

**Bug real encontrado e corrigido durante validação no navegador:** `abrirModalModulosEST()`
chamava `sbAdmin.from(...)` sem checar se `sbAdmin` existe — lançava
`Cannot read properties of null` se o modal fosse aberto antes do init. Corrigido com o
mesmo guard usado em `carregarESTs()`: `if (!modal || !lista || !sbAdmin) return;`.

**Validação feita:**
- `node --check` no bloco JS inline — sintaxe OK.
- Simulação no navegador (arquivo local, sem Supabase real): módulo desligado esconde
  item de menu + tela + bloco de adesão; módulos ligados continuam visíveis;
  `goScreen()` bloqueia navegação com toast; religar reverte tudo sem reload.
- **Não testado:** fluxo completo com Supabase real (login super_admin, modal, "Entrar
  como EST" de verdade). Fica para o usuário validar em DEV.

**Status das migrations:** aplicada em DEV. **PROD pendente** — só aplicar depois do
usuário validar o fluxo completo em DEV com login real.

---

## 2. Auditoria RLS DEV × PROD — dois gaps reais encontrados

Comparação direta de `pg_policies` nos dois bancos (não só os arquivos do repo) revelou
que a memória do projeto estava desatualizada e havia dois problemas reais:

### 2a. Bypass RLS do super_admin ausente em PROD (🔴 alto impacto)

`migration_painel_eleva.sql` tem duas partes: as RPCs `super_admin_stats()` /
`super_admin_tenant_details()` (SECURITY DEFINER) e 5 policies `*_super_admin_all` em
`empresas`, `ciclos`, `links_coleta`, `empresa_setores`, `empresa_funcoes`. **Só as RPCs
tinham sido aplicadas em PROD.** Consequência: `entrarComoEST()` → `carregarEmpresas()` /
`carregarLinks()` fazem queries diretas (sujeitas a RLS normal, não às RPCs) — a policy
`auth_select_empresas` exige `tenant_id = get_my_tenant_id()`, e o super_admin tem
`perfis.tenant_id = NULL` em PROD. A comparação nunca casa → **0 linhas, sem erro**. Ou
seja, "Entrar como EST" provavelmente mostrava tudo vazio em produção.

**Fix:** as 5 policies aplicadas em PROD via MCP nesta sessão. Confirmado idêntico a DEV.

### 2b. Drift não documentado em `questoes`/`questionarios`/`questionario_questoes` (🟡 médio)

PROD tinha `super_admin_write_*` (`USING (is_super_admin())`); DEV ainda tinha as policies
originais `admin_all_*` de `psicomap-admin-rls-policies.sql` com `USING (true)` — qualquer
usuário `authenticated` de qualquer tenant podia escrever no catálogo global de questões
(não é tenant-scoped). **A correção em PROD nunca foi versionada** — grep no repo não
encontra `super_admin_write_questoes` em nenhum arquivo.

**Fix:** criado `migration_questoes_write_super_admin.sql`, aplicado em DEV e PROD (em PROD
foi idempotente, já estava assim). Verificado antes de aplicar que `sincronizarQuestoes()`
(chamada no boot de todo usuário) só faz upsert quando a tabela `questoes` está vazia — as
27 questões oficiais já existiam nos dois bancos, então restringir a escrita não quebra
login de admin/consultor.

### 2c. Gaps de baixa prioridade (não corrigidos — DEV atrás de PROD, sentido oposto)

Não afetam produção, só podem gerar falso-negativo ao testar em DEV:
- `respostas`: falta `auth_insert_respostas` em DEV
- `respostas_fila`: falta `respostas_fila_select_super_admin` em DEV
- `planos_config`: faltam `planos_config_select_authenticated` e
  `planos_config_write_super_admin` em DEV

Advisor de segurança do Supabase rodado após as duas correções em PROD — nenhum alerta
novo, todos os itens do relatório são pré-existentes de outras áreas.

---

## 3. `develop` estava 31 commits atrás de `main` — sem o rebrand

Pedido do usuário para revisar URLs de DEV. Ao abrir `https://develop.pseg-safesign.pages.dev/`
no navegador: título da aba "PSEG — Admin" (não "PsicoMap — Admin"), e `/` redirecionava
para `/pseg-admin-questionario` (path antigo pré-rebrand).

**Causa:** `git log origin/develop..origin/main` = 31 commits (incluía o commit do rebrand
`ab7f6b9` e tudo depois); `git log origin/main..origin/develop` = 0 commits. `develop` era
um subconjunto estrito de `main`, nunca atualizado desde antes do rebrand.

**Fix:** `git push origin origin/main:develop` — fast-forward limpo, sem merge, sem risco de
conflito (develop não tinha nenhum commit próprio). Deploy DEV do Cloudflare Pages rebuilda
automaticamente a partir do push.

**Lição:** ao fazer rebrand ou qualquer mudança que só é testável em DEV, checar se
`develop` está sincronizado com `main` antes de assumir que "já testei isso". O
`build.js` documenta a convenção (`branch develop = dev, branch main = prod`) mas não
existe nenhum mecanismo automático que mantenha os branches alinhados — isso é manual.

---

## Commit e PR

Commit `04ebef3` no branch `docs/licoes-rebrand` (nome não reflete mais o conteúdo — a PR
virou a de módulos por EST, branch não foi renomeado). PR #40 aberta para `main`, com o
status das 3 migrations e o test plan para o usuário validar em DEV antes do merge.

## Checklist para a próxima sessão

- [ ] Usuário testa fluxo completo de módulos em DEV com login real de super_admin
- [ ] Após validar, aplicar `migration_tenant_modulos.sql` em PROD
- [ ] Revisar/aprovar PR #40
- [ ] (opcional, baixa prioridade) fechar os 3 gaps DEV-atrás-de-PROD listados em 2c
- [ ] Verificar periodicamente se `develop`/`main` voltaram a divergir — não há automação
