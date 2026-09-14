# Importação de Agrupamentos GHE por par (setor × função) — 2026-09-11

Estado: **em `develop`/DEV, validado com dados reais. NÃO promovido para `main`/PROD.**
Commits: `a953b37` → `79a9f91` (ver `git log origin/main..origin/develop`).

---

## 1. O problema

A configuração de GHE era 100% manual. O consultor abria Resultados, filtrava setores,
filtrava funções, gerava — e não ficava histórico nenhum. Para regerar, refazia tudo.

Pior: as duas fontes de nome **não são a mesma**.
- O catálogo (`empresa_setores`/`empresa_funcoes`) vem da planilha de colaboradores do cliente.
- A matriz de GHE vem do **PGR da empresa** — outro documento, outra pessoa, nomenclatura
  quase sempre defasada ("Supervisor RH" no catálogo × "Coordenador de RH" no PGR).

O consultor refazia esse casamento de cabeça, a cada empresa e a cada reimportação.

## 2. A descoberta que definiu a arquitetura

`grupos_setor` modelava **dois eixos independentes**: `tipo='setor'` (lista de setores) OU
`tipo='funcao'` (lista de funções). A matriz do PGR é outra coisa: um conjunto de **PARES**
(setor, função).

Os dois eixos não conseguem representar isso:
1. Vira produto cartesiano — pares que o PGR nunca declarou passam a existir.
2. `agruparPorGrupos()` põe cada setor no **primeiro** grupo que casar. Num PGR real
   "Produção" está no GHE dos operadores E no da supervisão — um dos dois seria esvaziado
   **em silêncio**, gerando laudo errado sem nenhum erro na tela.

Confirmado com dado real: a Inovadoor tem `GHE 11 = Elétrica/ELETRICISTA` e
`GHE 12 = Elétrica/AUX. PRODUCAO`. O modelo antigo perderia um dos dois.

## 3. O que foi construído

### Banco (migrations aplicadas em DEV **e** PROD, inertes até o HTML subir)
- `migration_grupos_setor_ghe.sql` — `tipo='ghe'` + coluna `pares jsonb`
  (`[{"s":setor,"f":funcao|null}]`, grafia crua; `f` nulo = **coringa do setor**),
  índice único parcial `(empresa_id, lower(nome)) WHERE tipo='ghe'`.
- `migration_empresa_apelidos.sql` — de-para aprendido, **escopo por empresa**.
  `apelido_norm` é coluna e não expressão: o banco não tem `unaccent`/`citext`.
  `REVOKE ALL FROM anon` incluído (ver divergência DEV↔PROD no CLAUDE.md).

### Frontend
- **Assistente de 3 etapas** (`#modal-import-ghe`): arquivo → conciliação → prévia.
  Nada toca o banco antes do "Aplicar". Reimportar substitui todos os `tipo='ghe'` da empresa.
- **Conciliação**: resolve na ordem exato → de-para aprendido → sugestão → órfão.
- **Prévia**: diff criar/atualizar/remover, conflitos de par, órfãos e **cobertura contra as
  respostas já coletadas** — o item que mais pegou erro real.
- **Granularidade "Por GHE"** no laudo e **`_segMode='ghe'`** na tela Resultados, ambos
  alimentados por `_gruposPorGranularidade`/`_linhasDoGrupo` (fonte única).
- **Filtro "GHE (setor × função)"** nas 3 telas, para isolar um GHE em vez de ver todos.
- **`exportarParesGhe()`** — CSV dos pares com resposta, incluindo os `Outro:` digitados.
  Sai no formato que a importação lê: é relatório, modelo de planilha e round-trip.

## 4. Bugs reais encontrados e corrigidos (todos silenciosos)

| Bug | Sintoma | Causa |
|---|---|---|
| `'ghe'` era candidato de coluna **setor** | planilha com header "Agrupamento GHE" tinha essa coluna eleita como setor na importação de **estrutura**, deslocando tudo | match por `includes` sem exclusão |
| Cabeçalho **"Funções"** (plural) ignorado | coluna inteira descartada, todo par virava coringa, GHE cobria o setor inteiro | `função`→`funções` **muda o radical**: `funcoes` não contém `funcao`. `setores`/`cargos` funcionam porque só acrescentam "s" |
| Sugestão ignorava o setor da linha | `ANALISTA DE VENDAS Pl` (L minúsculo) casou com `ANALISTA DE VENDAS` de outro setor em vez de `ANALISTA DE VENDAS PI` (i maiúsculo); a resposta ficou fora de todo GHE | conciliação resolvia nome a nome, jogando fora o contexto do par |
| preview ≠ PDF no laudo | seções de análise de risco e ações ignoravam a granularidade escolhida no preview, enquanto o PDF a respeitava | duas montagens de grupo diferentes |
| `_sgMode`/`_sgModeR` órfãos | as 3 views de Resultados quebravam em **todos** os modos | refactor removeu a declaração, mas as leituras estavam mais abaixo na mesma função |
| botão "Aplicar" morto | segunda importação da sessão abria com o botão desabilitado | `disabled` nunca resetado ao reabrir |

## 5. Decisões de projeto que valem manter

- **Regra de partição, nunca bônus numérico.** A sugestão de cargo prefere candidatos que
  existem no setor declarado; dentro de cada grupo, ordena por semelhança. Cheguei a
  implementar como bônus de 0.35 e o caso real passou por **1.02 contra 1.00** — ganhar por
  coincidência entre a constante e a diferença de similaridade não serve para decisão que
  termina em laudo.
