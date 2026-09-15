# PsicoMap — Guia para o Agente

## Contexto de negócio

O PsicoMap é uma **plataforma SaaS de avaliação de riscos psicossociais ocupacionais**,
voltada a consultorias de segurança do trabalho que precisam aplicar e analisar questionários
exigidos pela **NR-01, NR-17 e BS 8800** nas empresas clientes.

**Atores principais:**
- **Consultoria (admin)** — cadastra empresas, importa estrutura organizacional (GHE), gera links
  de coleta e analisa resultados.
- **Funcionário (anon)** — acessa o formulário pelo link, responde as 27 questões em escala 1–4,
  envia. Sem login, sem cadastro.
- **Cliente viewer** — acesso read-only futuro (backlog) para a empresa ver seus próprios
  resultados sem intermediação da consultoria.

**Fluxo central:**
```
Consultoria → cadastra empresa + GHE (setores/funções) + ciclo
           → gera link com token único por empresa/ciclo
           → compartilha via WhatsApp / QR Code

Funcionário → abre link no celular → responde → envia (Supabase + localStorage fallback)

Consultoria → vê respostas em tempo real
           → analisa por empresa / setor / função / nível de risco
           → gera laudo PDF e exporta CSV
```

**O que NÃO é o sistema:** não é um RH, não gerencia contratos, não emite certificados. É
exclusivamente um instrumento de coleta e análise de risco psicossocial.

## Regras de negócio críticas

1. **Um link ≠ um funcionário.** O `link_token` é compartilhado com múltiplos funcionários do
   mesmo setor/ciclo. Idempotência é por `session_id` (não por token). Nunca tratar token como
   identificador individual.

2. **Respostas são anônimas.** O sistema coleta setor, função e escolaridade — nunca nome ou CPF.
   Qualquer mudança que associe resposta a identidade pessoal viola a premissa de anonimato e pode
   conflitar com LGPD.

3. **GHE é pré-requisito para o formulário funcionar.** Sem setores/funções cadastrados via GHE,
   o formulário público exibe combos vazios. A importação é feita pelo admin antes de distribuir
   os links.

4. **O catálogo reflete a planilha — não o contrário.** A fonte da verdade do quadro de
   colaboradores é sempre a planilha Excel do cliente. O banco deve espelhar a planilha, nunca
   ser editado manualmente para "tapar" divergências. Usar `/validar-importacao-ghe` antes de
   qualquer entrega.

5. **Ciclos definem o escopo temporal de uma coleta.** Respostas de ciclos diferentes não se
   misturam na análise. Um ciclo representa uma rodada de avaliação (ex: semestral, anual).

6. **Score de risco = P × S (probabilidade × severidade), escala 1–25.** Classificação:
   IRRELEVANTE (1–2) / BAIXO (3–6) / MÉDIO (7–12) / ALTO (13–19) / CRÍTICO (20–25).
   Questões invertidas têm seu valor espelhado antes do cálculo (valor = 5 − valor_original).

7. **Multi-tenant.** Cada empresa pertence a um `tenant` (consultoria). RLS garante que dados
   de uma consultoria nunca vazam para outra. `super_admin` pode ver todos os tenants.

8. **`currentTenantId` é a variável global de contexto de tenant** para todo INSERT e query JS com
   filtro explícito. Para `admin`/`consultor`/`viewer` é o tenant do usuário logado. Para
   `super_admin` em modo suporte (`entrarComoEST`) é o `tenantId` da EST visitada; ao sair
   (`sairModoSuporte`) volta a `null`. **Nunca hardcodar tenant_id em queries — sempre usar
   `currentTenantId`.**

## Arquitetura

- **SPA de arquivo único**: `psicomap-admin.html` (painel admin) e `psicomap-forms.html`
  (formulário público). Toda lógica JS é inline — sem bundler, sem build step nos arquivos.
- **Backend**: Supabase. PROD: `vftyiildukrpgmnbcnao`. DEV: `szqatgvgghxvyyncsjxl`.
- **Deploy**: Cloudflare Pages. `develop` → DEV. `main` → PROD. `main` tem branch protection —
  PRs criados via `gh` CLI (autenticado — conta `elevaitconsultoria`, token no keyring Windows).
  Usar skill `/commitar-e-pr` para o fluxo completo.
- **Build**: `build.js` injeta `SUPA_URL` e `SUPA_ANON_KEY` nos HTMLs antes do deploy no CF Pages.
- **`develop` é branch compartilhada, com mais de um desenvolvedor trabalhando em paralelo.**
  Um commit que você não reconhece em `develop` é o normal, não uma anomalia — e há duas
  consequências que a ferramenta **não** deixa evidentes:

  1. **Todo mundo commita com a mesma identidade git** (`Eleva_admin
     <eleva.it.consultoria@gmail.com>`). `git log --format=%an` não distingue autor nenhum:
     não dá para saber de quem é um commit pela autoria, só pela mensagem e pelo conteúdo.
     Nunca conclua "isto é meu" a partir do autor.
  2. **`psicomap-admin.html` é um único arquivo de ~950KB com todo o JS inline.** Trabalho
     paralelo cai no mesmo arquivo quase sempre. Antes de commitar: `git fetch` e conferir
     `git log HEAD..origin/develop`. **Nunca usar `git add -A` / `git commit -a`** — sempre
     nomear os arquivos e reler o próprio diff (`git show --stat` + o conteúdo), ou você
     varre trabalho não commitado de outra pessoa para dentro do seu commit.

  Duas coisas que afetam terceiros no mesmo instante do push, sem aviso:
  - **`git push origin develop` publica o DEV para todos** (Cloudflare Pages). Se alguém está
    homologando algo em DEV, o ambiente muda por baixo dessa pessoa.
  - **Migration aplicada em DEV/PROD vale para todas as sessões imediatamente**, inclusive as
    de quem está rodando um build antigo. Por isso o padrão de `.select()` tolerante (ver
    "Importação de Agrupamentos GHE por par" adiante).

  **Duas sessões de agente no mesmo diretório não funcionam.** Aconteceu de verdade em
  2026-09-11: entre dois comandos, a branch do checkout mudou por baixo da sessão e um commit
  foi parar na branch de outra pessoa; o `git push origin develop` seguinte respondeu
  "Everything up-to-date" — correto, porque a branch local `develop` não havia mudado — e o
  commit ficou só local. O remédio é **git worktree**: cada sessão com seu próprio diretório e
  checkout, mesmo repositório e mesmo remote.
  - Criar **fora da pasta do repo** (`git worktree add -b <branch> ../<pasta> origin/develop`):
    `.claude/worktrees/` **não** está no `.gitignore` e apareceria como untracked no `git
    status` de quem está na pasta principal.
  - **Numa branch própria, nunca em `develop`** — um branch só pode ter checkout em um worktree
    por vez, e prender `develop` impediria a outra pessoa de trocar para ela.
  - Publicar com `git push origin HEAD:develop` (fast-forward conferido antes com
    `git merge-base --is-ancestor origin/develop HEAD`), sem nunca dar checkout em `develop`.
  - Copiar o `.env` para o worktree (é gitignored) e buildar com `node --env-file=.env build.js`.
  - **Nunca usar `git stash` sem tag**: a pilha de stash é compartilhada entre worktrees, e um
    `pop` pega o que a outra sessão empilhou. Prefira um commit WIP.
  - **Sempre conferir `git branch --show-current` antes de commitar** (não só `git status`) e
    **validar que o push subiu** (`git log origin/<branch>..HEAD`) em vez de confiar na mensagem.

  **Consequência para decisão de release — a mais importante:** "minha mudança é segura" não é
  a mesma afirmação que "`develop` está pronta para promover". `develop` pode carregar trabalho
  de outras pessoas que você não revisou nem testou. Antes de promover `develop` → `main`,
  rodar `git log origin/main..origin/develop --oneline` e confirmar que **cada** commit do
  intervalo foi validado — não só os seus. Validar o próprio delta contra `origin/main` mede o
  seu risco, não o risco do release.

- **`develop` não sincroniza com `main` sozinho.** Não existe automação (CI, branch protection
  com auto-merge) que mantenha os dois alinhados — é manual. Achado real 2026-07-30: `develop`
  ficou 31 commits atrás, sem nenhum commit próprio, e nunca recebeu o rebrand — o deploy DEV
  ficou servindo `pseg-admin-questionario` (path antigo) enquanto PROD já estava em
  `psicomap-admin.html`. Antes de testar algo "em DEV" e concluir que está validado, checar
  `git log origin/develop..origin/main --oneline`; se não-vazio e sem commits exclusivos de
  `develop`, um `git push origin origin/main:develop` (fast-forward) resolve sem risco.

## Divergências DEV ↔ PROD (não ignorar)

| Campo | DEV | PROD |
|-------|-----|------|
| `respostas.session_id` | `text` (qualquer string) | `uuid` (UUID v4 válido) — **CRÍTICO** |
| `respostas.setor` | NOT NULL | nullable |
| `perfis` — função helper | `is_active_consultor()` | `is_tenant_consultor()` |
| Variáveis CF env | podem estar desatualizadas | fonte da verdade |

**Antes de qualquer deploy que toque o pipeline de submissão de respostas: rodar `/validar-formulario`.**

**Não confiar só nos arquivos `.sql` do repo para saber o que está aplicado.** Auditoria real
em 2026-07-30 (comparando `pg_policies` nos dois bancos, não os arquivos) encontrou duas
divergências que nenhum arquivo do repo documentava:
- As 5 policies `*_super_admin_all` de `migration_painel_eleva.sql` (bypass de RLS para
  super_admin em `empresas`, `ciclos`, `links_coleta`, `empresa_setores`, `empresa_funcoes`)
  só tinham sido aplicadas em DEV. Sem elas em PROD, `entrarComoEST()` retornava listas vazias
  para o super_admin — as RPCs `super_admin_stats()`/`super_admin_tenant_details()` (que
  também fazem parte da mesma migration) funcionavam normalmente por serem SECURITY DEFINER,
  mascarando o problema. Corrigido — aplicado em PROD.
- `questoes`/`questionarios`/`questionario_questoes` tinham sido endurecidas em PROD (escrita
  restrita a `is_super_admin()`) **sem nenhuma migration file** — DEV ainda tinha as policies
  originais permissivas (`USING (true)` para qualquer `authenticated`) de
  `psicomap-admin-rls-policies.sql`. Formalizado em `migration_questoes_write_super_admin.sql`,
  aplicado nos dois bancos.

