# Laudo `padrao_pseg2.0` (2026-10-13)

Branch `feat/laudo-padrao-pseg2` (worktree `../pseg-safesign-laudo2`, base `origin/develop`).
Segundo modelo de laudo, ao lado do `default` (que não mudou). Vale só para o instrumento BS 8800.

## Origem
Documento-modelo da PSEG (`Relatório riscos psicossociais - Modelo`, caso Inovadoor, 22/09/2026,
~66 páginas, 18 capítulos). Regra do usuário: **o que vale é a estrutura geral** — texto padrão
(igual em todo laudo) + variáveis (empresa, ciclo, dados). O amarelo do modelo é só reforço de
variável/revisão e **não é exaustivo** (o *Objetivo* cita empresa e cidade sem marca).

## O que existe
- **Seletor** `#laudo-versao` (`default` | `padrao_pseg2.0`) na sidebar do Relatório. Grava `template`
  em `snapshot_json` e em `snapshot_json.config` (ausente = `default`); o "Reaplicar" restaura.
- **Gerador único** `_p2Build(ctx, {preview})` — o preview é um `<iframe srcdoc>` com o MESMO HTML do PDF
  (evita a classe de bug preview×PDF). Contexto em `_p2Contexto()`.
- **Texto padrão** `P2_TEXTOS` (extraído do .docx por script, não digitado), `P2_RESP_TEXTOS`,
  catálogo de medidas por fator (`P2_TEXTOS.plano`, 50 medidas, do modelo).
- **Persistência** `laudo_dados` (`migration_laudo_dados.sql`): `escopo` `est` | `empresa` | `ciclo`,
  `dados` jsonb. Aplicada em **DEV** (2026-10-13); **PROD pendente** (só com autorização).
  Uma tabela e não colunas em `empresas`/`est_perfil` porque `empresas` é legível por `anon`.
- **Modal "Dados do laudo"**: CNAE, grau de risco, ramo, local, efetivo, título descritivo por GES
  (por empresa); revisões, período e textos padrão editados (por ciclo); imagens temporárias.
- **Perfil da EST**: card com cabeçalho, rodapé (tel/e-mail/site) e elaboradores + mini-currículos
  (admin/super_admin). Uma função (`_p2PageCss`) lê tudo — cabeçalho/rodapé são configurados num lugar só.
- **Imagens anexadas** (ART etc.): só em memória (`_p2Anexos`), até 6 × 1,5 MB. Nunca vão ao banco, ao
  snapshot ou ao `localStorage`; o histórico guarda só a contagem. Limpas no logout (`_limparEstadoTenant`).

## Decisões técnicas que não são óbvias
- **Cabeçalho/rodapé com `position:fixed` NÃO funciona** na impressão do Chrome: o offset negativo é
  ignorado e o cabeçalho cai no pé da página (testado com Chrome headless). Solução: caixas de margem do
  `@page` (`@top-*`, `@bottom-*`), que exigem **Chrome/Edge ≥ 131** (também dão "Página X de N").
  A capa usa a página nomeada `capa` (`margin:0`) e por isso não recebe cabeçalho. No Firefox/Safari o
  documento sai sem cabeçalho/rodapé. O logo do cliente é reduzido por canvas (`_p2ReduzirLogo`): na caixa
  de margem a imagem entra no tamanho natural.
- **Numeração dos fatores**: o modelo numera 1–11; o sistema usa `cd` {1,3,4,5,6,7,8,9,10,11,12}.
  `P2_FATORES_ORDEM` mapeia só a apresentação; o `cd` interno não muda.
- **Variável vazia nunca fica em branco**: vira `[a preencher: X]` e entra em `ctx.pend`; ao gerar há
  `confirm()` com a lista (convenção "salvaguarda + confirm").
- **N mínimo** `P2_N_MIN = 5` (provisório, igual ao `N_MIN_ANONIMATO` da branch HSE — unificar quando as duas
  chegarem em `develop`). Grupo abaixo dele sai com "Resultados omitidos". O modelo mostra grupos com 2 e 3
  respondentes; o v2.0 não.
- O filtro de **nível de risco** é ignorado no v2.0 (o modelo apresenta todos os fatores).
- Salvar: SELECT → UPDATE/INSERT (não upsert), porque a unicidade é um índice por expressão (`COALESCE`).

## Divergências modelo × sistema encontradas (decisão do usuário pendente — ver Próximos passos)
1. **Q8** ("tratado de forma justa e respeitosa"): modelo → fator 3 (constrangimento); sistema → `cd 9`
   (conflitos interpessoais, fator 6 do modelo). **Q13**: modelo → "3 e 5"; sistema só `cd 4`. O Quadro 1 do
   v2.0 imprime o que o sistema calcula, não o que o modelo diz.
