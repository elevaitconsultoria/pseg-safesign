# Redesign do painel admin — Rodada 1 em produção, auditoria e plano da Rodada 2 (2026-09-11)

Disparado por: pedido do usuário para avaliar oportunidades de melhoria de design/UX geral no
`psicomap-admin.html` e "subir esse escopo". Resultou em: 7 commits de redesign (PR
[#65](https://github.com/elevaitconsultoria/pseg-safesign/pull/65), squash-mergeada em
`9ba04fe`), uma auditoria de fluxo/acessibilidade/vocabulário que gerou o plano da Rodada 2
(ainda não implementada), e a sincronização forçada de `develop` com `main` por causa do
squash merge.

## Rodada 1 — o que foi entregue (PR #65, 7 commits)

Arquivo único tocado: `psicomap-admin.html`. Zero linhas de acesso a dados (`.from/.rpc/.insert/
.update/.delete`), zero mudança em `.sql`, `psicomap-forms.html` intocado — confirmado por grep
nos 7 commits antes do merge.

1. **`599e662` — Design tokens + casca neutra.** `:root` de 19 para ~110 variáveis (escala
   neutra `--n0..--n950`, espaçamento `--sp-*`, tipografia `--fs-*`/`--fw-*`, elevação
   `--sh-*`, raio `--r/--rl/--rx/--rpill`, ícones `--ic-*`, camadas `--z-*`, navegação
   `--nav-*`, risco `--risk-*`). Sidebar do gradiente azul para grafite sólido com acento
   verde; login migrado de DM Sans/Playfair para Inter.
2. **`37e45ed` — Componentes unificados.** 5 famílias de botão, 2 KPI cards, 3 modais, 2
   estilos de tabela e 10 sistemas de badge convergem para bases únicas, por **agrupamento de
   seletor** (sem trocar classe no markup — ex: `.btn,.dl-btn,.fp-toggle-btn{...}`). Criou
   `.btn-primary` (verde) que nunca foi usada — ver bugs abaixo.
3. **`b0c2744` — Estados de sistema.** `_skeleton`, `_loadingState`, `_emptyState`,
   `_errorState` com casca comum (`.state-box`). Corrigiu `goScreen` que engolia erro de
   render em `console.warn` silencioso.
4. **`601dfe7` — Tela morta + busca unificada.** Removeu `sc-backlog` (156 linhas mortas) e 3
   referências órfãs. Unificou o campo de busca (`.input-busca`) nas 4 telas que repetiam o
   mesmo bloco inline.
5. **`e505797` — Tela GHE.** Era a única 100% inline (`padding:0` no `style`), forçando
   `!important` nos media queries. Migrada para classes reais.
6. **`0015e82` — Tela Links.** De 27 estilos inline para 0.
7. **`ed2fa0e` — Contexto único + filtros auto-apply.** `SELECTS_EMPRESA`/`SELECTS_CICLO` como
   fonte única de sincronização (antes `setEmpresaAtiva` e `goScreen` sincronizavam conjuntos
   diferentes). Todo combo de filtro passou a aplicar sozinho com debounce de 180ms, via mapa
   declarativo `COMBO_RENDER`.

**Bugs reais corrigidos no caminho** (nenhum foi procurado, apareceram ao mexer em código
adjacente): `toast(msg,'r')` nunca teve cor (erro saía com cor de aviso neutro);
`setComboNivel` não re-renderizava; `--bg2` usado mas nunca definido; `.btn-amber` era a única
variante sem `:hover`; `_nudgeEmpresa` era o único call site de `goScreen` sem passar `btn`.

## Bugs introduzidos pela própria Rodada 1 (achados numa auditoria própria, antes do merge)

Fiz uma auditoria do meu próprio trabalho a pedido do usuário ("veja se n tem nenhum bug no
que vc fez"). Achados, nenhum deles quebra dados:

1. **`--g-ring` (anel de foco) com contraste ~1,3:1** contra o mínimo de 3:1 — criado na Fase 3
   especificamente para dar foco visível, e não cumpre a função. Medido no browser compondo o
   alpha sobre branco e calculando WCAG (não estimado). Prioridade de correção na Rodada 2 (F3).
2. **Regressão visual no modal "Módulos habilitados"**: `_loadingState()` (163px, borda
   tracejada) substituiu um `"Carregando…"` de uma linha dentro de uma lista compacta de
   checkboxes. Não quebra, mas causa salto de layout.
3. **`.btn-primary` nasceu morta** — 0 usos no markup contra 39 de `.btn-g` (cinza escuro, que
   é o botão primário de fato em produção).
4. **`applyCombo()` ficou órfã** depois que os 9 botões "Aplicar" foram removidos na Fase 6 — o
   comentário no código dizia "o dropdown ainda fecha por aqui", o que estava errado: quem
   fecha é um listener de click-outside (`composedPath`).

Todos os 4 confirmados por evidência direta (medição de contraste real, screenshot, grep de
usos), não suposição.

## Bugs pré-existentes, achados na mesma auditoria (não causados pelo redesign)

**Confirmado por comparação lado a lado**: extraí a versão anterior aos 7 commits
(`git show 75a5e7a:psicomap-admin.html`), servi as duas versões e reproduzi o mesmo
comportamento nas duas — prova de que não é regressão da Rodada 1.

- **Auditoria não popula ciclos na primeira entrada na tela** (só na segunda). Causa:
  `popularSelectsEmpresas()` (`:5248`) não inclui `audit-empresa`, `agrup-empresa`, `ad-empresa`
  nem `ghe-empresa-sel` na lista de ids que sincroniza — a propagação do `goScreen` é um no-op
  silencioso nessas 4 telas, e a função de boot de cada uma roda com empresa vazia.
- **Comparativo e Plano de Ação renderizam sem estilo nenhum.** Usam 5 classes que nunca
  existiram no CSS: `.filter-grp`, `.filter-lbl`, `.filter-sel`, `.btn-prim`, `.btn-sec`. Os
  selects saem como widget nativo do browser, os botões como cinza do sistema operacional.
  Confirmado visualmente em DEV e, depois do merge, em PROD.

## O bug reportado pelo usuário — nunca reproduzido

Usuário reportou: "Seções do laudo nao está funcionando" / "clico, mas o preview não reflete
minha seleção em develop". Investigação:

1. Testei `toggleLaudoSecao`/`buildLaudoSecoesChecks`/`renderLaudo` isolados via console — a
   lógica está correta (Set de seções ativas, toggle funciona, `renderLaudo` lê o Set certo).
2. Confirmei que o deploy DEV estava atualizado (grep de assinaturas da Fase 6 no HTML servido).
3. Rodei o fluxo completo em modo demo no DEV publicado (sem login) — `onLaudoFiltro()` +
   `renderLaudo()` produziram 203KB de HTML, toggle de seção reduziu de 7 para 6 seções
   corretamente, sem erro.
4. **Nunca reproduzi o bug.** Ficou registrado como pendência para o usuário testar logado —
   suspeita de erro assíncrono não tratado em `renderLaudo()` com dados reais (a chamada não
   tem `try/catch` no call site do toggle), mas não confirmado.

Ver `[[feedback-auth-impersonation-blocked]]` — a impossibilidade de logar é o motivo de não
ter fechado esse caso.

## Merge da PR #65 e sincronização forçada de `develop`

Usuário instruiu: "suba tudo em produção, dps ajustaremos mais". PR #65 estava `MERGEABLE`/
`CLEAN`, sem review pendente — merge via `gh pr merge 65 --squash` (mesmo método usado nas PRs
anteriores do repo, confirmado por `gh pr list --state merged` antes de escolher a estratégia).

**Consequência não trivial do squash merge**: `main` ganhou 1 commit novo (`9ba04fe`) que não é
descendente do último commit de `develop` (`ed2fa0e`) — `git merge-base --is-ancestor
origin/develop origin/main` retornou falso. Isso quebra a receita documentada no `CLAUDE.md`
("`git push origin origin/main:develop` fast-forward resolve sem risco"), que assume merges
não-squash. Foi necessário `git push origin origin/main:develop --force`.

Antes do force-push, confirmei que era seguro: nenhum commit exclusivo de `develop` seria
perdido de fato (os 7 commits da Rodada 1 têm o mesmo conteúdo final que o commit squash —
`git diff origin/main origin/develop --stat` vazio depois do push), e não havia trabalho local
não commitado (`git status --short` só mostrava `supabase/.temp/`, não rastreado). Os 7 commits
individuais saem do histórico de `develop` mas continuam acessíveis via o histórico da PR #65 no
GitHub.

**Atualização da receita do `CLAUDE.md`**: a resolução documentada para drift `develop`↔`main`
só vale sem ressalva quando o merge foi feito sem squash. Com squash, o fast-forward simples é
rejeitado pelo git e o force-push é necessário — seguro porque o conteúdo é idêntico, mas é uma
reescrita de histórico da branch `develop` (não de `main`, que tem branch protection).

## Validação em produção sem login — técnica usada e seu limite

Confirmado de novo nesta sessão que **não é possível gerar sessão autenticada** mesmo com
autorização explícita do usuário (ver `[[feedback-auth-impersonation-blocked]]`). A validação
possível, usada tanto antes do merge (DEV) quanto depois (PROD), sempre a mesma receita:

```js
document.querySelector('.login-overlay')?.classList.remove('show');
document.querySelector('.app-shell').style.display='grid';
isDemoMode = true;
currentUser = { id:'t', email:'t@l', role:'super_admin' };
_empresas = [{id:'abc', nome:'Empresa Demo ABC', setores:[...]}];
_ciclos = [...]; gruposSetor = [];
popularSelectsEmpresas();
// loop de goScreen(tela) por todas as 19 telas, capturando window.onerror/unhandledrejection
```

Essa técnica provou, nesta sessão, em PROD: 19/19 telas navegam sem erro; RBAC 7/7 casos
corretos (trocando `currentUser.role` e conferindo se `goScreen` bloqueia); geração de laudo
PDF sem erro (com `window.open` mockado); debounce dos filtros ativo; responsivo mobile intacto.

**Armadilha própria nessa sessão**: ao testar `abrirLaudoJanela()` com `window.open` mockado
incompleto (faltava `document.open` no stub), apareceu um erro de console real —
`win.document.open is not a function`. Quase reportei como bug da aplicação; percebi a tempo
que era falha do meu próprio mock e confirmei refazendo com o stub completo (erro sumiu). Vale
lembrar em validações futuras: **erro de console durante teste sintético não é
automaticamente bug do app** — checar se a causa é o ambiente de teste antes de reportar.

**O que essa técnica não prova, nunca**: RLS ponta a ponta, dados reais de cliente, os fluxos
que dependem de sessão autenticada de verdade, os 13 `confirm()` de ações destrutivas, e —
concretamente nesta sessão — o bug de "Seções do laudo" reportado pelo usuário.

## Estado no fim da sessão

- `main` e `develop` idênticos, ambos em `9ba04fe` (PROD e DEV servindo o mesmo código).
- Plano completo da **Rodada 2** (PR #66 "consertar e terminar o design system" + PR #67
  "fluxo e vocabulário", 12 fases) já escrito em
  `C:\Users\consu\.claude\plans\quero-que-vc-atue-agile-newell.md` — **nada implementado
  ainda**. Cobre os 4 bugs da Rodada 1 listados acima, os 2 bugs pré-existentes, e uma
  auditoria de fluxo/IA (features mortas, ordem do menu, Ciclos sem tela própria, terminologia
  inconsistente).
- Usuário validou visualmente em PROD e autorizou documentar ("parece ok" / "pode documentar").