Ao investigar um comportamento estranho de RBAC/RLS, comparar `pg_policies` (e triggers em
`information_schema.triggers`) entre DEV e PROD diretamente via MCP é mais confiável que ler
os arquivos `.sql` — alguém pode ter aplicado algo direto no SQL Editor sem versionar.

**Gap adicional encontrado e corrigido em 2026-08-27**: `respostas` e `resposta_itens` nunca
tiveram policy de bypass para `super_admin` (as 5 de `migration_painel_eleva.sql` cobriam
`empresas`, `ciclos`, `links_coleta`, `empresa_setores`, `empresa_funcoes`, mas não essas duas).
Sintoma: super_admin em Modo Suporte via `entrarComoEST()` com `currentTenantId` correto no
client, mas as telas Auditoria/Análise/Laudo mostravam "nenhuma resposta encontrada" — porque
toda policy de SELECT dessas tabelas compara `tenant_id` contra `perfis.tenant_id` do usuário
logado, e super_admin tem `tenant_id = NULL`, falhando em todas. Corrigido em DEV e PROD com
`respostas_super_admin_all` / `resposta_itens_super_admin_all` (mesmo padrão `FOR ALL TO
authenticated USING/WITH CHECK (is_super_admin())` das outras 5). Validado via
`set_config('request.jwt.claims', ...)` simulando o JWT do super_admin em transação com
ROLLBACK, sem precisar de sessão HTTP real.

**Gap adicional encontrado e corrigido em 2026-08-28**: `empresa_headcount` (tabela criada por
`migration_empresa_headcount.sql`, **depois** de `migration_painel_eleva.sql`) nunca recebeu a
mesma policy de bypass — mesma classe de bug do gap de `respostas`/`resposta_itens` acima, só
que na escrita: super_admin em Modo Suporte reimportando o quadro de funcionários de uma EST
via GHE recebia `"Erro ao salvar GHE: Quadro de funcionários: new row violates row-level
security policy for table \"empresa_headcount\""`, porque `salvarGHE()` insere com
`tenant_id = currentTenantId` (o tenant da EST visitada), mas a única policy de INSERT exigia
`tenant_id = get_my_tenant_id()`, que para super_admin é `NULL`. Corrigido em DEV e PROD com
`empresa_headcount_super_admin_all` (mesmo padrão das outras), formalizado em
`migration_empresa_headcount_super_admin.sql`. Validado com o mesmo método
`set_config`/`ROLLBACK`: super_admin falhava antes do fix, admin/consultor do próprio tenant
nunca foi afetado.

## Copiar dados de uma empresa PROD → DEV (para testar features ainda não deployadas)

Não existe FDW/dblink configurado entre os dois projetos Supabase, e nenhuma credencial de
conexão direta está disponível — a cópia é feita via MCP, gerando SQL pronto no lado PROD
(leitura) e executando esse SQL no lado DEV (escrita). **PROD nunca recebe um `INSERT`/`UPDATE`
nesse fluxo — é estritamente somente leitura.**

Padrão usado (empresa ASSA ABLOY, 2026-08-27, ~3780 linhas de `resposta_itens`):

1. Copiar em ordem de dependência: `empresas` → `empresa_setores`/`empresa_funcoes`/
   `empresa_headcount` → `ciclos` → `links_coleta` → `respostas` → `resposta_itens`.
2. Gerar o `INSERT` como texto no PROD com `string_agg(format('(%L,%L,...)', ...), ',')`,
   já incluindo `WHERE NOT EXISTS (...)` de idempotência — permite reexecutar/reordenar batches
   sem duplicar linhas mesmo se a ordem dos batches mudar no meio do processo.
3. `questoes.id` **diverge entre os bancos** — nunca copiar o UUID direto; sempre fazer o
   `JOIN questoes q ON q.codigo = v.codigo` usando o código da questão (`Q01`..`Q27`) como
   chave estável entre ambientes.
4. UUID em `VALUES (...)` precisa de cast explícito (`::uuid`) quando a coluna de destino é
   `uuid` — senão `ERROR: column "id" is of type uuid but expression is of type text`.
5. A resposta do MCP tem limite de ~56.000 caracteres — para tabelas grandes, paginar com
   `LIMIT`/`OFFSET` em lotes de 800–1000 linhas, sempre com `ORDER BY` estável (ex:
   `resposta_id, codigo`) para não perder nem duplicar linhas entre lotes.
6. Ao final, validar com `SELECT count(*)` comparando DEV vs PROD para a mesma empresa — se não
   bater, comparar por `resposta_id` quantos itens cada uma tem (`GROUP BY ... HAVING count(*) <> 27`)
   para achar a lacuna específica em vez de reprocessar tudo de novo.

## Pipeline GHE (importação de estrutura organizacional)

Três tabelas formam o catálogo de uma empresa:
- `empresa_setores` — setores únicos
- `empresa_funcoes` — cargos únicos, com `setor_id` (FK) ou `NULL` (cargo universal)
- `empresa_headcount` — par `(setor text, funcao text, quantidade int)` — texto desnormalizado, sem FK

**Cargo→setor é mapeamento 1:N** (corrigido 2026-07). Se a validação encontrar pares ausentes com
padrão "mesmo cargo, setor diferente", a importação foi feita antes do fix — reimportar pelo admin.

**`salvarGHE()` tem duas salvaguardas:**
1. Catálogo populado + estrutura nova vazia → `confirm()` (não bloqueia; usuário decide)
2. Nenhum setor + cargos presentes → `confirm()`

**Ao limpar catálogo, `empresa_headcount` também é deletado** (fix 2026-07-22). Sem isso,
headcount fica órfão (mostra "207 func." com 0 setores/0 cargos).

**Dedup de acentuação** (fix 2026-07-23): `_gheNormStrong` (strip de diacríticos via NFD) é
usado como chave de matching durante o import — `"Producao"` e `"Produção"` colapsam para a
mesma entrada. `_ghePrefAcentuado` garante que a forma mais acentuada (grafia correta pt-BR) é
sempre preservada. Ocorre **só no momento do import** — dados já no banco não são reprocessados.
Capitalização não é normalizada — responsabilidade do cliente na planilha.

**Antes de enviar laudo para cliente com base importada: rodar `/validar-importacao-ghe`.**

## Formulário público (`psicomap-forms.html`)

- `carregarGHEEmpresa()` faz fetch do banco a cada load — sem cache local. Reimportar pelo admin
  reflete imediatamente; não é necessário gerar novo link.
- Setores e cargos são ordenados alfabeticamente (pt-BR, `localeCompare`) no carregamento.
  "Outro" sempre inserido por último, fora do sort.
- `link_token` não é único por funcionário — idempotência é por `session_id`.

## Checklist de rebrand (aprendido no rebrand PsicoMap, 2026-07)

Ao renomear arquivos HTML que têm URLs distribuídas publicamente (WhatsApp, QR Code, e-mail):

1. **Nunca deletar** — sempre redirecionar. Adicionar 301 em `_redirects` antes de remover o arquivo.
2. **Cobrir ambas as variantes** — o CF Pages serve `foo.html` também como `/foo`:
   ```
   /pseg-forms.html  →  /psicomap-forms.html  301
   /pseg-forms       →  /psicomap-forms.html  301
   ```
3. **Copiar `_redirects` para `dist/`** — confirmar que está no array `staticFiles` de `build.js`.
4. **Rodar `/validar-formulario`** após deploy para confirmar que o pipeline de submissão está intacto.
5. **Testar um link real** (distribuído antes do rebrand) antes de fechar o ciclo.

**Alternativa mais segura:** mudar apenas o conteúdo dos arquivos HTML sem renomeá-los —
elimina toda a categoria de bugs de link quebrado.

## Skills disponíveis

| Skill | Quando usar |
|-------|-------------|
| `/validar-formulario` | Antes de qualquer deploy que toque submissão de respostas |
| `/validar-importacao-ghe` | Antes de enviar laudo; após reimportar planilha de cliente |
| `/commitar-e-pr` | Sempre que houver mudanças prontas — faz add, commit, push e abre PR documentada |

## Convenções de código

- Funções de salvamento críticas usam pattern **"salvaguarda + confirm"** para ações destrutivas —
  nunca hard-block sem escape hatch para ações intencionais.
- Normalização de texto: `_gheNorm` (trim + espaços + lowercase) para matching simples;
  `_gheNormStrong` (idem + strip de diacríticos via NFD) para dedup com tolerância a acentuação
  — ex: pipeline GHE. Nunca usar para exibição ou persistência.
- Queries Supabase têm limite silencioso de 1000 linhas. Para empresas grandes, verificar
  `COUNT(*)` antes de assumir resultado completo. Use `_fetchAllSupabase()` / `_fetchAllGHE()`
  (helpers de paginação já existentes) em vez de queries simples quando o volume for incerto.
- Não editar `empresa_setores`/`empresa_funcoes`/`empresa_headcount` manualmente via SQL para
  "tapar" GAPs — isso mascara bugs de importação. A ação correta é sempre reimportar.
- Guard obrigatório contra empresa_id nulo antes de qualquer operação de banco:
  `if (!empresaId || empresaId === 'null') return;`
- Ao inserir via Supabase, sempre incluir no `.select()` de retorno TODOS os campos novos que
  serão usados na UI — omitir causa "campo some até recarregar" (bug real 2026-07-21).
- Toggles custom: colocar lógica no `onchange` do `<input>`, nunca no `onclick` do `<label>`
  que o envolve — 1 clique físico gera 2 eventos se a lógica estiver no label (bug real 2026-07-21).

## RBAC — Matriz de acesso por role (2026-07-24)

| Tela | super_admin | admin | consultor | cliente_viewer |
|------|-------------|-------|-----------|----------------|
| dashboard | ✅ | ✅ | ✅ | ✅ |
| empresas (Clientes) | ✅ | ✅ | ✅ | ❌ |
| ghe (Setores/Funções) | ✅ | ✅ | ✅ | ❌ |
| links de coleta | ✅ | ✅ | ✅ | ✅ leitura |
| questionário | ✅ | ✅ | ✅ | ❌ |
| analise / graficos | ✅ | ✅ | ✅ | ✅ |
| comparativo | ✅ | ✅ | ✅ | ❌ |
| auditoria | ✅ | ✅ | ✅ | ❌ |
| laudo (relatório) | ✅ | ✅ | ✅ | ✅ |
| plano de ação | ✅ | ✅ | ❌ | ❌ |
| usuarios (equipe) | ✅ | ✅ | ❌ | ❌ |
| riscos / assinatura | ✅ | ✅ | ❌ | ❌ |
| est-perfil (Perfil EST) | ✅ | ✅ | ❌ | ❌ |
| gestao-ests | ✅ | ❌ | ❌ | ❌ |

