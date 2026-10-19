# COPSOQ como terceira metodologia — o que o HSE construído ensina, o que o COPSOQ exige e como preparar a arquitetura

> Criado em 2026-10-19, a pedido do usuário ("todos os recursos serão adaptados; pense no COPSOQ"). **Análise e recomendação — nenhum código foi alterado por causa dele.**
> Complementa a análise antecipada de 03/08 (`2026-08-03-metodologia-hse-icao35-planejamento.md` §14, que continua válida) com o que só ficou claro **depois** de construir o HSE de ponta a ponta.

## 0. Resumo (leia só isto se tiver pouco tempo)
1. **A análise de 03/08 se confirma:** nenhum impeditivo de licença ou de validação; a decisão é de portfólio. Hoje há mais um dado: **não existe COPSOQ III validado para o Brasil** (só o COPSOQ II: curto, Gonçalves et al. 2021, e médio, Lima et al. 2019); Portugal tem COPSOQ III médio/curto.
2. **O que mais pesa não é técnico, é LGPD:** o COPSOQ pergunta **saúde** (burnout, estresse, saúde geral) e **comportamentos ofensivos** — são **dados pessoais sensíveis** (LGPD art. 5º, II). O HSE não pergunta isso. Exige consentimento específico, RIPD, e regras de anonimato mais duras. Detalhe em §4.
3. **O código HSE de hoje é ~1.900 linhas no admin + 30 no formulário, com 12 pontos de despacho `=== METODOLOGIA_HSE` e 4 tabelas `hse_*`.** Clonar para o COPSOQ repetiria tudo isso (e as armadilhas de tabela nova: GRANT/REVOKE do `anon`, RLS, backup).
4. **Existe uma janela barata, e ela fecha:** o HSE **ainda não está em PROD**. Generalizar o banco (`hse_*` → família `instrumento_*`) e o front (registro de metodologias) custa **agora** reescrever 4 migrations + 2 versões da RPC + 5 seeds + o guia de backup, e trocar **6 consultas** no admin (o formulário só usa a RPC); **depois do go-live** custa migração de dados de produção.
5. **Recomendação de sequência:** (1) integrar com `develop`; (2) generalizar **antes** do go-live do HSE; (3) go-live do HSE e validar em produção (o teste real do "motor por metodologia"); (4) só então o COPSOQ. O que fazer em cada passo está em §6.

## 1. O que já sabemos (e o que mudou hoje)
Resumo do que está em §14 do plano, com a atualização de hoje:
| Tema | Situação |
|---|---|
| Versão candidata | **COPSOQ II-Br curto** (Gonçalves, Moriguchi, Chaves & Sato, 2021, *Rev Saúde Pública* 55:69): 40 itens, 11 dimensões, 7 domínios. Existe também a média (Lima et al. 2019, 70 itens). |
| COPSOQ III no Brasil | **Não encontrado** (busca de 19/10/2026). A rede internacional lista, no Brasil, só COPSOQ II. Portugal: III médio (85 itens, Cotrim et al. 2022, *IJERPH*) e curto preliminar. Austrália tem III com referências. |
| Licença | CC BY-NC-ND 4.0 **com exceção comercial explícita**: não se cobra pelo questionário em si; cobra-se por avaliação, assessoria, análise, treinamento. **ND**: conteúdo adaptado **não pode ostentar o nome "COPSOQ"**. Pede contato prévio com a equipe nacional. (O "NC" × exceção comercial é ambíguo: confirmar por escrito com a rede antes de vender.) |
| Direção da escala | **Por dimensão**, não por instrumento ("each scale is scored in the direction indicated by the scale name"). |
| Referência | Sem tabela de referência brasileira publicável localizada; só a norma dinamarquesa tem divulgação ampla. O "farol" (verde/amarelo/vermelho) é conceitual. |
| Confiabilidade | "Comportamentos ofensivos" com α = 0,54 e efeito piso (69% "nunca") na amostra brasileira. |

