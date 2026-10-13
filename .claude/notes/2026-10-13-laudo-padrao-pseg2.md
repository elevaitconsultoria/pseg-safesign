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

## Divergências modelo × sistema encontradas (decisão do usuário pendente)
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