**Duas camadas de proteção no frontend:**
1. `aplicarRestricoesPorRole()` — oculta itens do sidebar no boot
2. `goScreen()` — verifica `restritos[role]` em tempo de navegação e bloqueia com toast

**Três camadas para funções críticas** (ex: `salvarEstPerfil`): sidebar + goScreen + guard no início da função.

**super_admin — sidebar dinâmico:**
- Boot normal: mostra apenas Gestão de ESTs + Equipe
- Após `entrarComoEST()`: expande para visão admin (sem gestao-ests)
- Após `sairModoSuporte()`: colapsa de volta

**cliente_viewer — isolamento de dados:**
- JS: `carregarEmpresas()` filtra por `currentUser.empresa_id`
- Banco: policy RESTRICTIVE `viewer_empresa_select_empresas` em `empresas`
- Botões de escrita ocultos: `links-action-btns` e `dash-hdr-actions`

**Policies RESTRICTIVE do viewer no banco** (DEV + PROD, `migration_viewer_write_hardening.sql`):
- INSERT/DELETE bloqueados em: `links_coleta`, `laudos`, `empresa_headcount`, `ciclos`
- SELECT em `empresas` scoped a `get_my_empresa_id()`
- UPDATE em tabelas operacionais (migration anterior `migration_rbac_viewer_hardening.sql`)

## Módulos por EST — feature flags (2026-07-29)

**Eixo independente do role.** Role responde "quem é você"; módulo responde "o que está ligado
para esta EST". Serve para segurar recursos ainda em desenvolvimento diante de um cliente
específico, sem criar mais um role. **Nunca criar role novo para recortar visibilidade** — as
policies RESTRICTIVE existentes testam literalmente `<> 'cliente_viewer'`, então um role novo
nasceria com escrita liberada em tudo.

- Tabela `tenant_modulos (tenant_id, modulo, habilitado, updated_at, updated_by)` —
  `migration_tenant_modulos.sql`. **SELECT** por qualquer usuário do tenant; **escrita só
  `is_super_admin()`**.
- **Não colocar os flags em `tenants`**: a policy `tenant_update_admin` deixa o admin da própria
  EST fazer UPDATE naquela linha — ele religaria os módulos via API.
- **Ausência de linha = habilitado.** Nenhum seed necessário; EST nova e módulo novo nascem
  ligados. Ao salvar pelo modal, grava-se linha para todos os módulos do catálogo (religar é
  UPDATE, não DELETE).
- `MODULOS_CATALOGO` (catálogo do modal) e `MODULO_POR_TELA` (tela→módulo) em
  `psicomap-admin.html`. Acrescentar módulo ao catálogo é seguro.
- Aplicação: `carregarModulosTenant()` preenche `_modulosOff` → `aplicarModulos()` marca
  `[data-modulo]` com a classe `.modulo-off` (`display:none!important`).
  **`aplicarModulos()` roda sempre DEPOIS de `aplicarRestricoesPorRole()`**, que começa
  resetando `display=''` em todos os `.nav-item` — a ordem inversa não gruda.
- Classe, não `style.display`: reversível e não atropela displays inline pré-existentes.
- Conteúdo gerado por template string precisa de `_esconderElementosModulos()` no fim do render
  (já feito em `renderLinks()`, `_renderGHETabela()` e `goScreen()`). Para condicionais dentro de
  template use o helper `moduloOn('id')`.
- **O gate é client-side (cosmético)** — adequado para módulo imaturo, não é fronteira de
  segurança. Bloqueio real exige policy RESTRICTIVE na tabela de dados do módulo.
- `carregarModulosTenant()` **falha aberto**: erro de leitura loga warn e mantém tudo visível,
  em vez de esconder o app inteiro se a migration não estiver aplicada.
- Módulo `adesao` não é tela: guard em `carregarAdesaoGHE()` força `_gheAdesaoData = null` (o
  detail pane e a tabela já degradam nesse caminho) + `data-modulo` no `#ghe-adesao-row`, nas
  duas colunas da tabela GHE e no botão "Ver adesão" da tela de Links.

## Cadastro de usuários pelo sistema (2026-07-31)

Convite/exclusão de usuário **sempre** passa por Edge Function com `service_role` — nunca
client-side. `auth.admin.*` (criar/convidar/excluir) só existe no SDK server-side; a
`service_role key` fica só no runtime da Edge Function, nunca no client (`sbAdmin` usa
`anon key`). Padrão usado por `convidar-est`, `convidar-usuario` e `excluir-usuario`: a
function recebe o JWT do caller no header `Authorization`, resolve role/tenant do caller
lendo `perfis` com esse JWT (nunca confia em valores enviados no body) e só então usa o
client `service_role` para a operação de Admin API.

- `supabase/functions/convidar-usuario/index.ts` — convida (`auth.admin.inviteUserByEmail`)
  ou reenvia (`{ resend_user_id }`) um membro de equipe. `admin` só convida para o próprio
  tenant (ignora `tenant_id` do body); `super_admin` informa e a function valida que o tenant
  existe. `role` do convidado nunca pode ser `super_admin` (evita escalonamento). Depois do
  convite, corrige `role`/`tenant_id`/`nome` que o trigger `handle_new_user()` grava com
  valores default (`role='consultor'`, `tenant_id=NULL`).
- `supabase/functions/excluir-usuario/index.ts` — `auth.admin.deleteUser`; `perfis.id →
  auth.users(id)` é `ON DELETE CASCADE`, então não precisa apagar as duas tabelas. Nunca
  permite excluir `super_admin` nem a própria conta do caller.
- `perfis_com_status()` (`migration_perfis_status_rpc.sql`) — `SECURITY DEFINER`, mesmo
  padrão de `auth_role()`/`get_my_tenant_id()`/`is_super_admin()`. Existe porque
  `auth.users.last_sign_in_at` não é alcançável pelo client via `select` direto em `perfis`
  (RLS não estende a `auth.users`); a function faz o `JOIN` internamente e filtra por tenant
  do caller dentro da própria function. `carregarUsuarios()` usa essa RPC, não mais `select`
  direto — badge "Convite pendente" quando `last_sign_in_at IS NULL`.
- O loop pós-convite (e-mail → `?type=invite` na URL → `onAuthStateChange('SIGNED_IN')` →
  `showSetPassword()` → `definirSenha()` → `auth.updateUser({password})`) já existia antes
  desta feature (`psicomap-admin.html:9592-9612`, `~11531-11571`) — como o `tenant_id`/`role`
  já são gravados corretos pela Edge Function antes do primeiro login, o usuário nunca passa
  por um estado "logado mas sem tenant".
- Redirect URL do Supabase Auth (Authentication → URL Configuration no Dashboard) é
  configuração de plataforma, não alcançável por código nem MCP — confirmar manualmente que
  os domínios de DEV/PROD estão na allowlist sempre que o link de convite parecer quebrado.
- Ver `.claude/notes/2026-07-31-cadastro-usuarios-sistema.md` para o detalhamento completo
  (incluindo como testar `SECURITY DEFINER` via `set_config('request.jwt.claims', ...)` sem
  precisar de uma sessão HTTP real).

## Segunda metodologia de avaliação — planejamento em andamento (2026-08-03)

O produto hoje aplica **uma única metodologia** de risco psicossocial (BS 8800 / Mulhausen &
Damiano, 27 questões, escala 1–4, P×S com lookup 4×4). Está em planejamento — **nada implementado
ainda** — a adição do **HSE Management Standards Indicator Tool**, via a adaptação brasileira
validada **ICAO-35** (35 itens, 7 dimensões, escala 1–5, direção oposta: alto = melhor condição).
Plano completo, incluindo análise antecipada de um terceiro instrumento candidato (COPSOQ) e de
uma ideia de "combo" de metodologias, em
`.claude/notes/2026-08-03-metodologia-hse-icao35-planejamento.md`.

Pontos que **já valem para qualquer trabalho futuro no pipeline de submissão de respostas**, ainda
antes da implementação, porque foram descobertos auditando o banco de produção nesta investigação:

- **A RPC `salvar_resposta` descarta em silêncio itens com `valor` fora de 1–4** — o `INSERT`
  final tem `WHERE (item->>'valor')::int BETWEEN 1 AND 4`, que é filtro, não validação. Um cliente
  malformado ou uma metodologia com escala diferente perderia itens sem erro nenhum, com HTTP 200
  e "Obrigado!" na tela do funcionário. Isso é um bug pré-existente, independente da segunda
  metodologia — vale corrigir (fazer a validação falhar em voz alta) mesmo que o plano de HSE não
  avance.
- **Existem dois overloads de `salvar_resposta` em PROD** (9 e 10 argumentos; o de 9 é morto) —
  qualquer PR que mexer na assinatura dessa RPC deve usar `CREATE OR REPLACE` sobre a de 10 args,
  nunca criar um terceiro overload (risco de `PGRST203`, ambiguidade que quebra o formulário
  inteiro).
- **`exportarCSV` (`psicomap-admin.html:5498-5510`) está com bug**: lê `r.resposta_itens`, que
  `loadRespostasParaEmpresa` nunca retorna (ela pivota para `r.q`). As colunas de resposta do CSV
  saem sempre vazias. Achado colateral, não relacionado à segunda metodologia.

**Decisões de arquitetura já tomadas caso este plano avance** (não implementadas — só para não
serem redescobertas do zero numa sessão futura): `metodologia` vive no ciclo e é snapshot na
resposta, nunca no link; **nenhum conversor entre metodologias**, nem plotagem no mesmo eixo —
cada uma tem seu próprio motor de cálculo, despachado em poucos pontos, nunca um motor genérico
configurável; catálogo de questões ganha uma coluna `direcao` (alto=bom / alto=ruim) por questão,
não por metodologia inteira, porque a pesquisa de um terceiro instrumento (COPSOQ) revelou que a
direção da escala é uma propriedade por dimensão, não por instrumento.

## Catálogo de Ações Recomendadas (2026-08-24)

`CATALOGO_ACOES` (`psicomap-admin.html`, ~linha 8421) é a fonte única de textos de ação por
`cd_risco`, usada tanto no laudo (`porNivel`: MÉDIO/ALTO/CRÍTICO) quanto na tela Plano de Ação
(`w5h2`: O quê/Por quê/Onde/Quem/Quando/Como/Quanto). Fonte oficial: planilha "Riscos
Psicossociais e Fontes Geradoras" enviada pelo cliente no início do programa — tabela completa
extraída e mapeamento `cd_risco ↔ linha da planilha` em
`.claude/notes/2026-08-24-planilha-riscos-fontes-geradoras.md`.

