# Tela Resultados — cascata Setor→Função, pacote de análises, segmentação como filtro (2026-09-11)

Sessão de melhorias na tela **Resultados** (`#sc-analise`) de `psicomap-admin.html`.
Pedido inicial do usuário: dois itens (botão de download único restrito a admin +
filtro de Função em cascata). O escopo foi ajustado duas vezes durante a sessão, com
decisões tomadas via perguntas diretas — cada reescopo virou um commit próprio.

**5 commits, todos em `develop`** (ainda não mergeados para `main` no fim da sessão):

| Commit | O quê |
|--------|-------|
| `944c66b` | Cascata Setor→Função + botão "Baixar todos os formatos" + fix do `exportarCSV()` |
| `c6cff58` | Reescopo: "Baixar todas as análises" — 3 PNGs + 1 PDF único, sem CSV |
| `9368a0c` | Segmentação sai do header e vira filtro na sidebar |
| `0260775` | Fix: quebra de página do PDF nunca era aplicada (`#pseg-content`) |
| `1b0ce78` | Segmentação abre em "Geral" por padrão |

Arquivo único afetado em todos: **`psicomap-admin.html`**. Nenhuma migration, nenhuma
mudança de schema, `psicomap-forms.html` intocado.

---

## 1. Cascata Setor → Função (`944c66b`)

### Problema

`onEmpresaChange()` populava `combo-setor` e `combo-funcao` a partir de dois `Set`
independentes derivados da **mesma** query. Selecionar "Produção" não reduzia a lista
de funções: o usuário via todos os cargos da empresa, inclusive os sem nenhuma resposta
naquele setor/ciclo, e ao escolher um caía em "Nenhuma resposta para os filtros
selecionados".

### Solução

Novo estado `_paresSetorFuncao` — os trios `(setor, funcao, ciclo_id)` que **existem em
`respostas`**. Alimentado pela query que `onEmpresaChange()` já fazia; só ganhou
`ciclo_id` no `.select()`. **Zero query nova.**

```js
let _paresSetorFuncao = [];   // pares reais de respostas
let _funcoesFallback  = [];   // catálogo, quando a empresa ainda não tem resposta

function _funcoesDisponiveis() {
  if (!_paresSetorFuncao.length) return _funcoesFallback;
  const cicloId = document.getElementById('f-ciclo')?.value || '';
  const sel     = comboState['combo-setor'];
  const todos   = comboItems['combo-setor']();
  // Set vazio ou completo = "sem filtro de setor" (convenção defensiva de rodarAnalise)
  const semFiltroSetor = sel.size === 0 || sel.size === todos.length;
  ...
}
```

Normalização **idêntica** à de `loadRespostasParaEmpresa` (`r.setor || 'Geral'`,
`r.funcao || '—'`) — sem esse alinhamento o filtro retorna 0 mesmo havendo dados,
armadilha já documentada no comentário original da função.

### Cargos universais (`empresa_funcoes.setor_id = NULL`)

**Decisão: tratar pelo par real da resposta**, não cruzando catálogo. Como
`respostas.setor`/`funcao` guardam o par escolhido pelo funcionário, o cargo universal
aparece exatamente nos setores/ciclos em que de fato respondeu. Isso é o que satisfaz
"só opções com dados reais" — e evita o problema de que `_gheItensDisponiveis()`
(linha ~7122) monta o catálogo de funções a partir de `hierarquia[].funcoes`, onde os
universais **não aparecem** (`carregarEmpresas()` os coloca só em `emp.funcoes` e
`emp.universais`).

### Gatilho — `COMBO_CASCATA`

```js
// Combos que reconfiguram outro combo antes de re-renderizar a tela.
const COMBO_CASCATA = { 'combo-setor': () => _sincronizarComboFuncoes() };

function _renderParaCombo(id, imediato) {
  COMBO_CASCATA[id]?.();   // síncrono: a lista dependente atualiza no mesmo clique
  const fn = COMBO_RENDER[id];
  ...
}
```

Ponto central: cobre `toggleComboItem` / `selectAllCombo` / `clearCombo` / `applyCombo`
**de uma vez**, sem tocar em nenhuma delas. Roda síncrono — o debounce de 180 ms vale só
para o re-render da análise, não para a atualização da lista.

`#f-ciclo` também dispara: `onchange="setCicloAtivo(this.value);_sincronizarComboFuncoes();rodarAnalise()"`.

