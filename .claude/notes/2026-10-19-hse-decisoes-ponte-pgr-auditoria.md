# HSE — decisões do usuário (2026-10-19), estudo da ponte 4×4 para o PGR, média simples e Auditoria

> Branch `feat/hse-icao35-sim` (worktree `../pseg-safesign-hse`), **só local**. Nada em `develop`/PROD, sem migration e sem dado novo em banco.
> Continuação de `2026-10-13-hse-revisao-completa.md` §10. Análise do COPSOQ e da arquitetura multi-metodologia: `2026-10-19-copsoq-e-arquitetura-multi-metodologia.md`.

## 1. As decisões (respostas às perguntas abertas do handoff §4.2)

| # | Pergunta | Decisão | Consequência |
|---|---|---|---|
| 1 | H22, H08, H26 mal traduzidos | **Manter o texto como está** | Nada muda no seed v2. **B1 continua valendo** (texto validado + permissão): o texto é de terceiro e **nunca vai para PROD** assim. Registrado em §2. |
| 2 | Ordem dos itens | **A recomendação minha** → **manter intercalada** (a do HSE original) | Nenhuma mudança de código. Argumentos em §3. |
| 3 | Ponte para o PGR: 4×4 ou 5×5 | **Manter 4×4**; "fazer o estudo e aplicar em formato similar ao que já temos" | Estudo em §4; o que foi aplicado em §5. |
| 4 | Média simples no laudo | **Criar, e melhorar se necessário** | Feito em §6 (laudo, tela e comparativo). |
| 5 | Auditoria resposta a resposta para HSE | **Permitir**, pela melhor forma | Feito em §7, com anonimato tratado. |
| 6 | COPSOQ no futuro: "pense nisso" | Análise | `2026-10-19-copsoq-e-arquitetura-multi-metodologia.md`. |

**Sobre "o player também tinha 4×4":** o único documento dele que tenho (F2, 23 páginas) diz literalmente "matriz de risco 5x5" e a matriz impressa
tem P1–5 × S1–5. Se existe outro documento/versão com 4×4, mande: comparo com a nossa. Até lá, **manter a nossa 4×4 não depende disso** — ela é a mesma
matriz do BS 8800 (um argumento próprio, §4.4).

## 2. H22, H08, H26 (manter) — o que fica registrado
- O texto da v2 continua sendo o do formulário F1 do outro player, `config.rascunho = true` e selo RASCUNHO no laudo.
- **Limitação declarada, não corrigida:** a v2 reescreve os itens de concordância (24–35 do HSE) como pergunta de **frequência** (escala única). Isso muda o
  formato de resposta do instrumento validado na ICAO-35. Para uso real, B1 (texto validado + permissão dos autores) é pré-requisito; `seed_hse_icao35_validado.sql`
  (go-live) deve abortar com `config->>'rascunho'='true'`.

## 3. Ordem dos itens — recomendação adotada: **intercalada**
1. **Comparabilidade com a referência.** A referência (benchmark HSE 2023) e a validação brasileira (ICAO-35: EFA, α de Cronbach) foram feitas com o questionário na ordem
   original. Reordenar muda o contexto de cada pergunta (efeito de ordem, *priming*, halo), e o resultado deixa de ser rigorosamente comparável.
2. **Itens de uma mesma dimensão juntos revelam o construto** ("estas 8 perguntas são sobre pressão") e favorecem a aquiescência (responder tudo no mesmo tom). A dimensão nunca aparece
   para o respondente — só no relatório.
3. **O F1 agrupa por dimensão por ser ficha para correção manual** (somar à mão por bloco), não por ser melhor para quem responde.
4. **Custo zero para mudar depois:** o formulário já ordena por `ordem`; mudar a ordem é uma **versão nova** do questionário (B21), sem código.
5. A auditoria e o laudo são independentes da ordem (usam o código H01..H35).

## 4. Estudo da ponte HSE → inventário do PGR (4×4 × 5×5)
Reprodutível: `node _dev/estudo-ponte-pgr.js` (usa o motor do próprio admin; sem rede). O "player 5×5" é a engenharia reversa do F2 (nota 2026-10-08 §5): P por faixas fixas de % (90/75/60/40),
matriz lida célula a célula, S variável por dimensão. **Fala só daquele documento, não do produto dele.**