Antes de 2026-08-24 existiam **dois catálogos separados** (`ACOES_SUGERIDAS` no laudo,
`ACOES_5W2H` no Plano de Ação) que já haviam divergido: `ACOES_5W2H` tinha 3 entradas
(`cd_risco` 6, 7, 9) com texto de outra taxonomia (termos do HSE Management Standards Indicator
Tool — ver "Segunda metodologia" acima — que não correspondem aos fatores reais desses códigos
nesta planilha), 1 entrada órfã (`cd_risco` 2, que não existe em nenhuma questão do
questionário) e nenhuma entrada para `cd_risco` 12. Unificado num catálogo só — **ao editar
texto de ação, editar `CATALOGO_ACOES`, nunca recriar um catálogo paralelo**.

A seção "Ações Recomendadas" do PDF final (`_buildLaudoHTML`) passou a segmentar por setor
(reaproveitando `gruposLaudo`, já usado por "Resultados por setor" no mesmo documento) — antes
só o preview interativo (`renderLaudo`) segmentava; o PDF exportado gerava um bloco único
consolidado apesar do checkbox de seção se chamar "Ações por setor". **Correção 2026-08-28**:
essa mudança original referenciava uma variável `setoresList` que nunca chegou a ser declarada
em `_buildLaudoHTML` — bug real em produção (`"Erro ao gerar laudo: setoresList is not
defined"`), corrigido usando `gruposLaudo` de fato. Ver nota
`.claude/notes/2026-08-28-agrupamentos-outro-normalizado-e-bugs-laudo.md`.

## Modo Suporte (super_admin — `entrarComoEST`)

O super_admin opera normalmente na tela Gestão de ESTs. Para inspecionar/operar no contexto de
uma EST específica, usa o botão "Entrar como":

```
entrarComoEST(tenantId, nome)
  → _supportMode = true
  → _supportTenant = { id, nome }
  → currentTenantId = tenantId      ← INSERTs usam tenant correto
  → carregarEmpresas() com filtro   ← SELECTs filtrados pelo tid
  → aplicarRestricoesPorRole()      ← sidebar expande (visão admin)
  → banner amarelo visível

sairModoSuporte()
  → _supportMode = false
  → _supportTenant = null
  → currentTenantId = null          ← super_admin não tem tenant
  → _empresas = [], _links = []     ← limpa sem carregar cross-tenant
  → aplicarRestricoesPorRole()      ← sidebar colapsa
  → goScreen('gestao-ests')
```

`entrarComoEST` também chama `carregarModulosTenant()` (antes de
`aplicarRestricoesPorRole`) e `sairModoSuporte` limpa `_modulosOff` — sem isso os flags da EST
visitada continuariam valendo fora do modo suporte.

**Por que `currentTenantId = tenantId` é crítico**: todos os INSERTs do sistema usam
`currentTenantId` como `tenant_id`. Sem isso, registros criados em modo suporte teriam
`tenant_id = null` e ficariam órfãos (invisíveis para o admin da EST).

## Gotchas críticos de arquitetura

- **Textos de questões hardcoded em dois lugares**: `QS_OFICIAIS` (admin, ln ~3989) e `BLOCOS`
  (forms, ln ~30). Qualquer atualização de texto **deve ser feita nos dois arquivos** — nunca
  só em um. A tabela `questoes.texto` existe mas não é fonte de verdade do admin.
- **`psicomap-forms.html` tem credenciais PROD hardcoded** (linhas 332–333). O `build.js` substitui
  via regex — se o código ao redor mudar, o regex falha silenciosamente sem erro. O admin usa
  placeholders seguros (`__SUPA_URL__`); o forms não. Cuidado ao reformatar essas linhas.
- **Hard delete sem soft-delete**: `excluirEmpresa()` (ln ~4996) é irreversível com CASCADE.
  Dados apagados não são recuperáveis (caso real: ELEVA IT CONSULTORIA 2026-07-22).
- **`_redirects` e `_headers` devem estar em `dist/`**: o Cloudflare Pages serve a partir de
  `dist/`. Sem copiar esses arquivos no `build.js` (array `staticFiles`), nenhum redirect
  ou header de segurança chega ao deploy. Verificar `staticFiles` em `build.js` sempre que
  adicionar regras de routing.
- **Cloudflare Pretty URLs**: o CF Pages serve `foo.html` também como `/foo` (sem extensão).
  Qualquer redirect de compatibilidade deve cobrir **ambas** as variantes (`/foo.html` e `/foo`).
- **Toda nova tabela Supabase precisa de `GRANT ... TO authenticated`** além de `ENABLE ROW LEVEL SECURITY`.
  Sem o GRANT, o Postgres bloqueia com "permission denied" na camada de privilégio antes de checar RLS —
  as policies ficam invisíveis. Padrão obrigatório após criar a tabela:
  ```sql
  ALTER TABLE nova_tabela ENABLE ROW LEVEL SECURITY;
  GRANT SELECT, INSERT, UPDATE, DELETE ON nova_tabela TO authenticated;
  -- depois as policies...
  ```
  Achado real: `grupos_setor` (2026-08-17) — criada com RLS + policies corretas mas sem GRANT;
  erro "permission denied" ao tentar inserir.
- **Branding nos exports usa `_estPerfil.nome_empresa` — nunca string hardcoded**: `exportarResultadosPrint()`,
  export de Gráficos e toolbar do `_buildLaudoHTML` usam o nome dinâmico da EST. Se ausente, o campo
  some (sem fallback para "Eleva IT" ou outro nome de consultoria). O corpo do laudo usa
  `estPerfil?.nome_empresa || 'PsicoMap'` — fallback para o nome do produto, não da consultoria.

## Acompanhamento de Adesão (2026-08-28)

Tela `#sc-adesao` (`nb-adesao`, entre Agrupamentos GHE e Links), módulo `adesao`, bloqueada
para `cliente_viewer`. Existe porque a adesão só vivia num badge do header da GHE e num painel
colapsado por link — não havia tela de acompanhamento, nenhum export, e nenhuma noção de tempo.

- **`calcRepresentatividade()` continua sendo o único motor de adesão.** A tela, o badge da GHE,
  o painel `verAdesaoLink` e o PDF exportado leem todos dele — nunca recalcular adesão em
  outro lugar (a divergência de números de 2026-08-27 nasceu exatamente assim).
- **Matching migrou de `_gheNorm` para `_gheNormStrong`** (alinhado a `agruparPorGrupos`, 2026-08-28).
  Vale também para os joins de catálogo × quadro × adesão em `_gheLinhasTabela()`,
  `_renderGHESetoresPanel()`, `_renderGHEDetailPane()` e na detecção de linhas órfãs do quadro.
  Consequência: "Produção" e "Producao" passam a ser a mesma linha — `naoClassificadas` só pode
  cair, nunca subir.
- **Campos novos no retorno** (aditivos, consumo antigo não quebra): `faltam` por linha e no
  total, `porDia` (Map `'YYYY-MM-DD'→n`), `ultimaResposta`, `ultimos7`. `respondido_em` era
  carregado e descartado; agora alimenta a curva e o "parado há N dias".
- **Ordenação default é por `faltam`, não por `%`** — quem cobra precisa do número absoluto;
  por percentual um setor de 0/1 (0%) aparece antes de um de 20/100.
- **`_gheCorAdesao()` é a fonte única de cor** (70/30). A miniBar do painel de setor usava 80/50
  e `verAdesaoLink` tinha os ternários duplicados inline — unificados.
- **`_hcCache` / `_getHeadcountCached()`**: cache do quadro por empresa, invalidado em
  `salvarGHE()`, `limparHeadcount()` e ao entrar/sair do Modo Suporte via
  `_invalidarHeadcountCache()`.
- **`exportarAdesaoPrint()`**: relatório imprimível para o RH do cliente (molde de
  `exportarResultadosPrint`). Branding via `_estPerfil.nome_empresa`, curva embutida como
  `canvas.toDataURL()`, tabela ordenada por faltantes e **nota de anonimato obrigatória** — o
  documento sai da consultoria para a empresa e não pode sugerir rastreabilidade individual.
- `_abrirAdesao(empresaId, cicloId)` grava `_adAlvo` e chama `goScreen` — **não** chamar
  `_setupTelaAdesao()` junto: `goScreen` já o dispara no próprio `setTimeout` e as duas cargas
  corriam em paralelo.
- `_adAtualizarTabela()` repinta **só o `<tbody>`** e os indicadores de sort. Trocar o card
  inteiro recriava o input de busca (perda de foco/cursor a cada tecla) e destruía o canvas.

## Dashboard e Clientes — status, adesão e urgência (2026-08-28)

- **`_statusEmpresa(m)` + `_EMP_STATUS` são a fonte única de status de coleta.** Antes o
  Dashboard tinha a lógica inline (4 faixas, limiar `<10` respostas) e `_calcMetricasEmpresa`
  tinha outra (3 faixas, outros rótulos) — a mesma empresa aparecia como "Aguardando respostas"
  na Home e "Aguardando" em Clientes. Estados: `inativa | semLinks | aguardando | parada |
  coletando | completa | finalizada` (ver seção "Finalização de campanha" abaixo).
- **Adesão exibida em Home/Clientes é BRUTA** (`respostas ÷ quadro`, o mesmo "Total geral" já
  definido no sistema) — a *classificada* exige carregar as respostas de cada empresa e continua
  exclusiva da tela de Adesão. A UI diz isso nos tooltips; não trocar um pelo outro.
- **`carregarHeadcountCarteira()`** — uma única query agregada de `empresa_headcount` por
  tenant, popula `_headcountPorEmpresa`. Limpo ao entrar/sair do Modo Suporte.
- **`carregarContagemRespostas()` agora traz `respondido_em`** na mesma query e preenche
  `l.ultimaResposta` por link — "parado há N dias" sem nenhuma consulta adicional.
- **`_urgenciaEmpresa(m)`** ordena a Home: `faltam_até_a_meta * 10 + dias_parado`. O alvo é a
  **meta (`AD_META_PCT` = 70%)**, não 100% — com 100% um cliente a 80% (já "Meta atingida")
  pontuava mais alto que um que nunca recebeu resposta e liderava a lista de cobrança.
