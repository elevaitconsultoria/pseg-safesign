# COPSOQ — avaliação dos dois documentos do outro player e generalização aplicada

> Criado em 2026-10-19. Documentos avaliados (ambos em `Downloads`, enviados pelo usuário):
> **`AVALIAÇÃO - COPSOC.pdf`** (formulário "COPSOQ II-Br curta", 2 páginas) e **`CopSoq II - INTERPRETAÇÃO DAS PERGUNTAS.pdf`** (14 páginas, um texto explicativo por pergunta).
> Complementa `2026-10-19-copsoq-e-arquitetura-multi-metodologia.md` (que recomendou "generalizar antes do go-live do HSE"). **A generalização foi feita no mesmo dia, em DEV** (§4).
> **Nenhum questionário COPSOQ foi semeado em lugar nenhum** — o ganho de hoje é a base, não o instrumento.

## 0. Resumo
1. **Os documentos são úteis como referência de produto, mas não são o instrumento validado.** São uma adaptação livre: 40 perguntas curtas sob um rótulo "COPSOQ II-Br curta", **uma única escala de frequência (Nunca…Sempre) para tudo**, sem tabela de dimensões nem de itens invertidos. Não servem de texto para uso real (§2).
2. **Três achados mudam o desenho, e já estão atendidos pela base nova:** (a) a **direção** (alto = bom ou ruim) varia **item a item dentro do mesmo "fator"** — em "Saúde e bem-estar" convivem "se sente esgotado" e "está satisfeito" — então a direção tem de existir por **item** e por **dimensão**; (b) o texto de **interpretação** é um auxiliar por pergunta, que pode **enviesar** a resposta se for exibido ao respondente; (c) as perguntas de **saúde** são dado sensível (LGPD art. 5º, II), e o formulário do player as mistura com **idade e avaliador** — o oposto do nosso anonimato.
3. **O que falta para o COPSOQ não é banco nem formulário: é (i) o texto validado + a licença por escrito, (ii) o motor de cálculo (0–100, direção, itens ausentes), (iii) o laudo (com seção de saúde separada do PGR) e (iv) o anonimato reforçado.** Lista em §5.
4. **Generalização:** DEV já roda HSE na família genérica `instrumento_*`; 13 cenários da RPC sob o papel `anon` e as médias por dimensão (7 de 7) bateram com os números anteriores. Falta só PROD (que nunca teve as tabelas `hse_*`, então recebe a versão genérica direto).

## 1. O que os documentos contêm
### 1.1 Formulário ("AVALIAÇÃO - COPSOC")
- Cabeçalho individual: **Cargo/função, Setor/Ghe/Ges/Ambiente, Idade, Data, Avaliador**. É um formulário de **papel com identificação**.
- Instrução: "últimos seis meses", frequência 1–5 (Nunca, Raramente, Às vezes, Frequentemente, Sempre), "não existem respostas certas ou erradas". Aviso de que "algumas questões possuem pontuação invertida… convertida automaticamente pelo sistema" — **sem dizer quais**.
- Banner: "Referência original: Pejtersen et al., 2010. Validação brasileira: Gonçalves et al., 2021. Composição: **40 questões, 7 domínios e 11 dimensões**."
- Agrupamento real da grade (7 "fatores", **sem as 11 dimensões nomeadas**):

| Fator (como no documento) | Itens | Qtde |
|---|---|---|
| Demandas no trabalho | 1–7 (rápido, intensidade, prazos, concentração, decisões difíceis, envolvimento emocional, situações emocionalmente difíceis) | 7 |
| Controle e desenvolvimento | 8–13 (influência, organizar o trabalho, aprender, desenvolver habilidades, importância, propósito) | 6 |
| Relações e liderança | 14–19 (ajuda e confiança nos colegas; supervisor ajuda, conversa, organiza, respeita) | 6 |
| Organização do trabalho | 20–25 (clareza do esperado e das responsabilidades, tarefas contraditórias/desnecessárias, justiça das decisões e do tratamento) | 6 |
| Conflito trabalho–vida | 26–28 | 3 |
| Segurança no emprego | 29–32 (medo de perder o emprego, insegurança, **"já sofreu tratamento injusto"**, **"já foi desrespeitado"**) | 4 |
| Saúde e bem-estar | 33–40 (estressado, sobrecarregado, esgotado, sem energia, **satisfeito**, **motivado**, **saúde boa**, **bem física e mentalmente**) | 8 |

### 1.2 "Interpretação das perguntas"
Para cada uma das 40: **"Essa pergunta quer entender… / Por exemplo… / Em outras palavras…"**. É redação do próprio player (não do instrumento). Serve a dois públicos possíveis: o **respondente** (ajuda a entender) e o **analista** (glossário).