### 4.1 As duas matrizes (mesmos nomes de nível)
```
Nossa 4×4                                   Player 5×5 (colunas S1..S5)
P4  MÉDIO  ALTO   ALTO   CRÍTICO            P5  BAIXO  MÉDIO  ALTO  CRÍTICO CRÍTICO
P3  BAIXO  MÉDIO  ALTO   ALTO               P4  BAIXO  BAIXO  MÉDIO ALTO    CRÍTICO
P2  BAIXO  BAIXO  MÉDIO  ALTO               P3  IRREL. BAIXO  MÉDIO ALTO    CRÍTICO
P1  IRREL. BAIXO  BAIXO  MÉDIO              P2  IRREL. BAIXO  MÉDIO MÉDIO   ALTO
                                            P1  IRREL. IRREL. BAIXO MÉDIO   MÉDIO
```
Os dois produzem os mesmos **cinco níveis** (Trivial…Intolerável = IRRELEVANTE…CRÍTICO).

### 4.2 Resultado do estudo (números do script)
| Teste | Resultado | Leitura |
|---|---|---|
| Exemplo do F2, mesmo S | **4 de 7 iguais · 3 com o nosso 1 nível acima · 0 abaixo** | Nunca mais permissivo que o documento de referência. As 3 diferenças vêm da faixa relativa (Papel: referência 4,16) e da matriz. |
| Organização exatamente na média mundial | player: **P≥3 em 4 de 7** (P4 em Demandas e Mudanças); nossa: **P2 em todas** | Cortes fixos tornam "amarelo" o estado normal (a crítica da nota de 08/10, agora medida). A nossa é calibrada pela média: "como a maioria". |
| 20.000 organizações simuladas × 7 dimensões | **41,1% iguais · 55,1% o nosso mais alto · 3,9% mais baixo** (+1: 44,3%; +2 ou mais: 10,8%) | Parte vem do **desenho da matriz**: a nossa tem P4 e S4 como máximos (P4 = "quase certo"), então os mesmos numerais caem em nível mais alto. **Mais alto ≠ mais correto**: são calibrações diferentes. |
| Sensibilidade a S | ±1 em S desloca o nível **0,56–0,69** por dimensão | A severidade pesa tanto quanto a faixa. É por isso que S é decisão de SST, **versionada e assinada**. |
| Alerta de piso absoluto | só 3 referências podem dar zona fixa vermelha com faixa ≠ "Ação urgente": **Saúde/Demandas, Educação/Demandas, Emergência/Mudanças**; com o **Geral nunca** | O risco que preocupava (referência setorial baixa esconder problema absoluto) é pequeno e foi **sinalizado**, não "corrigido" (§5). |

### 4.3 Diferença estrutural que decide: S fixo × S variável
No F2, S varia por dimensão sem ser fixo (Controle e Apoio com S1, Demandas com S4): indício de que S depende do resultado. Se S depende do mesmo número que gerou P, **P e S deixam de ser independentes** e a matriz conta o mesmo dado duas
vezes (nota 2026-10-08 §5.2). Na nossa, **S é uma propriedade do perigo** (fixa por dimensão, definida e assinada por SST, com versão): auditável, reproduzível, e não muda de um relatório para outro.

### 4.4 Por que manter a 4×4 (e o que ela dá que a 5×5 não dá)
1. **Uma régua só para o inventário do PGR**: a matriz é a do BS 8800 (`MATRIZ_RISCO`), os cinco níveis e a **conduta administrativa** (`CONDUTA_ADMINISTRATIVA`) são os mesmos. Um cliente com um ciclo BS 8800 e outro HSE tem **um** inventário com a mesma escala.
2. **Os critérios de severidade (S1–S4) já existem** (`S_CRITERIA`, tabela do documento PsicoMap) e passam a valer para as duas metodologias.
3. P pela **faixa do benchmark** (não por % fixo) evita o "amarelo é normal"; e as zonas fixas continuam ao lado, como leitura cruzada.
4. Nenhuma conversão entre metodologias: a ponte produz **a entrada do inventário**, nunca compara HSE com BS 8800 (regra de arquitetura mantida).

