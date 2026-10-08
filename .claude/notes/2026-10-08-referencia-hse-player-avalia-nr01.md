# Referência de mercado — HSE no player "AVALIA NR01"

> **Status: referência de pesquisa — não é plano de execução.** Criado em 2026-10-08.
> Complementa `2026-08-03-metodologia-hse-icao35-planejamento.md` (o plano) e **não o altera**.
> O que este documento propõe está marcado como **proposta (D1…D8)** e aguarda decisão do usuário.
> Nenhuma linha de código, migration ou texto de produto foi alterada por causa dele.

## 0. Resumo

1. O player aplica o HSE (35 itens, 7 dimensões) numa **escala única de frequência** e entrega um
   relatório de 23 páginas posicionado como **AEP — Avaliação Ergonômica Preliminar (NR-17 / NR-1)**,
   não como "laudo psicossocial".
2. O cálculo é simples e **reproduzível**: dimensão = média dos itens; `% = (média − 1) / 4`;
   zonas fixas **< 40 % vermelho · 40–74,99 % amarelo · ≥ 75 % verde** (≡ média < 2,6 · 2,6–3,99 · ≥ 4,0).
   Refiz todas as contas do exemplo e batem (§3).
3. Cria um **score global** ("Média Geral 55,9 % | 3,2 Atenção") que o HSE não define — e que, no
   próprio exemplo, **contradiz** o inventário do PGR do mesmo relatório (cabeçalho "Atenção",
   inventário com duas dimensões "Intolerável").
4. Tem uma **ponte para o inventário do PGR**: converte o % de cada dimensão em Probabilidade (1–5),
   atribui Severidade (1–5) e consulta uma matriz 5×5 → Trivial … Intolerável. É o tipo de conversão que
   o plano §3 proíbe *entre metodologias* — mas aqui o destino é uma terceira coisa (a entrada do
   inventário), e é provavelmente o que o mercado espera, porque o PGR exige um nível de risco. **D1**
   reabre a questão com cuidado (§5, §7).