## 2. O que o HSE construído ensina (lições que valem para a 3ª metodologia)
1. **Cálculo por instrumento, despachado em poucos pontos, funcionou** — a regra de 03/08 se confirmou. O que **não** funcionou bem foi o *despacho espalhado*: 12 `if (… === METODOLOGIA_HSE)` literais e pares fixos "BS, HSE" (`[METODOLOGIA_BS, METODOLOGIA_HSE].forEach`, `metodologias.push(...)`). Com 3 metodologias isso vira 3 ramos em cada ponto.
2. **O estado global acumulado contamina** (`_hseMetaCache` misturando versões/empresas) — o motor **tem de receber só os itens do questionário das linhas**. Vale para qualquer instrumento.
3. **Anonimato é transversal e foi o que mais cresceu**: n mínimo → supressão complementar → CSV k-anônimo → auditoria generalizada. Tudo isso é **independente do instrumento** e deve morar numa camada comum.
4. **Conferir o documento impresso**, não o DOM: o PDF real mostrou folhas só com rodapé. A infraestrutura (harness sem login, fixtures do simulador, impressão headless, teste do motor por `vm`) é reaproveitável sem mudança.
5. **Texto fixo de SST** (agente/danos/ações/conduta) é a parte lenta: cada instrumento precisa do seu catálogo revisado por profissional.
6. **O índice de favorabilidade 0–100** foi a lente que unificou telas e laudo. Para o COPSOQ ela coincide com a transformação 0–100 do COPSOQ III ((v−1)×25) **e** exige aplicar a direção da dimensão (favorabilidade = 100 − score quando alto = pior). Serve de **lente comum por metodologia — nunca para comparar metodologias entre si** (regra mantida: nenhum conversor, nenhum gráfico com eixo comum).

## 3. Inventário de acoplamento (onde o HSE está "gravado")
| Camada | Hoje, específico do HSE | Para o COPSOQ |
|---|---|---|
| **Banco** | Tabelas `hse_itens`, `resposta_itens_hse`, `hse_benchmark`, `hse_riscos_config`; `CHECK codigo ~ '^H[0-9]{2}$'`; `CHECK dimensao IN (7 do HSE)`; `valor BETWEEN 1 AND 5`; `escala_labels IN ('freq','concord')`; `CHECK metodologia IN ('BS8800','HSE_ICAO35')` (3×) | Clonar ou generalizar (§5). Itens de assédio têm **resposta binária + "de quem"**: não cabe em `valor smallint`. |
| **RPC** | `obter_instrumento_link` e o ramo HSE de `salvar_resposta`: o **total de itens** já vem da tabela (genérico), mas escala 1–5, nome da tabela e erro `hse_incompleto` são fixos | Parametrizar por instrumento; manter **um** `salvar_resposta` (nunca 3º overload — PGRST203). |
| **Formulário** | `renderInstrucoesHSE`/`buildQuestoesHSE` (~30 linhas): duas partes, dois conjuntos de rótulos | COPSOQ tem **5+ famílias de rótulos** (frequência, intensidade, concordância, satisfação, saúde percebida) + binário. Pede renderização por `escala_labels` configurável. |
| **Admin — despacho** | 12 pontos `=== METODOLOGIA_HSE` (Resultados, Laudo preview/PDF, Distribuição ×2, Comparativo, Plano, Auditoria, Adesão ×2, snapshot) | Registro de metodologias (§5.2) |
| **Admin — código** | Blocos HSE ≈ 1.900 linhas (S7 993, S8 416, AUD 145, S8b-UI 102, base 253) | A maior parte é **reaproveitável** (tabela abaixo) |
| **Cálculo** | `calcDimensoesHSE`: média das médias, inversão **por item** `6−v`, índice, faixa relativa, favoráveis/desfavoráveis | COPSOQ: média dos itens **transformados em 0–100**, **direção por dimensão**, regra de itens ausentes (≥ 50% da escala), escalas de **1 item** (satisfação, saúde geral) |