**Recomendação:** manter 4×4, benchmark para P, S fixo assinado. Não adotar a 5×5.

## 5. O que foi aplicado — "formato similar ao que já temos"
Tudo no laudo e na tela, reaproveitando o que o BS 8800 já tinha:
| Item | Onde | Origem |
|---|---|---|
| **Conduta administrativa por nível** (5 níveis, com marca do que aparece no documento) | Laudo, página "Risco psicossocial — conduta, severidade e cortes"; Plano de Ação (tela): selo "PGR: ALTO" + conduta | `CONDUTA_ADMINISTRATIVA` do BS 8800 (a nota de 08/10 já elogiava o "nível → ação" do player) |
| **Critérios de severidade S1–S4** + quais dimensões têm cada S | Laudo (mesma página); card de severidade (Gestão de ESTs) | `S_CRITERIA` do BS 8800 |
| **Pontos de corte da leitura por dimensão** (ref−0,50 · ref · ref+0,40, com o índice equivalente) | Laudo | novo (`_hsePontosCorte`; testado contra `_hseFaixa` nas 6 fronteiras × 7 dimensões) |
| **Agente/fator por dimensão** na tabela de risco | Laudo e tela | `HSE_DIM_AGENTE` (redação nossa) |
| **Nível de risco por recorte** num mapa só (recorte × dimensão) | Laudo | novo (substituiu uma tabela completa por recorte) |
| **Alerta ⚠ de piso absoluto** (zona fixa vermelha com faixa ≠ Ação urgente) | Tabela de risco (tela e laudo) | novo; **não altera P nem a faixa** (ficaria incoerente com a leitura) |
| **Proposta de partida de severidade para a SST** | Card de severidade: botão "Preencher com a proposta" + critérios visíveis | novo; **só preenche o formulário**; salvar e validar seguem exigindo as 7 severidades, o responsável e a confirmação |

### 5.1 Proposta de partida de severidade (para a SST revisar — **não é validação**)
| Dimensão | S | Raciocínio (critérios do BS 8800) |
|---|---|---|
| Demandas | **S3** Sério | Sobrecarga crônica → estresse crônico, esgotamento, distúrbios do sono (critério S3); DORT associados |
| Relacionamentos | **S3** Sério | Conflitos/assédio → ansiedade, afastamentos; há implicação legal |
| Controle, Apoio da gestão, Suporte dos colegas, Clareza de papel, Mudanças | **S2** Moderado | Frustração, irritabilidade, fadiga moderada, queda de motivação (critério S2); agravam o efeito das demandas |
Textos de "possíveis danos" propostos estão em `HSE_PROPOSTA_SEVERIDADE` (redação nossa). Com esses S, o inventário fica: organização mediana → Demandas e Relacionamentos MÉDIO, o resto BAIXO; exemplo do F2 → Demandas, Papel e Mudanças ALTO, Suporte, Relacionamentos MÉDIO.

## 6. Média simples — "visão sintética" (tela, laudo, comparativo)
Decisão: **criar**. Melhorias para não repetir o defeito do player (manchete "Atenção" × inventário "Intolerável" no mesmo documento):
- **Nunca sozinha**: o texto traz, junto, **quantas dimensões pedem ação** (e quais estão em "Ação urgente") e **a mais baixa**; diz que o HSE não define score global e que a média **não recebe faixa** (não existe corte do HSE para ela).
- Mostra a **média das 7 referências** e a diferença (ex.: 3,50 × 3,76 = −0,27), além do índice de favorabilidade.
- **Laudo** (página do Resumo): caixa "Visão sintética (referência interna)". **Tela de Resultados**: no lugar da nota solta. **Comparativo**: linha "Média simples (referência)" com a variação entre ciclos.
- Dimensão sem dado → **nada** (não inventa média). Testes: F2 = 3,237 / 55,9%; referência = média das 7; pior = Demandas.

## 7. Auditoria resposta a resposta para HSE
Antes: a tela dizia "ainda não existe para o HSE". Agora funciona como a do BS 8800 **com o que o BS não tem**.

