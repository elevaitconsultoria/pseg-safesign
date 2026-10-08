# Plano geral — HSE/ICAO-35 como segunda metodologia do PsicoMap

> **Status: plano de implantação APROVADO em 2026-10-08 — execução ainda não iniciada além de S0 local.**
> Substitui o §11 (sequência de PRs) do plano de agosto
> (`2026-08-03-metodologia-hse-icao35-planejamento.md`). Aprendizados de mercado em
> `2026-10-08-referencia-hse-player-avalia-nr01.md`. Acompanhar o andamento marcando as etapas
> abaixo (S0…S11) conforme forem concluídas e verificadas.

## Andamento (atualizar a cada etapa)

| Etapa | DEV | PROD | Observação |
|---|---|---|---|
| S0 higiene/baseline | parcial | — | `_dev/check-inline-js.js` e baselines de `salvar_resposta` feitos; **falta** fast-forward `develop`←`main`, dataset de teste e golden master (precisa de login no admin de DEV) |
| S1 esquema | **aplicado e testado** (2026-10-08) | pendente — **B12 (PITR)** | trava de metodologia, congelamento de itens, limites 1–5 e ausência de privilégio do `anon` verificados |
| S2 RPC `obter_instrumento_link` | **aplicada e testada como `anon`** | pendente (aplicar antes do formulário) | mesmo erro para token inexistente/inativo/expirado; HSE não vaza `inversa`/`dimensao` |
| S3 `salvar_resposta` | **aplicada e testada** (`migration_salvar_resposta_hse_dev.sql`) | pendente — arquivo próprio de PROD (`session_id` uuid, 2 overloads) | BS 27 itens ok (também como `anon`), idempotência ok, HSE 35 itens ok, 9 rejeições sem resíduo, overloads mortos sem EXECUTE |
| S4 seed placeholder | **aplicado** (35 itens, 12 invertidos, 7 dimensões, benchmark geral) | **nunca** | só médias gerais do benchmark; as 13 médias setoriais precisam ser transcritas da fonte |
| S5…S11 | não iniciadas | — | |

Pendência técnica anotada no S3: a fila offline do formulário (formato legado) chama a RPC com 7 parâmetros nomeados; em DEV isso agora resolve para o overload de 10 args. Conferir no S5.

## Context

Hoje o PsicoMap aplica **uma metodologia só**: BS 8800 (27 questões Q01..Q27, escala 1–4, P×S, alto = pior). A decisão de produto (2026-08-03) é a consultoria poder **escolher a metodologia ao criar o ciclo**, começando pelo **HSE Management Standards / ICAO-35** (35 itens H01..H35, 7 dimensões, escala 1–5, média por dimensão, alto = melhor, classificação por bandas relativas ao benchmark HSE 2023).

Existe um plano técnico de agosto (`.claude/notes/2026-08-03-metodologia-hse-icao35-planejamento.md`) e agora o documento de aprendizados do relatório de teste de um concorrente (`.claude/notes/2026-10-08-referencia-hse-player-avalia-nr01.md`). **Nada foi implementado** (0 ocorrências de `HSE_ICAO35` no repo; nenhuma coluna `metodologia` em DEV nem em PROD).

Este plano **revalida o de agosto contra o código e os dois bancos de hoje (2026-10-08)**, corrige o que ficou falso, incorpora os aprendizados do concorrente e ordena a execução em etapas com dependência, gate de verificação, risco, rollback e tamanho. Foi feito com 3 explorações de código (admin, formulário/build, banco/convenções), consultas somente-leitura nos dois Supabase e uma revisão crítica independente do desenho.

## Decisões já tomadas (por você)

| Tema | Decisão |
|---|---|
| Dados do HSE | **Tabelas separadas** (`hse_itens`, `resposta_itens_hse`); `respostas` continua o cabeçalho compartilhado. Troca o plano de agosto, que reaproveitava `questoes`/`resposta_itens`. |
| n mínimo por grupo | **Trilha própria**, independente do HSE (vale para o BS 8800 também). Eu implemento o helper; **você e o jurídico fixam o valor antes dessa etapa**. |
| Exposição | **Livre para todas as ESTs** (escolha no ciclo), assim que o instrumento estiver *publicado* no ambiente. |
| Ponte HSE → inventário PGR (matriz 5×5 do concorrente) | **Fase 1.1**, depois da v1 validada em produção, com faixas revisadas por SST. Fora desta v1. |
| Fluxo para a mesma empresa | **Uma metodologia por ciclo, escolhida na criação, com atalho "criar também um ciclo com a outra metodologia".** Funcionário responde 27 ou 35 itens por link; análise e laudo separados por perfil. |
| Combo (um link, 62 itens, duas saídas) | **Fora da v1.** A v1 **deixa a porta aberta**: telas consultam `_instrumentosDoCiclo()` (lista, 1 elemento) e a metodologia aceita extensão. |

Decisões técnicas que adotei (diga se quiser outra): a metodologia chega ao formulário por uma **RPC anônima `obter_instrumento_link(token)`**, não por GRANT em `ciclos`; o **texto dos 35 itens vive no banco**, não no JS do formulário; **sem trigger por linha** de validação de escala; a RPC `salvar_resposta` do BS 8800 **não fica mais restritiva** nesta v1.