### 3.1 O que é genérico e o que não é
| Recurso construído para o HSE | Reaproveitável pelo COPSOQ? |
|---|---|
| n mínimo, supressão complementar, k-anonimato do CSV e da Auditoria | **Sim, sem mudança** (e deve subir de nível — §4) |
| Mapa recorte × dimensão, comparação entre recortes, tendência entre ciclos | **Sim** (com direção por dimensão) |
| Barras divergentes de distribuição | **Sim** (com direção) |
| Seletor de referência (benchmark por grupo) | **Sim**, se houver tabela de referência — para o COPSOQ-Br **não há** (§4) |
| Auditoria (uniforme/quase/LGPD/sessão repetida, modo teste) | **Sim** — "uniforme" depende de a escala ter sentido misto; revisar |
| Laudo: capa, rodapé por margem, ajuste de folha, índice numerado, seções condicionais | **Sim** |
| Ponte para o PGR (P pela faixa, S fixo assinado, matriz 4×4, conduta por nível) | **Só para as dimensões de EXPOSIÇÃO** (Demandas, Influência, Liderança…). **Burnout, saúde e satisfação são desfecho**, não exposição: não alimentam P×S (§4). |
| `HSE_DIM_INFO`, textos de ação, estados esperados | **Não** — catálogo próprio, com revisão de SST |
| Harness, simulador (`--fixture`), impressão headless, teste do motor via `vm` | **Sim** (perfil novo no simulador) |

## 4. O que o COPSOQ exige de diferente
1. **Dados sensíveis (LGPD art. 5º, II):** saúde percebida, burnout/estresse e comportamentos ofensivos. Consequências: texto de consentimento **específico** (não só o aceite LGPD genérico do formulário), **RIPD** (relatório de impacto), base legal definida com o cliente, retenção, e **regras de anonimato mais duras para essas dimensões**: n mínimo maior (a definir com o jurídico), **sem cruzamento fino** (setor × função × escolaridade) nas dimensões de saúde, sem exportação por respondente dessas colunas, e **comportamentos ofensivos nunca em recorte pequeno** (α = 0,54 + efeito piso: dado frágil e perigoso de expor).
2. **Desfecho × exposição:** o PGR trabalha com **fatores de risco** (exposição). Burnout/saúde são **sintoma**; devem aparecer em seção própria do laudo ("indicadores de saúde e bem-estar"), **sem** nível P×S e com a ressalva de que não são diagnóstico individual.
3. **Direção por dimensão** (e 1 item invertido no curto-Br): o motor precisa de `direcao` por dimensão (`alto_melhor | alto_pior`); já previsto como coluna em §6.1 do plano. Todas as telas/laudo passam a ler a direção para o índice de favorabilidade, a cor e a ordenação.
4. **Escala 0–100 e regra de itens ausentes**: o formulário atual exige 100% dos itens; no COPSOQ a dimensão se calcula com ≥ 50% dos itens, então **pode** haver "não se aplica"/em branco permitido (decisão: manter obrigatório, que simplifica e preserva a regra da RPC).
5. **Itens binários com "de quem"** (assédio): `valor` + `detalhe jsonb` na tabela de respostas; o "de quem" é um **quase-identificador** (colegas/chefia/cliente) — sensível.
6. **Sem referência brasileira:** o seletor de referência não tem o que mostrar. Opções: (a) **comparar ciclos e recortes da própria empresa** (a leitura mais honesta); (b) referência de outro país com aviso; (c) **referência interna agregada** do PsicoMap entre tenants (exige contrato/consentimento, k-anonimato e massa crítica — decisão comercial futura). O "farol" só deve ser mostrado se houver corte publicado.
7. **Nome e fidelidade:** conteúdo adaptado não pode se chamar "COPSOQ" sem sair da licença → rótulo neutro na interface/laudo (como já se evita "Stress Indicator Tool"); contato prévio com a equipe nacional.
8. **Não somar com o HSE:** há sobreposição alta nas dimensões de exposição (Demandas, Influência/Controle, Liderança/Apoio). Com os dois no mesmo cliente, são **ciclos separados** (regra atual), nunca uma média nem um gráfico conjunto.
9. **Valor incremental real** (§14.10 do plano): burnout/estresse, conflito trabalho-família, satisfação, saúde geral, comportamentos ofensivos. É isso que justifica a terceira metodologia — não a repetição de exposição.