2. **Q23**: texto do modelo ("sem aviso prévio") ≠ sistema ("sem comunicação prévia adequada").
3. O modelo diz "a sequência não é contínua porque o código 2 foi descontinuado", mas a tabela é 1–11
   contínua. Trecho removido. Também corrigidos: "BS 880" → "BS 8800" e referências "item 6.6/6.7" → Tabela 4 /
   Quadro 3. A medida do fator 10 citava "Pricing e Presidência/Diretoria" (outro cliente) — generalizada.
4. A tabela de resultados ganhou colunas P e S (o texto do modelo promete os índices; o print dele não os mostra).

## Não feito / limites
- **Sumário sem nº de página** (Chrome não tem `target-counter`).
- **Persistência não testada com sessão autenticada** (o harness não permite login). Testado: RLS por papel
  e tenant via `set_config` + ROLLBACK, sintaxe do filtro PostgREST, lógica do modal/estado e geração com
  dados sintéticos; PDF impresso com Chrome headless e conferido página a página.
- **HSE**: esta branch parte de `develop`, que ainda não tem o HSE. Ao juntar, desviar o v2.0 só para o
  ramo BS 8800 (ciclo HSE continua no gerador próprio e ignora o seletor).
- Migration em **PROD** e `git push origin develop` não foram feitos.

## .docx editável (2026-10-13)
`baixarLaudoDocx()` — botão "Baixar .docx (editável)" no card do modelo e na barra do preview.
- **Não é um segundo gerador de conteúdo**: `_p2DocxConverter` converte o MESMO HTML do PDF (`_p2Build(ctx,{docx:true})`)
  para docx.js (vocabulário restrito: h1–h3, p, ul/ol, table, img, svg, `.p2assin`). Texto, ordem e dados não divergem.
- docx.js 8.5.0 carregado sob demanda do jsdelivr (já no CSP). Imagens e o SVG viram PNG por canvas.
- Cabeçalho/rodapé nativos (`_p2Cab`, mesma fonte do PDF), "Página X de Y" em campo, estilos Heading 1–3 reais, tabelas
  reais, capa em seção própria (sem cabeçalho). **Sumário é lista estática, sem nº de página** (campo TOC não popula
  no Google Docs).
- No Anexo B o cartão com barras vira **tabela** (% por questão) — só no .docx (`ctx.docx`).
- Opção "Destacar campos variáveis em amarelo" vale só para o .docx. Registra em `laudos` com `formato:'docx'`.
- Validação: abrir o .docx no Word via COM (`Word.Application`) e `ExportAsFixedFormat` → PDF → PyMuPDF.

## Seções ocultas, páginas extras e visualizador de PDF (2026-10-13)
- **Seções e páginas extras** (card do modelo + modo edição do preview): `laudo_dados` escopo `ciclo` guarda `ocultos` (chaves de
  `P2_CAPS`) e `extras` (`{id,titulo,apos,html,imgs}`). `ctx.caps` é a lista final; numeração e sumário seguem ELA
  (`_p2Num(ctx,k)`). Extras não têm número. Texto das extras passa por `_laudoSanitize` (B/I/U/listas/P); imagens só
  em memória (`_p2Anexos`, ids efêmeros).
- **PDF sem pop-up**: `_p2GerarPDF()` abre um visualizador em tela cheia (iframe) com Imprimir / Abrir em nova aba /
  Baixar .docx. Motivo: o pop-up (window.open + document.write) falhava em silêncio e o catch fechava a janela. Erros agora
  aparecem NA tela. "Abrir em nova aba" cobre navegador que ignore `@page` ao imprimir iframe.
- Assinatura: campo de 24 mm acima da linha (placeholder "espaço para assinatura" só na tela); CPF e papel opcionais.

## .docx para qualquer modelo (2026-10-13)
`baixarLaudoDocx()` agora atende o `default` também: `gerarLaudoPDF({docx:true})` monta o MESMO HTML do PDF (sem pop-up) com
`window._laudoDocxMode = true` — os cartões de risco e as barras de distribuição viram TABELAS (`_laudoCardDocxHTML`, ramo em
`_renderDistGrupo`) — e `_p2DocxConverter(..., 'default', meta)` converte por classes (`.sec-title`→Título 1/2 com fundo verde,
`.tbl-*`, `.highlight-box`, `.cover-*`, `.assinatura-bloco`…). Legendas de barras ficam de fora. Rodapé nativo "EST · Página X de Y".
- **HSE** (`_buildLaudoHSEHTML`) não existe nesta branch (base = develop). Ao juntar, passe o HTML dele pelo mesmo conversor
  (perfil `default` serve de ponto de partida) e valide no Word via COM.