## Fluxo de uso (UX) — como o sistema se comporta

**Princípio:** a metodologia é uma propriedade do **ciclo** (a campanha). Escolhe-se uma vez, antes de qualquer link; link, formulário, análise e laudo apenas herdam. O funcionário nunca escolhe nem vê o nome da metodologia.

| Pergunta | Desenho |
|---|---|
| O consultor define antes da campanha? | **Sim**, no modal "Novo ciclo": dois cartões (BS 8800 / HSE) com texto de orientação ("quando usar"). Dá para trocar até o 1º link ou resposta; depois **trava** (trigger no banco + campo desabilitado com explicação). Ciclos existentes = BS 8800. Link "sem ciclo" = BS 8800 (com aviso na tela de links). |
| Um questionário só com as duas (≈ 62 itens, 2 saídas)? | **Não na v1.** Dobra a sessão do funcionário (27 → 62), e o HSE só é válido como "adequado" com taxa de resposta ≥ 50% — questionário mais longo ataca justamente isso; a validação do instrumento pressupõe aplicação isolada; misturar exige decidir ordem dos blocos e salvar-e-continuar. Fica como **v2 ("avaliação aprofundada")**; a v1 deixa a porta aberta (abaixo). |
| Definir 1 e tratar 2 perfis? | **Sim — é o desenho recomendado.** Um "perfil" por ciclo: formulário, tela de análise, laudo, taxa de resposta e histórico trocam sozinhos conforme a metodologia do ciclo selecionado. |
| Empresa que quer as duas | **Dois ciclos**, criados juntos pelo atalho "Criar também um ciclo com a outra metodologia"; cada um com links próprios, que podem ser escalonados (ex.: HSE em outubro, BS 8800 em novembro). Análise e laudo separados; nunca no mesmo gráfico. |

**Passo a passo da consultoria**
1. **Cliente e GHE** — sem mudança.
2. **Novo ciclo** — mês/ano + cartões de metodologia + aviso de trava + atalho para criar o segundo ciclo. Se escolher HSE e a empresa não tem quadro de funcionários, aviso: "a taxa de resposta não poderá ser calculada" (link para o GHE).
3. **Links** — o seletor de ciclo mostra "Avaliação HSE — Out/2026 · HSE"; a lista de links ganha o selo; mensagem do WhatsApp/QR igual à de hoje.
4. **Acompanhamento** — Dashboard, Clientes e Adesão por ciclo, com selo. A adesão HSE usa a leitura de taxa do HSE (≥ 50% adequada; faixas 60/70/80); o BS 8800 mantém a meta atual de 70%.
5. **Resultados** — empresa + ciclo; o selo da metodologia aparece junto do ciclo ativo e a tela renderiza o perfil (BS: níveis P×S, por risco/questão; HSE: resumo, 7 dimensões, itens, benchmark, selo "indicativo"). **"Todos os ciclos" numa empresa com as duas pede para escolher um ciclo** (Análise e Laudo); as demais telas listam por ciclo.
6. **Laudo** — seleciona o ciclo; seções do catálogo do perfil; o histórico mostra o selo e "Reaplicar" respeita o perfil.

**Funcionário:** mesmo link, mesma entrada de hoje, instrumento definido pelo ciclo. BS 8800: igual a hoje. HSE: instruções com "últimos 6 meses", identificação (setor/função/escolaridade), 35 itens em duas partes (frequência / concordância), 5 opções, envio e agradecimento.

**Telas na v1**

| Tela | Ciclo BS 8800 | Ciclo HSE |
|---|---|---|
| Dashboard, Clientes, Links, Adesão | Como hoje (com selo) | Sim, com taxa HSE própria |
| Resultados (Análise) | Como hoje | **Perfil HSE** |
| Laudo / Histórico / Presets | Como hoje | **Laudo HSE**; metodologia gravada no histórico |
| Exportar CSV | Como hoje | Sim (item a item, sem identificação) |
| Gráficos, Comparativo, Plano de ação, Auditoria | Como hoje | Aviso "previsto na fase 1.1" (a Análise HSE já traz as barras por dimensão) |
| Questionário da empresa | Como hoje | "Instrumento fechado" (não personalizável) |
| Metodologia (ajuda) / Riscos config | Como hoje | Ajuda ganha aba HSE; Riscos config não se aplica |

**Casos de borda:** ciclo existente → BS 8800; link sem ciclo → BS 8800; ciclo apagado com formulário aberto → mensagem clara, nada é gravado; trocar de metodologia depois do 1º link → bloqueado (criar novo ciclo); empresa sem headcount → "taxa não calculável" + selo "indicativo"; `cliente_viewer` vê análise/laudo do perfil do ciclo, mesma regra de acesso de hoje.

**Porta aberta para o combo (v2), sem custo relevante agora:** as telas perguntam `_instrumentosDoCiclo(cicloId)` (uma lista; na v1 sempre com 1 elemento), as respostas HSE já vivem em tabela própria (um combo só preencheria as duas) e o CHECK de metodologia é extensível. Faltaria: ordem/blocos, salvar-e-continuar, seletor de instrumento dentro da tela e do laudo, completude por instrumento na RPC (estimativa minha: L–XL, e só depois de ver taxa de conclusão real do HSE sozinho).