## 5. Arquitetura recomendada
### 5.1 Banco: família genérica `instrumento_*` (recomendada) × clonar
| | A) Clonar por instrumento (`copsoq_itens`, `resposta_itens_copsoq`, …) | B) Família genérica (`instrumento_itens`, `resposta_itens_instrumento`, `instrumento_referencia`, `instrumento_riscos_config` + catálogo de dimensões) |
|---|---|---|
| Esforço do COPSOQ | Médio por tabela, **repetido** | Baixo (linhas novas, sem DDL) |
| Risco de classe de bug (GRANT/REVOKE `anon`, RLS, backup) | **Repete em cada instrumento** (já mordeu `grupos_setor`, `tenant_modulos`, `empresa_apelidos`) | Uma vez |
| `salvar_resposta` | Um ramo novo por instrumento | Um ramo, regras lidas do catálogo (escala, nº de itens, binário) |
| Custo **agora** (HSE fora de PROD) | Zero | Reescrever 4 migrations + 2 RPCs (DEV/PROD) + 5 seeds + `RESTAURACAO_BACKUP.md` e trocar 6 consultas do admin (o formulário usa só a RPC); dados de DEV recriados pelos seeds |
| Custo **depois** do go-live | Zero | **Migração de dados de produção** |
| Risco se o COPSOQ nunca vier | Nenhum | Generalização "à toa" (custo moderado) |
**Recomendação: B, antes do go-live do HSE**, dado que o usuário confirmou que o COPSOQ virá. Se isso mudar (B11 do plano: decisão de portfólio), A é o caminho de menor risco.
Esboço de B: `instrumento_dimensoes(metodologia, codigo, nome, direcao, ordem)`; `instrumento_itens(… dimensao, inversa, escala_labels, config jsonb)` sem `CHECK` por instrumento (a validação vem do catálogo); `resposta_itens_instrumento(resposta_id, item_id, valor smallint, detalhe jsonb)`; `instrumento_referencia` (hoje `hse_benchmark`, com `metodologia`); `instrumento_riscos_config(metodologia, dimensao, …)`. `respostas.metodologia`/`ciclos.metodologia` já existem; o `CHECK` vira FK para um catálogo `metodologias`.

### 5.2 Front-end: registro de metodologias
```js
const METODOLOGIAS = {
  BS8800:      { rotulo: 'BS 8800', escala: {min:1, max:4}, motor: calcFatores, telas: { resultados, laudo, distribuicao, comparativo, plano, auditoria, adesao } },
  HSE_ICAO35:  { rotulo: 'HSE (ICAO-35)', escala: {min:1, max:5}, motor: calcDimensoesHSE, carregar: carregarRespostasHSE,
                 telas: { resultados: rodarAnaliseHSE, laudoPreview: _laudoHSEPreview, laudoGerar: gerarLaudoHSE, distribuicao: renderGraficosHSE, comparativo: renderComparativoHSE,
                          plano: renderPlanoAcaoHSE, auditoria: renderAuditoriaHSE } },
  /* COPSOQ_II_BR: { … } */
};
const _despachar = (tela, cicloId, ...args) => METODOLOGIAS[_metodologiaDoCiclo(cicloId)].telas[tela]?.(...args);
```
Os 12 `if` viram `if (await _despachar('resultados', cicloId, …)) return;`; `_guardaTelaBS` (hoje sem uso) vira o **fallback padrão** quando uma metodologia ainda não implementa uma tela. Cartões de lateral passam de `data-so-bs`/`data-so-hse` para `data-met="BS8800 HSE_ICAO35"`; o seletor do "Novo ciclo" e os `optgroup` leem o registro (hoje têm o par BS/HSE fixo).
**Não generalizar o cálculo**: continua um motor por instrumento (regra de 03/08).

