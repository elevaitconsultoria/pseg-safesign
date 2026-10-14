# HSE/ICAO-35 — revisão completa, motor testado, laudo novo e UX de metodologia (2026-10-13)

> Branch **`feat/hse-icao35-sim`** (worktree `../pseg-safesign-hse`, **só local**). **Nada em `develop` nem em PROD**, como manda o usuário.
> Nenhuma migration, nenhum dado novo em banco: tudo é front-end (`psicomap-admin.html`) + scripts em `_dev/`.
> Ponto de entrada geral continua sendo `2026-10-13-hse-handoff-proxima-sessao.md`; esta nota detalha a revisão.

## 1. O pedido
Revisar a implementação inteira do HSE: gaps, o que está bom e o que não está; motor de cálculo garantido e testado; relatório com
layout novo usando o do outro player (F2) como referência; análises pela divisão do HSE (as 7 dimensões); UX das telas onde se
escolhe a metodologia; código e documentação.

## 2. Diagnóstico — o que estava bom
| Área | Leitura |
|---|---|
| Modelo de dados | Metodologia no ciclo (imutável), snapshot na resposta, tabelas próprias, versão congelada por questionário (B21). Correto. |
| Coleta | RPC anônima + `salvar_resposta` com ramo HSE que rejeita incompleto/duplicado/fora da escala. Correto e testado em DEV. |
| Fórmula | Inversão só em Demandas/Relacionamentos; dimensão = média das médias dos itens (= média por respondente, porque os 35 itens são obrigatórios — conferido por SQL). |
| Exemplo F2 | Reproduzido exatamente (7 dimensões, índice, zona, média simples 55,9%). |
| Anonimato | n mínimo aplicado em tela, laudo, CSV; recorte pequeno diz que foi omitido. |
| Laudo | Gerador único (preview = PDF), pré-checagem, selos de rascunho/critério não validado, sem placeholder. |

## 3. Diagnóstico — o que NÃO estava bom (e o que foi feito)
| # | Achado | Gravidade | Situação |
|---|---|---|---|
| 1 | **`_hseMetaCache` global contaminava o cálculo**: abrir uma empresa na v1 e outra na v2 na mesma sessão fazia a segunda mostrar "5 de 10 itens" e itens vazios; CSV e snapshot do laudo levavam itens de outro questionário. | Alta (número errado no laudo) | **Corrigido**: `_hseMetaDasLinhas`; o motor filtra sozinho. |
| 2 | Ciclo com respostas de **duas versões** do questionário (versão nova publicada no meio da coleta) contaria 70 itens. | Média | **Corrigido**: itens casados por código; aviso na tela e na pré-checagem. |
| 3 | **Faixa decidida em ponto flutuante**: 2,7499999 aparecia "2,75" e caía noutra faixa que um 2,75 exato. | Média | **Corrigido**: decide em centésimos inteiros. |
| 4 | Laudo dizia "frequência nos itens 1 a 23; concordância nos 24 a 35" — **falso para a v2** (escala única). | Média (texto errado no documento) | **Corrigido**: a escala é lida dos próprios itens. |
| 5 | Laudo em formato de tabelas: sem página-resumo, sem página por dimensão, sem leitura do que cada dimensão significa, recomendação genérica. | Média (produto) | **Refeito** (§4). |
| 6 | Nenhuma ação por dimensão HSE (Plano de Ação bloqueado no HSE). | Média | **Feito**: `HSE_DIM_INFO` + Plano de Ação HSE. |
| 7 | Adesão cega ao HSE (0% em ciclo HSE). | Média | **Corrigido** antes desta revisão (`6e680b9`). |
| 8 | Decimais misturados (2.47 ao lado de 38,3%). | Baixa | **Corrigido**: `_hseNum`. |
| 9 | Telas só-BS (Distribuição, Auditoria) num ciclo HSE davam um aviso sem saída. | Baixa (UX) | **Melhorado**: aviso diz onde está o resultado, com atalhos. |
| 10 | Filtros que não valem para o HSE (nível de risco, seções/textos do laudo BS, exportação BS) ficavam visíveis. | Baixa (UX) | **Feito**: somem num ciclo HSE e voltam no BS. |
| 11 | Selects de ciclo misturavam as metodologias; "Todos os ciclos" não dizia que exclui o HSE. | Baixa (UX) | **Feito**: `optgroup` por metodologia; "Todos os ciclos BS 8800". |
| 12 | Cartão do HSE no "Novo ciclo" dizia "Sem nível P×S" — desatualizado desde o S8b. | Baixa | **Corrigido** + link "Qual escolher?" para a aba nova da Metodologia. |

