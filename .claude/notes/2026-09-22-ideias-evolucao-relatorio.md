# Ideias de evolução do relatório (laudo) — backlog vivo

Criado em 2026-09-22, durante o trabalho de edição de conteúdo do laudo
(branch `claude/edicao-relatorios-w4xgnq`).

**Este arquivo é um backlog, não um plano.** Nada aqui está decidido nem implementado.
A ordem das seções é por relação valor × custo, não por prioridade acordada.

---

## Origem: análise de relatório concorrente (2026-09-22)

O usuário enviou duas telas de uma ferramenta concorrente — "AVALIA NR01 — Ferramenta de
Indicador de Estresse" — para avaliar o que valeria trazer. Eram: a capa do relatório
dela e a seção "1 IDENTIFICAÇÃO".

### 1. Campos de identificação que o nosso laudo não tem

A seção de identificação deles traz o conjunto que um laudo de NR-01 costuma carregar.
Situação de cada campo aqui:

| Campo | Situação no PsicoMap |
|---|---|
| CNPJ | **Já existe** (`empresas.cnpj`) — só não é exibido na capa |
| Endereço da empresa avaliada | **Não existe.** O `endereco` que temos é o da CONSULTORIA (`_estPerfil`), não o do cliente |
| CNAE do estabelecimento | **Não existe** |
| Grau de risco (Quadro I da NR-4) | **Não existe** |
| Data da avaliação | Temos como "data de emissão" na capa |
| Nº de trabalhadores avaliados | Temos como "total de respondentes" |
| Reavaliação recomendada | **Não existe** — ver item 2 |

**Custo:** CNPJ na capa é quase de graça (o dado já está no banco). Endereço do cliente,
CNAE e grau de risco exigem colunas novas em `empresas`, migration (padrão de
`migration_filtro_presets.sql`) e campos no cadastro de cliente.

**Cuidado:** `empresas` é uma das tabelas com policies RESTRICTIVE de viewer; qualquer
coluna nova entra no mesmo regime e a migration precisa do `GRANT` + `REVOKE ALL FROM anon`
do padrão da casa (PROD concede ALL ao `anon` por `ALTER DEFAULT PRIVILEGES` — ver CLAUDE.md).

### 2. Prazo de reavaliação recomendado — o melhor achado

Eles trazem "Reavaliação Recomendada: 3 meses" como campo digitado à mão.

**Podemos fazer melhor e sem banco nenhum:** derivar o prazo do NÍVEL DE RISCO MÁXIMO
encontrado no laudo. Um documento com fator CRÍTICO pede reavaliação mais curta que um
todo em BAIXO, e a NR-01 exige periodicidade de reavaliação. O dado para decidir já está
calculado em `calcFatores`.

Entraria como mais um item dos metadados da capa, via `_laudoCapaHTML` (fonte única), com
o prazo editável pelo consultor por cima do sugerido — mesma mecânica de `LAUDO_BLOCOS`.

**Pendência antes de implementar:** confirmar com o usuário se a consultoria já usa uma
tabela de prazos por nível de risco com clientes, ou se derivamos uma da BS 8800. Não
inventar a tabela: é conteúdo técnico que sai num documento de NR-01.

### 3. Código do documento

Eles têm "AEP-FRPRT NR01 / HSE-SIT-UK" no topo da capa — um identificador do tipo de
documento. O nosso laudo não tem número nem código, o que dificulta o cliente arquivar e
referenciar. Barato; cabe como bloco editável da capa.

### 4. Numeração de seção em círculo

Puramente estético: eles usam um círculo numerado antes do título da seção
("① IDENTIFICAÇÃO"), o que deixa a leitura mais escaneável que o nosso "1. Introdução —".
Custo baixo, valor cosmético. Cuidado: mexe no CSS do laudo, que vive dentro do template
literal `const css` em `_buildLaudoHTML` — uma crase ali quebra o `<script>` inteiro.

---

## Anexar imagens e arquivos ao relatório

Pedido do usuário a partir da ferramenta concorrente. **Tem valor real** — registro
fotográfico do posto, organograma, evidência de divulgação, ata de CIPA são anexos comuns
num laudo de NR-01.

**Mas NÃO cabe na arquitetura da edição de textos**, e essa é a conclusão importante:

- A edição de textos vive em `sessionStorage` (decisão explícita de "só na sessão"), que
  tem cerca de 5 MB por origem. Uma foto de celular em base64 passa de 4 MB sozinha — a
  primeira imagem já estoura, e o modo de falha é silencioso.
- Fazer direito exige **Supabase Storage**: bucket, política de acesso, tabela de anexos
  com `tenant_id`/`empresa_id`, migration e RLS. Vira dado persistente, com backup e custo
  de armazenamento. É uma feature própria, não uma extensão do editor.
- **Ponto de LGPD que precisa de decisão do usuário, não técnica:** a regra 2 do projeto é
  que as respostas são anônimas — o sistema nunca coleta nome nem CPF. Uma foto do ambiente
  pode conter trabalhadores identificáveis, num documento que hoje não carrega identidade
  nenhuma. Anexar imagem muda a natureza do documento nesse aspecto.

**Se avançar:** tratar como projeto separado, com persistência de verdade. Um meio-termo
possível para reduzir peso é comprimir no client (canvas → JPEG ~0.75, lado maior ~1200px)
antes de subir, mas isso não substitui o Storage.

---

## O que NÃO copiar do concorrente

Anotado porque é fácil confundir defeito com recurso ao olhar a tela de outro produto:

- **"17/09/2026, 21:04 | AVALIA NR01…" no topo da página** é o cabeçalho de impressão do
  NAVEGADOR vazando para o PDF deles — falta `@page { margin: 0 }`. O nosso gerador já
  tem isso no `const css`. É defeito, não recurso.
- **"Consultoria não disponível"** estampado na capa: campo vazio exibido como mensagem de
  erro para o cliente final. O nosso `_estPerfil` tem fallback para o nome do produto.
- **"Número de Trabalhadores Avaliados: 1"**: eles emitem laudo com um respondente e sem
  nenhuma noção de representatividade. A tela de Adesão e `calcRepresentatividade()` são
  uma vantagem nossa; não perder isso de vista ao copiar layout.
- **Título ocupando quatro linhas** no meio da capa, desequilibrando a página.

---

## Ideias já levantadas antes e ainda abertas

Vindas das notas anteriores, repetidas aqui para ficarem num lugar só:

- **Tela de Relatório não tem filtro de Funções**, enquanto Resultados e Gráficos têm
  (assimetria pré-existente, nota de 2026-09-18).
- **Converter as tabelas profundas da Metodologia para fonte única.** Probabilidade,
  Severidade, Matriz P×S, Couto e Conduta ainda são montadas de `METODOLOGIA.*` no preview
  e por HTML próprio no PDF. Hoje divergem em forma, não em conteúdo. Seria o mesmo padrão
  de `_laudoCapaHTML`/`_laudoAcoesDoGrupo` (nota de 2026-09-22).
- **Rótulos dos metadados da capa editáveis** ("EMPRESA AVALIADA" → outro texto). Os
  VALORES seguem calculados, pela regra de que bloco editável não carrega dado calculado.
- **Paginação fiel no preview.** Hoje uma folha do preview é uma SEÇÃO, não uma página do
  PDF. Fazer de verdade exige medir altura em milímetros e quebrar por página — ou seja,
  uma segunda implementação da paginação, que é justamente a classe de bug que o CLAUDE.md
  registra como recorrente neste código. Só encarar com fonte única de paginação.