- KPI "Empresas ativas" passou a respeitar `emp.ativo`; o card de alerta virou
  "Precisam de cobrança" e filtra a lista ao ser clicado.
- Busca de Clientes cobre nome, CNPJ, **razão social e o código `CLI-xxx`**; a tela ganhou
  filtro por status e ordenação (Nome | Adesão | Respostas), e passou a renderizar **apenas a
  visão ativa** (a grade era montada mesmo em modo lista).
- `carregarEmpresas()` grava `_empresasErro` e a tela mostra estado de erro com "Tentar
  novamente" — antes uma falha de rede era indistinguível de "Nenhum cliente cadastrado".
- Título da tela de links passou a ser **"Coleta & Links"** (era "Clientes & Coleta", ambíguo
  com o menu "Clientes"). Só o rótulo — nenhum id, rota ou arquivo renomeado.

## Finalização de campanha de link de coleta (2026-08-31)

Antes, um link só tinha `ativo`/`inativo` — não dava pra distinguir uma pausa temporária de
uma campanha concluída de verdade. As duas situações caíam na mesma tag cinza "Inativo", e uma
empresa que terminou a coleta com sucesso aparecia igual a uma que nunca recebeu link nenhum
(rótulo "Sem links" no Dashboard/Clientes). PR
[#64](https://github.com/elevaitconsultoria/pseg-safesign/pull/64).

- **Coluna nova, aditiva**: `links_coleta.encerrado_em TIMESTAMPTZ` (`migration_links_encerrado_em.sql`,
  DEV + PROD). **Não é** o gate de aceitação de respostas — `ativo` continua sendo o único campo
  lido por RLS, pela RPC `salvar_resposta` e pelo `psicomap-forms.html`; `encerrado_em` é só
  metadado de UI que anota a *intenção* por trás de um `ativo=false`.
- **3 estados por link**: Ativo (`ativo=true`) / Pausado (`ativo=false, encerrado_em=NULL`,
  badge "Inativo" cinza) / Finalizado (`ativo=false, encerrado_em` preenchido, badge roxo `.tp`).
  **Reativar sempre limpa `encerrado_em`** — não existe "ativo e finalizado" ao mesmo tempo
  (`toggleLink()`, `psicomap-admin.html`).
- **Ação é por link individual, não em lote por empresa/ciclo** — decisão de escopo tomada com
  o usuário: uma empresa pode ter vários links simultâneos (um por setor via "Gerar em lote"),
  e cada um se finaliza separadamente. Botão "🏁 Finalizar campanha" → `finalizarLink(id)`.
- **Desativar um link nunca escondeu respostas já coletadas** de nenhuma análise/laudo/adesão —
  `loadRespostasParaEmpresa()` sempre filtrou só por `is_teste`, nunca por `link.ativo`. Isso
  continua valendo para links finalizados: o dado coletado segue entrando normalmente em tudo.
- **`_EMP_STATUS`/`_statusEmpresa()` ganharam o status `finalizada`** (roxo): empresa sem
  nenhum link ativo, mas com pelo menos um link finalizado (`!linksAtiv && linksEmp.some(l =>
  l.encerrado_em)`) — substitui "Sem links" nesse caso. `_urgenciaEmpresa()` já excluía
  `!linksAtiv` da lista de cobrança, então cobre "finalizada" automaticamente, sem mudança.
  Chip de filtro adicionado em `_renderEmpFiltros()` (array `ordem`).

## Agrupamentos GHE (2026-08-17 → 2026-08-28)

Feature de agrupamentos para análise e laudo, sem alterar a hierarquia de cargos da empresa.
Ver `.claude/notes/2026-08-17-agrupamentos-ghe.md`,
`.claude/notes/2026-08-18-agrupamentos-ghe-v2.md` e
`.claude/notes/2026-08-28-agrupamentos-outro-normalizado-e-bugs-laudo.md` para detalhamento
completo. A nota de 2026-08-28 documenta 3 PRs: normalização de matching (respostas "Outro"
com variação de caixa/acento/espaço passam a cair no mesmo grupo), conexão de Grupos de Função
a filtros reais (antes existiam só como cadastro, sem efeito em nenhuma tela), e dois bugs
reais encontrados em produção logo depois (filtros sem auto-apply, `setoresList` nunca
declarada em `_buildLaudoHTML`).

**Tabela `grupos_setor`** (`migration_grupos_setor.sql` — DEV e PROD):
- `tipo TEXT CHECK (tipo IN ('setor','funcao'))`, `nome TEXT`, `itens TEXT[]`, `empresa_id`, `tenant_id`
- Não usar `empresa_setores.grupo` (apagado na reimportação GHE, e UI de edição removida em 2026-08-17) — essa tabela persiste independente.
- Policy `grupos_setor_write`: somente `admin | consultor | super_admin` (viewer lê, não escreve).

**Tela "Agrupamentos GHE"** (`#sc-agrupamentos`):
- Sidebar: `nb-agrupamentos` entre GHE e Links de Coleta. Restrita a `cliente_viewer` (não aparece).
- Dois painéis: Grupos de Setores | Grupos de Funções. Reutiliza `#modal-grupo` já existente.
- `_setupTelaAgrupamentos()` / `renderTabelaAgrupamentos()` (novas funções).
- **Criar**: `abrirNovoGrupo(tipo)` — modal vazio. **Editar**: `editarGrupo(tipo, id)` — modal pré-populado com nome e itens do grupo (`grupoEditandoId` controla dispatch INSERT vs UPDATE em `salvarGrupo()`).
- **Fonte de itens**: catálogo `_empresas[].hierarquia[]` — grupos configuráveis antes de qualquer resposta existir.

**Toggle de 3 modos na Análise** (`_segMode`):
- `'segregado'` → Por Setor (raw) | `'agrupado'` → Por Agrupamento GHE | `'consolidado'` → Geral
- Botão "Por Agrupamento" desabilitado (opacity 0.4) quando não há grupos cadastrados.
- Hierarquia de toggles: [Por Setor | Por Agrupamento | Geral] → [Por Risco | Por Questão] → [Gráfico | Tabela] (visível só em "Por Risco")
- `renderViewGrafica()`, `renderViewRisco()`, `renderViewQuestao()` tratam o novo modo `'agrupado'`.

**Seletor de granularidade no Laudo** (`#laudo-granularidade`):
- Default `'agrupado'` quando há grupos; `'segregado'` quando não há.
- `_buildLaudoHTML()` **e** `renderLaudo()` respeitam a granularidade — gráficos e análise por risco iteram sobre `gruposLaudo`.

**Filtros de Agrupamento GHE e de Função** (Resultados / Gráficos / Relatório, desde 2026-08-28):
- `_populateGheCombo(comboId, fcId, tipo='setor')` — popula combo (`gruposSetor` ou `gruposFuncao`); oculta filter-card quando não há grupos daquele tipo.
- `_grupoValoresFiltro(comboId, tipo='setor')` (renomeado de `_gheSetoresFiltro`) — expande grupos selecionados para Set de chaves **normalizadas** (`_gheNormStrong`, não string exata); retorna `null` quando todos/nenhum selecionado (= sem filtro ativo). Comparar sempre com `.has(_gheNormStrong(r.setor))` / `.has(_gheNormStrong(r.funcao))`, nunca com o valor bruto.
- Combos de setor: `combo-ghe` (Resultados), `combo-gf-ghe` (Gráficos), `combo-ld-ghe` (Relatório).
- Combos de função (novos): `combo-fun-ghe`, `combo-gf-fun-ghe`, `combo-ld-fun-ghe` — mesmas 3 telas.
- **Nenhum desses 6 combos tem botão "Aplicar"** (só "Todos"/"Limpar") — são auto-apply via `COMBOS_AUTO_APPLY` (Set de ids) + `_renderParaCombo(id)`, chamado direto por `toggleComboItem`/`selectAllCombo`/`clearCombo` quando o id está no Set. Ao adicionar um combo novo desse tipo (sem "Aplicar"), lembrar de incluí-lo em `COMBOS_AUTO_APPLY` — esquecer isso foi exatamente o bug real encontrado em 2026-08-28 (seleção não refletia na tela até outro filtro com "Aplicar" ser clicado).
- `gerarLaudoPDF()` (exportação real do PDF) e `renderLaudo()` (preview) devem ler os mesmos filtros — já existiu um gap onde só o preview aplicava o filtro de Agrupamento GHE, corrigido em 2026-08-28.

**`agruparPorGrupos(setores, grupos)`**: matching via `_gheNormStrong` desde 2026-08-28 (antes
era string exata) — variantes "Outro: X" que só diferem em caixa/acento/espaço caem no mesmo
grupo automaticamente, sem precisar que o admin selecione cada variante.

**Backward compatibility**: `agruparPorGrupos(setores, [])` retorna cada setor como seu próprio
grupo — empresa sem grupos cadastrados = comportamento idêntico ao anterior em todas as telas.

**Limitação conhecida e intencional**: reescrever `respostas.setor`/`funcao` (`UPDATE`) para
reclassificar respostas "Outro" já enviadas está **fora de escopo por decisão do usuário** —
a mitigação é sempre cosmética via `grupos_setor`, nunca sobre o dado bruto. Consequência: o
contador "não classificadas" da tela Adesão GHE (compara contra `empresa_headcount`, não contra
`grupos_setor`) continua contando resposta "Outro" como não classificada mesmo depois de
agrupada.

**Bug conhecido (não crítico)**: `renderLaudo()` não filtra `linhas` por `ld-ciclo` — o ciclo
selecionado afeta apenas o nome na capa do PDF, não os dados exibidos. Bug pré-existente.

## Importação de Agrupamentos GHE por par (2026-09-11) — Fase 1

**O problema que motivou.** A configuração de GHE era manual. O catálogo
(`empresa_setores`/`empresa_funcoes`) vem da planilha de colaboradores do cliente; a matriz de
GHE vem do **PGR da empresa** — outro documento, com nomenclatura quase sempre defasada
("Supervisor RH" no catálogo × "Coordenador de RH" no PGR). O consultor refazia o casamento de
cabeça a cada empresa e a cada reimportação.

**Por que os dois eixos existentes não serviam.** `tipo='setor'` e `tipo='funcao'` modelam
UM eixo cada. A matriz do PGR é um conjunto de **pares** (setor, função). Usar os dois eixos
viraria produto cartesiano, e `agruparPorGrupos()` põe cada setor no **primeiro** grupo que
casar — num PGR real "Produção" está no GHE dos operadores E no da supervisão, e um dos dois
seria esvaziado em silêncio, gerando laudo errado sem nenhum erro.

**`grupos_setor` ganhou `tipo='ghe'` + `pares jsonb`** (`migration_grupos_setor_ghe.sql`):
- `pares` = `[{"s": setor, "f": funcao|null}]`, grafia **crua** do catálogo. `f` nulo/vazio =
  **coringa do setor** (linha do PGR sem função).
- `itens` também é preenchido nas linhas `ghe` (setores distintos dos pares) — derivado, para
  que qualquer caminho legado que leia `itens` degrade para grupo de setor, não para grupo vazio.
- `ordem` é sequencial pela planilha: a regra de desempate quando um par cai em dois GHE é
  "o primeiro por `ordem` vence". Tudo em `ordem=0` tornaria o laudo não reproduzível.
- Índice único **parcial** `(empresa_id, lower(nome)) WHERE tipo='ghe'` — global falharia contra
  duplicatas já existentes nos tipos legados.
- RLS e GRANT: zero mudança, as policies não olham `tipo`.

**Tabela nova `empresa_apelidos`** (`migration_empresa_apelidos.sql`) — o de-para aprendido,
**escopo por empresa** (decisão explícita: "Supervisor" em duas empresas pode ser cargo
diferente). `apelido_norm` é **coluna, não expressão**: o banco não tem `unaccent`/`citext`, e
`lower()` sozinho não colapsaria acento — é gravada pelo frontend com o mesmo `_gheNormStrong`
usado na leitura. Texto, não FK, pelo mesmo motivo de `grupos_setor`: `salvarGHE()` apaga e
recria o catálogo a cada reimportação e regenera todos os `id`.

**Estado real (verificado via `pg_constraint`/`pg_policies`, não pelos arquivos): as duas
migrations já estão aplicadas em DEV e PROD** (2026-09-11), com os dois bancos idênticos —
CHECK `('setor','funcao','ghe')`, `pares jsonb NOT NULL DEFAULT '[]'`, índice parcial
`uq_grupos_setor_ghe_nome`, `empresa_apelidos` com RLS + GRANT + as duas policies. Linhas
legadas intactas e nenhuma com `pares <> '[]'`. **Falta só publicar o HTML.**
RLS validada com `set_config('request.jwt.claims',...)` + ROLLBACK: admin e consultor escrevem,
`cliente_viewer` lê e é bloqueado na escrita das duas tabelas, `super_admin` com `tenant_id NULL`
lê e escreve pelo `OR is_super_admin()`, e `anon` não tem GRANT.

**Divergência DEV↔PROD encontrada ao aplicar (nova, vale para QUALQUER tabela futura):** o
schema `public` de **PROD** tem `ALTER DEFAULT PRIVILEGES` concedendo **ALL ao `anon`** em toda
tabela nova; **DEV não tem**. Ou seja, toda tabela criada em PROD nasce com CRUD completo para o
papel anônimo e passa a depender **exclusivamente do RLS** — o `GRANT ... TO authenticated` do
padrão da casa não substitui um `REVOKE`. `empresa_apelidos` nasceu assim e foi fechada com
`REVOKE ALL ... FROM anon` nos dois bancos (verificado via REST: `anon` agora recebe 42501 no
SELECT e no INSERT).

Varredura completa de `grantee='anon'` feita em PROD na mesma sessão — **não há vazamento
ativo**, é lacuna de defesa em profundidade:
- 12 tabelas têm grant do `anon` sem nenhuma policy para `anon` (`grupos_setor`,
  `empresa_headcount`, `perfis`, `respostas_fila`, `resposta_itens`, `laudos`, `tenants`,
  `subscriptions`, `pagamentos`, `planos_config`, `riscos_config`, `tenant_contadores`).
  Todas com RLS ligada, então o `anon` recebe `[]` — mas **só o RLS segura**.
- As 5 views (`v_respostas_admin`, `v_questoes_empresa`, `v_cobertura_questionario`,
  `v_subscription_ativa`, `tenant_usage`) aparecem como "sem RLS" numa varredura ingênua, mas
  **todas têm `security_invoker=on`** e portanto herdam o RLS das tabelas de base. O que o
  `anon` lê em `v_questoes_empresa` (nome de empresa + questões) vem das policies `pub_read_*`
  que o formulário público já precisa — é exposição intencional, não regressão.
- Conclusão: nada a corrigir com urgência; se for endurecer, é `REVOKE ALL ... FROM anon` nas
  12 tabelas acima, o que não deve afetar nenhum fluxo (o formulário só lê `empresas`,
  `empresa_setores`, `empresa_funcoes`, `links_coleta`, `ciclos`, `questoes*`, `est_perfil`).

**⚠️ ORDEM DE DEPLOY.** As duas migrations vão para DEV e PROD **antes** do HTML.
`carregarGruposSetor()` usa lista explícita de colunas; pedir `pares` antes de a coluna existir
devolve 42703 e o catch antigo zerava `gruposSetor` **e** `gruposFuncao` — toda empresa perderia
os agrupamentos em Resultados/Gráficos/Laudo sem erro visível. Existe rede de proteção: o select
tem **retry sem `pares`**, que preserva os tipos legados e só desliga o GHE.

**Assistente de 3 etapas** (`#modal-import-ghe`, botão na tela Agrupamentos):
1. Arquivo (CSV/XLSX, reusa `_parseGHECSV` e o SheetJS já carregado)
2. Conciliação — resolução na ordem **exato → de-para aprendido → sugestão → órfão**. Só os dois
   primeiros são automáticos; sugestão exige confirmação (guard no Avançar). Índice, e não nome,
   nos handlers: nomes vêm de planilha de terceiro e quebrariam `onchange="...('${nome}')"`.
3. Prévia — diff `criar/atualizar/remover`, conflitos de par, órfãos e **cobertura contra as
   respostas**. Nada toca o banco antes do Aplicar.

**`_simNomes`** = maior entre coeficiente de sobreposição de tokens e Dice de bigramas.
Usa **stopwords**, não corte por tamanho: cortar tokens com menos de 3 chars descartava
`RH`/`TI`/`SG`, e "Supervisor RH" × "Coordenador de RH" caía para 0 — exatamente o caso que
motivou a feature. Limiar `GHE_SIM_MINIMA = 0.45`.

**Órfãos** (nome da planilha sem correspondente no catálogo): são **gravados com a grafia da
planilha e marcados como pendência** no painel da tela. Nunca criam setor/cargo — isso
contrariaria a regra 4 ("o catálogo reflete a planilha do cliente, não o contrário") e seria
apagado na reimportação de estrutura seguinte.

**Correções de bugs vivos que vieram junto:**
- `_detectarColuna` casa por `includes` e `'ghe'` estava na lista de candidatos de **setor**:
  uma planilha com header "Agrupamento GHE" tinha essa coluna eleita como setor na importação
  de estrutura, deslocando tudo em silêncio. Agora há `excluir` (Set de headers já reivindicados)
  e `_detectarColAgrupamento`, que é conservador — exige a palavra "agrupamento", então um header
  chamado só "GHE" continua valendo como setor (comportamento histórico preservado).
- `_onAgrupEmpresaChange` atribuía `_empresaAtiva` direto em vez de chamar `setEmpresaAtiva` —
  não persistia em `sessionStorage`, não sincronizava os outros selects nem o chip da topbar.

### Fase 2 — granularidade "Por GHE" no laudo

`#laudo-granularidade` ganhou `ghe` como primeira opção, e ela vira o default quando a empresa
tem GHE importado (`ghe` > `agrupado` > `segregado`; `consolidado` é escolha explícita e nunca é
sobrescrita). A opção fica `hidden` quando não há GHE, e `_granularidadeLaudo()` degrada sozinha
se o modo escolhido ficar sem base (ex.: GHE apagado depois de selecionado).

**`agruparPorPares(linhas, ghes)`** — recebe as LINHAS de resposta, não nomes de setor, porque a
unidade de pertencimento é o par. Três passadas: **par exato → coringa de setor → residual**.
- Cada resposta entra em exatamente um grupo. É o que garante `Σ n(grupo) === linhas.length`;
  sem isso o mesmo respondente contaria duas vezes no laudo.
- Par declarado em dois GHE: o primeiro por `ordem` fica com ele; o conflito volta em
  `conflitos` e vai para o `console.warn`, nunca some.
- Resposta fora de todo GHE vai para grupo **residual por setor** (não por par). Sem isso ela
  sumiria do corpo do laudo continuando contada na capa — o laudo **sub-reportaria risco**.
  `_gruposPorGranularidade` verifica a invariante e grita no console se ela quebrar.

**`_linhasDoGrupo(grupo, linhas)`** é o único lugar que decide membership: grupo com `_chaves`
casa por par; grupo legado continua casando por nome de setor, byte a byte como antes.
Substituiu os 6 `linhas.filter(r => grupo.setores.includes(r.setor))` do laudo e os 3 da tela
Resultados.

### Tela Resultados — `_segMode = 'ghe'` (feito junto, reaproveitando a Fase 2)

Não foi preciso código novo de agrupamento: `#f-segmentacao` ganhou a opção **"Por GHE (setor ×
função)"** e as três views passaram a chamar `_gruposPorGranularidade`/`_linhasDoGrupo`, os mesmos
do laudo — as duas telas não podem divergir sobre o que "Por GHE" significa.