`_sincronizarComboFuncoes()` preserva a seleção do usuário quando ela sobrevive ao novo
setor; se nenhuma sobreviver, volta a "todas" em vez de deixar um filtro vazio sem
explicação. `rodarAnalise()` **não mudou** — o contrato "Set vazio = todos" segue intacto.

### Fora de escopo, registrado

Cascata só na tela Resultados. Gráficos (`combo-gf-*`) e Laudo (`combo-ld-*`) seguem como
estão; a estrutura `COMBO_CASCATA` já fica pronta para estendê-los.

---

## 2. Pacote de análises (`944c66b` → reescopo em `c6cff58`)

### Versão inicial (`944c66b`) — descartada no mesmo dia

"Baixar todos os formatos": CSV → PNG → PDF da **view atual**. Restrito a admin.

### Versão final (`c6cff58`)

Reescopo pedido pelo usuário depois do deploy em DEV: **sem CSV**, e percorrendo as
**três análises** da tela, não uma.

```js
const ANALISES_PACOTE = [
  { vm: 'risco',   dm: 'grafica', slug: 'risco-grafico', titulo: 'Análise por risco — visão gráfica' },
  { vm: 'risco',   dm: 'tabela',  slug: 'risco-tabela',  titulo: 'Análise por risco — tabela' },
  { vm: 'questao', dm: 'grafica', slug: 'por-questao',   titulo: 'Análise por questão' },
];
```

Saída: **3 PNGs + 1 PDF** com as três seções, uma por página.

**Por que UM PDF e não três:** `exportarResultadosPrint()` abre uma janela de impressão
por chamada. Três chamadas = três popups, bloqueados a partir do segundo. Um documento
único também é o que se entrega ao cliente.

**Por que sequencial e não `Promise.all`:** as três análises compartilham o mesmo
`#view-content`. Cada uma precisa ser renderizada, capturada e só então substituída pela
próxima. Em paralelo sairiam arquivos corrompidos. (O usuário sugeriu `Promise.all` como
opção no pedido original; a razão da escolha está no comentário da função.)

### Reuso — nenhuma geração de arquivo foi reescrita

- `exportarResultados(fmt, opts)` — ganhou `opts.sufixo` (nome do arquivo) e
  `opts.silencioso` (suprime toasts). Ambos opcionais; chamadas antigas intactas.
- `exportarResultadosPrint(secoes)` — parâmetro opcional. Sem ele, comportamento idêntico
  ao de sempre (verificado: gera `<div id="psicomap-content">`, subtítulo "Visão Gráfica",
  sem `.psicomap-secao`).
- `_capturarViewContentExpandido()` — extraído dos passos 1-3 do print e compartilhado.
  **De quebra corrige um detalhe:** restaura só as seções que ele próprio abriu; antes o
  print colapsava também as que o usuário já tinha aberto.
- `_renderAnaliseParaExport(vm, dm)` — mesmo dispatch de `_setSegMode`. O estado da view
  do usuário é restaurado no `finally` via `_setViewMode`, que ressincroniza os botões.

### RBAC — três camadas (padrão do projeto)

`_podeBaixarTodos()` → `admin` **ou** `super_admin` (Modo Suporte opera com visão de admin).

1. Render condicional em `rodarAnalise()`
2. Reavaliação em `aplicarRestricoesPorRole()` — cobre `sairModoSuporte()` sem reload
3. Guard no início de `baixarTodasAnalises()`

O id `btn-export-all` foi **mantido** entre as duas versões porque é o que
`aplicarRestricoesPorRole()` referencia.

---

## 3. Segmentação: toggle do header → filtro na sidebar (`9368a0c`, `1b0ce78`)

Decisão do usuário: **o toggle do header sai**; a segmentação vive só na sidebar.
Motivo declarado no commit: dois controles para o mesmo `window._segMode` divergem na
primeira mudança.

Novo `<select id="f-segmentacao" class="filter-select">` na `.fp-side`, entre "Funções" e
"Nível de risco". Os botões `sgbtn-seg` / `sgbtn-grup` / `sgbtn-cons` foram removidos.

### `SEG_PADRAO` / `SEG_LABEL` — fontes únicas

```js
const SEG_PADRAO = 'consolidado';   // Geral — pedido do usuário (1b0ce78)
const SEG_LABEL  = { segregado: 'Por setor', agrupado: 'Por agrupamento', consolidado: 'Geral' };
```