## O que mudou desde agosto — verificado hoje

| # | Plano de agosto dizia | Realidade (2026-10-08) | Efeito |
|---|---|---|---|
| 1 | O form lê `ciclos(id, metodologia)` sem policy nova (`pub_read_ciclos` existe) | **`anon` não tem SELECT em `ciclos`** (nem DEV nem PROD; revogado de propósito em `migration_revoke_anon.sql`). O embed derrubaria **toda** a leitura do link: todo link mostraria "Token inválido". | **Bloqueio.** Nova RPC anônima (S2). |
| 2 | Base do `CREATE OR REPLACE`: `supabase_security_migrations.sql:47-186` | Esse arquivo só tem a versão de **7 args**, obsoleta. A de 10 args (viva) **não está no repo**. PROD tem 2 overloads; **DEV tem 3** (7, 9 com `session_id text`, 10). `session_id` é `uuid` em PROD e `text` em DEV. | Partir de `pg_get_functiondef` por ambiente; um arquivo por ambiente. |
| 3 | "A falha fica auditável em `respostas_fila`" | **Falso.** O handler faz `RAISE`, a transação inteira desfaz (fila e `raw_backup` incluídos). Só sobram log do Postgres e o `localStorage` do cliente. | Classificar erros no cliente; ler logs nas primeiras semanas. |
| 4 | Overloads mortos são inofensivos | Em **ambos** os bancos os overloads mortos têm **EXECUTE para `anon`** e filtram `BETWEEN 1 AND 4`. | `REVOKE EXECUTE` neles no S3 (reversível; o `DROP` fica para depois). |
| 5 | PROD: 288 respostas | **1.855 respostas / 50.085 itens** (=1.855×27 exato); 9 empresas; 246 respostas em 30 dias, **0 nos últimos 7**. | Migration continua barata (ms), mas o raio de dano cresceu; janela calma agora. |
| 6 | Ciclo sempre presente | PROD: 11 links, **3 sem ciclo (2 ativos)**; 8 respostas com `ciclo_id` NULL. | Ciclo NULL ⇒ BS 8800, sempre. |
| 7 | `respostas.questionario_id` daria rastreabilidade (B21) | **NULL em 100% das linhas** de PROD (a RPC copia de `empresas.questionario_id`, também NULL). | B21 só vale para o HSE daqui em diante; corrigir a nota de referência. |
| 8 | `COMBOS_AUTO_APPLY`, capa com "Mulhausen & Damiano" hardcoded, `calcFatores` em exportarCSV/Auditoria/renderGraficos, bloco LGPD no laudo | Não existem mais (viraram `COMBO_RENDER`/`COMBO_CASCATA`; capa sem metodologia). `calcFatores` tem **10 chamadas em 7 funções**; há um **2º motor** hardcoded 1–4 (`calcDistribuicaoQuestoes`, 4 chamadores); `exportarCSV` já foi corrigido. | Guardas em mais pontos que "3". |
| 9 | Loader generalizado com prefixo `H` e `r.q={int:valor}` | H01..H27 **colidiriam** com Q01..Q27 (mistura silenciosa). Com o loader atual intocado, linhas HSE somem (`r.q` vazio, descartadas em `:12779`) — padrão seguro. | Loader HSE separado, estrutura disjunta. |
| 10 | Linhas de código (forms 333-334, admin :6506 etc.) | Forms: credenciais em **`:337-338`**; admin tem **21.399 linhas**. | Referenciar por nome de função, não por linha. |
| 11 | — | `develop` está **3 commits atrás de `main`** (squash dos PRs #90/#91; `develop` sem commits exclusivos). | S0: fast-forward antes de começar. |
| 12 | — | 5 montadores de `<select>` de ciclo, nome de ciclo auto-gerado ("Avaliação — Mês Ano") **idêntico** para dois ciclos do mesmo mês, contexto global `_cicloAtivo`; `gerarLaudoPDF` duplica `_filtroLaudo`; preview e PDF do laudo são geradores independentes que já divergiram. | S6/S8. |
| 13 | — | **Sem testes automatizados nem CI**; deploy é de arquivo único, `develop` compartilhada e promovida inteira a `main`. | Ferramentas de verificação criadas em S0. |

## Arquitetura-alvo (resumo)

**Banco (S1).** `ciclos.metodologia` e `respostas.metodologia` (`'BS8800'` default, CHECK `BS8800|HSE_ICAO35`) com **trigger de imutabilidade** (não muda se o ciclo já tem link ou resposta). `questionarios` ganha `metodologia`, `versao`, `publicado` (default false; a linha BS existente entra `true`), `config jsonb` (instruções, cabeçalhos das duas partes, rótulos, texto LGPD). `hse_itens(id, questionario_id, codigo, ordem, parte, dimensao, texto, inversa, escala_labels, UNIQUE(questionario_id,codigo))` e `resposta_itens_hse(resposta_id, item_id, valor smallint CHECK 1..5, PK(resposta_id,item_id))` com FK `RESTRICT` no item. `hse_benchmark` (leitura `authenticated`, escrita `super_admin`; `p20/p50/p80` permanentemente NULL). Novas tabelas: RLS + `GRANT authenticated` + `REVOKE ALL FROM anon`, políticas copiadas das de `resposta_itens` (lidas do banco vivo). **Nenhuma** tabela de BS 8800 é alterada.

**RPCs (S2, S3).** `obter_instrumento_link(p_token)` — `SECURITY DEFINER`, `search_path=public`, `EXECUTE` só para `anon, authenticated`, mesma resposta para token inexistente/inativo/expirado, termina com `NOTIFY pgrst,'reload schema'`. BS 8800 → `{metodologia, ciclo_id}`; HSE → instrumento completo (sem `inversa`/`dimensao`). `salvar_resposta`: **mesma assinatura de 10 args, sem parâmetro novo**; deriva a metodologia do ciclo (`ciclo_id` NULL ⇒ BS8800); ramo HSE valida 35 itens distintos do questionário do ciclo, valor 1..5, grava `respostas.metodologia/questionario_id` + `resposta_itens_hse`; erro explícito com prefixos permanentes (`instrumento_incompativel`, `hse_incompleto`, `valor_fora_da_escala`, `item_duplicado`, `ciclo_inexistente`); ramo BS 8800 **literalmente igual ao de hoje**.

**Formulário (S5).** Boot: leitura do link e `obter_instrumento_link` em paralelo; BS 8800 continua usando o mapa de questões atual. HSE: itens H01..H35 na **ordem original, em duas partes** (frequência H01–H23 / concordância H24–H35, uma frase de cabeçalho cada, sem mostrar o nome da dimensão ao respondente); layout de 5 opções **prototipado a 320/360/390 px** (lista vertical vs. controle segmentado); constantes 27/1–4/'Q' parametrizadas só para o HSE; `FORM_VERSION`; marcador informativo no payload offline + classificação de erro permanente × transitório (rejeição permanente sai da fila e mostra mensagem). Linhas `337-338` não se tocam.

**Admin (S6–S8).** `_metodologiaDoCiclo` como ponto único; seletor no modal de ciclo (só quando há instrumento publicado no ambiente); `_cicloLabel(c)` nos 5 montadores/9 selects (sufixo só para HSE); guardas de entrada nas telas só-BS (Análise ×7 chamadores, Comparativo, Plano de Ação, Auditoria, exportarCSV, Gráficos, Questionário, Riscos config, Metodologia) com mensagem "metodologia HSE ainda não suportada aqui". Loader próprio `carregarRespostasHSE` (cache por `(empresa, ciclo)`, exclui `is_teste`, pagina), motor `calcDimensoesHSE` (inversão `escalaMax+1−v`, média por dimensão, bandas vs. benchmark 2023), `calcAdesaoHSE` (reusa só o headcount), `renderAnaliseHSE`. **Laudo HSE com gerador único** `_buildLaudoHSEHTML` para preview e PDF, `LAUDO_SECOES_HSE` próprio, rodapé OGL v3.0 + © Crown, sem logo do HSE, selo "dados apenas indicativos" (< 50% ou taxa incalculável), `snapshot_json` com `metodologia`/questionário/versão/textos impressos, e **checagem pré-geração** (nada de placeholder: ausência de consultoria, cidade/UF ou responsável bloqueia/avisa). Código HSE em regiões delimitadas (`// ==== HSE BEGIN/END ====`) e edições em funções compartilhadas limitadas a pontos de despacho de uma linha. **Motores e loader BS 8800 ficam byte-idênticos.**

## Impactos no sistema

- **Banco / pipeline:** é o ponto de maior raio de dano — `salvar_resposta` serve toda coleta de PROD. Tabelas separadas isolam o resto. `restauracao` (`RESTAURACAO_BACKUP.md`) precisa incluir as novas tabelas e as duas colunas. Limites de plano (`max_respostas_mes`) contam HSE como 1 resposta (declarar a regra).
- **Segurança/anon:** superfície do `anon` não cresce (nenhum GRANT novo); passa a existir 1 função anônima nova. `migration_revoke_anon.sql` e CLAUDE.md ("Superfície do anon") precisam ser atualizados.
- **Formulário:** é a única mudança que o funcionário vê; 35 itens em celular (risco de abandono), 5 opções em 320–360 px, cache de navegador com versão antiga do form.
- **Admin:** arquivo único de 21 mil linhas, sem testes: o risco real é regressão no BS 8800 e erro de sintaxe que apaga o painel. Muitas telas assumem 1–4/27 e precisam de guarda.
- **Laudo/produto:** ~600 das linhas do laudo atual são prosa/estrutura BS 8800; o HSE é um gerador novo (a estimativa de 150–200 linhas de agosto subiu para algo como 300–450 com CSS/rodapé/numeração reaproveitados).
- **Conteúdo/jurídico:** o texto validado dos 35 itens (B1) e a **permissão dos autores da ICAO para uso comercial** são externos ao código; seções fixas do laudo precisam de revisão de SST/psicólogo; consentimento LGPD e eventual RIPD para o novo instrumento.
- **Operação/suporte:** treinamento (inversão de direção alto = bom), material comercial/suporte (B6), monitorar conclusão (B7, só por proxy: sem telemetria de abertura).

## Dificuldades e complexidade

| Frente | Dificuldade | Por quê |
|---|---|---|
| RPC `salvar_resposta` | **Alta** | Caminho mais crítico; função viva fora do repo; DEV≠PROD (overloads e tipo de `session_id`); rollback = reaplicar baseline. |
| Formulário HSE | **Alta** | ~25 pontos hardcoded 27/1–4/'Q', layout 5 opções em mobile, fila offline, versão em cache. |
| Admin plumbing + guardas | Média | Muitos pontos, cada um simples; risco é esquecer um e misturar/zerar dados. |
| Motor + análise HSE | Média | Matemática simples; difícil é validar bandas e inversão. |
| Laudo HSE | **Alta** | Gerador novo + checagem pré-geração + conteúdo regulatório. |
| n mínimo | Média | Pequeno em código, **muda de propósito** o que o BS 8800 mostra hoje. |
| Conteúdo (B1, SST, autores) | **Incerta** | Fora do nosso controle; pode ser o caminho crítico real. |

Total estimado: **~37–43 dias-dev ideais** (caminho crítico ~24 com duas pessoas, porque as etapas do admin serializam no arquivo único). Inclui o desenho de uso acima (seletor de metodologia, selos, atalho dos dois ciclos, CSV HSE); **não** inclui o combo (v2). Escala: S ≤ 1 · M 2–3 · L 4–6 · XL > 6.

## Execução — etapas em ordem

Invariante: **PROD funcional após cada merge; nenhuma etapa sozinha muda o comportamento do BS 8800** (S9 é a única exceção intencional). Fluxo de git (CLAUDE.md): worktree por sessão, `git add` com arquivos nomeados, `git push origin HEAD:develop`, PR `develop→main` com **merge commit**, reconferir o intervalo imediatamente antes do merge. Migrations: DEV primeiro, PROD depois, em arquivo `migration_*.sql` idempotente com verificações no fim.

### S0 — Higiene e linha de base · S (1)
- `git fetch` + `git push origin origin/main:develop` (fast-forward; confirmar `git log origin/develop..origin/main` vazio). Trabalhar em worktree.
- Criar `_dev/check-inline-js.js` (extrai os `<script>` inline dos dois HTML e roda `node --check`) — única checagem automática barata deste ambiente.
- Dataset de DEV: empresa sintética (setores, funções, headcount), ciclo BS 8800, link normal e link `is_teste`. Não copiar respondentes de PROD.
- **Golden master do BS 8800**: saída de `calcFatores`/`renderViewRisco` para 2 ciclos em DEV via `javascript_tool` no Browser pane (requer você logado no admin de DEV) + diff do texto dos motores; fallback: contagens por questão em SQL.
- Commitar as definições vivas de `salvar_resposta` (DEV e PROD) como baseline/rollback.
- PR separada opcional: `build.js` falha se a troca de credenciais não casar exatamente 1 vez.
- **Gate:** `check-inline-js` passa nos dois HTML; golden master salvo; **B12 (PITR no Dashboard de PROD) confirmado por você** antes de qualquer migration em PROD. **Risco:** baixo. **Rollback:** n/a.

### S1 — Migration de esquema · M (2–3) · depende de S0
`migration_metodologia_hse_icao35.sql`: objetos da seção "Banco". Aplicar DEV → validar → PROD (janela calma; reconferir "0 respostas em 7 dias" na hora).
- **Gate:** diff do esquema; `has_table_privilege('anon', …)` falso para todas as tabelas novas; `/validar-formulario` em DEV (submissão BS continua gravando 27 itens com `metodologia='BS8800'`); golden master BS igual.
- **Risco:** baixo/médio (política ou GRANT diferente entre ambientes). **Rollback:** `DROP` dos objetos novos (vazios) — irreversível só depois de existir dado HSE.

### S2 — RPC anônima `obter_instrumento_link` · S–M (1–2) · depende de S1
- **Gate (com `SET LOCAL ROLE anon`):** `select * from ciclos` → permission denied; mesma resposta para token inexistente/inativo/expirado; link com ciclo BS → `BS8800`; link **sem ciclo** → `BS8800`; no DEV semeado → payload HSE completo. Repetir em PROD.
- **Ordem obrigatória:** aplicar em PROD **antes** de promover o formulário que a chama (senão todo link com ciclo falha). **Risco:** baixo. **Rollback:** `DROP FUNCTION` (nada depende dela até S5).

### S3 — `salvar_resposta` endurecida · L (4–6) · depende de S1
- Por ambiente: `CREATE OR REPLACE` da assinatura exata de 10 args (mantendo `SECURITY DEFINER` e `search_path`), ramo BS **idêntico**, ramo HSE novo, prefixos de erro; `REVOKE EXECUTE` nos overloads mortos (PROD: o de 9; DEV: o de 7 e o de 9 `text`). Conferir o tipo de retorno para decidir se vale um retorno sentinela em vez de `RAISE` (traço durável das rejeições).
- **Gate (`/validar-formulario` em DEV e PROD, com link `is_teste`):** BS: 27→27 linhas, reenvio com mesma `session_id` devolve o mesmo id, ciclo NULL aceito. HSE (DEV): 35 válidos → 35 linhas em `resposta_itens_hse` com metodologia gravada; rejeições com **0 linhas** em `respostas`, `resposta_itens_hse`, `respostas_fila` e `respostas_raw_backup`: 34 itens, item duplicado, valor 0 e 6, ids do BS em ciclo HSE, ids HSE em ciclo BS e em ciclo NULL, ciclo apagado; overload morto → permission denied.
- **Risco: alto** (caminho quente). **Rollback:** reaplicar o baseline do S0 e regravar os `GRANT`s antigos (totalmente reversível). **Merge isolado**, em janela calma.

### S4 — Seed de placeholder (só DEV) · S–M (1–2) · depende de S1
`seed_hse_icao35_dev_placeholder.sql`: questionário HSE com `config`, 35 itens (7 dimensões; 12 invertidos = Demandas + Relacionamentos; parte 1 = H01–H23 frequência, parte 2 = H24–H35 concordância), todos com `[RASCUNHO]` + original em inglês; `hse_benchmark` (as médias oficiais de 2023 e as 13 setoriais); `publicado=true` só em DEV; instrução atômica + selects de verificação.
- **Gate:** 35 itens, 12 invertidos, 7 dimensões, todos `[RASCUNHO]`. **Guarda anti-vazamento:** o seed de PROD (S11) é **outro arquivo** e começa com um bloco que dá `RAISE` se existir qualquer `[RASCUNHO]`.

### S5 — Formulário HSE · XL (6–7) · depende de S2, S3, S4
Conforme "Formulário" na arquitetura. **Gate:** `/validar-formulario`; Browser pane a 320/360/390 px sem estouro de rótulo, 35 itens respondíveis, envio ok; link BS em DEV continua gravando 27 itens; teste da fila offline nos dois instrumentos; teste conhecido do **form antigo em cache** contra link HSE; erros de boot distintos (token inválido × falha da RPC × ciclo apagado). **Risco:** médio/alto (regressão do boot BS). **Rollback:** reverter/rollback do Cloudflare (instantâneo); respostas já gravadas permanecem.

### S6 — Admin: escolha da metodologia, selos e guardas · M–L (4) · depende de S1 (S4 para ver o seletor)
Escopo: modal "Novo ciclo" com os dois cartões, aviso de trava (trocar só até o 1º link/resposta) e atalho "criar também um ciclo com a outra metodologia"; `_metodologiaDoCiclo` e `_instrumentosDoCiclo` (lista, 1 elemento na v1); `_cicloLabel` e selo nos 9 selects, lista de links, Dashboard/Clientes; aviso de link "sem ciclo = BS 8800"; "Todos os ciclos" misto pede para escolher; guardas e mensagens "previsto na fase 1.1" nas telas só-BS; "Instrumento fechado" no Questionário; gancho de módulo `hse` (sem exigir opt-in). Os textos dos cartões e das orientações são conteúdo de produto: revisar com SST.
**Gate:** `check-inline-js`; golden master BS **idêntico**; criar ciclo BS gera a mesma linha de antes; ciclo HSE em DEV mostra guarda em toda tela só-BS e o rótulo certo nos 9 selects; trocar metodologia antes do 1º link funciona e depois dele é recusado pelo banco. **Risco:** médio (guarda esconder tela BS por engano). **Rollback:** reverter PR.

### S7 — Loader, motor e tela de análise HSE · L (5) · depende de S3, S4, S6
Inclui a segmentação por Geral / Setor / GHE / Agrupamento reaproveitando `_gruposPorGranularidade` e `agruparPorPares` (as linhas HSE também têm setor e função) e o CSV HSE.
**Gate:** respostas sintéticas em DEV (todas 5: dimensões não invertidas = 5, invertidas = 1; mais um conjunto assimétrico) comparadas a um **cálculo de referência em SQL**; taxa de resposta contra o headcount; `is_teste` excluído; golden master BS intacto. **Risco:** médio (inversão/bandas erradas; faixas são decisão de conteúdo). **Rollback:** reverter PR.

### S8 — Laudo HSE + checagem pré-geração · XL (6–7) · depende de S7 (e S9 para saída por item)
**Gate:** gerar o laudo em DEV para: caso bom, taxa < 50%, headcount ausente, assinante/cidade ausentes (a checagem **deve parar**); preview = PDF; sem placeholder; rodapé OGL presente. **Risco:** médio. **Rollback:** reverter PR.

### S9 — n mínimo (B15) · M (3) · independente do HSE; **bloqueada pela definição do valor**
`_nMinimo(n)` aplicado em segmentações, laudo, barras por item e à política de acesso às linhas por respondente da Auditoria (que hoje mostra `session_id`/dispositivo a consultores e admins — conflita com a promessa de anonimato do modal LGPD). Considerar k-anonimato do cruzamento setor × função × escolaridade, não só por segmento. **Gate:** em DEV, segmento abaixo do limite some; diff do golden master mostra **só** as diferenças pretendidas. **Risco:** médio (muda saída do BS 8800 de propósito). **Rollback:** limite = 0 ou reverter.

### S10 — Documentação e skills · S–M (1–2) · dentro da definição de pronto de cada etapa
CLAUDE.md (seção "Metodologias", superfície do anon, texto do HSE no banco em vez de "textos em 3 lugares", divergência de overloads DEV/PROD); `RESTAURACAO_BACKUP.md`; skill `validar-formulario` (testes HSE e de valor fora da faixa; trocar `questoes LIMIT 3`, que pode devolver itens H; corrigir join `text = uuid`); incorporar B14–B21 ao §16 do plano; **corrigir** a nota de referência (B21: `questionario_id` é NULL em PROD) e a afirmação de "falha auditável" no plano de agosto.

### S11 — Go-live · S (1) + passos humanos · depende de S1–S8, B1, B12, validação de SST
Promover `develop → main` (merge commit; reconferir o intervalo de commits). Aplicar o **seed validado em PROD** como operação de dados (`seed_hse_icao35_validado.sql`; guarda `[RASCUNHO]` primeiro, `publicado=true` por último). `/validar-formulario` em PROD com link `is_teste` HSE. Teste de aceite ponta a ponta (empresa de teste → ciclo HSE → link → 3 respostas conferindo os dois conjuntos de rótulos → análise com as 7 dimensões → laudo com rodapé OGL, referência ICAO, sem logo do HSE, selo "indicativo"; depois um ciclo BS 8800 na mesma empresa e "Todos os ciclos" mostrando a nota de exclusão). Monitorar B7 por proxy (respostas ÷ headcount de HSE vs. BS) e os logs por `instrumento_incompativel`.
- **Rollback = despublicar** (`publicado=false`: o seletor some e a RPC recusa); **depois da primeira resposta real os dados e o esquema permanecem** — é o ponto sem volta.

**Fase 1.1 (fora da v1):** ponte HSE→inventário PGR (B14, opt-in, versionada, SST), coleta em papel (B17), CNAE/grau de risco (B18), múltiplos responsáveis técnicos (B19), reavaliação derivada (B20), comparativo/plano de ação por dimensão (B9).

### Ordem e paralelismo
```
S0 → S1 → { S2 ∥ S3 ∥ S4 ∥ S6 } → S5 (precisa S2,S3,S4)
                                  → S7 (precisa S3,S4,S6) → S8 (precisa S7; S9 para saída por item)
S9 corre em paralelo a partir de S1, assim que o valor for definido · S10 acompanha cada etapa · S11 por último
```
PRs do `psicomap-admin.html` (S6, S7, S8, S9) **mergeiam uma de cada vez**, mesmo desenvolvidas em paralelo.

## Bloqueios humanos / externos
- **B12** — PITR ativo em PROD (só você vê no Dashboard) — antes de qualquer migration em PROD.
- **B1** — texto validado dos 35 itens **e permissão dos autores da ICAO** para uso comercial (contatar: Ferreira, Freitas, Devotto, Damasio); fallback: tradução profissional do HSE original (perde a validação psicométrica brasileira). Define também a escala (rótulos únicos × dois conjuntos) — o desenho suporta os dois (`escala_labels` por item). Só bloqueia o **go-live**, não a engenharia.
- **n mínimo:** valor a definir com o jurídico antes de S9.
- **SST/psicólogo:** revisar bandas (S7) e textos fixos do laudo (S8) antes de S11; decidir a definição das bandas (em pontos ou em desvios do benchmark).

## Registro de riscos (por severidade)

| ID | Risco | Prob. | Impacto | Detecção | Mitigação | Etapa |
|---|---|---|---|---|---|---|
| R1 | `CREATE OR REPLACE` de `salvar_resposta` com assinatura/`search_path` errado quebra toda a coleta | Média | Crítico | `/validar-formulario` DEV+PROD | Baseline do banco vivo, arquivo por ambiente, merge isolado, janela calma, baseline = rollback | S3 |
| R2 | Form promovido antes da RPC em PROD → todo link com ciclo falha | Média | Crítico | Abrir link real em PROD após o deploy | Ordem migration→form; tela de erro distinta; testar com link `is_teste` | S2, S5 |
| R3 | Primeira resposta HSE real torna o esquema irreversível | Certa | Alto | — | Tudo reversível antes; `publicado=false` como chave geral; PITR | S1, S11 |
| R4 | Texto `[RASCUNHO]` chega a PROD | Baixa | Alto | `count(*)` de `[RASCUNHO]` | Seed de PROD é outro arquivo com `RAISE`; `publicado` por último; checklist | S4, S11 |
| R5 | Resultado de grupo pequeno identifica pessoa (n=1 em segmentos e Auditoria) | **Alta hoje** | Alto (LGPD) | Revisão das saídas | `_nMinimo` + política de acesso à Auditoria | S9 |
| R6 | Erro de sintaxe no JS inline apaga o painel; sem CI | Média | Alto | `check-inline-js` + smoke no Browser pane | Checagem local obrigatória; regiões HSE delimitadas | S0 |
| R7 | Regressão silenciosa do BS 8800 por guarda/rótulo | Média | Alto | Golden master | Guardas só em pontos de entrada; motores intocados | S6 |
| R8 | Overloads mortos (com EXECUTE para `anon`) driblam a validação | Média | Alto | Chamada anônima de teste | `REVOKE EXECUTE` | S3 |
| R9 | Superfície do `anon` ampliada por engano | Baixa | Alto | `SET LOCAL ROLE anon`; allowlist | RPC em vez de GRANT; atualizar allowlist | S1, S2 |
| R10 | Inversão ou bandas erradas geram resultado errado | Média | Alto | Cálculo de referência em SQL | Conjuntos sintéticos; revisão SST | S7 |
| R11 | Form antigo em cache contra link HSE: usuário preenche 27 itens e é rejeitado | Média | Médio | Teste do form antigo | `FORM_VERSION`; criar links HSE só após conferir o deploy; erro permanente claro | S5 |
| R12 | Fila offline reenvia para sempre um payload rejeitado em definitivo | Média | Médio | Teste offline | Classificar permanente × transitório | S5 |
| R13 | Rejeições do HSE não deixam rastro no servidor | Certa | Médio | — | Logs do Postgres nas primeiras semanas; avaliar retorno sentinela | S3 |
| R14 | Permissão/licença do texto em português | Incerta | Alto (go-live) | Resposta dos autores | Contato precoce; fallback de tradução; revisão jurídica | S11 |
| R15 | `build.js` não troca as credenciais em silêncio (DEV serve o banco de PROD) | Baixa | Crítico | Saída do build | PR de hardening; não tocar `:337-338` | S0 |
| R16 | Filtros do loader HSE divergem do legado (`is_teste`, tenant, paginação > 1000) | Média | Médio | Contagem contra SQL | Copiar e comparar; paginar | S7 |
| R17 | Taxa de resposta enganosa (headcount sem ciclo, defasado ou ausente) | Média | Médio | Checagem pré-laudo | "Não calculável" + selo "indicativo" | S7, S8 |
| R18 | Restauração de backup perde metodologia/tabelas novas | Baixa | Alto | Ensaio do runbook | Atualizar `RESTAURACAO_BACKUP.md` | S10 |
| R19 | Preview e PDF do laudo divergem | Média | Médio | Comparação manual | Gerador único | S8 |
| R20 | Placeholder/seção vazia no laudo entregue ao cliente | Média | Médio | Checagem pré-geração | Bloquear/avisar; nunca imprimir fallback | S8 |
| R21 | Consentimento LGPD desatualizado para o novo instrumento | Média | Médio | Revisão jurídica | Texto parametrizado em `config`; RIPD | S5, S11 |
| R22 | Metodologia do ciclo mudada depois de haver dados | Baixa | Alto | Trigger | Imutabilidade | S1 |
| R23 | Exposição "livre" abre o HSE a todas as ESTs antes de o suporte estar pronto | Média | Médio | — | Material de suporte (B6) e treinamento antes de publicar; `publicado` por ambiente | S11 |
| R24 | B7 (taxa de conclusão) não mensurável (sem telemetria de abertura) | Certa | Baixo | — | Proxy; telemetria só com aval de LGPD | S11 |
| R25 | Respostas de teste (`is_teste`) poluem PROD | Média | Baixo | Query de `is_teste` | Excluir no loader; limpeza em PROD exige sua autorização | S7, S11 |

## Verificação ponta a ponta (como saber que está certo)

Sem suíte de testes: cada etapa fecha por **gate objetivo** (acima). Ferramentas: `check-inline-js` (sintaxe), golden master do BS 8800 (regressão), `/validar-formulario` (pipeline de submissão, estendida para HSE), SQL com `set_config('request.jwt.claims', …)`/`SET LOCAL ROLE anon|authenticated` + `ROLLBACK` (RLS e superfície do anon), Browser pane com `resize_window` a 320/360/390 px (formulário), cálculo de referência em SQL (motor), e o **teste de aceite do S11**. DEV tem 2 tenants — usar para testar isolamento entre ESTs; PROD tem uma só e mascara vazamento.

## Arquivos críticos
- `psicomap-forms.html` — boot, `buildQuestoes`, `coletarRespostas`, `_validarItens`, `enviarResposta`, fila offline, CSS `.q-scale`; **não tocar `:337-338`**.
- `psicomap-admin.html` — `calcFatores`, `calcDistribuicaoQuestoes`, `loadRespostasParaEmpresa`, `rodarAnalise`, `renderLaudo`/`_buildLaudoHTML`/`gerarLaudoPDF`, `salvarCiclo`/`carregarEmpresas`, `preencherSelectCiclos` e demais montadores, `calcRepresentatividade`, `_registrarLaudo`, `MODULOS_CATALOGO`.
- Novos: `migration_metodologia_hse_icao35.sql`, `migration_obter_instrumento_link.sql`, `migration_salvar_resposta_hse_{dev,prod}.sql`, `seed_hse_icao35_dev_placeholder.sql`, `seed_hse_icao35_validado.sql`, `_dev/check-inline-js.js`.
- Alterados: `migration_revoke_anon.sql`, `CLAUDE.md`, `RESTAURACAO_BACKUP.md`, `.claude/skills/validar-formulario/SKILL.md`, as duas notas de planejamento/referência.

## Primeiros passos após a aprovação
1. S0 (higiene, baseline, golden master) e, em paralelo, **você** confirma B12 e dispara o contato com os autores da ICAO (B1).
2. S1 em DEV → S2/S3/S4 → só então tocar formulário e admin.
3. Corrigir já as notas (B21 e "falha auditável") e registrar B14–B21 no backlog do plano de agosto.
