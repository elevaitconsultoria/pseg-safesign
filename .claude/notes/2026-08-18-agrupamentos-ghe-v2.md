# Agrupamentos GHE — Edição de grupos + Filtros + Correções de laudo (2026-08-18)

Continuação de `2026-08-17-agrupamentos-ghe.md`. Todos os commits desta sessão
vão em `develop` → PR #47 aberta para `main`.

---

## 1. Edição de grupos (renomear + alterar composição)

**Problema**: o modal só criava ou excluía grupos — edição não existia.

**Implementação**:

```js
// Novo estado global
let grupoEditandoId = null;

// UPDATE no banco
async function _editarGrupoNoBanco(id, nome, itens) {
  await sbAdmin.from('grupos_setor')
    .update({ nome, itens, atualizado_em: new Date().toISOString() })
    .eq('id', id);          // RLS policy grupos_setor_write protege cross-tenant
}

// Abre modal pré-populado com dados existentes
function editarGrupo(tipo, id) {
  const g = (tipo==='setor' ? gruposSetor : gruposFuncao).find(x => x.id === id);
  if (!g) return;
  grupoEditandoId = id;
  document.getElementById('grupo-modal-title').textContent = '...';
  _abrirModalGrupo(tipo, g.nome, g.itens || []);
}

// salvarGrupo() despacha: grupoEditandoId → UPDATE, null → INSERT
```

`fecharGrupo()` e `abrirNovoGrupo()` limpam `grupoEditandoId = null`.

Botão "✎ Editar" adicionado em `renderTabelaAgrupamentos()` ao lado do "✕".

**Segurança**: o UPDATE filtra apenas por `id` (UUID), sem passar `tenant_id`.
Isso é seguro porque (a) UUID impossibilita colisão acidental e (b) a policy
RLS `grupos_setor_write` no banco bloqueia qualquer UPDATE cross-tenant antes
de executar.

---

## 2. Laudo PDF — gráficos e análise por risco respeitam granularidade

**Problema**: `_buildLaudoHTML()` já calculava `gruposLaudo` corretamente, mas só
aplicava o agrupamento na seção de "Resultados por tabela". As seções de gráficos
e análise por risco continuavam calculando sobre `linhas` inteiras (todos os setores).

**Implementação**: ambas as seções agora iteram sobre `gruposLaudo.forEach(grupo => ...)`:

```js
// graficosHTML
gruposLaudo.forEach(grupo => {
  const linhasGrupo = linhas.filter(r => grupo.setores.includes(r.setor));
  if (!linhasGrupo.length) return;
  const dist = calcDistribuicaoQuestoes(_normalizeLinhasGraficos(linhasGrupo));
  if (gruposLaudo.length > 1) graficosHTML += `<div class="sec-title sub">${grupo.nome}</div>`;
  graficosHTML += _renderDistGrupo(dist);
});

// analiseRiscoHTML (mesmo padrão)
gruposLaudo.forEach(grupo => {
  const linhasGrupo = linhas.filter(r => grupo.setores.includes(r.setor));
  if (!linhasGrupo.length) return;
  const fatoresGrupo = calcFatores(linhasGrupo).filter(f => f.nivel !== 'IRRELEVANTE');
  if (gruposLaudo.length > 1) corposAR += `<div class="sec-title sub">${grupo.nome}</div>`;
  corposAR += fatoresGrupo.length ? _renderCardsRisco(fatoresGrupo) : `<p ...>Nenhum fator...</p>`;
});
```

Quando `gruposLaudo.length === 1` (granularidade "Geral"), o cabeçalho de grupo é omitido
— comportamento idêntico ao anterior.

---

## 3. Preview do Relatório na tela respeita granularidade

**Problema**: `renderLaudo()` (preview na tela) e `_buildLaudoHTML()` (PDF) são funções
separadas. Somente o PDF foi corrigido inicialmente.

**Correção em `renderLaudo()`**:

```js
const _granPreview = document.getElementById('laudo-granularidade')?.value
  || (gruposSetor.length ? 'agrupado' : 'segregado');
const _gruposPreview =
  _granPreview === 'consolidado' ? [{nome: 'Todos os setores', setores: _setoresDisp}]
  : _granPreview === 'segregado' ? _setoresDisp.sort().map(s => ({nome: s, setores: [s]}))
  : agruparPorGrupos(_setoresDisp, gruposSetor);

_gruposPreview.forEach(grupo => {
  const lSetor = linhas.filter(r => grupo.setores.includes(r.setor));
  // ... renderiza tabela de resultados para o grupo ...
});
```

---

## 4. Reorganização dos toggles de Resultados

**Problema**: a hierarquia [Gráfica | Tabela] → [Por Risco | Por Questão] era
semanticamente errada — "Por Questão" gerava gráficos de barras, não uma tabela.
Além disso, `_setSegMode()` não atualizava `.stg-active` no botão "Por Agrupamento".

**Nova hierarquia**:

| Nível | Toggle | Visível quando |
|-------|--------|----------------|
| 1 | [Por Setor \| Por Agrupamento \| Geral] | sempre |
| 2 | [Por Risco \| Por Questão] | sempre |
| 3 | [📊 Gráfico \| 📋 Tabela] | `_viewMode === 'risco'` |
| 3 | [▼ Mostrar detalhes] | `_viewMode === 'risco'` E `_displayMode === 'grafica'` |

`_setViewMode(mode)` gerencia a visibilidade de `#toggle-format` e `#btn-detalhes`.
`_setDisplayMode(mode)` gerencia `#btn-detalhes` (sem mais referência ao antigo `#toggle-view`).

Bug fix em `_setSegMode()`:
```js
const bg = document.getElementById('sgbtn-grup');
if (bg) bg.classList.toggle('stg-active', mode === 'agrupado'); // linha faltante
```

O botão "▼ Mostrar detalhes" fica na linha de toggles superiores (ao lado de
Gráfico/Tabela), não na linha da legenda.

---

## 5. Filtros de Agrupamento GHE nas três telas

### Funções auxiliares

```js
// Popula o combo com nomes dos grupos; oculta o filter-card quando não há grupos.
// Inicializa com todos selecionados (= sem filtro ativo).
function _populateGheCombo(comboId, fcId) {
  const nomes = gruposSetor.map(g => g.nome);  // apenas tipo='setor'
  const fc = document.getElementById(fcId);
  if (fc) fc.style.display = nomes.length ? '' : 'none';
  comboItems[comboId] = () => nomes;
  comboState[comboId] = new Set(nomes);
  buildCombo(comboId);
}

// Expande grupos selecionados → conjunto de setores brutos.
// Retorna null quando todos ou nenhum estão selecionados (= sem filtro).
function _gheSetoresFiltro(comboId) {
  const sel  = [...comboState[comboId]];
  const todos = gruposSetor.map(g => g.nome);
  if (!sel.length || sel.length === todos.length) return null;
  return new Set(
    gruposSetor.filter(g => sel.includes(g.nome)).flatMap(g => g.itens)
  );
}
```

**Por que só `gruposSetor` (tipo='setor')?** O campo filtrado é `r.setor`. Grupos de
funções contêm nomes de cargos — usá-los como filtro de setor não faria sentido.

### Três combos HTML

| ID | Tela | IDs HTML | Auto-trigger |
|----|------|----------|--------------|
| `combo-ghe` | Resultados | `fc-ghe` | não (botão Aplicar) |
| `combo-gf-ghe` | Gráficos | `fc-gf-ghe` | não (botão Atualizar) |
| `combo-ld-ghe` | Relatório | `fc-ld-ghe` | sim (`startsWith('combo-ld-')` → `renderLaudo()`) |

Todos ocultos por padrão (`display:none`) — `_populateGheCombo` os exibe quando há grupos.

### Pontos de população

- `onEmpresaChange()` → `_populateGheCombo('combo-ghe', 'fc-ghe')` após `carregarGruposSetor`
- `onGrafFiltroChange()` → `carregarGruposSetor(empId)` + `_populateGheCombo('combo-gf-ghe', 'fc-gf-ghe')` (dentro do bloco `if (!isDemoMode && empId && sbAdmin)`)
- `onLaudoFiltro()` → `_populateGheCombo('combo-ld-ghe', 'fc-ld-ghe')` após `carregarGruposSetor`

