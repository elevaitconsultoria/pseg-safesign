# Agrupamentos GHE — matching normalizado, Grupos de Função conectados, 3 bugs de Laudo (2026-08-28)

Continuação de `2026-08-17-agrupamentos-ghe.md` / `2026-08-18-agrupamentos-ghe-v2.md`.
Disparado por: vários funcionários responderam "Outro" em produção e as respostas ficavam
"soltas" (fragmentadas) na Análise/Laudo. Decisão de escopo do usuário: **não** reescrever
`respostas.setor`/`funcao` (são `TEXT` livre, sem FK/CHECK — ver `psicomap-schema-v3.sql:102-113`)
— reforçar a mitigação cosmética já existente via Agrupamentos GHE em vez disso.

Três PRs nesta sessão, todas `develop → main`, todas mergeadas:

| PR | Commit(s) | O quê |
|----|-----------|-------|
| [#58](https://github.com/elevaitconsultoria/pseg-safesign/pull/58) | `8803a4b` | Matching normalizado + Grupos de Função conectados a filtros |
| [#59](https://github.com/elevaitconsultoria/pseg-safesign/pull/59) | `3f4ad57` | Fix: filtros sem auto-apply + pop-up bloqueado no Laudo |
| [#60](https://github.com/elevaitconsultoria/pseg-safesign/pull/60) | `6e7a433` | Fix: `setoresList` nunca declarada em `_buildLaudoHTML` (bug antigo, exposto pelo #59) |

---

## PR #58 — Matching normalizado + Grupos de Função conectados

### 1. Descoberta: Grupos de Função nunca tiveram efeito nenhum

`gruposFuncao` (tabela `grupos_setor` com `tipo='funcao'`) só era lido dentro da própria tela
Agrupamentos GHE (CRUD/listagem). Nenhuma tela de Análise/Gráficos/Relatório/Laudo consumia —
`_segMode` (segregado/agrupado/consolidado) só aceita `gruposSetor`. Criar um grupo de função
só gravava a linha no banco, sem efeito visível em lugar nenhum. Confirmado por grep antes de
implementar qualquer coisa.

### 2. `agruparPorGrupos()` — matching por string exata → normalizado

```js
// Antes: g.itens.filter(i => setores.includes(i))  — case/acento/espaço sensível
// Depois:
function agruparPorGrupos(setores, grupos) {
  if (!grupos.length) return setores.map(s=>({nome:s,setores:[s]}));
  const usados = new Set();
  const result = grupos.map(g=>{
    const chaves = new Set(g.itens.map(_gheNormStrong));
    const match = setores.filter(s=>chaves.has(_gheNormStrong(s)));
    match.forEach(s=>usados.add(s));
    return {nome:g.nome, setores:match};
  }).filter(g=>g.setores.length>0);
  const sem = setores.filter(s=>!usados.has(s)).map(s=>({nome:s,setores:[s]}));
  return [...result,...sem];
}
```

Reusa `_gheNormStrong()` (trim + lowercase + strip NFD de diacríticos) — mesmo helper do
pipeline de import GHE (`:13744`). Testado ao vivo (console, DEV e PROD): `"Produção"`,
`"Outro: PRODUÇÃO "`, `"outro:  Producao"` caem no mesmo grupo; `"Outro: RH"` fica separado.

### 3. `_gheSetoresFiltro` → generalizado para `_grupoValoresFiltro(comboId, tipo)`

Mesma normalização, agora parametrizado por `tipo: 'setor'|'funcao'` para reusar com
`gruposFuncao`.

### 4. Novo filtro "Agrupamento de Função" nas 3 telas

Combos novos: `combo-fun-ghe` (Resultados), `combo-gf-fun-ghe` (Gráficos),
`combo-ld-fun-ghe` (Relatório) — espelham os combos de setor já existentes
(`combo-ghe`/`combo-gf-ghe`/`combo-ld-ghe`), mesmo HTML/CSS, populados via
`_populateGheCombo(comboId, fcId, tipo='funcao')` (ganhou 3º parâmetro).

### 5. Bug lateral encontrado e corrigido: `gerarLaudoPDF()` ignorava o filtro GHE

A exportação real do PDF (`gerarLaudoPDF()`) nunca leu `combo-ld-ghe` — só o preview em tela
(`renderLaudo()`) aplicava o filtro. Corrigido para os dois lerem o mesmo filtro
(`gheSetores`/`gheFuncoes` via `_grupoValoresFiltro`).

### 6. Modal de agrupamento — dedup de variantes "Outro: X"

`_abrirModalGrupo()`: a lista de valores digitados livremente (`doRespostas`) agora colapsa
variantes que só diferem em caixa/acento/espaço (mesmo padrão `_gheNormStrong` +
`_ghePrefAcentuado` do import GHE) e descarta variantes que já normalizam igual a um item do
catálogo — reduz ruído visual na lista de seleção.

### Fora de escopo (decisão do usuário, documentado, não implementado)

- Reescrever `respostas.setor`/`funcao` via `UPDATE` — decisão explícita de manter só a
  mitigação cosmética via `grupos_setor`.
- Contador "não classificadas" da tela Adesão GHE continua comparando contra
  `empresa_headcount`, não contra `grupos_setor` — resposta "Outro" segue contando como não
  classificada mesmo depois de agrupada.
- Visão segmentada "Por Agrupamento de Função" (blocos como o `_segMode` de setor) — função
  continua só filtro, nunca eixo de segmentação (consistente com o resto do produto).
- Sinônimos genuinamente diferentes ("RH" vs "Recursos Humanos") continuam exigindo seleção
  manual de ambos no mesmo grupo.

---

## PR #59 — Dois bugs reportados pelo usuário logo após o merge da #58

### Bug 1: filtros de Agrupamento GHE "com delay"

Causa: os 6 combos de Agrupamento GHE/Função **nunca tiveram botão "Aplicar"** (só
"Todos"/"Limpar") — mas `toggleComboItem`/`selectAllCombo`/`clearCombo` só chamavam
`buildCombo(id)` (atualiza a lista visual), nunca disparavam `rodarAnalise()`/
`renderGraficos()`/`renderLaudo()`. A seleção só refletia quando outro filtro *com* "Aplicar"
era clicado depois. **Bug pré-existente para o filtro de setor desde a #47/#58** — a PR de
função só duplicou o mesmo gap em mais 3 combos.

Fix: `COMBOS_AUTO_APPLY` (Set com os 6 ids) + helper `_renderParaCombo(id)` (extraído do antigo
corpo de `applyCombo`, e agora também cobre `combo-ghe`/`combo-fun-ghe` da tela Resultados, que
o dispatcher original nem reconhecia). `toggleComboItem`/`selectAllCombo`/`clearCombo` chamam
`_renderParaCombo(id)` quando `COMBOS_AUTO_APPLY.has(id)`. Combos com "Aplicar" explícito
(setor/função/nível) mantêm o comportamento em lote de sempre — testado (contador de chamadas
via stub) que não regrediu.

### Bug 2: "Exportar / Imprimir" não respondia a clique nenhum

Causa: `gerarLaudoPDF()` fazia `await getLinhasParaAnalise(...)` **antes** de `window.open()`.
Depois de um `await`, o navegador não reconhece mais a chamada como gesto direto do usuário e
bloqueia o pop-up — silenciosamente, sem erro visível na maioria dos casos.

Fix: `window.open()` movido para ser a primeira coisa na função (com um placeholder "Gerando
laudo…" escrito nela), tudo depois dentro de `try/catch` — qualquer falha fecha a janela e
mostra toast em vez de morrer em silêncio. **Esse `try/catch` foi o que expôs o bug real da
PR #60** (antes dele, a exceção de `setoresList` já estourava, só que silenciosamente).

---

## PR #60 — `setoresList is not defined`

Reportado pelo usuário em produção ~1h depois do merge da #59: `"Erro ao gerar laudo:
setoresList is not defined"`.

`_buildLaudoHTML()` tinha **3 usos de uma variável `setoresList` que nunca foi declarada** —
bug antigo (não introduzido nesta sessão; CLAUDE.md já citava essa variável como se existisse,
na nota da feature "Catálogo de Ações Recomendadas" de 2026-08-24). Antes da #59 (sem
try/catch), a exceção estourava **antes** de `window.open()` — por isso o botão "parecia" não
fazer nada. O fix da #59 não causou o bug, só o tornou visível pela primeira vez.

Correção:
- Seção "Ações Recomendadas": `setoresList.forEach(setor=>...)` → `gruposLaudo.forEach(grupo=>...)`,
  igual ao padrão já usado em "Resultados por setor" e "Distribuição de respostas" no mesmo
  documento. Bônus: agora respeita a granularidade escolhida (segregado/agrupado/consolidado)
  em vez de listar setor a setor sempre.
- Capa + Sumário Executivo ("Setores avaliados"): `setoresList` → `setoresAtivos` (já calculada
  no topo da função).

Testado via console com `RESPOSTAS_DEMO` (constante estática, disponível mesmo com
`isDemoMode=false` — `DEV_BYPASS_AUTH` é sempre `false`, não existe modo demo real acessível
sem login de verdade) chamando `_buildLaudoHTML()` direto, nas 3 granularidades — sem exceção.

---

## Limitação de validação nesta sessão

**Não foi possível autenticar no painel** (login com senha real é ação bloqueada, mesmo sob
pedido explícito do usuário) — toda validação foi feita via:
1. `node --check` no JS extraído do HTML (sintaxe).
2. Chamadas diretas de função no console do navegador (local, DEV, e depois PROD pós-deploy),
   usando `RESPOSTAS_DEMO` como dado sintético.
3. Leitura de código para achar os bugs reais (não haveria como "clicar e ver" sem login).

Os dois bugs reportados pelo usuário em produção (#59, #60) só apareceram no uso real
logado — reforça que essa limitação é real e a validação por console, embora correta para o
que testa, não substitui um clique-a-clique humano antes de decisões de merge apressadas.

## O que NÃO muda (todas as 3 PRs)

- `respostas.setor`/`funcao`/`empresa_setores`/`empresa_funcoes`/`empresa_headcount` — intocados.
- `psicomap-forms.html` / `salvar_resposta` RPC / pipeline de coleta — zero alterações.
- Nenhuma migration nova — só `psicomap-admin.html`.