## 2. Avaliação — o que os documentos NÃO são
| Ponto | Constatação | Consequência |
|---|---|---|
| **Fidelidade ao II-Br** | Perguntas encurtadas e reescritas; escala única de frequência para tudo. Perguntas como "Seu trabalho é importante para você?", "Você considera sua saúde boa?" e "Você está satisfeito…?" com resposta "Nunca…Sempre" **mudam o construto** (o instrumento validado usa outros conjuntos de resposta nessas escalas). | Não comparável com a literatura nem com normas. Não pode ser chamado de COPSOQ (licença **ND**: conteúdo adaptado não leva o nome). |
| **Dimensões** | O banner diz "11 dimensões", a grade mostra 7 fatores. As dimensões intermediárias **não são identificáveis** no documento. | O mapa item → dimensão **não pode ser tirado daqui**; tem de vir da fonte validada. |
| **Itens invertidos** | "Algumas" são invertidas, sem lista. No instrumento validado a inversão é mínima (apenas 1 item no curto-Br, segundo a literatura consultada); aqui a **direção mista é intrínseca ao texto** (positivos e negativos na mesma escala). | O modelo precisa de `inversa` **por item**, e a lista tem de ser decidida item a item e revisada. |
| **Itens 31 e 32** | "Já sofreu tratamento injusto?" / "Já foi desrespeitado?" estão sob **Segurança no emprego**, com escala de frequência dos "últimos seis meses". "Já" pergunta sobre a vida toda; o rótulo "segurança no emprego" não é o construto (são comportamentos ofensivos/justiça). | Candidato a **dado frágil e sensível** (no validado, "comportamentos ofensivos" teve α = 0,54 e efeito piso). Tratar à parte. |
| **Pontuação, cortes, risco** | Nenhum ponto de corte, nenhuma faixa, nenhum nível de risco, nenhuma referência. | Farol, ponte para o PGR e referência continuam **decisões nossas**, a validar com SST — como no HSE. |
| **Anonimato** | Pede **idade, data, avaliador** e setor/GHE/GES/ambiente. | **Não copiar** esses campos. Mantemos setor, função, escolaridade (já cobertos pelo n mínimo). |
| **Saúde** | 8 perguntas de saúde/estresse/esgotamento no mesmo papel que identifica a pessoa. | Dado sensível. Exige consentimento específico, RIPD e regras de anonimato mais duras (§5). |

## 3. A "interpretação das perguntas": o que fazer com ela
- **Não exibir ao respondente por padrão.** Os exemplos induzem (Q17: "sem medo de punição, julgamento ou represálias"; Q7: "agressividade, tristeza, perdas") e a resposta passa a depender de qual exemplo o respondente leu.
- Se for exibida, tem de ser **parte do questionário versionado** (mesmo texto para todos, congelado ao publicar, revisado por SST/psicólogo) — é para isso que `instrumento_itens.ajuda` existe (opcional; a RPC devolve; o formulário mostra abaixo da pergunta).
- Melhor uso imediato: **glossário para quem lê o laudo e para o consultor** ("o que esta dimensão mede").
- É redação **do player**: usar só como estudo e em simulação em DEV marcada `rascunho` (mesmo tratamento do formulário F1 do HSE). **Não** replicar em produção.

## 4. A generalização aplicada (DEV, 2026-10-19)
### 4.1 Banco (`szqatgvgghxvyyncsjxl`)
- Família `instrumentos`, `instrumento_dimensoes` (com `dominio`, `direcao`, `sensivel` por dimensão), `instrumento_itens` (`inversa` e `ajuda` por item, `escala_labels`), `resposta_itens_instrumento` (valor **bruto**), `instrumento_referencias`, `instrumento_riscos_config`. As tabelas `hse_*` foram **removidas** depois da conferência.
- `salvar_resposta` (mesma assinatura, 10 args) e `obter_instrumento_link` passaram ao ramo genérico. O limite superior de cada valor é o **número de rótulos da escala do item** (`questionarios.config.rotulos.<escala_labels>`), com `instrumentos.escala_max` como reserva. Erro novo: `instrumento_incompleto` (era `hse_incompleto`; o formulário aceita os dois).
- **Verificação:** contagens idênticas (70 itens, 2625 respostas-item, 98 referências, 7 severidades) e **média por dimensão idêntica** nas 7 dimensões; 13 cenários sob `SET LOCAL ROLE anon` com `ROLLBACK` (token ruim, HSE completo, idempotência por `session_id`, 34 itens, duplicado, valor 0/6/texto, questão BS em ciclo HSE e o inverso, BS completo, formato `questao_id` legado); `anon` sem nenhum GRANT nas 6 tabelas novas; só o overload de 10 args executável.
- Arquivos: `migration_metodologias_instrumentos.sql`, `migration_instrumento_riscos_config.sql`, `migration_obter_instrumento_link.sql`, `migration_salvar_resposta_instrumento_{dev,prod}.sql`, `migration_dev_converter_hse_para_instrumentos.sql` (só DEV, **já aplicado**), seeds `seed_hse_*` reescritos e testados.

