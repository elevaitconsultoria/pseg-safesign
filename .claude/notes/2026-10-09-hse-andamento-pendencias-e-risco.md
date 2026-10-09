# HSE/ICAO-35 — o que foi feito, pendências e como calcular risco a partir do HSE

> Documento de passagem de bastão, escrito em 2026-10-09. Complementa
> `2026-10-08-plano-implantacao-hse.md` (plano, com quadro de andamento por etapa),
> `2026-10-08-referencia-hse-player-avalia-nr01.md` (aprendizados do concorrente) e
> `2026-08-03-metodologia-hse-icao35-planejamento.md` (plano original, parcialmente substituído).
> Branch: **`feat/hse-icao35`**, 8 commits, **nenhum push**. **PROD não foi tocado.**

## 1. Estado em uma página

| | |
|---|---|
| Código da v1 (S0–S8) | **Escrito, commitado e testado em DEV** (com harness; ver §5 sobre o que não foi exercitado) |
| DEV (banco) | Migration, RPCs e seed **aplicados** |
| PROD (banco e app) | **Nada aplicado.** Bloqueado por B12 (PITR) e por decisões de conteúdo |
| Caminho crítico até PROD | Pessoas e conteúdo, não engenharia: B12, B1, valor do n mínimo, revisão de SST |
| Branch | `feat/hse-icao35` a partir de `develop` (87b7864); `develop` está 3 commits atrás de `main` (squash dos PRs #90/#91) |

## 2. O que foi feito

### 2.1 Pesquisa e planejamento
- Retomada do plano de agosto (HSE/ICAO-35, 35 itens, 7 dimensões) e **revalidação contra o código e os dois bancos**.
- Análise de dois materiais de um concorrente (formulário impresso e relatório de teste de 23 páginas): fórmulas
  reconstruídas e conferidas, defeitos catalogados, ponte HSE→PGR documentada.
- Plano de implantação em 12 etapas (S0–S11), 25 riscos, estimativa ~37–43 dias-dev, aprovado.
- Decisões do usuário: tabelas separadas para o HSE; n mínimo como trilha própria; exposição livre às ESTs;
  ponte HSE→PGR só na fase 1.1; **uma metodologia por ciclo** com atalho para criar os dois; combo (62 itens) fora da v1
  mas com porta aberta (`_instrumentosDoCiclo`).

### 2.2 Correções ao plano de agosto (achados que mudaram o desenho)
1. **`anon` não lê `ciclos`**: o embed `ciclos(metodologia)` quebraria todo link ("Token inválido") → RPC anônima.
2. `salvar_resposta` de 10 args **não existe no repo** (só a de 7); DEV tem 3 overloads, PROD 2; `session_id` é `uuid` em PROD e `text` em DEV.
3. A falha da RPC **não é auditável** (o `RAISE` desfaz a transação inteira, fila e backup incluídos).
4. Overloads mortos têm **`EXECUTE` para `anon`** nos dois bancos.
5. `respostas.questionario_id` é **NULL em 100%** de PROD (versionar texto só vale daqui em diante).
6. Reusar `questoes`/`resposta_itens` colidiria `H01..H27` com `Q01..Q27` → tabelas separadas.

### 2.3 Implementação (commits da branch)

| Etapa | Commit | O que entrega | Onde está aplicado |
|---|---|---|---|
| Docs + S0 parcial | `a2eac7c` | plano, referência do concorrente, `_dev/check-inline-js.js` | repo |
| **S1** esquema | `3e5bf24` | `ciclos/respostas/questionarios.metodologia`; trigger de imutabilidade; `hse_itens` (congelados ao publicar); `resposta_itens_hse` (1..5); `hse_benchmark`; baselines de `salvar_resposta` | **DEV** |
| **S2** RPC `obter_instrumento_link` + **S4** seed | `4917f5b` | metodologia do ciclo sem dar SELECT em `ciclos` ao `anon`; seed de 35 itens `[RASCUNHO]` + benchmark geral 2023 | **DEV** |
| **S3** `salvar_resposta` | `21f18de` | ramo HSE validado (35 itens, 1..5, sem duplicar, sem item de outro instrumento); ramo BS idêntico; `REVOKE` dos overloads mortos | **DEV** |
| **S5** formulário | `91e9571` | HSE 35 itens em 2 partes, lista vertical, erro permanente não repete; BS e linhas de credencial intocados | repo (testado contra DEV) |
| **S6** admin: escolha e guardas | `b570271` | cartões BS/HSE no "Novo ciclo", atalho "criar também…", selos, guardas nas telas só-BS, fallback sem a coluna | repo |
| **S7** análise HSE | `0b2f59d` | loader próprio, `calcDimensoesHSE`, tela, CSV, n mínimo provisório = 5 | repo |
| **S8** laudo HSE | `eb83ad9` | gerador único (preview = PDF), OGL em toda página, checagem pré-geração, metodologia no histórico | repo |

### 2.4 Arquivos criados ou alterados
- **Novos:** `migration_metodologia_hse_icao35.sql`, `migration_obter_instrumento_link.sql`, `migration_salvar_resposta_hse_dev.sql`,
  `seed_hse_icao35_dev_placeholder.sql`, `_dev/check-inline-js.js`, `_dev/baseline/salvar_resposta_{dev,prod}_2026-10-08.sql`, as notas.
- **Alterados:** `psicomap-forms.html` (S5), `psicomap-admin.html` (S6–S8; código novo em regiões `// ==== HSE … BEGIN/END ====`).
- **Intocados de propósito:** motores e loader do BS 8800 (`calcFatores`, `calcDistribuicaoQuestoes`, `loadRespostasParaEmpresa`),
  `build.js`, linhas `SUPABASE_URL/ANON` do formulário.

### 2.5 Dados de teste deixados em DEV (empresa Allmed)
Links `is_teste`: `hsetests5a01` (HSE), `bstests5a001` (BS), `semciclos5a01` (sem ciclo); ciclos "[TESTE S5] …"; respostas de teste;
link **não-teste** `hsetests7a001` com 8 respostas (5 em "S7 Setor A", 3 em "S7 Setor B") — valores `((k*7+ordem*3)%5)+1`.
Scores de referência (SQL): Relacionamentos 2,8438 · Mudanças 2,8750 · Apoio da gestão 2,9250 · Papel 2,9750 · Suporte dos colegas 3,0000 · Demandas 3,0469 · Controle 3,1042.
Remover quando não forem mais úteis.

## 3. Como o HSE funciona no sistema (resumo)
- **Fluxo:** consultor escolhe a metodologia ao criar o ciclo (trava depois do 1º link/resposta); links herdam; o funcionário nunca escolhe.
  Link sem ciclo = BS 8800. Empresa com as duas = dois ciclos.
- **Cálculo:** valor do item = bruto, ou `6 − v` nos itens invertidos (Demandas e Relacionamentos inteiras); média por item; **score da dimensão = média das médias** (1,00–5,00, alto = melhor).
- **Classificação:** 4 faixas relativas à média de referência HSE 2023: `< ref − 0,50` Ação urgente · `< ref` Necessidade clara de melhoria · `< ref + 0,40` Bom, mas há o que melhorar · acima, Muito bem.
  **Não são percentis oficiais** (não existem na fonte).
- **Taxa de resposta** = respostas do ciclo ÷ quadro; `< 50%` ou sem quadro ⇒ "dados apenas indicativos".
- **Anonimato:** recorte com `< 5` respondentes não exibe resultado (valor **provisório**, só no HSE).

## 4. Testes realizados e o que NÃO foi exercitado

**Feito (DEV, com rollback quando aplicável):** trava de metodologia; congelamento de itens; limite 1–5; ausência de privilégio do `anon`
nas tabelas novas; `obter_instrumento_link` como `anon` (token inválido/inativo/expirado/nulo, sem ciclo, BS, HSE, sem vazar `inversa`/`dimensao`);
`salvar_resposta` (BS 27 itens também como `anon`, idempotência, HSE 35 itens, 9 rejeições sem resíduo); formulário real a 320/375 px
(sem estouro, envio gravou 35 itens, BS inalterado, erro permanente não repete); motor JS contra cálculo de referência em SQL nas 7 dimensões
e nos casos extremos; admin com harness (lógica, guardas, fallback sem coluna, criação de ciclos, tela de análise, preflight, histórico).

**Não exercitado — importante:**
- **Nenhum teste logado no admin real de DEV** (a ferramenta não gera sessão). O harness provou a lógica e o DOM, não o carregamento
  real com RLS por EST de `hse_itens`/`hse_benchmark`/`resposta_itens_hse`.
- **PDF real nunca foi impresso** (só o HTML foi verificado). A paginação precisa de olho humano.
- Formulário **antigo em cache** contra link HSE; fila offline legada (7 parâmetros); tela de erro quando a RPC falha no boot.
- **Golden master do BS 8800** (S0) nunca foi capturado; a regressão do BS foi garantida por construção (código intocado) e por testes pontuais.
- Nada foi testado em PROD.

## 5. Pendências

### 5.1 Dependem de você (humanas / externas)
| # | Pendência | Bloqueia |
|---|---|---|
| B12 | Confirmar **PITR ativo em PROD** (Dashboard Supabase) | qualquer migration em PROD |
| B1 | Texto **validado** dos 35 itens + **permissão dos autores da ICAO** para uso comercial (Ferreira, Freitas, Devotto, Damásio); fallback: tradução profissional do HSE original | go-live |
| S9 | **Valor definitivo do n mínimo** (com o jurídico). Hoje: 5, provisório, só no HSE (`HSE_N_MIN_PROVISORIO`) | S9; amplia a proteção ao BS 8800 |
| SST | Revisar **textos fixos do laudo** e **definição das faixas** (±0,50 / +0,40) | go-live |
| **SST** | **Definir e assinar a severidade (S1–S4) das 7 dimensões** e os "possíveis danos"; aceitar (ou não) faixa do HSE como P | **go-live do HSE** (sem isso o laudo não gera: erro na checagem) |
| Teste logado | Abrir o admin de DEV e percorrer: criar ciclo HSE → responder → analisar → gerar laudo | confiança antes de PROD |
| Push | Autorizar `git push` da branch e o fast-forward `develop ← main` (publica o DEV para todos) | PR e deploy |
| Escala | Definir rótulos únicos × dois conjuntos (depende de como a ICAO rotula os itens 24–35) | B1 |

### 5.2 Técnicas (eu posso fazer)
| Etapa | Pendência |
|---|---|
| S0 | Fast-forward `develop`; dataset formal de teste; **golden master** do BS 8800; PR de hardening do `build.js` |
| S3 | **`migration_salvar_resposta_hse_prod.sql`** (arquivo próprio: `session_id` uuid, 2 overloads) e teste em PROD com link `is_teste` |
| S1/S2 em PROD | Aplicar migration e RPC **antes** de promover o formulário (senão todo link com ciclo falha) |
| S10 | Atualizar `migration_revoke_anon.sql` (a RPC anônima nova) e o CLAUDE.md ("Superfície do anon", seção Metodologias, divergência de overloads DEV/PROD); `RESTAURACAO_BACKUP.md` (novas tabelas e colunas); skill `validar-formulario` (testes HSE, valor 5, `questoes LIMIT 3` pode devolver H, join `text = uuid`) |
| S5 | ~~Testar formulário antigo, fila offline legada e erro de boot~~ — feito em 2026-10-09, ver §5.5 |
| S6 | ~~Trocar a metodologia pela interface; selo no Dashboard e em Clientes~~ — feito em 2026-10-09, ver §5.7 |
| S8b | Aplicar `migration_hse_riscos_config.sql` em PROD (**vazia**); seed de PROD deve **abortar** se houver `validado=false`; ~~tela para SST cadastrar severidade~~ (feita em 2026-10-09, ver §5.6) |
| S9 | `_nMinimo` para o BS 8800 (segmentações, laudo, Auditoria com `session_id`/dispositivo), com o valor definido |
| S11 | `seed_hse_icao35_validado.sql` (guarda `[RASCUNHO]`, publica por último); teste de aceite ponta a ponta; monitoramento (taxa de conclusão por proxy) |
| Seed | Transcrever as **13 médias setoriais** do relatório HSE 2023 (hoje só as gerais) |
| Dados | Limpar os dados de teste de DEV quando não servirem mais |

### 5.5 Testes do formulário em cenários de borda (2026-10-09, DEV)
Harness: cópia do `psicomap-forms.html` (e do `origin/develop`, para o formulário antigo) com credenciais de DEV, `fetch` interceptado.
- **Boot, RPC `obter_instrumento_link` falhando** (HTTP 500, rede caída, 404 de proxy, resposta nula): erro claro "Não foi possível carregar…", sem virar BS 8800 em silêncio. Itens vazios e metodologia desconhecida: mensagens próprias. PGRST202 (função ausente) segue como BS 8800, de propósito.
- **Defeito achado e corrigido:** RPC que **pendura** deixava "carregando" para sempre. Agora `Promise.race` de 20 s → mesmo erro (medido: 20,5 s).
- **Defeito achado e corrigido:** o PostgREST **continua listando os overloads revogados** e responde `PGRST203` (HTTP 300) a chamadas com 7 ou 9 chaves — o `REVOKE` não tira a função do schema cache. A fila offline **legada** (formato `payload`+`itens`, 7 chaves) nunca reenviava (já era assim em PROD com 9+10 args). `reenviarPendentes` agora completa `p_session_id`/`p_lgpd_aceito`/`p_device_info`, e a chamada casa só com a de 10 args (400 funcional). Resposta HSE recusada é descartada; erro transitório fica na fila.
- **Formulário antigo contra link HSE** (código pré-S5, não corrigível): mostra 27 questões; o servidor recusa com `hse_incompleto`, **nada é gravado**, mas o respondente vê "guardada localmente — tente novamente" e fica uma pendência que nunca passa. O formulário novo limpa essa pendência (erro permanente → descarta). **Regra operacional:** promover o formulário (S5) **antes** de criar qualquer ciclo HSE em PROD; o HTML do CF Pages revalida (`_headers` não cacheia), então o risco real é só aba já aberta.
- Regressão: links BS (com e sem ciclo) seguem com 27 questões × 4 opções, sem erro.
- Não testado: fila legada contra link BS válido (gravaria resposta real); recarga com `bfcache`.

### 5.6 Tela do critério de severidade HSE (2026-10-09)
Card **"Critério de risco do HSE"** em **Gestão de ESTs** (`#hse-riscos-card`; `hseRiscosCfgRender`/`hseRiscosCfgSalvar`, bloco `HSE (S8b-UI)`). Só super_admin: é quem a RLS deixa gravar e a tela já é exclusiva dele; o guard também está nas funções.
- **Critério único e global** (vale para todas as ESTs): versão única para as 7 dimensões (o laudo imprime o maior valor); a assinatura cobre o conjunto.
- **Validação nunca é implícita:** qualquer mudança em S ou danos derruba a assinatura de **todas** as linhas e sobe a versão; validar exige as 7 severidades + responsável (nome e registro, ≥5 caracteres) + confirmação. Rascunho parcial é permitido. Salvar sem mudança não grava nada.
- Diferente do loader do laudo (que degrada para "critério ausente"), a tela **mostra o erro** se a tabela não existe (migration não aplicada).
- Testes: harness com `sbAdmin` fake que imita o CHECK (13 cenários, 0 violações) + **banco real de DEV** com `set_config`/ROLLBACK: super_admin grava no formato da tela; admin é barrado pela RLS (UPSERT) e não altera nada (UPDATE); CHECK `hse_riscos_validado_completo` barra "validado sem responsável"; DEV voltou intacto.
- **Quem valida de fato:** o super_admin digita o nome/registro de quem assinou — o sistema registra a declaração, não autentica o profissional de SST. A assinatura real continua sendo fora do sistema (por escrito).
- Não testado: renderização visual (login real no DEV) e o fluxo logado de ponta a ponta.

### 5.7 Troca de metodologia e selos por empresa (2026-10-09)
- **Trocar metodologia pela interface** (modal Ciclos): botão "⇄ Trocar para HSE/BS 8800" só enquanto o ciclo não tem link carregado; com link aparece "🔒 metodologia travada". O banco é a autoridade (trigger `tg_ciclo_metodologia_imutavel`): se outra sessão criou link/resposta no meio, a recusa vira mensagem clara e o estado local não muda. Renomeia **só** nomes gerados pelo sistema (`Avaliação — Mês Ano` ↔ `Avaliação HSE — Mês Ano`); nome editado à mão é preservado. Só existe com HSE publicado e módulo `hse` ligado.
- **Selos por empresa** (Dashboard, grade e lista de Clientes): `BS 8800` e/ou `HSE` conforme os ciclos da empresa (+ link sem ciclo = BS). Sem HSE publicado nada aparece (comportamento anterior idêntico).
- **Bug de números evitado:** a "adesão bruta" dividia a **soma** das respostas de todos os links pelo quadro. Com um ciclo BS e outro HSE na mesma empresa isso contava a mesma pessoa duas vezes (80 BS + 60 HSE = 140/100). Agora `m.respAdesao` = respostas do instrumento com **mais** respostas (`max(BS, HSE)`); com um instrumento só, é igual a `respTotal` (nada muda). Vale para chip do Dashboard, barra de Clientes, urgência e KPI da carteira (no teste: 83% → 63%). `respTotal` continua sendo o total (tile "Respostas", status "N resp.") e o tooltip mostra a divisão BS/HSE.
- **Não alterado, vale revisar:** a tela **Adesão** (`calcRepresentatividade`) e o painel por link seguem com a lógica própria; não verifiquei como elas tratam empresa com os dois instrumentos.
- Testes: banco real de DEV (admin troca sem link; trigger barra com link; viewer 0 linhas; ROLLBACK) + harness com 13 verificações de UI e números. Não testado: sessão logada real.

### 5.3 Fase 1.1 (fora da v1)
Opção D (prevalência) como complemento ao risco, comparativo/plano de ação/auditoria/gráficos para HSE, catálogo de ações por dimensão, coleta em papel,
CNAE e grau de risco em `empresas`, vários responsáveis técnicos no laudo, reavaliação derivada do resultado, seções editáveis do laudo HSE, combo.

### 5.4 Ordem sugerida para chegar a PROD
1. B12 → 2. golden master + push/PR → 3. S1, S2, S3-prod aplicados em PROD (janela calma: PROD teve 0 respostas em 7 dias em 2026-10-08) →
4. promover o app (S5–S8; sem o seed validado o HSE fica invisível em PROD) → 5. B1 + SST + n mínimo → 6. seed validado (publica) → 7. teste de aceite → 8. piloto.

## 6. Como calcular **risco** a partir do HSE

> **DECISÃO (2026-10-09):** o usuário confirmou que o cliente que contrata **só o HSE precisa de nível de risco no PGR**
> (NR-01 exige riscos psicossociais no inventário). A ponte deixa de ser "fase 1.1 opcional" e passa a ser **parte do que o laudo HSE entrega**.
> Escolhido: **P a partir da faixa do HSE** (opção C) e **severidade definida por SST** (o sistema só traz o mecanismo).
> Implementado como etapa **S8b** — ver §6.7. Os parágrafos abaixo preservam a análise que levou à decisão.

### 6.1 A resposta curta
**O HSE não calcula risco.** Ele mede a condição percebida de cada dimensão e diz onde agir primeiro (as 4 faixas). Não existe fórmula oficial
HSE → "nível de risco". Qualquer P×S derivado do HSE é um **critério adotado pela consultoria**: precisa ser declarado no laudo, versionado e validado
por profissional de SST. Isso é possível, e o mercado o faz porque o inventário do PGR exige um nível de risco — mas deve ficar **separado** do resultado do HSE.

### 6.2 O que o concorrente fez (e por que é frágil)
- P (1–5) por faixas do índice 0–100: ≥90 → 1; 75–89 → 2; 60–74 → 3; 40–59 → 4; <40 → 5. S (1–5) por dimensão. Nível por matriz 5×5 (lookup por célula).
- Fragilidades: faixas 90/60 inventadas; mistura "nível de condição" com "probabilidade de evento"; a severidade parece depender do resultado
  (Controle e Apoio com S=1 quando saem bem), o que faria P e S deixarem de ser independentes; ignora a taxa de resposta (amostra "inadequada" ainda gera "Intolerável");
  a manchete (média geral) contradisse o inventário.

### 6.3 Opções para o PsicoMap

| Opção | Como | Prós | Contras |
|---|---|---|---|
| **A. Não converter** (status quo) | HSE = diagnóstico; o consultor leva as dimensões em risco ao inventário com P×S **do BS 8800** | Sem criar critério novo; mais defensável | Trabalho manual; cliente que só contrata HSE fica sem nível de risco |
| **B. Ponte do concorrente** | Índice 0–100 → P (5 faixas), S por dimensão, matriz 5×5 | Familiar ao mercado | Faixas arbitrárias; vocabulário novo (Trivial…Intolerável) |
| **C. Ponte pelas faixas do próprio HSE (recomendada como candidata)** | As **4 faixas** (relativas ao benchmark) viram **P1–P4**; **S1–S4 fixa por dimensão** (catálogo validado por SST); nível pela **mesma matriz 4×4** do BS 8800 | 4 faixas ↔ 4 níveis de P, sem inventar cortes novos; reusa `MATRIZ_RISCO`, vocabulário e laudo do PGR | O nível parece comparável ao do BS 8800 (mitigar rotulando "derivado do HSE" e nunca no mesmo gráfico); S é julgamento |
| **D. Prevalência de exposição** | P a partir do **% de respondentes em resposta desfavorável** (ex.: itens normalizados ≤ 2) em vez da média | Mais próximo de "probabilidade de a condição atingir pessoas"; sensível a bimodalidade (média esconde) | Corte de "desfavorável" é escolha; sem benchmark oficial para essa medida |

**Recomendação:** tratar a **C** como candidata principal (e a **D** como complemento de leitura), entregue como **recurso opcional da fase 1.1**, não como parte do resultado HSE.

### 6.4 Desenho proposto para C (para validação, não implementado)
1. **Fonte do P:** a faixa da dimensão (já calculada): Ação urgente → P4 · Necessidade clara de melhoria → P3 · Bom, mas há o que melhorar → P2 · Muito bem → P1.
2. **Fonte do S:** tabela `hse_riscos_config` (padrão de `riscos_config`), uma linha por dimensão, **fixa e independente do resultado**, editável só por `super_admin`,
   com texto de "possíveis danos" por dimensão. Valores de S **dependem de SST/psicólogo** — não sugiro números aqui.
3. **Nível:** `MATRIZ_RISCO[P_S]` (a mesma do BS 8800) → Irrelevante/Baixo/Médio/Alto/Crítico.
4. **Travas:** só gera quando a taxa de resposta é adequada (≥ 50%) e o recorte atende ao n mínimo; abaixo disso a seção sai marcada como "indicativa" ou não sai.
5. **Transparência no laudo:** seção "Critério adotado pela consultoria" com as tabelas de P e S e a frase de que **esta conversão não faz parte do instrumento HSE**.
6. **Separação:** nunca no mesmo gráfico do BS 8800; no inventário do PGR cada linha indica a origem (HSE ou BS 8800).
7. **Versionamento:** a versão do critério entra no `snapshot_json` do laudo (como já entram metodologia e texto dos itens).

### 6.5 Exemplo com os dados de DEV (apenas ilustrativo — S fictício)
Dimensão **Demandas**: score 3,05 contra referência 3,25 ⇒ faixa *Necessidade clara de melhoria* ⇒ **P3**. Se o catálogo de SST definisse S = 3 (Sério),
a matriz daria P3×S3 = **Alto**. Já **Mudanças** (2,88 contra 3,30; faixa *Necessidade clara de melhoria*) também daria P3, e o nível dependeria só do S da dimensão.
Isso mostra o ponto sensível: **com P vindo de apenas 4 faixas, a severidade passa a decidir quase todo o resultado** — por isso o catálogo de S precisa de validação técnica.

### 6.6 Perguntas que bloqueiam a decisão
- Um profissional de SST aceita "faixa relativa ao benchmark = probabilidade"? Se não, a opção D ou a A.
- Quem define e assina o catálogo de severidade por dimensão?
- O cliente que contrata só HSE precisa mesmo de nível de risco no PGR, ou o diagnóstico + grupos focais basta?
- As citações normativas que o concorrente usa (NR-01, NR-17, AEP/AET) **não foram verificadas por nós**; antes de posicionar o laudo HSE assim, validar com SST/jurídico.

### 6.7 Implementação da opção C (S8b) — o que existe agora
- **Banco:** `migration_hse_riscos_config.sql` — tabela `hse_riscos_config` (uma linha por dimensão: `severidade` 1–4, `danos`, `versao`, `validado`, `validado_por`, `validado_em`).
  Trava de coerência: `validado = true` exige severidade, responsável e data. Leitura `authenticated`; escrita só `super_admin`; **nenhum acesso do `anon`**.
  Aplicada em **DEV** com `seed_hse_riscos_config_dev_teste.sql` (valores arbitrários, `validado=false`, **nunca em PROD**).
- **Cálculo (`calcRiscoHSE`):** `P = {Ação urgente:4, Necessidade clara de melhoria:3, Bom, mas há o que melhorar:2, Muito bem:1}`; `S` da tabela; nível = **`MATRIZ_RISCO[P_S]`** (a mesma do BS 8800).
  Conferido contra a matriz nas 7 dimensões dos dados de DEV.
- **Tela de análise:** bloco "Risco para o PGR · critério derivado do HSE" por recorte, com a declaração de que não faz parte do instrumento e não é comparável ao BS 8800.
  Sem severidade cadastrada: **não calcula**, explica. Critério não validado: marca "CRITÉRIO NÃO VALIDADO". Taxa baixa: marca "dados apenas indicativos".
- **Laudo:** nova **seção 4 "Risco psicossocial para o PGR"** (critério adotado, tabela por dimensão, por recorte ≥ mínimo, tabela de severidade e matriz 4×4 impressas, "validada por …").
  Seções renumeradas (5 itens, 6 recomendações, 7 referências). **Checagem pré-geração:** sem severidade cadastrada = **erro** (o laudo não alimentaria o PGR);
  cadastrada mas não validada = aviso + documento marcado "CRITÉRIO NÃO VALIDADO" (capa e rodapé).
- **Histórico:** o `snapshot_json` guarda versão do critério, validação, severidades e as linhas P/S/nível do documento.
- **O que NÃO foi feito:** tela para SST cadastrar a severidade (hoje é SQL por `super_admin`); a opção D (prevalência) como complemento; o catálogo de "possíveis danos"
  (campo `danos` fica a cargo de SST); validação por SST de **qualquer** valor.
- **Ponto sensível, de novo:** com P vindo de só 4 faixas, a severidade decide quase todo o nível. Nos dados de DEV, 5 das 7 dimensões caem em P4 e o nível sai quase todo "Alto".
  A calibração (e se faixa relativa ao benchmark é aceita como probabilidade) é decisão de SST.

## 7. Riscos conhecidos (resumo)
Ver R1–R25 no plano. Os que estão mais vivos agora: promover o formulário antes da RPC em PROD (R2); texto `[RASCUNHO]` chegando a PROD (R4);
resultado de grupo pequeno no BS 8800 (R5, ainda sem proteção); erro de sintaxe no JS inline sem CI (R6, mitigado por `_dev/check-inline-js.js`);
primeira resposta HSE real torna o esquema irreversível (R3, mitigado por `publicado=false` como chave geral).

## 8. COMO RETOMAR (leia isto primeiro numa sessão nova)

**Estado do repositório (2026-10-09, fim da sessão):** branch `feat/hse-icao35`, **10 commits à frente de `origin/develop`, nenhum push**, working tree limpo
(só `deno.lock` e `supabase/.temp/` sem versionamento, que não são nossos). Nenhum servidor local ficou rodando.
Commits: `a2eac7c` docs/S0 · `3e5bf24` S1 · `4917f5b` S2+S4 · `21f18de` S3 · `91e9571` S5 · `b570271` S6 · `0b2f59d` S7 · `eb83ad9` S8 · `0e921d5` doc · `098ebad` S8b.

**Estado dos bancos:** DEV (`szqatgvgghxvyyncsjxl`) tem tudo aplicado: S1, S2, S3, S4 (seed `[RASCUNHO]`), S8b (tabela + seed de TESTE).
**PROD (`vftyiildukrpgmnbcnao`) não tem nada.** Antes de qualquer coisa em PROD: **B12 (PITR)** e janela calma (`select count(*) from respostas where respondido_em > now() - interval '7 days'` = 0 em 2026-10-08).

**Ordem para ir a PROD** (cada passo só depois do anterior verificado):
1. Usuário confirma B12. 2. `git fetch` e fast-forward `develop ← main` (publica o DEV). 3. Capturar o golden master do BS 8800 (precisa do usuário logado no admin de DEV).
4. Aplicar em PROD: `migration_metodologia_hse_icao35.sql` → `migration_obter_instrumento_link.sql` → `migration_salvar_resposta_hse_prod.sql` (**já escrita em 2026-10-09, NÃO aplicada**; gerada do `_dev` com `session_id` uuid e REVOKE só do overload de 9 args; hash da função viva em PROD conferido = baseline; reconferir antes de aplicar) → `migration_hse_riscos_config.sql` (vazia). Testar cada um (`SET LOCAL ROLE anon`, `/validar-formulario` com link `is_teste`).
5. Só então promover o app. Sem o seed validado o HSE fica invisível em PROD. 6. Seed validado (texto B1 + severidade validada por SST) → teste de aceite → piloto.

**Faltando para o go-live (todos dependem de pessoas):** B12 · B1 (texto ICAO + permissão dos autores) · severidade S1–S4 por dimensão assinada por SST + aceitar faixa como P · revisão de SST dos textos fixos do laudo e das faixas · valor definitivo do n mínimo (hoje 5, provisório, só HSE).

**Pendências técnicas, em ordem de valor:** (1) ~~arquivo S3 de PROD~~ (feito, falta aplicar e testar em PROD); (2) `migration_revoke_anon.sql` + CLAUDE.md (seção Metodologias, superfície do anon: **a RPC `obter_instrumento_link` é anônima**), `RESTAURACAO_BACKUP.md`, skill `validar-formulario`; (3) ~~tela para SST cadastrar `hse_riscos_config`~~ (feita, §5.6);
(4) `_nMinimo` também no BS 8800; (5) testes do formulário: versão antiga em cache, fila offline legada, falha da RPC no boot; (6) trocar metodologia pela UI antes do 1º link; selo no Dashboard/Clientes; (7) 13 médias setoriais do benchmark; (8) PR de hardening do `build.js`.

**Como validar sem login (o que foi feito):** harness no Browser pane — servir uma cópia do HTML com credenciais de DEV (`__SUPA_URL__`/`__SUPA_ANON__` entre aspas), substituir `sbAdmin` por um falso e chamar as funções no console.
Isso prova lógica e DOM, **não** o carregamento real com RLS: o usuário precisa abrir o admin de DEV logado e percorrer ciclo HSE → responder → analisar → laudo.

**Cuidados aprendidos (para não repetir):**
- `develop` é compartilhada e vai inteira para `main`; nunca `git add -A`; conferir `git branch --show-current` antes de commitar.
- O formulário público tem credenciais de PROD hardcoded (`:350-351` hoje); `build.js` as troca por regex — não editar essas linhas.
- O erro da query de ciclos em `carregarEmpresas` era engolido: por isso o fallback sem `metodologia`.
- Não usar `.eq('is_oficial', true)`/`r.q` para HSE (H01..H27 colidiria com Q01..Q27): HSE tem loader e tabelas próprios.
- Dados de teste em DEV (Allmed): links `hsetests5a01`, `bstests5a001`, `semciclos5a01` (`is_teste`) e `hsetests7a001` (não-teste, 8 respostas); limpar quando não servirem.