5. Tem **falhas que não devemos repetir**: placeholders vazando para o cliente ("Consultoria não
   disponível" em todas as páginas, "Cidade - ES"), seções entregues em branco, resultado **por item
   com 1 respondente** (quebra de anonimato), amostra "adequada" só com 100 % de resposta, item 8
   mal traduzido.
6. **Confirma** o nosso mapeamento item → dimensão (§7 do plano) e a inversão **por dimensão**
   (Demandas e Relacionamentos).
7. Nada aqui bloqueia as PRs 1–2 do plano.

## 1. Fontes e limites

| # | Arquivo | O que é |
|---|---|---|
| F1 | `AVALIAÇÃO - IMPRESSA HSE.pdf` | Formulário **impresso** de aplicação do HSE, 2 páginas |
| F2 | `AVALIA NR01 - Ferramenta de Indicador de Estresse.pdf` | Relatório **gerado**, 23 páginas, datado de 17/09/2026 |

Limites desta análise — o que **não** sei:

- Só vi **documentos de saída**, nunca a plataforma. Fluxo de coleta, UX do respondente, tratamento de
  resposta em branco e quebra por vários setores são desconhecidos.
- F2 tem **1 respondente de 3** (aparenta conta de teste). O comportamento numérico é observável; a
  robustez estatística, não.
- As seções 11 (Plano de Ação) e 12 (Anexos) saíram **em branco**; não sei se o produto as preenche.
- As citações normativas do relatório (NR-1 item 1.5.3.1, NR-17 item 17.3.2, Portaria MTP 423/2021,
  Guia do MTE) são **deles; não as verifiquei**. Antes de reproduzir qualquer uma num laudo nosso,
  conferir com SST/jurídico.
- A correspondência item a item com o questionário HSE original (§2) foi feita por mim, comparando o
  conteúdo; as contagens por dimensão batem com o §7 do plano.
- Identificadores do cliente do relatório e dos responsáveis técnicos foram **omitidos de propósito**.

## 2. O instrumento como o player o apresenta

### 2.1 Estrutura (F1 e F2 coincidem)

| Dimensão (nome do player) | Itens | Invertida | Nº no HSE original |
|---|---|---|---|
| Demandas | 8 | **sim** | 3, 6, 9, 12, 16, 18, 20, 22 |
| Controle | 6 | não | 2, 10, 15, 19, 25, 30 |
| Apoio da gestão | 5 | não | 8, 23, 29, 33, 35 |
| Suporte dos colegas | 4 | não | 7, 24, 27, 31 |
| Relacionamentos | 4 | **sim** | 5, 14, 21, 34 |
| Clareza de papel / função | 5 | não | 1, 4, 11, 13, 17 |
| Gerenciamento de mudanças (F1: "Comunicação e mudanças") | 3 | não | 26, 28, 32 |

- Os itens aparecem **reordenados por dimensão** (1–8, 9–14, 15–19, 20–23, 24–27, 28–32, 33–35), não na
  ordem do HSE original.
- A instrução impressa diz: *"para o fator demanda e do relacionamento, a escala é inversamente"* —
  regra **por dimensão inteira**, igual à do plano.
- Janela de **seis meses** no enunciado, como no plano.
- **Uma escala só** para os 35 itens: Nunca · Raramente · Às vezes · Frequentemente · Sempre (1–5).
  O HSE original tem dois conjuntos de rótulos (frequência nos itens 1–23, concordância nos 24–35); o
  player **reescreve como pergunta** os itens de concordância ("Eu entendo claramente o que é esperado
  de mim no trabalho?") para caber na frequência.
- Cabeçalho do formulário impresso: Cargo/função · Setor/GHE/GES/Ambiente · **Idade** · Data ·
  **Avaliador**. Nós não coletamos idade (anonimato) e não devemos passar a coletar.
- Referência citada: Manual do Usuário da Ferramenta Indicadora HSE, V03, 2014 (via anexo de uma
  política de um NHS Trust). **Não** cita a ICAO nem qualquer validação brasileira; o relatório diz
  "adaptada para o contexto brasileiro" sem apontar a adaptação.
- Chama o instrumento de **"Stress Indicator Tool (SIT)"** — nome que o plano §2 manda evitar.

### 2.2 Qualidade do texto em português — por que não serve de base

| Achado | Onde | Consequência |
|---|---|---|
| Item 8 "Tenho pausas temporárias impossíveis de cumprir?" corresponde a *"I have unrealistic time pressures"* (original 22) — erro de tradução; ainda repete o tema "pausas" do item 5 | F1 e F2 | O erro está no impresso **e** no relatório entregue ao cliente |
| Item 15 "Recebo informações e suporte que me ajudam…" ↔ original 8 *"I am given supportive feedback on the work I do"* — perde "feedback" | F1 e F2 | Construto alterado |
| Item 33 com redações diferentes: F1 "pedir explicações ao chefe sobre as mudanças" × F2 "questionar os gestores sobre mudanças" | F1 × F2 | O texto não está congelado nem versionado, **dentro do mesmo produto** |
| "Clareza de papel" descrita como "transparência nos critérios de promoção na carreira e reconhecimento" | F1 | Descrição não é o construto (Role = clareza de papel) |
| Texto diz "seis domínios" (Apoio unificado); resultados usam sete | F2 §3 × §5 | Inconsistência interna |

**Lições para nós:** reforça o B1 (precisamos do texto validado) e acrescenta uma regra barata —
**versionar o texto pelo questionário**: mudou uma palavra → questionário novo (`questionarios.id`
novo), nunca editar `questoes.texto` no lugar. Sem isso, dois ciclos "HSE" podem ter perguntas
diferentes e deixam de ser comparáveis, que é justamente o valor do instrumento.

> **Correção (2026-10-08, depois de consultar PROD):** `respostas.questionario_id` existe, mas está
> **NULL em 100 % das linhas** (a RPC copia de `empresas.questionario_id`, também NULL em todas as
> empresas). Ou seja, não há rastreabilidade de versão do histórico do BS 8800, e ela **só passa a
> existir para o HSE daqui em diante**, quando a RPC gravar `questionario_id` pelo ciclo. Ver
> `2026-10-08-plano-implantacao-hse.md`.

## 3. Como o relatório calcula (engenharia reversa, conferida)

Regras observadas:

1. O **score exibido por item** vai de 1 a 5 e **sempre alto = melhor**, em todas as dimensões.
2. `% do item = (score − 1) / 4`.
3. **Score da dimensão = média aritmética dos itens**; `% da dimensão = (média − 1) / 4`.
4. **Média Geral** = média simples dos 7 percentuais de dimensão (e, em paralelo, das 7 médias).
5. **Zonas**, iguais no nível de item e de dimensão: **≥ 75 % verde · 40–74,99 % amarela · < 40 %
   vermelha**. Em score: ≥ 4,0 · 2,6–3,99 · < 2,6. No item: 25 % já é vermelho, 50 % amarelo, 75 % verde.
6. **Adequação da amostra**: "1 de 3 funcionários responderam · mínimo exigido: 3 respostas →
   *Inadequado*" — aplicam a tabela de tamanho de amostra do HSE (≤ 500 → todos; 501–1.000 → 500;
   1.001–2.000 → 650; 2.001–3.000 → 700; > 3.000 → 800) como se fosse um mínimo de respondentes.

**Conferência com os números do PDF** (todas as linhas batem):

| Dimensão | Scores dos itens | Média | % | Zona |
|---|---|---|---|---|
| Demandas | 1, 2, 1, 1, 1, 1, 1, 1 | 1,125 | 3,1 % | vermelha |
| Controle | 5, 5, 5, 5, 3, 5 | 4,667 | 91,7 % | verde |
| Apoio da gestão | 3, 5, 5, 5, 5 | 4,600 | 90,0 % | verde |
| Suporte dos colegas | 2, 3, 5, 5 | 3,750 | 68,8 % | amarela |
| Relacionamentos | 5, 3, 5, 4 | 4,250 | 81,3 % | verde |
| Clareza de papel / função | 5, 5, 1, 1, 1 | 2,600 | 40,0 % | amarela (no limite) |
| Mudanças | 1, 1, 3 | 1,667 | 16,7 % | vermelha |
| **Geral** | — | 3,237 | **55,9 %** | amarela ("3.2 Atenção") |

**Inferência (o PDF não mostra a resposta bruta):** o score exibido já está **depois da inversão**.
Em Demandas todos os itens aparecem em 1,0 pintados de vermelho/"RUIM" com a legenda "SEMPRE –
NEGATIVO"; isso só é coerente se o respondente marcou "Sempre" e a inversão já foi aplicada. A legenda
de cada dimensão descreve o **sentido da resposta bruta** (em Demandas e Relacionamentos "Nunca =
bom"; nas demais "Sempre = bom"), enquanto o número e a cor já estão normalizados.

Observações sobre o método:

- **Normalizar tudo para "alto = bom, 0–100"** deixa as 7 barras comparáveis num relance — bom para
  leitura executiva. Cuidado: "3,1 %" lê-se como "3 % dos trabalhadores…"; é um **índice**, não uma
  proporção. Se adotarmos, rotular "índice de favorabilidade".
- **As zonas fixas não são o método do HSE** (o HSE classifica por percentil contra uma população de
  referência). Com as médias do benchmark HSE 2023 (plano §2) uma organização *mediana* apareceria
  assim nas zonas do player — Demandas 56,3 %, Controle 68,0 %, Apoio da gestão 70,0 %, Suporte dos
  colegas 75,3 %, Relacionamentos 77,8 %, Papel 79,0 %, Mudanças 57,5 % — ou seja, **4 de 7 em amarelo e
  a média geral em ≈ 69 % "Atenção"**: o amarelo é o estado normal e o vermelho só aparece muito abaixo
  da média mundial. É o problema que o plano §2 já apontava para cortes fixos únicos (cálculo meu, a
  partir da tabela do plano).
- **A média esconde padrão bimodal**: Clareza de papel fecha em 40 % ("Atenção") com dois itens em 100 %
  e três em 0 %. O drill-down por item é indispensável (o player o mostra; o plano também o prevê).
- **Score global**: o HSE não define. O player coloca-o como manchete; no exemplo ele diz "Atenção"
  enquanto o inventário do mesmo documento diz "Intolerável" para Demandas e Mudanças. A manchete é a
  primeira coisa que o cliente lê.

## 4. Apresentação — estrutura do relatório

| # | Seção | Natureza | Observação |
|---|---|---|---|
| — | Capa | gerada | Tipo do documento em destaque ("Avaliação Ergonômica Preliminar"), subtítulo normativo, cartão do cliente |
| 1 | Identificação | gerada | Empresa, CNPJ, endereço, **CNAE, classe de risco (grau)**, setores avaliados, nº de trabalhadores avaliados, data, **reavaliação recomendada (3 meses)**, **3 responsáveis técnicos** (TST, médico do trabalho, psicólogo — cada um com registro) |
| 2 | Objetivo | fixa | Liga AEP → decisão sobre AET, priorização e PGR |
| 3 | Metodologia | fixa + tabela | Descreve o SIT, as etapas e **copia do manual HSE** lista de trabalhadores / tamanho / seleção de amostra |
| 4 | Importância da participação | fixa | Cita participação dos trabalhadores (NR-1/NR-17), confiança e ausência de represália |
| 5 | Resultados gerais | gerada | 1 página-resumo + **7 páginas de gráficos** (uma por dimensão) |
| 6 | Conclusões e recomendações preliminares | fixa | 4 marcadores genéricos (priorizar riscos elevados · reavaliar em 3 meses · treinar saúde mental · AET se necessário) — **nada por dimensão** |
| 7 | Limitações | fixa | "AEP não substitui a AET"; percepção num momento; participação voluntária e confidencial |
| 8 | Responsabilidades | fixa + assinaturas | Avaliador e **aprovador (representante legal do cliente)**; a empresa responde pela implementação |
| 9 | Classificação e avaliação dos riscos | fixa | Explica a ponte, matriz 5×5, tabelas de probabilidade, severidade e hierarquia de controle |
| 10 | Inventário de riscos para o PGR | gerada | Tabela por dimensão (ver §5) |
| 11 | Plano de ação recomendado | **em branco** | Só o título |
| 12 | Anexos — fotos enviadas | **em branco** | Só o título |

**Padrões visuais que valem como referência**

- **Página-resumo única**: número grande + selo ("55,9 % · 3,2 Atenção"), barras das 7 dimensões com
  "% | score", caixa com as três zonas, caixa "Amostra de respostas — Adequado/Inadequado".
- **Uma página por dimensão**: barra da média no topo; abaixo, **uma barra por pergunta** (texto à
  esquerda, barra com % e selo RUIM/ATENÇÃO/BOM, score à direita) e uma **legenda que muda de sentido**
  conforme a dimensão (resolve o risco R8 do plano na leitura humana).
- **Tabelas de critério impressas no próprio laudo** (probabilidade, severidade, nível → ação):
  transparência que um auditor aprecia.
- **Rodapé em todas as páginas** com data e nome da consultoria.

**Texto de "agente nocivo / possíveis danos" por dimensão** (autoria do player, só como referência de
vocabulário; o nosso catálogo oficial continua sendo `CATALOGO_ACOES` / planilha do cliente):

| Dimensão | Agente nocivo | Possíveis danos |
|---|---|---|
| Demandas de trabalho | Excesso de demandas no trabalho | Transtorno mental; DORT, estresse ocupacional, fadiga mental |
| Controle sobre o trabalho | Baixo controle no trabalho / falta de autonomia | Transtorno mental; DORT |
| Apoio da gestão | Falta de suporte/apoio no trabalho | Transtorno mental |
| Suporte dos colegas | Más relacionamentos no local de trabalho | Transtorno mental; DORT |
| Relacionamentos no trabalho | Conflitos frequentes na equipe | Transtorno mental |
| Clareza de papel/função | Baixa clareza de papel/função | Transtorno mental |
| Gerenciamento de mudanças | Má gestão de mudanças organizacionais | Transtorno mental; DORT |

**Defeitos observados — não repetir**

1. **"Consultoria não disponível"** impresso na capa, no rodapé das 23 páginas e no bloco de assinatura
   — o texto de fallback de um campo vazio foi para o documento do cliente.
2. **"Cidade - ES, 17 de setembro de 2026"** na assinatura — placeholder não resolvido (o cliente é de SP).
3. **Seções 11 e 12 entregues vazias**, com título e sem conteúdo.
4. **Página 8 com uma linha só** (quebra de página ruim).
5. **Resultado por item de 1 único respondente** impresso (ex.: "Sou perseguido no trabalho? 5,0") com
   "Setores avaliados: Administrativo" — com n = 1 a resposta de uma pessoa identificável está na mesa.
6. **Amostra "Inadequado" e mesmo assim** o relatório classifica "Intolerável" e alimenta o PGR, sem
   nenhuma ressalva ligada ao selo.
7. **Reavaliação "3 meses"** fixa, igual para qualquer resultado.
8. **Manchete × inventário** em contradição (§3).
9. **"Responsável pela avaliação"** sem nome (mesmo bug do item 1).

## 5. A ponte para o PGR (inventário de riscos)

### 5.1 Probabilidade a partir do %

| % da dimensão | Interpretação | P |
|---|---|---|
| 90–100 | ambiente muito saudável | 1 |
| 75–89 | boa condição | 2 |
| 60–74 | atenção | 3 |
| 40–59 | problema frequente | 4 |
| < 40 | problema crítico | 5 |

Os cortes 75 e 40 coincidem com as zonas; 90 e 60 são acréscimo do player. A tabela impressa tem
**lacunas de fronteira** (89,5 % não está em "75–89" nem em "90–100"); numa implementação usar
intervalos semiabertos (`[90,100]`, `[75,90)`, `[60,75)`, `[40,60)`, `[0,40)`).

### 5.2 Severidade

| S | Impacto |
|---|---|
| 1 | desconforto leve |
| 2 | fadiga mental leve |
| 3 | estresse ocupacional |
| 4 | transtornos psicológicos |
| 5 | adoecimento grave |

No exemplo a severidade por dimensão foi: Demandas 4 · Controle **1** · Apoio da gestão **1** · Suporte 3 ·
Relacionamentos 4 · Papel 4 · Mudanças 4. **Não dá para saber, com um relatório só, se S é fixa por
dimensão ou derivada do resultado.** Indício: Controle e Apoio têm P = 1 e S = 1; se S fosse uma
propriedade do perigo ("baixo controle" → "transtorno mental; DORT", que pela própria tabela de
severidade é ≥ 3), não seria 1. Ou S é "achatada" quando o resultado é ótimo, ou o critério é outro. Se
S depende do mesmo % que gerou P, **P e S não são independentes** e a matriz conta o mesmo dado duas vezes.

### 5.3 Matriz 5×5 (lida célula a célula do PDF)

| P \ S | 1 leve | 2 baixo | 3 moderado | 4 alto | 5 extremo |
|---|---|---|---|---|---|
| **5** muito provável | Tolerável | Moderado | Substancial | Intolerável | Intolerável |
| **4** provável | Tolerável | Tolerável | Moderado | Substancial | Intolerável |
| **3** possível | Trivial | Tolerável | Moderado | Substancial | Intolerável |
| **2** pouco provável | Trivial | Tolerável | Moderado | Moderado | Substancial |
| **1** rara | Trivial | Trivial | Tolerável | Moderado | Moderado |

A legenda impressa dá faixas de produto **sobrepostas** (Trivial 1–3, Tolerável 3–8, Moderado 4–12,
Substancial 10–16, Intolerável 15–25), e a célula P=5 × S=3 (produto 15) é "Substancial" apesar de 15
constar em "Intolerável". **O nível é um lookup por célula, não um limiar sobre o produto** — implementar
como tabela. (Nosso BS 8800 usa limiares sobre 1–25; são mecanismos diferentes.)

### 5.4 Nível → ação

| Nível | Ação |
|---|---|
| 1º Intolerável | Ações imediatas |
| 2º Substancial | Controle necessário |
| 3º Moderado | Controle adicional, se possível / viável |
| 4º Tolerável | Nenhum controle adicional necessário |
| 5º Trivial | Nenhuma ação necessária |

### 5.5 Conferência do inventário do exemplo (todas coerentes com a matriz)

| Dimensão | % | P | S | Nível |
|---|---|---|---|---|
| Demandas | 3,1 | 5 | 4 | Intolerável |
| Controle | 91,7 | 1 | 1 | Trivial |
| Apoio da gestão | 90,0 | 1 | 1 | Trivial (90,0 cai na faixa 90–100) |
| Suporte dos colegas | 68,8 | 3 | 3 | Moderado |
| Relacionamentos | 81,3 | 2 | 4 | Moderado |
| Clareza de papel/função | 40,0 | 4 | 4 | Substancial |
| Mudanças | 16,7 | 5 | 4 | Intolerável |

### 5.6 Leitura crítica

- **Por que o mercado quer isso:** o GRO/PGR pede inventário com classificação de risco; um relatório
  só de pesquisa obriga o consultor a traduzir à mão.
- **Por que é frágil:** (a) as faixas 90/75/60/40 são escolha do player, não do HSE; (b) mistura um
  **nível de condição percebida** com uma **probabilidade de evento**; (c) S é ambígua (§5.2); (d) o
  mesmo número aparece como "índice" e como "probabilidade"; (e) não há trava quando a amostra é
  inadequada.
- **Relação com a regra do plano §3** ("nunca converter entre metodologias"): a ponte **não** converte
  HSE em BS 8800; produz um terceiro objeto, a *entrada do inventário*. Mesmo assim, põe numa matriz P×S
  um número que se compara a olho com os níveis do BS 8800 — o que o plano quer evitar plotar junto.

## 6. Comparação com o nosso plano

| Tema | Player | Nosso plano | Leitura |
|---|---|---|---|
| Escala | 1 conjunto de rótulos (frequência) nos 35 itens | 2 conjuntos (`freq` 1–23, `concord` 24–35) | Simplifica UI e schema, mas se afasta do instrumento validado. **Depende de como a ICAO rotula 24–35 (B1)** |
| Classificação | Zonas absolutas 40/75 | Bandas relativas ao benchmark HSE 2023 | Absolutas tornam "Atenção" o estado normal (§3). Manter a nossa |
| Score global | Existe (manchete) | Não existe (HSE não define) | Manter: sem manchete global |
| Escala de exibição | Índice 0–100 + score 1–5 | Média 1–5 + faixa | 0–100 é bom como escala **auxiliar** |
| Direção | Normaliza tudo para alto = bom | Alto = bom nas 7 dimensões | Igual. Copiar a **legenda que inverte o sentido da resposta bruta** |
| Taxa / amostra | "Inadequado" se não responder 100 % (≤ 500) | Taxa > 50 % adequada, < 50 % "indicativo"; tabela de amostra separada | A tabela do HSE diz **quantos convidar/amostrar**, não quantos devem responder. Nosso desenho está certo |
| Ponte para o PGR | Sim (P×S 5×5) | Proibida (§3) | **D1** |
| Granularidade | Setor | GHE por par, agrupamentos, funções, presets | Vantagem nossa |
| Plano de ação | Em branco | Catálogo 5W2H por `cd_risco` (BS 8800); HSE na fase 1.1 | Vantagem nossa; falta o catálogo por dimensão HSE |
| Responsáveis técnicos | 3 profissionais fixos | 1 responsável por laudo (`psicomap_laudo_resp_*`) | Ideia: lista de responsáveis (B19) |
| Branding | "Consultoria não disponível" | `_estPerfil.nome_empresa`; campo some se ausente | Nossa regra está certa; falta **pré-checagem** (D6) |
| Reavaliação | 3 meses fixos | Ciclos por tenant | Derivar do resultado/ciclo (B20) |
| Nome do instrumento | "SIT" | Evitar "Stress Indicator Tool" | Manter |
| Anonimato | Mostra n = 1 | Sem n mínimo (ver abaixo) | **D5** |
| Coleta | Formulário em papel + digitação | Só link online | **D8** |
| Enquadramento | AEP (NR-17) + PGR (NR-1) | "Laudo" | **D7** |

Verificações no nosso repositório feitas para esta comparação (buscas textuais, não auditoria completa):
em `psicomap-admin.html` **não encontrei nenhum limite de n mínimo** por grupo (padrões usuais:
`amostra mínima`, `n < …`, `MIN_N`…), e **"cnae" não ocorre** em nenhum `.sql`, `.html` ou `.md` do repo.

## 7. Decisões propostas (aguardam o usuário)

**D1 — Ponte HSE → inventário do PGR.**
(a) Não fazer — status quo do plano. (b) Fazer, **opt-in, na fase 1.1**: critério como **dado
versionado** (faixas de P e severidade por dimensão editáveis só por `super_admin`, no padrão de
`riscos_config`), declarado no laudo como "critério adotado pela consultoria, não parte do instrumento
HSE", **suprimido ou com selo quando a taxa de resposta < 50 %**, e **nunca plotado com resultados do
BS 8800**. **Recomendo (b)**, depois da Camada 1. As faixas e a severidade precisam de validação por um
profissional de SST — não são decisão técnica minha.

**D2 — Classificação primária.** Manter bandas relativas ao benchmark (plano). Usar o índice 0–100 só
como escala auxiliar das barras. As zonas 40/75 só entram se D1(b) precisar de P.

**D3 — Score global.** Não exibir como manchete. Se um cliente exigir, rotular "média simples das 7
dimensões — referência interna, não é métrica do HSE", fora de destaque.

**D4 — Amostra × taxa.** Adequação = **taxa de resposta** (≥ 50 % adequada, abaixo "dados apenas
indicativos"). A tabela por porte vira texto informativo de dimensionamento, nunca regra de "Inadequado".

**D5 — n mínimo por grupo.** Limite configurável abaixo do qual o sistema **não exibe** resultado por
item/dimensão de um grupo (agrega ou oculta). Vale também para o BS 8800 e para as segmentações por
setor/função/GHE. O valor do limite é decisão do usuário (com jurídico/DPO) — não propus número.

**D6 — Pré-checagem do laudo.** Antes de gerar: consultoria, cidade/UF, responsável técnico e demais
campos obrigatórios; **avisar/bloquear**, nunca imprimir fallback. Segue o padrão do aviso de cobertura
de GHE já existente.

**D7 — Enquadramento do documento.** O player vende o HSE como **AEP-FRPRT (NR-17 + NR-1)**,
encaixando-o no fluxo AEP → AET → PGR. Pode ser um bom argumento comercial; **só adotar depois de
validação por ergonomista/SST** (eu não verifiquei as citações normativas deles).

**D8 — Coleta em papel.** Avaliar um modo presencial (formulário imprimível + digitação em lote) para
quem não tem celular no chão de fábrica. O schema já reserva `fonte = 'import_csv'` (0 linhas em PROD).
Sem desenho; só registro da demanda.

**Adotar (sem decisão pendente, entram no desenho do laudo HSE — PRs 6/7):** página-resumo única;
uma página por dimensão com barras por item e legenda que inverte o sentido; seções fixas de
**Limitações**, **Responsabilidades** e **Participação dos trabalhadores** (texto nosso, revisado por
SST); tabelas de critério impressas no laudo.

**Evitar:** placeholders no documento; seções vazias; resultado por item com n pequeno; "Inadequado" por
exigir 100 % de resposta; manchete global; reavaliação fixa; coleta de idade; texto de item sem versão.

## 8. Backlog proposto (IDs continuam o §16 do plano — **ainda não incorporados lá**)

| ID | Item | Camada | Prioridade | Nasce de |
|---|---|---|---|---|
| B14 | Ponte HSE → inventário PGR, opt-in e versionada | 1.1 | Média | D1 |
| B15 | n mínimo por grupo (HSE **e** BS 8800) | Transversal | **Alta** — independe do HSE | D5 |
| B16 | Pré-checagem de campos obrigatórios do laudo | Transversal | Média | D6 |
| B17 | Coleta em papel + digitação | — | Baixa | D8 |
| B18 | `empresas`: CNAE e grau de risco (NR-4) | Transversal | Baixa | §4 seção 1 |
| B19 | Vários responsáveis técnicos por laudo | Transversal | Baixa | §4 seção 1 |
| B20 | Reavaliação recomendada derivada do resultado / ciclo | 1 | Baixa | §4 defeito 7 |
| B21 | Versionar texto do instrumento por `questionarios.id` | 0 | Média | §2.2 |

B15 e B16 valem **mesmo que o HSE nunca avance** — o primeiro protege o anonimato (regra de negócio 2)
em qualquer segmentação fina que já existe hoje.

## 9. Em aberto — e como destravar

| Dúvida | Como resolver |
|---|---|
| Severidade é fixa por dimensão ou derivada do resultado? | Pedir/obter um 2º relatório do player com resultados bem diferentes (ex.: tudo ótimo; tudo péssimo) |
| O player quebra por vários setores? (o inventário vem rotulado "GERAL") | Relatório de uma empresa com 2+ setores |
| O score exibido é bruto ou invertido? | Entrada com resposta bruta conhecida (hoje só inferi) |
| Como a ICAO rotula os itens 24–35? | B1 — texto/escala da ICAO |
| O player preenche Plano de Ação e Anexos? | Relatório completo de cliente real |
| Citações normativas procedem? | SST / jurídico |

## 10. Fórmulas de referência

```js
// Itens (nossa convenção do plano, §9.3): score sempre "alto = melhor"
score = inv ? (escalaMax + 1 - raw) : raw      // inv = true só em DEMANDS e RELATIONSHIPS

// Player: índice 0–100 e zona
pct   = (media - 1) / (escalaMax - 1) * 100
zona  = pct >= 75 ? 'VERDE' : pct >= 40 ? 'AMARELA' : 'VERMELHA'   // mesmo corte p/ item e dimensão

// Player: ponte PGR (apenas referência — ver D1)
P = pct >= 90 ? 1 : pct >= 75 ? 2 : pct >= 60 ? 3 : pct >= 40 ? 4 : 5
nivel = MATRIZ[P][S]                           // lookup da tabela do §5.3, não limiar do produto
```

Os 4 pontos que mais custariam caro se esquecidos numa implementação: **(1)** inverter só as duas
dimensões; **(2)** a legenda da dimensão invertida descreve a resposta **bruta**; **(3)** a matriz é
lookup; **(4)** nada de exibir item a item com n pequeno.
