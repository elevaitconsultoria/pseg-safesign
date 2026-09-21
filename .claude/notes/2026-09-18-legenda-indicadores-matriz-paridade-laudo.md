# Legenda de indicadores, cores da matriz e paridade preview × PDF do laudo (2026-09-18 → 2026-09-21)

Sessão de ajustes gerais pedida em 4 itens (erros de português, nomenclatura do `cd_risco` 4,
cores da matriz no export, textos cortados) que cresceu para a paridade completa entre a tela
Resultados, o preview do laudo e o PDF exportado.

**9 commits na branch `claude/ajustes-gerais-matriz-5q7ln4`**, todos em `psicomap-admin.html`
(+ `CLAUDE.md`), mergeados em `develop` (`fb51c79`) e em `main` pela
[PR #77](https://github.com/elevaitconsultoria/pseg-safesign/pull/77) (`b4f73ce`).

| Commit | O quê |
|--------|-------|
| `2622e27` | Plural, `cd_risco` 4, cores da matriz P×S, textos truncados |
| `1be2d42` | Legenda de indicadores na tela Resultados |
| `e80f948` | Legenda uma vez só no PDF do pacote de análises |
| `632871d` | Legenda também no laudo em PDF |
| `025cce3` | Laudo usa a mesma barra e o mesmo card da tela |
| `29ae960` | Legenda mais discreta e alinhada |
| `a38aec9` | Paridade preview × PDF (card, segmentação, recorte) |
| `c4c1f5b` | Documentação no `CLAUDE.md` |
| `4232425` | Filtro "Seções do laudo" passa a valer no PDF |

---

## 1. Matriz P×S saía com metade das células sem cor (`2622e27`)

O usuário reportou como "cores mal definidas na exportação". **Não era escolha de tom — era
especificidade CSS.**

No CSS do laudo existe a regra genérica de zebra:

```css
tr:nth-child(even) td { background: #f9fafb }   /* (0,1,2) */
```

E as cores das células da matriz eram:

```css
.nc-med { background:#fef9c3 }                  /* (0,1,0) */
```

Comparação de especificidade olha a contagem de classes **antes** da de elementos: `(0,1,2)`
vence `(0,1,0)`. Resultado: **as linhas pares do `tbody` (P3 e P1) perdiam o fundo colorido**,
enquanto as ímpares (P4 e P2) mantinham. Por isso o sintoma parecia aleatório no print.

`.tbl-matriz .p-label` (0,2,0) **nunca foi afetada** — daí os rótulos de probabilidade
continuarem escuros enquanto as células ao lado saíam brancas. Essa assimetria é o que confirma
o diagnóstico.

**Fix:** as regras viraram `.tbl-matriz .nivel-cell.nc-*` (0,3,1).

Na mesma passada a escala de `.nc-*` / `.nb-*` foi alinhada à do app
(slate → verde → amarelo → laranja → vermelho). Antes CRÍTICO era **lilás** (`#ede9fe`), que lia
como *menos* grave que o ALTO vermelho — invertendo a leitura de gravidade num documento que vai
para o cliente.

## 2. Legenda de indicadores — "Como ler este resultado"

`_legendaIndicadoresHTML(chaves)` + `_LEG_ITENS` (tupla `chave · rótulo · definição`).
`LEGENDA_INDICADORES_HTML` é o conjunto completo, usado na tela.

**A ordem de `_LEG_ITENS` importa** — segue a leitura do card: P × S formam o Nível, depois as
marcações da barra (Meta, n), por último as convenções (↺ inv, Peso 1/N, cd). O `cd` é o último
porque é o item menos usado para interpretar, e no laudo ele nem entra.

### Onde entra, e a armadilha da exportação

Na tela Resultados é renderizada **dentro de `#view-content`**. Isso é de propósito: é exatamente
`#view-content` que `exportarResultados()` e `exportarResultadosPrint()` capturam, então a legenda
acompanha o PNG e o PDF sem nenhum tratamento adicional.

**Consequência que exigiu conserto:** `baixarTodasAnalises()` captura `#view-content` uma vez por
análise e junta as três num PDF único — a legenda apareceria **3×**, uma por página. O bloco
carrega `data-legenda-indicadores` e o caminho `multi` de `exportarResultadosPrint()` remove as
repetições, mantendo só a da primeira seção.

> A remoção é **por DOM** (`querySelectorAll` + `remove`), não por comparação de string: o HTML
> volta de um round-trip por `innerHTML`, e a normalização de aspas e ordem de atributos
> quebraria um `startsWith` contra o valor da constante.

No laudo entra na abertura da Análise Gráfica **sem o item `cd`**. A seção "Distribuição por
Questão" recebe uma versão reduzida (`n` / `Meta` / `↺ inv`) **só quando a Análise Gráfica não
está no documento** — garantindo uma ocorrência por documento em qualquer combinação de seções.

### Estilo

Deliberadamente discreto, depois de feedback do usuário ("menos marcada, mais clean"): sem fundo,
sem borda de destaque, só dois filetes `#eef0f2`; termo numa coluna fixa de 46px **alinhada à
direita** para todas as definições começarem no mesmo eixo; título 8px cinza; corpo 9px. Altura
caiu ~⅓ em relação à primeira versão.

## 3. Paridade preview × PDF do laudo (`025cce3`, `a38aec9`)

O PDF saía visivelmente mais pobre que o preview e que a tela.

**Causa:** o laudo montava as barras com um helper próprio, `_barPrint()`, criado como "barra de
distribuição **para impressão (sem CSS vars)**". Essa versão só desenhava os segmentos coloridos
— sem marcador ▼ de meta, sem âncoras ✓ Adequado / ✗ Elevado, sem o rótulo do nível no segmento
dominante e sem o rodapé "X predominante (n%) / Meta Y: n%". O card em volta também não trazia
severidade, a linha P × S → nível, a classificação ergonômica nem o peso por questão.

**A premissa do helper estava errada:** `renderBarraDistribuicao()` (linhas ~7111–7199) tem
**zero** ocorrências de `var(--…)` — sempre pôde rodar no documento autônomo do laudo. A duplicata
existia sem necessidade e foi divergindo. `_barPrint()` foi **removido**; hoje é a mesma barra nos
três lugares.

O card virou `_laudoCardRiscoHTML(f)`, **fonte única** do preview e do PDF, junto com
`LAUDO_NIVEL_BG` / `LAUDO_NIVEL_TX` (eram `NivelCores`/`NivelTxt` no preview e `NCP`/`NTP` no PDF,
com valores idênticos).

**Decisão de escopo:** no laudo o *conteúdo* passou a ser idêntico ao da tela, mas as **cores e
tamanhos seguem os do laudo**, não os da tela. A tela usa lilás para CRÍTICO nas bordas dos cards;
o laudo usa a escala slate→vermelho, a mesma dos badges e da matriz. Importar a paleta da tela
reintroduziria a inconsistência no documento do cliente.

## 4. Filtro "Seções do laudo" não valia no PDF (`4232425`)

Achado depois, ao testar em DEV. `_buildLaudoHTML()` lia `laudoSecoesAtivas` para **4 das 8**
seções (`indice`, `analise_risco`, `graficos`, `acoes`). **Capa, Metodologia, Conduta
Administrativa e Tabela de resultados saíam incondicionalmente** — desmarcá-las mudava o preview e
não mudava nada no documento exportado.

Dois efeitos colaterais que a correção obrigou a tratar:

- **Conduta era fisicamente uma subseção da página da Metodologia** (`1.5`). Agora é
  `${_snMet}.5` quando as duas estão ligadas e vira **seção própria numerada** quando só ela está;
  a página é emitida se qualquer uma das duas estiver ativa, com o rótulo de rodapé
  correspondente.
- **A numeração era fixa** (Metodologia `1.`, Resultados `2.`), então um laudo sem Metodologia
  começaria na seção 2. Virou contagem corrida sobre o que entra de fato, com as subseções
  `1.1`–`1.4` derivando de `_snMet`. Os números de página já vinham certos: `footer()` incrementa
  `_pdfPg` só nas páginas emitidas.

`_pn` / `_pnAR` / `_pnGF` / `_pnAC` removidos — calculados e nunca usados.

## 5. Acertos pontuais

- **Plural:** `' questão' + (n>1 ? 'ões' : '')` gerava `"3 questãoões"`.
- **`cd_risco` 4** renomeado de "Constrangimento no ambiente de trabalho" para **"Estresse por
  constrangimento no ambiente de trabalho"**, em `RISCOS_DETALHES`, na `<option>` do modal de
  questão e no comentário do `CATALOGO_ACOES`. `riscos_config` — que sobrescreve
  `RISCOS_DETALHES` em `carregarRiscosDB()` — estava **vazia em PROD**, então o default do código
  é a fonte efetiva e nenhuma migration foi necessária.
- **Textos cortados:** enunciado truncado em 60 caracteres no detalhamento por risco, e nome do
  risco cortado em 28/30 caracteres em três pontos (visão Por Questão, seção de gráficos do laudo
  e do preview). O corte de nome ficaria pior com o nome mais longo do `cd 4`.

---

## Merge para `develop` — 5 conflitos, todos no mesmo ponto

A branch partiu de `main`; a `develop` estava 22 commits à frente com a feature de **GHE por par**.
O merge deu 5 conflitos em `psicomap-admin.html`, **todos sobre a granularidade do laudo**.

A `develop` já havia corrigido a mesma divergência preview × PDF que eu corrigi, e **melhor**: com
`_granularidadeLaudo()` / `_gruposPorGranularidade(linhas, gran)` / `_linhasDoGrupo(grupo, linhas)`,
que ainda cobrem o modo **"Por GHE"** que esta branch não conhecia.

**A versão da `develop` prevaleceu nos cinco.** A minha era a versão ingênua do mesmo conserto.

O que veio desta branch e não colidiu: `_laudoCardRiscoHTML`, legenda de indicadores, cores da
matriz, gating das 8 seções, recorte de IRRELEVANTE no preview e os acertos de texto.

## Migrations — não estavam aplicadas em NENHUM dos dois bancos

Auditoria antes do merge para `main`, feita em `information_schema` (não nos arquivos `.sql`,
conforme a regra do `CLAUDE.md`):

| Objeto | Antes | Depois |
|---|---|---|
| `empresa_apelidos` | ✅ DEV + PROD | — |
| `grupos_setor.pares` | ✅ DEV + PROD | — |
| `grupos_setor.absorvidos` | ❌ **em nenhum** | ✅ aplicada DEV → PROD |
| `filtro_presets` | ❌ **em nenhum** | ✅ aplicada DEV → PROD |

**Consequência que passou despercebida:** as features "cobertura de GHE absorvidos" e "presets de
filtro" estavam **degradando silenciosamente durante o teste em DEV**. O código tem fallback para
as duas (`carregarGruposSetor()` tem cascata de colunas; os presets detectam `semTabela`), então
nada quebrou na tela — mas elas nunca chegaram a ser exercitadas. **Ficam pendentes de teste real.**

O cabeçalho de `migration_grupos_setor_ghe.sql` alerta que o SQL precisa estar nos dois bancos
**antes** do HTML novo subir — `pares` já estava; as outras duas não. O fallback do código foi o
que evitou o estrago descrito lá (zerar `gruposSetor` e `gruposFuncao` de toda empresa).

## Deploy — merge commit, não squash

PR #77 mergeada com **merge commit**. Um squash criaria em `main` um commit novo que a `develop`
não tem, recriando exatamente a divergência de "mesmo conteúdo, hashes diferentes" que já havia
acontecido nos PRs #68 e #69 (e que deixou `main` 4 commits "à frente" de conteúdo duplicado).

Depois do merge, `git push origin origin/main:develop` (fast-forward, remédio do `CLAUDE.md`):
**`main` e `develop` ficaram com 0 commits de diferença nos dois sentidos.**

## Validação

- **`/validar-formulario` contra PROD, antes e depois do merge** (o skill exige nos dois momentos):
  `session_id` uuid, RPC `salvar_resposta` `SECURITY DEFINER` + `search_path=public`, GRANTs
  completos, submissão real gravando nas 4 tabelas do pipeline, idempotência devolvendo o mesmo
  UUID sem duplicar linha. Dados de teste removidos, sem itens órfãos.
- Laudo gerado com **cada uma das 8 seções desmarcada isoladamente** — some só a desmarcada, as
  outras 7 intactas nos 8 casos; e 3 combinações de numeração.
- **Paridade preview × PDF** nas três granularidades: mesma contagem de cards, mesmos riscos,
  mesma ordem.

> **Nota de método:** a primeira versão do teste de paridade mentiu. O `<select>` de granularidade
> do stub só tinha uma opção, então as três granularidades rodaram como "segregado" e o teste
> passou sem exercitar nada. Ao montar stub de UI, conferir que o controle **aceita** os valores
> que o teste atribui.

## Armadilha de edição que quebrou o arquivo

O CSS do laudo vive **dentro de um template literal** (`const css = \`…\`` em `_buildLaudoHTML`).
Uma crase num **comentário de código** ali dentro encerra o template e quebra o `<script>` inteiro.

Como o `psicomap-admin.html` não passa por build, nada pegaria isso antes do deploy. Checagem
barata, que passou a ser rodada antes de cada commit desta sessão:

```bash
node -e "const h=require('fs').readFileSync('psicomap-admin.html','utf8');
 const m=[...h.matchAll(/<script(?![^>]*src=)[^>]*>([\s\S]*?)<\/script>/g)];
 for(const x of m) new Function(x[1]);   // lança se houver erro de sintaxe
 console.log('scripts ok:', m.length);"
```

## Pendências

- Testar **"cobertura de GHE absorvidos"** e **"presets de filtro"** — subiram para PROD com as
  migrations aplicadas, mas nunca foram exercitadas com o banco pronto.
- A paginação do PDF mudou (cards mais altos, `page-break-inside: avoid` mantido): um risco com
  muitas questões pode empurrar o card inteiro para a página seguinte. Vale olhar num laudo real
  antes de entregar para cliente.