## 4. Laudo HSE — novo layout
Referência: relatório F2 do player (página-resumo única; uma página por dimensão com barra por item; tabelas de critério impressas),
**sem os defeitos dele** (placeholder, seção vazia, score global como manchete, resultado de 1 pessoa, "Inadequado" por amostra).

| Seção | Conteúdo |
|---|---|
| Capa / Índice | Índice gerado da lista real de seções (numeração corrida: sem comparação, as seguintes sobem um número). |
| 1. Identificação e amostra | + lista de recortes avaliados com n (abaixo do mínimo: "menos de 5"). |
| 2. Metodologia | Tabela das 7 dimensões (o que avalia, nº de itens, sentido da resposta); escala lida dos itens; faixas; índice/zonas fixas e favoráveis/desfavoráveis explicados. |
| 3. **Resumo dos resultados** | 4 indicadores (respondentes, taxa, dimensões que pedem ação, dimensões "Muito bem"); barras das 7 dimensões com a referência; "Como ler"; pontos de atenção × favoráveis. **Sem nota global** (o HSE não define). |
| 4. **Análise por dimensão** (4.1–4.7) | **Uma página por dimensão**: indicadores, *o que avalia*, *estado esperado (Management Standards)*, itens com barra desfavorável/neutro/favorável + média + índice, comparação **por recorte** e **ações sugeridas** quando a faixa pede ação. |
| 5. Comparação entre recortes | Mapa recortes × dimensões colorido pela faixa (só com segmentação). |
| Risco para o PGR | Igual ao anterior (critério 4×4 + severidade de SST), por recorte. |
| Plano de ação sugerido | Prioridades (Ação urgente → Necessidade clara; menor score), nível PGR e 3 ações por dimensão; assinatura. |
| Limitações e responsabilidades | Texto fixo novo (percepção, anonimato, taxa, base do benchmark, critério da consultoria; papéis consultoria × empresa). |
| Referências | + Management Standards. Atribuição OGL em toda página. |

**Leitura de "favorável/desfavorável"**: % das respostas, já normalizadas, em 4–5 / 1–2. Mostra o padrão bimodal que a média esconde
(F2: Clareza de papel 2,60 = 40% fav. / 60% desf.).

## 5. Análise pela divisão do HSE (tela e plano)
- **Resultados**: mapa "Comparação entre recortes" quando a análise é segmentada (setor/GHE/agrupamento); cada dimensão ganhou a barra
  fav./desf., o que avalia e "Ações sugeridas" (com o estado esperado) quando está em Ação urgente/Necessidade clara.