- **Cruzamento multi-valor validado pelo cadastro.** Ao quebrar "RH, Contas a receber" ×
  3 cargos, só ficam as combinações que existem em `hierarquia` (`empresa_funcoes.setor_id`).
  Produto cartesiano inventaria pares, e par inventado **disputa precedência** com par real de
  outro GHE — muda de verdade quem cai onde. Verificado: 3 pares corretos, não 6.
- **Residual obrigatório.** Resposta fora de todo GHE vira grupo por setor. Sem isso ela
  sumiria do corpo do laudo continuando contada na capa — **sub-reporta risco**.
  `_gruposPorGranularidade` confere `Σ n(grupo) === linhas.length` e grita no console.
- **Órfão nunca cria setor/cargo** — contrariaria a regra 4 do CLAUDE.md e seria apagado na
  reimportação de estrutura seguinte.
- **`_filtroPorGhe` passa por `agruparPorPares`** em vez de expandir os pares direto: filtrar
  "Operacional" e segmentar por "Operacional" precisam dar o mesmo conjunto.
- **O importador declara o que detectou.** O bug do plural não foi caro por existir, e sim por
  falhar calado. Conciliação e prévia mostram campo → coluna e gritam quando a função falta.

## 6. Validação feita

- **47 testes de unidade** sobre as funções reais extraídas do HTML
  (`scratchpad/teste.cjs` 23/23, `teste2.cjs` 24/24).
- **A/B contra `origin/main`**: PDF do laudo **byte a byte idêntico** nas 3 granularidades
  legadas e os 9 renders da tela Resultados idênticos, para empresa sem GHE. Importação de
  estrutura idêntica em 3 formatos de planilha.
- **Migrations testadas no banco real** com transação revertida: 7/7 funcionais, 8/8 de RLS.
- **Importação real** com a matriz de PGR da Inovadoor: 8 GHE, 62 pares, e a cobertura fechou
  `25+7+7+4+2+2+3 + 11 fora = 61` = total de respostas.

### Dados de teste em DEV
Empresa **Inovadoor Portas Industriais** (`86436ac2-852d-4aee-99b6-a5a87d4292b1`) copiada de
PROD para DEV — 25 setores, 62 funções, 62 headcount, 1 ciclo, 1 link, 61 respostas, 1647
itens. PROD **somente leitura** em todo o processo. Digest de soma por questão idêntico nos
dois bancos (o mapeamento por `codigo` estava certo).
Para remover: `DELETE FROM empresas WHERE id='86436ac2-852d-4aee-99b6-a5a87d4292b1'` em DEV.

---

## 7. PRÓXIMOS PASSOS

### Pendência imediata do teste em andamento
1. **Corrigir o de-para errado.** Está gravado `ANALISTA DE VENDAS Pl → ANALISTA DE VENDAS`.
   Apelido aprendido **tem prioridade sobre a sugestão**, então ele reaplica sozinho. Na
   próxima importação, aba **Funções**, trocar para `ANALISTA DE VENDAS PI`. Isso reescreve o
   de-para e aquela resposta entra no GHE 01, sobrando só os 10 `Outro:`.
2. **Limpar a planilha**: a linha `N/A — N/A` (GHE 15) é lixo.
3. **Nomes de GHE são números** ("01", "02") — o laudo sai "Resultados — 01". Considerar
   nome descritivo na coluna de agrupamento.
4. **Gerar o laudo em "Por GHE"** e conferir que a soma por grupo bate com o total da capa.
5. Rodar `/validar-importacao-ghe` antes de considerar fechado.

### Lacunas conhecidas, em aberto (prioridade sugerida nesta ordem)
1. **Editar/criar GHE à mão.** `editarGrupo` só trata `'setor'`/`'funcao'` — passar `'ghe'`
   cai em `gruposFuncao` e volta sem fazer nada. O painel só tem excluir. Hoje o único
   conserto de um par errado é reimportar a planilha inteira, e **pendência (órfão) não tem
   caminho de resolução nenhum**. Empresa sem matriz de PGR não consegue usar a feature.
2. **Painel do de-para.** `empresa_apelidos` só existe na camada de dados. Um casamento
   confirmado errado fica invisível e reaplica sozinho para sempre. Mitigação parcial já
   feita: a conciliação mostra "N de importações anteriores (revise se algum estiver errado)".
3. **Histórico de análises geradas.** A tabela `laudos` recebe um registro a cada PDF (com
   `granularidade` e nomes dos grupos desde esta sessão) mas **nenhuma tela a lê**. Era um
   pedido explícito do usuário e continua sem solução.
4. **Presets de filtro.** Salvar um recorte com nome e reaplicar. É o que mais se aproxima do
   pedido original ("não refazer o trabalho"), e o maior dos quatro — precisa de tabela nova.

### Antes de promover para `main`/PROD
- As migrations **já estão em PROD** e são inertes (o HTML de lá não referencia `pares`).
- `git log origin/main..origin/develop` contém **trabalho de outra pessoa** (`6999833`,
  `deb205f` — fix do botão de pacote e do PDF). Validar o próprio delta mede o seu risco,
  não o do release: conferir cada commit do intervalo.
- O merge `develop` → `main` foi testado em worktree e roda limpo, zero conflitos.
- **Não há nenhum teste com sessão logada real além da importação da Inovadoor em DEV.**
  Em particular, o `.upsert()` do de-para só foi exercitado por esse caminho.