`SEG_PADRAO` alimenta o default de `rodarAnalise()`, o fallback de
`_atualizarSegSelect()` e os fallbacks de rótulo. `SEG_LABEL` alimenta o filtro, a tag
`#an-seg-label` e o subtítulo do PDF. Trocar o padrão de novo é **uma linha**.

`<option value="consolidado" selected>` no HTML para o select nascer coerente com
`SEG_PADRAO` antes de qualquer JS rodar — sem isso ele mostraria "Por Setor" (primeira
opção) por um instante. A ordem das opções segue a granularidade: Setor → Agrupamento → Geral.

**A escolha do usuário persiste na sessão.** `SEG_PADRAO` é só o ponto de partida e o
fallback — não força Geral a cada análise.

### `_atualizarSegSelect()` — habilitação migrou de lugar

A desabilitação de "Por Agrupamento" sem grupos GHE era **inline no template do
resultado**. Com o controle na sidebar, precisa valer **antes de qualquer análise rodar**,
porque o filtro existe desde que a tela carrega. Chamada em `onEmpresaChange()` (nos dois
ramos) e no início de `rodarAnalise()`.

**Bug corrigido de quebra:** empresa sem grupos herdava `_segMode = 'agrupado'` da empresa
anterior — o botão do header ficava desabilitado, mas o estado continuava e a análise
renderizava agrupada sem grupos. Agora cai para `SEG_PADRAO`.

### Feedback visual preservado

Tirar o toggle do header tirava também a indicação de qual segmentação está ativa. Entrou
a tag `#an-seg-label` na faixa de tags do resultado, mantida por `_setSegMode`. O
subtítulo do PDF também passou a incluir a segmentação ("Visão Gráfica · Por setor") —
informação que faltava no documento entregue ao cliente.

### O que NÃO mudou

- `.seg-toggle-group` / `.stg-active` continuam no CSS: usados por **outros 4 toggles**
  (Dashboard, Clientes, GHE, Adesão).
- `#laudo-granularidade` (tela Relatório) tem regra própria — default `'agrupado'` quando
  há grupos. **Intocado.**

---

## 4. Bugs reais corrigidos no caminho

### `exportarCSV()` — colunas de questão sempre vazias (`944c66b`)

Lia `r.resposta_itens` e `r.id`, que `loadRespostasParaEmpresa()` **nunca retorna** (ela
pivota para `r.q` e renomeia `respondido_em` → `data_registro`). Achado já registrado no
CLAUDE.md em 2026-08-03, corrigido agora porque o pacote de download entregaria um CSV
quebrado. Coluna `id` virou `session_id` (anônimo, UUID de sessão — não fere a premissa
de anonimato).

### Quebra de página do PDF nunca era aplicada (`0260775`)

O `<script>` embutido no documento de impressão procurava `'#pseg-content > div'` para
marcar os blocos de setor com `.psicomap-setor` (`page-break-inside: avoid`), mas a div se
chama `psicomap-content` **desde o rebrand** — o seletor nunca casou. Blocos de setor
vinham sendo cortados no meio da página em todo PDF gerado até hoje.

```js
document.querySelectorAll('#psicomap-content > div, #psicomap-content > .psicomap-secao > div')
```

O segundo seletor cobre o pacote multi-análises, onde os blocos ficam um nível abaixo,
dentro de cada `<section>`. As próprias `<section>` **não** recebem a classe —
`page-break-inside: avoid` numa seção inteira seria pior que nada.

Efeito limitado a quebra de página: o `margin-bottom: 32px` da classe **não** vence os
`margin-bottom` inline (44px/40px) dos blocos, então o espaçamento não muda.
**Consequência a validar com olhos humanos:** um bloco que não cabe no restante da página
agora é empurrado inteiro para a próxima, deixando espaço em branco no fim da anterior.
É o comportamento que a regra sempre quis, mas nenhum PDF validado até hoje tinha. Se
incomodar, dá para afrouxar (aplicar `avoid` só nos `.psicomap-card`).

### Typo de plural em `updateComboPreview()` (`944c66b`)

`${n} função${n!==1?'ões':''}` → `"2 funçãoões selecionadas"`. Pré-existente, mas a
cascata repinta esse contador a cada clique, então saltou à vista.

---

## Como foi validado

**Login real continua bloqueado no harness** (ver `feedback_auth_impersonation_blocked`) —
a mesma limitação das sessões anteriores. Validação feita por:

1. **`node --check`** no JS extraído do HTML, a cada commit (sintaxe).
2. **Teste unitário real em Node** — `_funcoesDisponiveis` / `_sincronizarComboFuncoes`
   **extraídas do arquivo por slicing de texto** (não copiadas) e executadas com stubs:
   9 casos (setor único, múltiplos, nenhum, universal dentro/fora do ciclo, fallback sem
   respostas, preservação e descarte de seleção). Todos passaram.
3. **Teste no DOM real da página** servida por `python -m http.server` — cascata via
   `toggleComboItem` (clique de verdade, passando pelo `COMBO_CASCATA`), contador do
   combo, RBAC nas 4 roles, `_atualizarSegSelect` com/sem grupos.
4. **Orquestrador com stubs** das funções de export: ordem das renderizações, 3 PNGs com
   sufixos distintos, 1 chamada de print com as 3 seções, rótulo progressivo, `is-loading`,
   clique duplo ignorado, estado da view e do botão restaurados.
5. **Documento de impressão parseado com `DOMParser`** para provar que o seletor corrigido
   casa (3 blocos no modo simples, 4 no multi) e que o antigo casava **0 em ambos**.

**Não foi possível tirar screenshot**: o shell do app só monta após login, e remover o
`.login-overlay` não basta. Conferência visual (posição do card de Segmentação, aparência
da tag, paginação do PDF) ficou com o usuário em DEV.

---

## Pendências ao fim da sessão

- **`develop` não foi mergeado para `main`** — os 5 commits estão só em DEV.
- **Validação visual em DEV pelo usuário** — principalmente a paginação do PDF
  (`0260775`), que é a única mudança capaz de alterar um documento já homologado.
- Possível ajuste combinado: se o fallback "empresa sem grupos estando em Por Agrupamento"
  cair em **Geral** incomodar, trocar para `'segregado'` preserva melhor a intenção de
  segmentar. É uma linha em `_atualizarSegSelect()`.
- **Ideia levantada e não implementada:** gerar o PDF via `html2canvas` + jsPDF (como
  `exportGrafPDF()` da tela de Gráficos já faz) em vez da janela de impressão — eliminaria
  o diálogo "Salvar como PDF". É outro caminho de implementação, não um ajuste.

## O que NÃO muda (todos os 5 commits)

- `respostas` / `resposta_itens` / `salvar_resposta` RPC / `psicomap-forms.html` — zero alterações.
- `empresa_setores` / `empresa_funcoes` / `empresa_headcount` / `grupos_setor` — intocados.
- Nenhuma migration; nenhuma policy RLS tocada.
- Telas Gráficos, Relatório, Comparativo, Auditoria, Adesão — sem alteração de comportamento.


---

## 5. Bug de produção pós-merge — botão sumindo de forma intermitente (2026-09-11)

Reportado pelo usuário minutos depois do merge da PR #67: o botão "Baixar todas as
análises" **não aparecia**, e depois "voltou sozinho". Intermitência = race condition.

### Causa

`_podeBaixarTodos()` lia `currentUser.role` **cru**. Esse campo carrega
`'authenticated'` (o role do JWT do Supabase) até `loadPerfil()` sobrescrevê-lo com o
valor de `perfis` — fato que o projeto já conhecia e documentava no comentário de
`aplicarRestricoesPorRole()`, mas que eu não repliquei.

Sequência do bug:

1. Usuário roda a análise enquanto `loadPerfil()` ainda está em voo →
   `currentUser.role === 'authenticated'` → `_podeBaixarTodos()` falso → botão escondido.
2. `loadPerfil()` termina → `_iniciarAppAposTenant()` → `aplicarRestricoesPorRole()` roda
   com `role === 'admin'` — **e não faz nada**, porque o guard que eu escrevi só sabia
   esconder:
   ```js
   if (btnExportAll && !(role === 'admin' || role === 'super_admin')) btnExportAll.style.display = 'none';
   ```
3. Botão fica escondido até a análise seguinte, quando `rodarAnalise()` reavalia. Daí o
   "voltou sozinho".

Os outros três botões (CSV/PDF/Imagem) não checam role nenhum — por isso continuavam
visíveis, o que tornava o sintoma "só esse botão sumiu".

### Correção

- **`_roleAtual()`** — a normalização que estava inline em `aplicarRestricoesPorRole()`
  virou helper, e `_podeBaixarTodos()` passou a usá-la. Fonte única do role do app.