- **Plano de Ação** (antes bloqueado no HSE): cartão por dimensão prioritária com Por quê / Onde (setores em Ação urgente; "também
  abaixo da referência" separado) / O quê / Quem·Quando·Quanto = "a definir com a empresa". Mesma fonte do laudo.
- **`HSE_DIM_INFO`**: texto-base nosso, resumindo os "estados a atingir" dos Management Standards (OGL). **Revisão de SST pendente.**

## 6. UX de escolha de metodologia
| Onde | Mudança |
|---|---|
| Novo ciclo | Cartões reescritos (o que cada um entrega, escala, PGR); aviso de que metodologias nunca se somam; link **"Qual escolher?"**; `aria-pressed`. |
| Metodologia (tela) | Aba nova **"HSE × BS 8800"** (só com HSE ativo): comparação lado a lado, quando preferir, quais telas leem HSE, as 7 dimensões. |
| Novo link | Select de ciclo agrupado por metodologia + linha dizendo qual questionário o funcionário responderá. |
| Resultados / Relatório / Distribuição / Auditoria / Plano | Select agrupado; "Todos os ciclos BS 8800" quando a empresa tem HSE; filtros só-BS somem no ciclo HSE (e voltam), com cartão explicativo; avisos com atalhos. |

## 7. Testes feitos
| Teste | Resultado |
|---|---|
| `npm run test:hse` (99 casos) | ✅ — F2 exato; limites de faixa e zona; inversão; matriz de risco; cache v1+v2; ciclo com 2 versões; taxa; prioridades; catálogo; **simulação de DEV = SQL** (geral e por setor). |
| Mesmo teste contra o código de antes | ❌ 25 falhas — pega os bugs 1, 2 e 3 de verdade (não é teste de fachada). |
| SQL independente em DEV (66 respostas) | Média por respondente = média das médias dos itens nas 7 dimensões; por setor bate com a tela. |
| Fixture offline (`--fixture`, seed 2026) | Reproduz as médias do banco de DEV nas 7 dimensões (4 casas). |
| Browser (harness, sem login) | Resultados segmentado (mapa + blocos), Plano HSE, aviso de Distribuição, laudo segregado (17 páginas, 9 seções) e consolidado (sem seção 5, numeração corrida), recorte com 3 pessoas omitido em **todas** as 10 ocorrências, aba Metodologia, select agrupado, instrumento no modal de link, filtros só-BS somem/voltam. |
| `check-inline-js`, `check-build` | ✅ |

**Não testado:** sessão logada real (RLS) e **PDF impresso** (paginação das páginas por dimensão — Demandas com 8 itens + recortes + ações pode passar de uma folha; o fluxo continua, mas conferir num PDF real).

## 8. Gaps que continuam abertos
1. **Diferença por complemento**: com "Geral" e todos os setores menos um visíveis, o setor omitido pode ser deduzido por subtração. O n mínimo não cobre isso (mesma família do k-anonimato de filtros combinados — decisão 4.2-5 do handoff).
2. Distribuição, Auditoria e Comparativo seguem só BS 8800 (o aviso agora aponta onde ver o HSE).
3. Benchmark **setorial** (já no banco de DEV) ainda não é selecionável — o laudo usa só o GERAL.
4. Textos fixos novos (`HSE_DIM_INFO`, Limitações, Responsabilidades, Plano) precisam de **revisão de SST**, como o resto do laudo.
5. Tudo de 4.1/4.2 do handoff (B1, B12, severidade assinada, n mínimo definitivo, decisões H22/H08/H26, ordem dos itens, 4×4 × 5×5, CSV por respondente).
6. Integração com `develop` (ciclo → campanha) — agora com mais linhas novas no admin; fazer num worktree próprio.

## 9. Como reproduzir
```bash
cd ../pseg-safesign-hse
npm run test:hse                                   # motor (99 casos, sem rede)
node _dev/simular-hse.js --fixture _dev/fixture-hse-sim.json --seed 2026 \
  --setores "Produção:36:critico-demandas,Administrativo:18:bom-gestor,Logística:12:conflito"
node _dev/harness-hse.js ../pseg-safesign/dist/_harness-hse/harness.html   # dist/ é gitignored
# servir a pasta por HTTP (preview "PsicoMap — Static (Python)" serve o diretório principal na 8080) e, no console:
#   await __hse.instalar(); await __hse.resultados('segregado'); await __hse.laudo('segregado'); await __hse.plano()
```