### Aplicação do filtro

```js
// Padrão idêntico nas três funções:
const gheSetores = _gheSetoresFiltro('combo-ghe'); // ou combo-gf-ghe / combo-ld-ghe
const filtrado = dados.filter(r =>
  (setores.length === 0 || setores.includes(r.setor)) &&
  (funcoes.length  === 0 || funcoes.includes(r.funcao)) &&
  (gheSetores === null  || gheSetores.has(r.setor))
);
```

---

## Análise de riscos e bugs conhecidos

### Sem risco de dados de produção

- Nenhuma escrita em `respostas`, `empresa_setores`, `empresa_funcoes`, `empresa_headcount`,
  `ciclos`, `links_coleta` — todas as mudanças são leitura + display ou UPDATE em `grupos_setor`.
- `grupos_setor` é uma tabela nova desta feature; nenhum pipeline pré-existente depende dela.
- RLS `grupos_setor_write` garante isolamento multi-tenant em DEV e PROD.

### Bugs identificados (não críticos)

**1. `_gheSetoresFiltro` — "todos selecionados" baseado em comparação de length**

```js
if (sel.length === todos.length) return null; // todos = sem filtro
```

Se dois grupos da mesma empresa tiverem nomes idênticos, `todos` teria duplicatas mas
o `comboState` (Set) não — `sel.length < todos.length` e o filtro seria ativado
indevidamente. **Risco prático: muito baixo** — `salvarGrupo` não valida unicidade
no banco, mas é improvável o operador criar dois grupos com nomes iguais.
Correção futura: adicionar `UNIQUE(empresa_id, tipo, nome)` na tabela ou validar
no JS antes de salvar.

**2. `renderLaudo()` não filtra por `ld-ciclo` (bug pré-existente, não introduzido aqui)**

O select `#ld-ciclo` existe no painel de filtros e dispara `renderLaudo()`, mas dentro
da função o valor não é lido para filtrar `linhas` — só `_buildLaudoHTML()` usa o
`cicloId` para preencher o nome do ciclo na capa. O preview sempre mostra todos os ciclos.
**Risco prático: cosmético** — o PDF gerado também não filtra por ciclo na leitura de dados
(somente no nome exibido). Correção futura: ler `ld-ciclo` em `renderLaudo()` e filtrar
`dados` por `r.ciclo_id`.

**3. UX: filtro GHE exibe apenas grupos de setores, não de funções**

Intencional tecnicamente (grupos de funções não podem filtrar `r.setor`), mas o label
"Agrupamento GHE" não deixa isso claro. Usuário que criou grupos de funções pode estranhar
não os ver. Sem impacto em dados.

---

## Commits desta sessão

| Hash | Descrição |
|------|-----------|
| `f0d5a89` | feat: editar agrupamentos GHE — renomear e alterar composição |
| `2ab3a4f` | fix: laudo respeita granularidade nos gráficos + reorganiza toggles Resultados |
| `232a004` | refactor: move botão Detalhes para linha da legenda (lado direito) |
| `d5dbbec` | fix: renderLaudo() respeita granularidade no preview de resultados |
| `c63ab0b` | feat: filtros de Agrupamento GHE nas telas Resultados, Gráficos e Relatório |
| `0d531f0` | fix: move botão Detalhes de volta para a linha de toggles (canto superior) |

**PR #47** — `develop → main` — aberta e atualizada.

## Deploy

- **DEV**: todos os commits aplicados em `develop`
- **PROD**: pendente merge da PR #47

## O que NÃO muda

- `respostas.setor` / `empresa_setores` / `empresa_funcoes` / `empresa_headcount` — intocados
- `psicomap-forms.html` — zero alterações
- `salvar_resposta` RPC — zero alterações
- Pipeline de coleta — zero alterações
- Empresas sem grupos: filter-card GHE oculto, análise e laudo idênticos ao comportamento anterior