- **`_sincronizarBotaoPacote()`** — fonte única da visibilidade, **simétrica**: mostra
  *e* esconde, condicionada a `_podeBaixarTodos() && window._analiseData`. Chamada tanto
  por `rodarAnalise()` quanto por `aplicarRestricoesPorRole()`. É essa simetria que traz o
  botão de volta quando o perfil chega depois.

### Lição aplicável a qualquer controle com RBAC nesta SPA

**Guard de visibilidade que só esconde é um bug esperando acontecer** em telas cujo estado
de permissão chega de forma assíncrona. Se a função que reage à mudança de role não for
capaz de *restaurar* o elemento, qualquer ordem de eventos diferente da feliz deixa a UI
travada no estado restritivo. O mesmo vale para `links-action-btns` / `dash-hdr-actions` /
`usuarios-new-btn-area`, que hoje também só são escondidos — não deu problema porque
`aplicarRestricoesPorRole()` é a única coisa que mexe neles, mas o padrão é frágil.

### Nota de método

Este bug **não teria sido pego** pelos testes desta sessão: todos avaliavam `_podeBaixarTodos()`
com `currentUser` já populado. Faltava exercitar a **ordem** dos eventos, não só o estado
final. O teste de regressão agora reproduz a sequência (análise antes do perfil → perfil
chega → botão deve voltar).


---

## 6. Ajustes do PDF/imagem pos-producao (2026-09-11, mesma noite)

Dois pontos reportados pelo usuario depois do deploy.

### 6.1 Paginas em branco — `page-break-inside: avoid` no alvo errado

O fix do item 4 passou a aplicar `.psicomap-setor` de verdade, e o efeito colateral
apareceu na hora: **paginas quase em branco**. Um bloco de setor costuma ser maior que o
espaco restante da folha, entao `avoid` empurrava o bloco inteiro para a proxima pagina.

A granularidade certa de "nao cortar no meio" e o **card de risco**, nao o setor inteiro.
`.psicomap-setor` ficou so com `margin-bottom`; `.psicomap-card` mantem o `avoid`.
A classe continua sendo aplicada (o seletor corrigido segue valendo) — o que mudou foi a
regra CSS, com comentario no proprio arquivo explicando por que ela **nao** leva `avoid`,
para ninguem "consertar" de volta.

### 6.2 O recorte de setores/funcoes nao aparecia no documento

Pergunta do usuario: "no caso de relatorios onde eu aplico filtro de setores, ele nao
mostra os setores filtrados no inicio do pdf ou imagem. esse comportamento era assim
antes?" — **sim, era**, e em ambos os casos por motivo diferente:

- **PDF**: a linha existia, mas condicionada a `setores.length > 1`. Filtrar exatamente
  um setor — o recorte mais especifico, onde a informacao mais importa — nao mostrava nada.
- **Imagem**: nunca mostrou. `exportarResultados('png')` captura `#view-content`, e as
  tags de setor vivem no header do `resultado-panel`, **fora** dessa div.

Ambos pre-existentes, nenhum introduzido nesta sessao.

**Decisao do usuario:** bloco "Filtros aplicados" **sempre** presente, nos **dois**
formatos, listando **setores e funcoes** (as demais dimensoes — ciclo, nivel, segmentacao,
agrupamentos — ficaram de fora por escolha dele; a segmentacao ja aparece no subtitulo).

`_resumoFiltrosHTML()` e a fonte unica:
- Deriva dos **dados filtrados** (`setoresAtivos` e `filtrado`), nao da selecao do combo —
  reflete o que de fato esta no documento.
- Diz "Todos os setores" / "Todas as funcoes" quando o recorte cobre todo o universo do
  combo, em vez de despejar a lista inteira. Isso tambem distingue *sem filtro* de
  *filtro omitido*, que era a ambiguidade do comportamento antigo.
- Carrega **estilos inline** (com `var(--...)`) de proposito: serve aos dois destinos —
  `resolverVars()` resolve no doc de impressao, `_resolveStyleVars()` resolve no clone do
  html2canvas. Classes do `<style>` do doc nao chegariam ao PNG.
- No PNG e injetado no **clone**, nunca no `#view-content` real — a tela nao e poluida
  (coberto por teste).

As regras `.psicomap-tags` / `.psicomap-tag` ficaram orfas e foram removidas.

**Detalhe de processo:** a primeira versao do comentario explicativo foi escrita dentro da
template string do documento, entao viajava para dentro de todo PDF gerado. Movido para o
codigo. Vale a atencao: tudo que entra naquela string vira conteudo do arquivo entregue.