## Próximos passos (atualizado em 2026-10-13, ao abrir o PR #95)

**Antes de levar para `main`**
1. Mergear o PR #95 em `develop` com **merge commit** (não squash) e conferir o DEV com um usuário real.
2. **Teste com login em DEV**: salvar/carregar `laudo_dados` nos três escopos (o ambiente do agente não permite login). Conferir:
   Perfil da EST (cabeçalho, rodapé, elaboradores) → "Dados do laudo" → revisões/textos → seções ocultas/páginas extras → PDF e .docx.
3. Conferir o **.docx no Google Docs** (cabeçalho, matriz P×S, rodapé "Página X de Y") — só foi validado no Word.
4. Aplicar `migration_laudo_dados.sql` em **PROD** (só com autorização). O código falha aberto sem ela.
5. Rodar `/validar-formulario` **não** é necessário (não toca submissão), mas conferir `has_table_privilege('anon','laudo_dados','SELECT')` = false em PROD.

**Backlog da semana** (detalhe no `ROADMAP.md`): pacote 1 (herdar do ciclo anterior + padrões da consultoria) → pacote 2 (dados da
empresa) → pacote 3 (preenchimento automático) → pacote 4 (painel de prontidão + lote).

**Decisões pendentes do usuário**
- Divergências modelo × sistema: **Q8** (modelo → fator 3; sistema → fator 6 do modelo) e **Q13** ("3 e 5" no modelo; só 3 no sistema). Hoje o
  Quadro 1 imprime o que o sistema calcula.
- Campos da empresa também na tela de **Clientes**, ou só em "Dados do laudo"?
- `P2_N_MIN` definitivo (hoje 5) e se vira configurável por EST (pacote 1).
- Sumário com número de página (hoje sem; Chrome não tem `target-counter`) — aceitar ou calcular medindo a paginação.

**Integração com a branch HSE** (`feat/hse-icao35`, ainda não em `develop`): `renderLaudo`/`gerarLaudoPDF` serão tocados pelas duas. Manter o ramo
HSE antes do `_p2Ativo()`; passar o HTML do laudo HSE (`_buildLaudoHSEHTML`) pelo `_p2DocxConverter` (perfil `default` é o ponto de partida) e validar no Word.

## Capítulo de resultados — paginação, negritos e tabela (2026-10-14)
Pedido do usuário com prints do modelo (seção 13 e "Análise dos resultados do grupo") e da tabela da tela Resultados.
- **Negritos do modelo**: na frase "Participaram da avaliação…" ficam em negrito o nº de colaboradores, o nº de grupos e
  "uma participação de X%." (o efetivo NÃO); a frase "A tabela a seguir, apresenta a consolidação macro…" sai inteira em
  negrito (`_p2paras(ctx,'res_geral',…,{negrito:true})` — vale também para texto editado). Na análise do grupo: "**1 fator de
  risco**"/"**N fatores de risco**" e a lista de fatores "**A, B e C.**" (com o ponto).
- **Lista de fatores só com os nomes**, como no modelo — antes saía "X, classificado como risco médio; Y, …". O nível de cada
  fator está na tabela da página anterior. O modelo escreve "foram identificados 1 fator"; mantivemos a concordância
  ("foi identificado 1 fator de risco").
- **Participação com duas casas** ("51,39%") via `ctx.pctTxt`; `ctx.pct` deixou de ser arredondado — com o arredondamento,
  49,6% virava 50% e a conclusão dizia que atendia ao mínimo.
- **Paginação**: tabela de cada grupo sozinha na folha e análise na seguinte. Ver CLAUDE.md (classes `.p2pg`, `.p2bl`,
  `.p2anlh`, `.p2pgh`, `.p2pk`). A folha da tabela fica com sobra embaixo e a da análise quase vazia — é o layout do modelo.
- **Tabela `p2res`**: células centralizadas na vertical e zebra leve `#F3F8F4` nas linhas pares (no .docx e no PDF).
- Validado com dados sintéticos (5 setores, um com 18 funções, um omitido por <5), modos "Por setor" e "Geral": .docx no Word
  (COM → PDF) e HTML no Edge headless, paginação idêntica nos dois. **Não testado com sessão real nem com dado de cliente.**