### 7.1 O que a tela mostra
Resumo de **qualidade** (respostas e período; completas; **uniformes** = todas iguais e **quase uniformes** ≥ 90% iguais; **sem LGPD**; **sessões repetidas**; links; versões do questionário) e a tabela por resposta
(ID, setor, função, escolaridade, data, versão, itens n/35, **alertas**, LGPD, dispositivo e os 35 valores **brutos**, com ↺ nos itens invertidos). Alertas são sinais de **qualidade do dado, não de culpa**. Exportação CSV da própria tabela.

### 7.2 Como o anonimato foi tratado (decisão de projeto)
O problema é real: setor + função + escolaridade + dia de resposta podem apontar uma pessoa. O BS 8800 mostra tudo isso (e o `session_id` inteiro e a hora). Para o HSE:
| Controle | Como |
|---|---|
| **k-anonimato dos identificadores** | `_hseGeneralizarCSV` (o mesmo do CSV): combinação com menos de 5 pessoas perde escolaridade → função → setor ("Outros setores"/"Outras funções"). As **respostas não mudam**. |
| **Filtros sobre o que é exibido** | Setor e função são filtrados pelos valores **generalizados**. Filtrar por valor bruto revelaria quem é ("filtro RH → 3 linhas 'Outros setores'") — é um ataque de diferença. |
| **Sem hora, ID aleatório, ordem sem relação com a chegada** | Data só como dia; ID = início do `session_id`; tabela ordenada por ele (numerar por ordem de chegada revela "o primeiro a responder"). |
| **n mínimo no ciclo** | Com menos de 5 respostas reais a **tabela não abre** (o resumo abre). |
| **Modo "Respostas de teste"** | Mostra as de **links de teste** (que as análises excluem), com dados originais, sem restrição — serve para validar a coleta (formulário → banco → análise) com poucas respostas. |
**Risco residual aceito e declarado na tela:** dia + grupo de 5 ainda pode ser reconhecido por quem sabe quando respondeu. A Auditoria continua restrita por papel (não abre para `cliente_viewer`).

### 7.3 Implementação
`carregarRespostasHSE(empId, cicloId, {auditoria, teste})` (colunas extras só quando pedidas); funções puras `_hseAuditoriaAvaliar/_hseAuditoriaResumo/_hseAuditoriaPreparar` (testadas); bloco `HSE (AUD)`; roteamento em `renderTelaAuditoria`; voltar de um ciclo HSE recarrega o combo de setor real (o BS 8800 usa o valor bruto). Limpeza de estado em `_limparEstadoTenant`.

## 8. Testes
| | |
|---|---|
| `npm run test:hse` | **161 casos** ✅ (+35: média, cortes × `_hseFaixa` nas fronteiras, conduta, severidade, alerta de piso, avaliação/resumo/preparo da auditoria, k-anonimato da auditoria) |
| Harness no navegador (sem login), com `comQA()` (uniformes, quase uniforme, sem LGPD, sessão repetida, 4 respostas de teste) | Alertas e KPIs corretos; filtro sobre valores generalizados (8 linhas "Outros setores", 7 de Logística); ciclo com 3 respostas → tabela oculta e resumo aberto; modo teste abre com dados originais; busca por ID; card de severidade com critérios e botão (preenche 3,2,2,2,3,2,2 sem marcar "validar") |
| PDF real (Chrome headless) | **18 folhas** no segregado (+1: página de conduta/critérios/cortes), 17 no consolidado, 18 com recorte oculto; nenhuma folha quase vazia (a menor é a de Referências, 30%). **Achado:** a regra de ajuste de folha medindo no layout de tela superestimava a altura em ~9% (a `.page` é flex na tela e as margens não colapsam; na impressão é bloco) — num cenário sobrou uma folha com 8%; a medição agora usa `display:block`. O `msedge` headless parou de gravar o PDF nesta sessão; o Chrome funcionou |
| `check-inline-js`, `check-build` | ✅ |

## 9. Pendências que ficam
- B1, B12, severidade **assinada por SST** (a proposta é só ponto de partida), valor do n mínimo, textos fixos novos (`HSE_DIM_INFO`, limitações, conduta/critérios) para revisão de SST, teste logado em DEV, integração com `develop` (**agora 49+ commits à frente**).
- Se o documento do player com 4×4 existir, comparar (§1).
- Auditoria HSE: confirmar com o jurídico se "dia + grupo de 5" é aceitável (§7.2) ou se a data deve virar semana.