`_segmentosResultado(filtrado, grupos)` substituiu as **três cópias quase idênticas** da lógica de
segmentação que existiam em `renderViewGrafica`, `renderViewRisco` e `renderViewQuestao`.
Acrescentar um modo exigia lembrar de editar as três; agora é um ponto só. O modo `agrupado`
continua consumindo o `grupos` pré-calculado por `rodarAnalise` (`agruparPorGrupos` sobre
`gruposSetor`) — comportamento idêntico ao anterior, verificado lado a lado.

`_atualizarSegSelect` esconde a opção quando a empresa não tem GHE (`optGhe.hidden`) e devolve
`_segMode` para `SEG_PADRAO` se o modo vigente ficar sem base — mesma regra de
`#laudo-granularidade`. `SEG_PADRAO` continua `'consolidado'`: a opção nova não muda o default da
tela. `SEG_LABEL.ghe` cobre de uma vez o filtro, a tag `#an-seg-label` e o subtítulo do PDF
exportado.

**Armadilha real encontrada ao fazer isso:** `renderViewGrafica` e `renderViewRisco` guardavam a
segmentação em locais (`_sgMode`/`_sgModeR`) que continuavam sendo lidos **mais abaixo na mesma
função**, fora do trecho substituído. Remover só o bloco de cima deixou duas referências órfãs que
quebravam as duas views em todos os modos — pegas só porque o teste executou as funções de
verdade, não apenas a sintaxe.

