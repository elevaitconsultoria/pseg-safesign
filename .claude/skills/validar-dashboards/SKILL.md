---
name: validar-dashboards
description: Compara e valida prints/screenshots de dashboards, tabelas ou telas de UI para checar se os dados batem entre duas versões (painel antigo vs novo, homologação, staging vs prod, antes/depois de uma mudança). Use esta skill sempre que o usuário enviar duas ou mais imagens de dashboards/painéis/tabelas pedindo para comparar, validar, checar divergência, conferir paridade de valores, ou perguntar "os números batem?" — mesmo que não use a palavra "validação" explicitamente. Também use quando o usuário pedir um resumo de progresso de validações já feitas na conversa (quais telas foram aprovadas, pendentes, etc).
---

# Validar Dashboards

Compara pares (ou conjuntos) de screenshots de dashboards/tabelas para confirmar que os dados exibidos são equivalentes entre duas versões de uma tela — independentemente do domínio (financeiro, e-commerce, RH, operacional, etc). O conteúdo específico de cada dashboard (nomes de campos, KPIs, linhas de tabela) varia totalmente de caso a caso; esta skill não assume nenhum schema fixo — tudo vem do que está visível nas imagens enviadas.

## Por que a ordem dos passos importa

O erro mais caro nesse tipo de validação não é bater um número errado — é comparar dois registros/escopos **diferentes** como se fossem o mesmo, e reportar uma "divergência" que na verdade é só duas coisas diferentes sendo mostradas. Por isso o passo de confirmar identidade/escopo vem sempre antes de comparar qualquer valor.

## Passo 1 — Identificar a tela/aba sendo validada

Antes de comparar qualquer coisa, determine qual tela, aba ou visão do produto está em jogo (ex: "Painel Geral", "Detalhe do Pedido", "Relatório de Vendas por Região"). Tente extrair isso das próprias imagens — títulos, cabeçalhos, breadcrumbs, nomes de rota visíveis. Se não conseguir inferir com segurança, pergunte ao usuário qual tela está sendo validada. Isso importa porque o resumo final é organizado por tela, não por número de mensagens trocadas (veja Passo 7).

## Passo 2 — Confirmar que as imagens são do mesmo registro/escopo

Este é o passo mais importante da skill. Cada dashboard tem seus próprios campos de identificação — pode ser um ID, um nome, um período, um filtro aplicado, uma categoria. Não existe uma lista fixa de "campos de identidade": olhe as imagens e identifique o que ali funciona como identificador único daquele recorte de dados.

Antes de comparar qualquer valor, confirme que os dois (ou mais) prints mostram o **mesmo** registro/escopo. Se os identificadores divergirem (ex: um print mostra o Produto A e outro o Produto B, ou um mostra o período Jan-Mar e outro Jan-Dez), **pare e avise o usuário explicitamente** em vez de seguir comparando valores. Comparar escopos diferentes sempre vai gerar diferenças numéricas — mas isso não é uma divergência real de dados, é um erro de setup da comparação. Deixe isso claro na resposta e não prossiga com a tabela de comparação até que o usuário confirme ou reenvie imagens do mesmo escopo.

Se o usuário avisar de antemão que os identificadores estarão mascarados/anonimizados ou vão variar (nomes trocados, dados de teste), ainda assim tente confirmar por outros sinais disponíveis (números de ID, datas, contagem de linhas, estrutura) — não pule esse passo, apenas adapte a que sinais você recorre.

## Passo 3 — Extrair todos os pontos de dado comparáveis

Percorra cada imagem e liste todo valor que aparece nas duas: cards de KPI, linhas e colunas de tabela, valores de gráfico, percentuais, totais/totalizadores. Não se prenda a "os KPIs do topo" — tabelas de detalhe e gráficos embutidos também fazem parte da comparação.

## Passo 4 — Montar a tabela de comparação lado a lado

Estruture a resposta principal como uma tabela: `Campo/Linha | Valor A | Valor B | Status`. Use os nomes de campo exatamente como aparecem nas imagens (não traduza nem padronize para uma terminologia genérica sua). Status pode ser: bate (✅) / diverge (❌) / não visível (⚠️).

## Passo 5 — Sinalizar dados incompletos, não assumir que batem

Tabelas com rolagem, paginação, ou colunas cortadas nas bordas da imagem podem esconder linhas que não estão nas duas versões. Quando um valor não estiver totalmente visível em uma das imagens, marque isso explicitamente como "não visível / possivelmente cortado por rolagem", em vez de simplesmente omitir a linha ou assumir que ela bate. Se o totalizador de uma tabela não fechar com a soma das linhas visíveis, isso é um sinal forte de que há linhas ocultas — mencione isso ao usuário.

## Passo 6 — Separar divergência real de diferença cosmética

Nem toda diferença entre as duas imagens é um problema de dado. Diferenças de rótulo/wording, formatação (prefixo de moeda presente/ausente, percentual exibido como decimal cru vs "%", ordem dos cards na tela) são diferenças de **copy/UX**, não de dado. Relate as duas categorias, mas deixe claro que são coisas diferentes — divergência de valor numérico é o que bloqueia homologação; diferença cosmética é sugestão de melhoria.

## Passo 7 — Rastrear o status por tela ao longo da sessão

Quando o usuário pedir um resumo de progresso ("quantas validações fizemos", "o que já foi aprovado"), responda agrupado por **tela/aba**, não por número de rodadas de comparação feitas. Cada tela deve ter um status: aprovada / pendente (com o motivo) / reprovada / ainda não avaliada (por falta de imagens ou por escopo inválido no Passo 2).

Inclua uma coluna de **% aproximado de aprovação** por tela: 100% se todo valor comparado bateu; proporcionalmente menor se alguns campos divergiram (estime com base na fração de itens que bateram); N/A se a tela não pôde ser avaliada (escopo inválido, imagens incompletas, ainda não enviada).

## Formato de resposta

Ao concluir uma comparação, a resposta deve conter, nesta ordem:
1. Confirmação de que as imagens são do mesmo escopo (ou aviso de que não são, encerrando ali)
2. Tabela de comparação campo a campo
3. Observações sobre dados incompletos/cortados, se houver
4. Divergências reais vs cosméticas, claramente separadas
5. Veredito da tela (aprovada / pendente / reprovada) e, se solicitado, o resumo consolidado de todas as telas já vistas na sessão