## 6. Sequência recomendada, com critério de pronto
| # | Passo | Pronto quando | Quem decide |
|---|---|---|---|
| 1 | **Integrar `develop`** (worktree próprio; ciclo → campanha; ~50 commits) | `check-inline-js`, `check-build`, `test:hse`, harness e `/validar-formulario` passam | — |
| 2 | **Generalizar** (B + registro), **antes** do go-live do HSE | HSE idêntico por teste (mesmos 161 casos + PDF); migrations reescritas aplicadas em DEV; formulário/RPC lendo o catálogo | **Você** (decisão A × B) |
| 3 | **Go-live do HSE** (B1, B12, severidade assinada, texto validado) e validação em produção | Piloto com cliente real; laudo entregue e revisado por SST | Pessoas (§4.1 do handoff) |
| 4 | **COPSOQ**: contato com a equipe nacional/licença por escrito; RIPD e consentimento; catálogo e seed; motor (direção, 0–100); formulário (rótulos, binário); telas e laudo (com seção de saúde separada); anonimato reforçado | Piloto; revisão de SST **e** do jurídico (dados sensíveis) | **Você** + jurídico |
Estimativa relativa (não em horas): o COPSOQ sobre a base generalizada dá **bem menos** trabalho do que o HSE deu — a parte pesada já existe — mas **a parte LGPD/licença é longa e independe de código**: começar o contato com a rede e o jurídico em paralelo ao passo 2.

## 7. O que fazer já, sem esperar (baixo risco)
- Em **código novo**, preferir o padrão do registro (um ponto de despacho) a espalhar `=== METODOLOGIA_HSE`; ao integrar com `develop`, migrar os 12 pontos de uma vez.
- Não criar novas constantes `HSE_ESCALA_MAX`/`HSE_DIMS` em lógica que seja **genérica** (n mínimo, k-anonimato): essas funções já não dependem do HSE e devem sair do bloco `HSE (S7)` no passo 2.
- Guardar `direcao` por dimensão desde já no catálogo do HSE (todas `alto_melhor` após a normalização) para o COPSOQ só acrescentar linhas.

## 8. Decisões que dependem de você
1. **A × B** do banco (§5.1) e **quando** (recomendo antes do go-live do HSE).
2. **Entrar em contato com a rede COPSOQ** agora (licença por escrito, equipe nacional, nome do produto).
3. **Jurídico/DPO** para dados de saúde: base legal, RIPD, n mínimo das dimensões sensíveis.
4. Quais dimensões do COPSOQ **entram** (as 11 do curto-Br ou um subconjunto sem "comportamentos ofensivos", dada a confiabilidade 0,54).

## Fontes
- Plano interno, §14 e referências: `.claude/notes/2026-08-03-metodologia-hse-icao35-planejamento.md`.
- COPSOQ International Network — [validation studies](https://www.copsoq-network.org/validation-studies) e [guidelines/licença](https://copsoq-network.org/guidelines) ([COPSOQ III License, PDF](https://www.copsoq-network.org/assets/pdf/COPSOQ-network-guidelines-an-questionnaire-COPSOQ-III-180821-1.pdf)).
- Cotrim et al. (2022), *Int J Environ Res Public Health* 19(3):1167 — [COPSOQ III médio, Portugal](https://rdpc.uevora.pt/bitstream/10174/34493/1/ijerph-19-01167.pdf).
- Gonçalves et al. (2021), *Rev Saúde Pública* 55:69 — COPSOQ II-Br curto; Lima et al. (2019), *Work* 62(2) — médio (referências no plano §14).