### Filtro "GHE (setor × função)" — isolar um GHE

Segmentar mostra **todos** os GHE de uma vez; filtrar isola **um ou alguns**. São necessidades
diferentes: o consultor entrega ora um documento consolidado, ora um documento por GHE.
Combos novos `combo-ghe-par` (Resultados), `combo-gf-ghe-par` (Gráficos) e `combo-ld-ghe-par`
(Relatório), populados por `_populateGheCombo(..., 'ghe')` e registrados em `COMBO_RENDER`
(auto-apply). O filter-card some quando a empresa não tem GHE importado.

**`_filtroPorGhe(comboId, linhas)` recebe as LINHAS e passa por `agruparPorPares`** em vez de
simplesmente expandir os pares do GHE selecionado. Não é desperdício: um par pode estar
declarado em dois GHE, e um GHE coringa ("qualquer função do setor X") se sobrepõe a pares
exatos de outro. Resolver a precedência aqui de um jeito e na segmentação de outro faria o
filtro "Operacional" trazer um conjunto diferente do bloco "Operacional" — o mesmo GHE com
`n` diferente conforme a tela, sem erro aparente. Reusando `agruparPorPares`, filtro e
segmentação são consistentes por construção (verificado GHE a GHE).

Aplicado nas **quatro** cadeias de filtro, incluindo `gerarLaudoPDF` — o export precisa ler os
mesmos filtros do preview, gap que já existiu antes com o filtro de Agrupamento GHE.

**O que este filtro NÃO resolve** (pedidos reais do usuário, ainda em aberto): não há histórico
de análises geradas — a tabela `laudos` recebe um registro a cada PDF (com `granularidade` e
grupos desde 2026-09-11) mas **nunca é lida por nenhuma tela**; e não há como salvar um recorte
de filtros como preset para reaplicar depois.

### Flexibilidade do importador e exportação de pares

Nota completa da feature (contexto, bugs, decisões e próximos passos):
`.claude/notes/2026-09-11-importacao-ghe-por-par.md`.

**O importador declara o que detectou.** Conciliação e prévia mostram a ligação campo → coluna
do arquivo, e quando a de função não casa o bloco fica vermelho, explica a consequência e lista
as colunas não usadas. Existe porque o bug do plural (abaixo) não foi caro por existir, e sim
por **falhar calado**: foram duas rodadas de importação com planilha de cliente só para
descobrir qual coluna não tinha casado.

**Seletor manual de coluna.** A detecção automática é só o palpite inicial — o usuário troca
qualquer uma na etapa 2 e o arquivo é reprocessado sem reabrir (`_gheiReprocessar`, que guarda
`st.rows` cru). Detecção falha deixou de ser beco sem saída: antes retornava erro e parava.
Nome de coluna é território de planilha de cliente; nenhuma lista de sinônimos cobre todos.

**Multi-valor por célula** (`GHE_SEP_MULTI`: `, ; / |` e " e "). Liga sozinho quando >30% das
células têm separador, mas o checkbox é do usuário. **O cruzamento N×M é validado contra
`hierarquia`** (`empresa_funcoes.setor_id`): ficam só as combinações que existem no cadastro.
Produto cartesiano puro inventaria pares que o PGR nunca declarou — e par inventado **disputa
precedência** com par real de outro GHE, mudando de verdade quem cai onde. Verificado:
"RH, Contas a receber" × 3 cargos → 3 pares certos, não 6. Sem reconhecimento nenhum no
cadastro, mantém o cruzamento completo (melhor palpite, e a prévia mostra antes de gravar).

**`exportarParesGhe()`** — CSV dos pares Setor × Função que têm resposta, com contagem, origem
e o GHE atual de cada um. Inclui os `Outro:` digitados **de propósito**: são os que não estão
no cadastro, somem de qualquer lista montada a partir dele, e são eles que caem no residual do
laudo. Sai no mesmo formato que o importador lê (`;` + BOM, que o Excel pt-BR abre direto e
`_parseGHECSV` detecta sozinho), então resolve três coisas: relatório, **modelo de planilha**
(o sistema não tinha nenhum) e round-trip. Round-trip verificado, inclusive as colunas extras
sendo ignoradas.

**Sugestão de cargo usa o setor declarado na linha.** Cada função carrega o conjunto de setores
(já conciliados) em que a planilha a coloca, e a escolha é por **PARTIÇÃO**: primeiro os
candidatos que existem naquele setor, depois por semelhança dentro de cada grupo
(`_noContexto`/`_ordenarCandidatos`). O limiar continua aplicado à semelhança **textual** —
contexto desempata plausíveis, nunca promove candidato que não se parece com nada.

> **Caso real que motivou, e a lição de engenharia:** o PGR trazia `ANALISTA DE VENDAS Pl`
> (P + **L minúsculo**) e o catálogo tem `ANALISTA DE VENDAS PI` (P + **i maiúsculo**) —
> visualmente idênticos. A similaridade textual apontava `ANALISTA DE VENDAS` (1.00, subconjunto
> exato de tokens) contra `ANALISTA DE VENDAS PI` (0.67); a sugestão errada virou de-para
> aprendido e a resposta real ficou fora de todo GHE. A informação para acertar estava na linha:
> ela diz "Comercial Obras", e só `PI` existe nesse setor.
> **Implementei primeiro como bônus de 0.35 e o caso passou por 1.02 contra 1.00.** Ganhar por
> coincidência entre a constante escolhida e a diferença de similaridade do caso concreto não
> serve para uma decisão que termina num laudo — daí a regra de partição.

**Bug do plural — `função` → `funções`.** A detecção casa por substring depois de normalizar.
`setor`→`setores` e `cargo`→`cargos` funcionam porque o plural só acrescenta "s" e contém o
singular. `função`→`funções` **muda o radical**: normalizado vira `funcoes`, que não contém
`funcao`. Resultado: coluna inteira ignorada, toda função vazia, **todo par virava coringa
"(qualquer função)"** e o GHE cobria o setor inteiro em vez dos cargos do PGR — sem erro na
tela. Plurais com mudança de radical precisam de entrada própria, e vão no **fim** da lista
para que um arquivo com "Cargo" e "Funções" continue elegendo "Cargo".

**Contagem de de-para aprendido na conciliação.** "Aprendido" conta como resolvido e sumia da
contagem de pendências, mas é decisão humana de uma importação passada que **reaplica sozinha e
tem prioridade sobre a sugestão** — um casamento confirmado errado uma vez ficaria invisível
para sempre. Agora aparece "N de importações anteriores (revise se algum estiver errado)".

**Dados de teste em DEV:** empresa Inovadoor Portas Industriais
(`86436ac2-852d-4aee-99b6-a5a87d4292b1`) copiada de PROD, 61 respostas / 1647 itens, seguindo o
procedimento da seção "Copiar dados de uma empresa PROD → DEV". Para remover:
`DELETE FROM empresas WHERE id='86436ac2-...'` em DEV (CASCADE leva o resto).

**`_gruposPorGranularidade(linhas, gran)` é fonte única de preview e export.** Isso corrigiu um
bug vivo: no preview, as seções `analise_risco` e `acoes` usavam `agruparPorGrupos` cru e
**ignoravam a granularidade escolhida**, enquanto `_buildLaudoHTML` a respeitava — preview e PDF
mostravam agrupamentos diferentes nas mesmas seções. O parâmetro `ordenar` existe só para
preservar a ordenação alfabética que a seção "Resultados" do preview já fazia no modo segregado.

**Capa e subtítulos.** `_rotuloGranularidade` troca "Setores avaliados" por **"GHE avaliados"**
(e "Escopo" no consolidado) — chamar nome de GHE de setor numa capa é lido por auditor como
setor. `_setoresCatalogados` ganhou ramo `'ghe'` próprio: lista nomes de GHE e só inclui grupo
residual se o setor estiver no catálogo. `_descricaoGrupo` declara o **par** ("Setor × função:
Produção — Operador; RH — (qualquer função)") em vez de "Setores incluídos" — dizer que um GHE
cobre um setor quando cobre 2 de 9 funções dele é afirmação falsa num documento de NR-01.

`_registrarLaudo` passou a gravar `granularidade` e os nomes dos grupos no `snapshot_json`: sem
isso não há como provar depois sob qual agrupamento um laudo entregue foi gerado.

Verificado com preview e `_buildLaudoHTML` lado a lado nas 4 granularidades (mesmos grupos em
todas), invariante fechando (6 respostas → 6 distribuídas, 1 no residual) e rótulo de capa
mudando conforme o modo.

### Editor de GHE par a par (2026-09-14)

`#modal-ghe-edit` + `abrirNovoGhe()`/`editarGhe(id)`. Fecha a lacuna 1 da nota: antes o GHE só
nascia da importação e só podia ser **excluído** — corrigir um par errado custava reimportar a
matriz inteira, par órfão não tinha resolução nenhuma, e empresa sem matriz de PGR não
conseguia usar a feature.

- **`#modal-grupo` não serve** — ele edita UM eixo (`itens[]`); um GHE é um conjunto de pares.
  `editarGrupo('ghe', id)` agora **desvia** para `editarGhe`: sem o desvio ele caía no ramo de
  `gruposFuncao`, não achava o id e voltava sem fazer nada nem avisar.
- **`_salvarGheUnicoNoBanco` faz insert/update de UMA linha** — não reusa `_salvarGheNoBanco`,
  que apaga todos os `tipo='ghe'` da empresa e regrava. Correto para a importação, destrutivo
  para uma edição. `itens` continua derivado dos setores dos pares (mesmo contrato).
- **Valor fora do catálogo é PRESERVADO no combo** (`_gheeOpcoes`), marcado "⚠ (fora do
  catálogo)". Sumir com ele faria a simples abertura do modal reescrever o dado em silêncio —
  e é justamente o par órfão que se vem consertar.
- **Trocar o setor não apaga a função escolhida.** Ela reaparece sinalizada como fora do
  catálogo, visível, em vez de ser zerada por baixo do usuário.
- **`_gheeSetFuncao` não repinta a lista** (só os avisos): repintar dentro do `onchange`
  destruiria o próprio `<select>` que recebeu o clique. `_gheeSetSetor` repinta porque as
  opções de função mudaram — mesma armadilha já documentada em `_adAtualizarTabela`.