### 4.2 Admin (`psicomap-admin.html`)
- **Registro `METODOLOGIAS`** (rótulo, selo, cartão, `motor`, `modulo`, prefixo de nome de campanha). `_metDef` devolve um stub **sem motor** para qualquer metodologia que o banco conheça e o código não.
- **Guarda `_metSemMotor` / `_painelSemMotor` em todos os pontos de despacho** (Resultados, Gráficos + export, Laudo preview + PDF, Auditoria, Plano, Comparativo, Adesão). Sem ela, o `else` herdaria o fluxo do **BS 8800** — um ciclo de terceira metodologia seria "analisado" como BS sem erro nenhum. Testado com um ciclo fantasma `COPSOQ_II`: todas as telas mostram "Metodologia em desenvolvimento" e o Comparativo BS **não** o inclui.
- Cartões de "Nova campanha", `optgroup`s, selos, botão "Trocar metodologia", Comparativo e contagem por metodologia agora vêm do registro (com 3+ metodologias o botão vira um `select` e o "Criar também…" some). Adesão ganhou `_doGenerico` (setor, função e data bastam).
- Regressão: telas HSE (Resultados, Laudo + pré-checagem, Plano, Distribuição, Comparativo, Auditoria real/teste) idênticas no harness; `test:hse` 161/161.

### 4.3 Formulário (`psicomap-forms.html`)
- Qualquer instrumento não-BS é **genérico**: itens, partes e rótulos vêm da RPC; opções = nº de rótulos do item; `ajuda` opcional; `config.aviso` opcional (parágrafo próprio nas instruções); validação por item. Testado: HSE de 2 escalas, escala de 7 pontos com ajuda e aviso, escape de HTML, instrumento sem rótulo/itens (recusado com erro), rótulos legados (`rotulos_freq`).

## 5. O que o COPSOQ ainda exige (e a base de hoje atende?)
| Necessidade | Situação |
|---|---|
| Várias famílias de rótulos (frequência, intensidade, concordância, satisfação, saúde) | ✅ `config.rotulos.<nome>` + `escala_labels` por item |
| Direção por dimensão **e** inversão por item | ✅ `instrumento_dimensoes.direcao` + `instrumento_itens.inversa` (a direção do **item** mistura: o motor precisa combinar as duas) |
| Hierarquia domínio → dimensão | ✅ `instrumento_dimensoes.dominio` |
| Dimensão com 1 item (satisfação, saúde geral) | ✅ sem restrição |
| Marcar dimensões de saúde como sensíveis | ✅ coluna; ❌ **nenhum comportamento ainda** (n mínimo reforçado, sem cruzamento fino, sem CSV por respondente) |
| Consentimento específico e RIPD | ❌ só `config.aviso` (texto); registro de consentimento específico e RIPD são trabalho jurídico + produto |
| Item binário com "de quem" (assédio) | ❌ `resposta_itens_instrumento` não tem `detalhe` — deixado de fora de propósito até haver o instrumento |
| Referência (benchmark) | ✅ tabela; **não há referência brasileira publicável** — comparar ciclos/recortes da própria empresa |
| Motor (0–100, direção, itens ausentes ≥ 50%) | ❌ a construir, **um motor por instrumento** (regra mantida) |
| Laudo: exposição × desfecho | ❌ burnout/saúde/satisfação **não** alimentam P×S; seção própria "indicadores de saúde e bem-estar", sem nível de risco |
| Texto validado + licença | ❌ **bloqueador real** (§6) |

## 6. Decisões e próximos passos (ordem sugerida)
1. **Obter o texto validado.** Fontes: Gonçalves et al. (2021), *Rev Saúde Pública* 55:69 (versão curta), tese de 2019 com a redação em português, e a rede COPSOQ. **Pedir por escrito** a confirmação da licença (CC BY-NC-ND com exceção comercial) e o contato da equipe nacional. Sem isso, nada vai a PROD.
2. **Definir o nome** do produto: com texto 100% validado e atribuição, "COPSOQ II-Br"; com qualquer adaptação nossa, nome neutro (ND).
3. **Mapa item → dimensão → direção → item reverso** a partir da fonte validada, não do PDF do player (que nem lista as 11 dimensões).
4. **Jurídico/DPO**: base legal, RIPD, n mínimo das dimensões de saúde, retenção.
5. Só então: seed (DEV, `rascunho`) → motor → formulário/laudo → anonimato reforçado → piloto com revisão de SST.
6. **Decisão do usuário:** o texto de "interpretação" vira `ajuda` (respondente) ou glossário do laudo? Recomendo **glossário**.

## 7. Estado e cuidados
- **PROD intocado; nada em `develop`.** Os arquivos estão no worktree `pseg-safesign-hse-integ` (branch `feat/hse-integracao-develop`), **sem push**.
- **O preview antigo de `feat/hse-icao35` (Cloudflare) deixou de funcionar contra DEV**: ele lê `hse_itens`/`resposta_itens_hse`, que não existem mais. Use a branch de integração.
- O harness (`_dev/harness-hse.js`) ficou nos nomes novos; `check-inline-js`, `check-build` e `test:hse` passam.
- Para PROD, a ordem é: `migration_metodologias_instrumentos.sql` → `migration_instrumento_riscos_config.sql` (arquivo separado; depende de `instrumento_dimensoes`) → `migration_obter_instrumento_link.sql` → `migration_salvar_resposta_instrumento_prod.sql` → só então o HTML. **Nunca** `migration_dev_converter_*` em PROD.
