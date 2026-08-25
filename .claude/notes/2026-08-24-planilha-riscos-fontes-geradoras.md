# Planilha oficial "Riscos Psicossociais e Fontes Geradoras" — referência

Fonte enviada pelo usuário no início do programa: `Riscos Psicosociais e fontes geradoras (1).xlsx`
(uma aba, `Planilha1`, 10 fatores × 5 colunas: Fator Ergonômico observado, Consequência, Fontes
Geradoras, Medidas de Controle, Plano de Ação). Extraída em 2026-08-24 para virar a fonte de
verdade do `CATALOGO_ACOES` em `psicomap-admin.html` — ver seção "Catálogo de Ações
Recomendadas" no `CLAUDE.md`.

## Mapeamento planilha ↔ `cd_risco`

| Linha planilha | Fator (planilha) | `cd_risco` | Nome em `RISCOS_DETALHES` |
|---|---|---|---|
| 2 | Carga de trabalho de excessiva | 1 | Carga de trabalho excessiva |
| 3 | Conflitos Hierárquicos | 6 | Conflitos hierárquicos no trabalho |
| 4 | Conflitos Interpessoais | 9 | Conflitos interpessoais no trabalho |
| 5 | Estresse por situações de constrangimentos no ambiente de trabalho | 4 | Constrangimento no ambiente de trabalho |
| 6 | Estresse por mudanças frequentes e não planejadas | 7 | Estresse por mudanças frequentes |
| 7 | Estresse por situações de desigualdade ou discriminação | **5 e 12** (split) | Estresse por situações de desigualdade / discriminação |
| 8 | Insatisfação no Trabalho | 8 | Insatisfação no trabalho |
| 9 | Sobrecarga de trabalho mental | 3 | Sobrecarga de trabalho mental |
| 10 | Desconfortos emocionais e físicos por trabalho em ambiente inadequado | 11 | Desconfortos por ambiente inadequado |
| 11 | Insegurança no emprego | 10 | Insegurança no emprego |

`cd_risco` 2 não existe na planilha nem em `RISCOS_DETALHES` nem em nenhuma questão do
questionário atual (`grep "cd:\s*2"` no admin não retorna nada) — confirmado como órfão, não
um gap real.

A linha 7 da planilha ("desigualdade ou discriminação") é a única que não tem correspondência
1:1 — o app já divide esse tema em dois `cd_risco` (5 = desigualdade, 12 = discriminação),
decisão pré-existente em `RISCOS_DETALHES`/`ACOES_SUGERIDAS`, mantida na unificação de
2026-08-24.

## Achado que motivou a unificação

Antes de 2026-08-24 existiam dois catálogos de ação separados: `ACOES_SUGERIDAS` (usado no
laudo, com texto por nível MÉDIO/ALTO/CRÍTICO) e `ACOES_5W2H` (usado na tela Plano de Ação,
formato O quê/Por quê/Onde/Quem/Quando/Como/Quanto). Comparando os dois contra esta planilha:

- `ACOES_SUGERIDAS` batia tematicamente com a planilha em 100% dos itens conferidos — não
  precisou de correção de conteúdo.
- `ACOES_5W2H` tinha 3 entradas (`cd_risco` 6, 7, 9) com texto de **outra taxonomia** — "falta
  de clareza de papéis" (cd6), "falta de apoio social" (cd7), "mudanças mal gerenciadas" (cd9)
  não correspondem aos fatores reais desses códigos na planilha (Conflitos Hierárquicos,
  Mudanças frequentes, Conflitos Interpessoais, respectivamente). Esses termos são dimensões do
  HSE Management Standards Indicator Tool — modelo que está em planejamento
  (`.claude/notes/2026-08-03-metodologia-hse-icao35-planejamento.md`), não desta planilha.
  Provável origem: rascunho anterior misturou referências de metodologias diferentes.
- `ACOES_5W2H` também tinha uma entrada órfã (cd 2, nunca acionável) e nenhuma entrada para
  cd 12 (discriminação).

## Resolução

`CATALOGO_ACOES` (psicomap-admin.html, ~linha 8421) unifica os dois catálogos por `cd_risco`,
cada entrada com `porNivel` (herdado do `ACOES_SUGERIDAS`, sem mudança de texto) e `w5h2`
(herdado do `ACOES_5W2H` para os `cd_risco` que já batiam — 1, 3, 4, 5, 8, 10, 11 — e reescrito
a partir das colunas D/E desta planilha para 6, 7, 9; novo para 12, espelhando o 5 com foco em
discriminação; removido o 2 órfão).