- **Conflito com outro GHE é avisado, nunca bloqueado** — o PGR pode mesmo repetir um par, e
  `agruparPorPares` dá o par ao GHE de menor `ordem`. GHE novo entra com `ordem =
  gruposGhe.length`, no fim da fila: não rouba pares de quem já saiu em laudo.
- Nome duplicado cai no índice único parcial (23505) e vira mensagem legível.
- Guard de `currentTenantId` igual ao da importação (super_admin fora do modo suporte).

### Histórico de laudos e presets de filtro (2026-09-15)

Fecham as lacunas 3 e 4 da nota de 2026-09-11. As duas respondem ao mesmo pedido — "não
refazer o trabalho" — por ângulos diferentes: o histórico reaplica **o que foi gerado**, o
preset guarda **um recorte que se usa sempre**, inclusive em Resultados e Gráficos, que não
geram laudo.

**Histórico (`laudos`).** A tabela recebia um registro a cada PDF desde o schema v3 e **nunca
era lida por tela nenhuma**.
- `snapshot_json` ganhou `config` (granularidade efetiva, seções, ciclo e os 6 combos) e
  `n_respostas`. As chaves antigas continuam sendo gravadas — já existem registros com elas,
  e `renderHistoricoLaudos` lê as duas formas. Registro antigo mostra "sem config" e **não**
  oferece o botão de reaplicar.
- **`ciclo_id` passou a ser gravado.** A coluna existe desde o schema v3 e nunca era
  preenchida: todo laudo ficava sem ciclo.
- `n_respostas` vem de `gerarLaudoPDF`, não do preview — `_registrarLaudo` dispara do botão
  Imprimir **daquela janela**, então é o número do documento que o cliente recebe.
- **Reaplicar não gera o PDF sozinho.** A base de respostas pode ter mudado; o documento
  sairia diferente do entregue mesmo com configuração idêntica.

**Presets (`filtro_presets`, `migration_filtro_presets.sql`).** Tabela nova, escopo por
empresa **e por tela** (`resultados|graficos|laudo`), `config jsonb`.
- **`config` é jsonb e não colunas**: o conjunto de filtros de cada tela muda com frequência
  (três combos novos entraram em 2026-08/09) e uma coluna por filtro exigiria migration a cada
  combo.
- **`PRESET_TELAS` é um descritor por tela**, não três implementações. Acrescentar um combo
  novo já exigiu lembrar de editar vários pontos antes — foi assim que combos ficaram fora de
  `COMBOS_AUTO_APPLY` e a seleção não refletia na tela.
- **`_aplicarConfigFiltros` é fonte única** de restauração, usada pelos presets **e** pelo
  "Reaplicar" do histórico. Duas implementações divergiriam e a diferença apareceria como "o
  preset traz um conjunto e o reaplicar traz outro", sem erro visível.
- **Restaurar só seleciona o que ainda existe, e NOMEIA o que não pôde.** Setor que saiu do
  catálogo, ciclo removido, granularidade/segmentação sem base hoje: cada um vira texto no
  toast. Ciclo inexistente cai para "todos os ciclos" — manter a seleção anterior produziria
  um recorte que ninguém pediu, já que todo o resto da tela acabou de ser sobrescrito.
- `carregarPresets` **falha aberto**: tabela ausente vira lista vazia com `console.warn`, a
  tela segue funcionando. Por isso a migration pode ir antes ou depois do HTML.
- Viewer aplica preset, não cria nem apaga (`_sincronizarBotoesPreset`, guard **simétrico** —
  capaz de mostrar, não só de esconder; o role chega depois do primeiro render).

**⚠ `migration_filtro_presets.sql` NÃO foi aplicada em nenhum banco.** Até aplicar, o card de
preset aparece e o "Salvar" responde "Presets ainda não estão disponíveis neste ambiente".

## Tela Resultados — cascata, pacote de análises e segmentação (2026-09-11)

Cinco commits em `develop` (`944c66b`, `c6cff58`, `9368a0c`, `0260775`, `1b0ce78`), **ainda
não mergeados para `main`**. Detalhamento completo em
`.claude/notes/2026-09-11-resultados-cascata-pacote-analises-segmentacao.md`.

**Filtro de Função em cascata.** `_paresSetorFuncao` guarda os trios `(setor, funcao,
ciclo_id)` que existem em `respostas` — alimentado pela query que `onEmpresaChange()` já
fazia (só ganhou `ciclo_id`), sem query nova. O combo de Função lista **apenas funções com
resposta real** para os setores e o ciclo selecionados. Cargos universais
(`empresa_funcoes.setor_id = NULL`) são tratados **pelo par real da resposta**, nunca
cruzando catálogo — `_gheItensDisponiveis()` monta a lista a partir de `hierarquia[].funcoes`,
onde os universais não aparecem. Normalização idêntica à de `loadRespostasParaEmpresa`
(`'Geral'` / `'—'`) — sem isso o filtro retorna 0 mesmo havendo dados.

**`COMBO_CASCATA`** (novo, ao lado de `COMBO_RENDER`): mapa `id → função`, chamado no topo de
`_renderParaCombo` de forma **síncrona**. Cobre `toggleComboItem`/`selectAllCombo`/`clearCombo`/
`applyCombo` de uma vez. Ao criar um combo que reconfigura outro, registrar aqui — não
espalhar a chamada nas quatro funções. Hoje só `combo-setor` (Resultados); Gráficos e Laudo
não têm cascata.

**Botão "Baixar todas as análises"** (`btn-export-all`, `baixarTodasAnalises()`) — restrito a
`admin`/`super_admin` via `_podeBaixarTodos()`, nas três camadas de sempre (`rodarAnalise` +
`aplicarRestricoesPorRole` + guard na função). Percorre `ANALISES_PACOTE` (Risco/Gráfico,
Risco/Tabela, Questão) e entrega **3 PNGs + 1 PDF único**, uma análise por página. Sequencial
de propósito: as três compartilham `#view-content`. **Um** PDF porque
`exportarResultadosPrint()` abre um popup por chamada. `exportarResultados(fmt, opts)` ganhou
`opts.sufixo`/`opts.silencioso` e `exportarResultadosPrint(secoes)` um parâmetro opcional —
ambos retrocompatíveis. `_capturarViewContentExpandido()` é compartilhado pelos dois caminhos.

**Segmentação virou filtro da sidebar.** O toggle `sgbtn-*` do header **foi removido**;
`<select id="f-segmentacao">` é o único controle de `window._segMode`. `SEG_PADRAO`
(`'consolidado'` = Geral) e `SEG_LABEL` são fontes únicas — `SEG_LABEL` alimenta o filtro, a
tag `#an-seg-label` do resultado e o subtítulo do PDF. A escolha do usuário persiste na
sessão; `SEG_PADRAO` é só ponto de partida e fallback. `_atualizarSegSelect()` habilita/
desabilita "Por Agrupamento" conforme `gruposSetor`/`gruposFuncao` — chamada em
`onEmpresaChange()` (dois ramos) e em `rodarAnalise()`, porque o filtro existe antes de
qualquer análise rodar. `.seg-toggle-group`/`.stg-active` seguem no CSS: usados por outros 4
toggles (Dashboard, Clientes, GHE, Adesão). `#laudo-granularidade` tem regra própria e não
foi tocado.

**Três bugs pré-existentes corrigidos:**
- `exportarCSV()` lia `r.resposta_itens`/`r.id`, que `loadRespostasParaEmpresa()` nunca
  retorna (pivota para `r.q`, renomeia `respondido_em` → `data_registro`) — colunas de questão
  saíam sempre vazias. Coluna `id` virou `session_id` (anônimo).
- O `<script>` do documento de impressão procurava `'#pseg-content > div'` para aplicar
  `.psicomap-setor` (`page-break-inside: avoid`), mas a div é `psicomap-content` desde o
  rebrand — **a classe nunca foi aplicada em nenhum PDF**. Corrigido para
  `'#psicomap-content > div, #psicomap-content > .psicomap-secao > div'`. **Muda a paginação
  de PDFs já homologados** (blocos de setor deixam de ser cortados, em troca de espaço em
  branco no fim da página) — validar visualmente antes de levar para PROD.
- Typo de plural em `updateComboPreview()` (`"2 funçãoões selecionadas"`).

**Bug de produção corrigido no mesmo dia (`btn-export-all` intermitente):**
`_podeBaixarTodos()` lia `currentUser.role` cru, que carrega `'authenticated'` (role do JWT)
até `loadPerfil()` sobrescrever — e o guard em `aplicarRestricoesPorRole()` **só escondia**,
nunca mostrava, então o botão não voltava quando o perfil chegava. Corrigido com
`_roleAtual()` (normalização, agora fonte única — era inline em `aplicarRestricoesPorRole`) e
`_sincronizarBotaoPacote()` (visibilidade **simétrica**, condicionada a
`_podeBaixarTodos() && window._analiseData`, chamada pelas duas funções).
**Regra geral:** nesta SPA, guard de visibilidade por role que só esconde trava a UI no
estado restritivo quando o role chega depois — sempre escrever a função capaz de restaurar.
Ler `currentUser.role` cru para decidir permissão tem a mesma armadilha: usar `_roleAtual()`.

**Ajustes do PDF/imagem (mesma data, pos-producao):**
- `.psicomap-setor` **nao** leva `page-break-inside: avoid` — aplicar no bloco de setor
  inteiro empurrava o bloco para a folha seguinte e deixava paginas quase em branco. A
  granularidade correta e `.psicomap-card` (card de risco), que mantem o `avoid`.
- **`_resumoFiltrosHTML()`** — bloco "Filtros aplicados" (setores + funcoes), fonte unica
  do recorte no cabecalho do PDF **e** da imagem. Antes o PDF so listava setores quando
  havia mais de um (`setores.length > 1`, errando no recorte de um setor so) e a imagem
  nunca listou nada, porque `exportarResultados('png')` captura `#view-content` e as tags
  ficavam no header, fora dela. Deriva dos dados filtrados, nao da selecao do combo, e diz
  "Todos os setores"/"Todas as funcoes" quando o recorte cobre tudo. Usa **estilos inline**
  porque precisa funcionar nos dois destinos (`resolverVars` no doc, `_resolveStyleVars` no
  clone do html2canvas); no PNG e injetado no clone, nunca no `#view-content` real.
- **Cuidado ao editar `exportarResultadosPrint`:** tudo que entra na template string do
  documento vira conteudo do PDF entregue ao cliente — inclusive comentarios de codigo.
