# HSE/ICAO-35 — HANDOFF para a próxima sessão (2026-10-13)

> **ENCERRAMENTO MAIS RECENTE: 2026-10-28 — leia `2026-10-28-sessao-encerramento-copsoq-dev.md` primeiro.**
>
> **ENCERRAMENTO 2026-10-19 — leia `2026-10-19-sessao-encerramento-hse-generalizacao-prod.md` primeiro** (banco genérico JÁ está em PROD; HTML e questionário HSE não).
>
> **Atualização 2026-10-19 (noite) — ONDE RETOMAR:** o trabalho está agora na branch **`feat/hse-integracao-develop`** (worktree **`../pseg-safesign-hse-integ`**,
> = `feat/hse-icao35-sim` + merge da `develop` de 49 commits + **generalização para a família `instrumento_*`**). `feat/hse-icao35-sim` fica como histórico.
> A generalização está **aplicada em DEV** (as tabelas `hse_*` foram removidas; o preview antigo de `feat/hse-icao35` não funciona mais contra DEV), **PROD intocado, nada em `develop`**.
> Detalhe e evidências: **`2026-10-19-copsoq-avaliacao-documentos-e-generalizacao.md`**. Para PROD a ordem é `migration_metodologias_instrumentos.sql` →
> `migration_instrumento_riscos_config.sql` → `migration_obter_instrumento_link.sql` → `migration_salvar_resposta_instrumento_prod.sql` → HTML; **nunca** `migration_dev_converter_*`.
> Admin: registro `METODOLOGIAS` + guarda `_metSemMotor` em cada ponto de despacho; formulário genérico (rótulos, `ajuda`, `aviso`). Pendências novas: texto validado + licença do COPSOQ,
> motor/laudo/anonimato reforçado do COPSOQ, e as de sempre (B1, B12, severidade assinada, valor do n mínimo, revisão de SST).
>
> **Atualização 2026-10-19:** o usuário respondeu as decisões (§4.2 abaixo): H22/H08/H26 **mantidos**, ordem **intercalada**, ponte **4×4 mantida**, média simples **criada**, Auditoria HSE **permitida e implementada**.
> Estudo, implementação e análise do COPSOQ: `2026-10-19-hse-decisoes-ponte-pgr-auditoria.md` e `2026-10-19-copsoq-e-arquitetura-multi-metodologia.md`. `test:hse` = 161 casos. **A `develop` está ~50 commits à frente.**
>
> **Atualização 2026-10-14:** referência setorial selecionável, supressão complementar (anonimato contra subtração), Distribuição e
> Comparativo HSE, PDF conferido por impressão real (Edge headless) e corrigido, CSV com k-anonimato — `2026-10-13-hse-revisao-completa.md` §10.
> **A `develop` está 33 commits à frente** (era 16): integrar logo.
>
> **Atualização (mesmo dia, sessão seguinte):** revisão completa feita — motor testado (`npm run test:hse`), laudo HSE com layout novo,
> Plano de Ação HSE, análise por dimensão e UX de metodologia. Detalhes em **`2026-10-13-hse-revisao-completa.md`**. Adesão HSE corrigida (`6e680b9`).
>
> **Leia este arquivo primeiro.** Ele substitui o §8 de `2026-10-09-hse-andamento-pendencias-e-risco.md` (que continua válido como
> histórico detalhado, §5.x por etapa). Outros documentos: `2026-10-08-plano-implantacao-hse.md` (plano S0–S11),
> `2026-10-08-referencia-hse-player-avalia-nr01.md` (análise do concorrente), `2026-10-10-simulacao-hse-e-comparacao-player.md`
> (texto PT-BR v2, simulador, comparação com o relatório F2).
>
> **Ordem do usuário, vigente: NÃO subir nada em `develop` nem em PROD até estar "boa parte funcional".** Push de branch de feature só com
> autorização explícita. PROD está **intocado**.

## 1. Onde está o quê

| Item | Estado |
|---|---|
| Worktree **`../pseg-safesign-hse`** | Branch **`feat/hse-icao35-sim`** @ `a24f2dd`, **só local** (não está no GitHub). **Trabalhar aqui.** Tem o `.env` de DEV copiado |
| Diretório principal `pseg-safesign` | Branch `feat/hse-icao35` @ `cb6a244` (= `origin/feat/hse-icao35`). ⚠ `psicomap-admin.html` tem **213 linhas não commitadas de OUTRA sessão** (segmentação do laudo por preset, já em `develop` como `424ff10`). **Não commitar nem descartar sem perguntar**; nunca `git add -A` |
| Relação das branches | `feat/hse-icao35-sim` = `feat/hse-icao35` + 1 commit (`a24f2dd`). Ambas partem de `develop@87b7864` (06/10) |
| `origin/develop` / `origin/main` | `424ff10` / `090741c` — **16 commits à frente** da base de `feat/hse-icao35` (PR #92 de UX com renomeio ciclo→campanha, #93, preset de laudo) |
| Outros worktrees de outras sessões | `-ghe`, `-preset`, `-seg`, `.claude/worktrees/silly-liskov-*` — não tocar |
| Cloudflare preview | Se existir, `feat/hse-icao35` está nele **sem** o commit `a24f2dd`; `feat/hse-icao35-sim` não foi publicada |

## 2. O que foi feito (linha do tempo)

**Base v1 (S0–S8b), sessão de 08–09/10** — `feat/hse-icao35` até `2451d89`: plano, esquema (`ciclos/respostas.metodologia`, `hse_itens`,
`resposta_itens_hse`, `hse_benchmark`, trigger de imutabilidade), RPC anônima `obter_instrumento_link`, `salvar_resposta` com ramo HSE,
formulário HSE, escolha de metodologia por ciclo, análise HSE (`calcDimensoesHSE`), laudo HSE com pré-checagem, risco para o PGR (S8b).

**Sessão de 09–10/10 (esta)** — 8 itens técnicos + 1 revisão, todos testados e documentados em `2026-10-09-hse-andamento-pendencias-e-risco.md` §5.x:

| Commit | O que entrega |
|---|---|
| `df0ca23` | `migration_salvar_resposta_hse_prod.sql` (S3 de PROD, **escrita e não aplicada**; hash da função viva em PROD = baseline) |
| `3c2e8ab` | S10: `migration_revoke_anon.sql` (docs + query de conferência), CLAUDE.md, skill `validar-formulario` (§2b), `RESTAURACAO_BACKUP.md` com passos **3-HSE/4-HSE** (testados em DEV com ROLLBACK) |
| `0cd8961` | Formulário: timeout de 20 s no boot do HSE; fila offline legada (7 params) agora casa com a RPC de 10 args (o PostgREST devolvia `PGRST203` para 7/9 chaves) |
| `68953d5` | Tela do critério de severidade por dimensão (card em Gestão de ESTs, só super_admin; versão única, validação nunca implícita) |
| `b4b0d67` | Trocar a metodologia do ciclo pela UI (antes do 1º link) + selos por empresa; **adesão por instrumento** (`max(BS,HSE)` — antes somava os dois e passava de 100%) |
| `3d27e5d` | Hardening do `build.js` (trocas contadas, JWT anon do mesmo projeto, cruzamento DEV↔PROD, Stripe test/live) + `_dev/check-build.js` (21 cenários; 16 falham no build antigo) |
| `1c551f7` | `seed_hse_benchmark_2023_setores.sql`: 13 setores × 7 dimensões (91 médias) extraídas do PDF oficial HSE 2023 por script e validadas; aplicado em DEV; **sem efeito hoje** (app lê só `GERAL`) |
| `cb6a244` | **n mínimo** de anonimato também no BS 8800 (`N_MIN_ANONIMATO = 5`, **PROVISÓRIO**, 0 desliga) — Resultados, Gráficos, Plano, Comparativo, Laudo |
| `a24f2dd` | **Texto PT-BR v2** (35 itens do formulário F1 do outro player, escala única), **simulador** `_dev/simular-hse.js`, empresa fictícia, **índice 0–100 + zona fixa** na tela/laudo, selo RASCUNHO vindo de `questionarios.config.rascunho` |

Resultado de maior valor: o **exemplo do relatório F2 do outro player foi reproduzido exatamente** (7 dimensões, índice, zona, média 55,9%, e as 7 linhas do inventário PGR pelo método deles).

## 3. Estado dos bancos (verificado em 10/10)

**PROD (`vftyiildukrpgmnbcnao`): NADA aplicado** — sem coluna `metodologia`, sem tabelas `hse_*`, sem `obter_instrumento_link`; `salvar_resposta` idêntica ao baseline de 08/10
(hashes `423fe5d4…` 10 args / `3c7f491c…` 9 args); 0 respostas em 7 dias; `questionarios.empresa_id` é nulável; 1.855 respostas / 50.085 itens.

**DEV (`szqatgvgghxvyyncsjxl`)** tem aplicado: S1, S2, S3-DEV, seed v1 `[RASCUNHO]`, `hse_riscos_config` + seed **de teste** (severidades arbitrárias, não validadas),
benchmark GERAL + 13 setores, **questionário v2** (publicado; maior versão ⇒ é a servida), empresa fictícia de simulação.
Duas versões HSE publicadas em DEV (v1: 9 respostas de teste na empresa Allmed · v2: 66 simuladas).

**Dados de teste em DEV**
- Allmed (`abc10c75-…`): links `hsetests5a01`, `bstests5a001`, `semciclos5a01` (`is_teste`) e `hsetests7a001` (não-teste, 9 respostas HSE v1).
- **Simulação**: empresa `aaaa0000-0000-4000-8000-0000000000a1` (quadro 120), ciclo `…c1` (HSE), link `simhse000001` (não-teste), 66 respostas (seed 2026: Produção 36 `critico-demandas` · Administrativo 18 `bom-gestor` · Logística 12 `conflito`).

## 4. Pendências — por tipo

### 4.1 Dependem de pessoas (bloqueiam PROD; nenhuma é técnica)
1. **B12** — confirmar PITR ativo em PROD (Dashboard Supabase).
2. **B1** — texto **validado** dos 35 itens + permissão dos autores da ICAO. A v2 em DEV usa redação **de um produto comercial de terceiro** (permissão **não verificada**) e tem defeitos de tradução (H22, H08, H26 — ver nota de 10/10).
3. **Severidade S1–S4 das 7 dimensões** definida e assinada por SST (+ aceitar a faixa do HSE como P). Sem isso o laudo HSE não gera.
4. **Valor definitivo do n mínimo** (hoje 5, provisório, vale para BS e HSE) — com o jurídico.
5. Revisão de SST dos textos fixos do laudo e das faixas (±0,50 / +0,40).
6. **Teste logado em DEV** (nunca feito com sessão real): criar ciclo → responder → analisar → laudo; conferir carregamento real com RLS e **PDF impresso** (paginação).
7. Golden master do BS 8800 (precisa do usuário logado no admin de DEV).

### 4.2 Decisões do usuário — **RESPONDIDAS em 2026-10-19** (resumo no fim desta seção; detalhe em `2026-10-19-hse-decisoes-ponte-pgr-auditoria.md`)
1. Texto: manter o F1 verbatim ou corrigir H22/H08/H26?
2. Ordem dos itens: intercalada (atual, a do HSE original) ou agrupada por dimensão como no F1?
3. Ponte PGR: manter 4×4 + severidade fixa assinada (atual) ou adotar a 5×5 do player (P por faixas fixas de %, S variável)?
4. Média simples das 7 dimensões: só nota discreta na tela (atual) ou também no laudo? (o HSE não define score global — D3)
**Respostas (19/10):** 1 manter H22/H08/H26 (B1 segue) · 2 ordem intercalada (recomendação adotada) · 3 manter 4×4 (estudo feito; conduta/critérios do BS 8800 reaproveitados; proposta de severidade para SST) · 4 média simples criada (visão sintética) · 5 Auditoria permitida, com k-anonimato (§7 da nota). Item 5 abaixo ficou parcialmente resolvido (Auditoria e CSV tratados; filtros combinados, não).
5. **Anonimato não coberto pelo n mínimo:** Auditoria mostra `session_id`/dispositivo por respondente; `exportarCSV` exporta uma linha por respondente; filtros combinados (setor×função×escolaridade) podem fatiar até n pequeno.

### 4.3 Técnicas — **bugs/lacunas achados e NÃO corrigidos**
1. ~~**Adesão (tela, badge do GHE, painel de links, PDF) é cega ao HSE**~~ — **corrigido em `6e680b9`** (ciclo HSE lê as respostas HSE; "todos" usa o instrumento com mais respostas). Texto original: o loader do BS descarta respostas sem itens BS, então num ciclo HSE mostra 0% enquanto Dashboard/Clientes mostram o certo. Correção curta: aviso no padrão `_guardaTelaBS`; ideal: contar respostas HSE. Auditoria e Comparativo com ciclo HSE: **não verificados**.
2. **Integração com `develop` (bloqueia o PR):** merge de teste = **6 conflitos**, todos em `psicomap-admin.html` (`CLAUDE.md` mescla sozinho). A `develop` renomeou **ciclo → campanha** na UI e tornou a campanha obrigatória em link novo; meus textos ("Ciclos", "Novo ciclo", "Sem ciclo (usa BS 8800)", cartões BS/HSE, "Trocar metodologia do ciclo") precisam seguir o vocabulário. Conflitos nos pontos: catálogo `MODULOS_CATALOGO`, selects de ciclo (`_cicloLabel`), `renderLaudo`, `gerarLaudoPDF`, `salvarCiclo`. Fazer **num worktree próprio**, nunca no diretório principal.
3. Resolver as alterações não commitadas da outra sessão no diretório principal (descartar, porque já estão em `develop`, ou deixar que ela commite).
4. Seed de PROD (go-live, **ainda não escrito**): `seed_hse_icao35_validado.sql` deve (a) abortar se houver `[RASCUNHO]` no texto **e** se `config->>'rascunho' = 'true'`; (b) publicar por último; (c) aplicar a severidade validada. A RPC serve a **maior versão publicada**.
5. Pequenos: comentário desatualizado em `seed_hse_icao35_dev_placeholder.sql` ("13 médias… ainda precisam ser transcritas" — já foram); CLAUDE.md da `feat/hse-icao35` ainda diz "sem push".
6. Não exercitado: formulário antigo em cache já testado em DEV (ok); **bfcache**, fila legada contra link BS válido, PDF real impresso.
7. Da revisão de 13/10 (ver nota própria §8): diferença por complemento (setor omitido deduzido por subtração do Geral), benchmark setorial não selecionável, textos fixos novos (`HSE_DIM_INFO`, Limitações, Plano) sem revisão de SST, PDF impresso das páginas por dimensão não conferido.
8. Fase 1.1 (fora da v1): seleção de setor/CNAE (usar o benchmark setorial), catálogo de ações por dimensão HSE, comparativo/plano/auditoria/gráficos para HSE, vários responsáveis técnicos, coleta em papel, combo de metodologias.

## 5. Caminho até PROD (só depois de 4.1 e 4.3-2 resolvidos)
1. B12 confirmado + janela calma (`select count(*) from respostas where respondido_em > now()-interval '7 days'` = 0 em 10/10).
2. Integrar com `develop` (item 4.3-2) e revalidar (`check-inline-js`, `check-build`, harness, `/validar-formulario`).
3. Aplicar em PROD, **nesta ordem, testando cada uma** (`SET LOCAL ROLE anon` + `/validar-formulario` com link `is_teste`):
   `migration_metodologia_hse_icao35.sql` → `migration_obter_instrumento_link.sql` → `migration_salvar_resposta_hse_prod.sql` (reconferir `pg_get_functiondef` contra o baseline antes) → `migration_hse_riscos_config.sql` (**vazia**) → `seed_hse_benchmark_2023_setores.sql` (pode ir a qualquer momento depois da primeira).
4. **Promover o formulário ANTES de criar qualquer ciclo HSE** (formulário antigo contra link HSE mostra "salva localmente" e nunca passa; nada é gravado).
5. Seed validado (texto B1 + severidade assinada) → teste de aceite → piloto.
6. `develop`→`main` **com merge commit, nunca squash**; antes, `git log origin/main..origin/develop` e validar **cada** commit.
**NUNCA em PROD:** `seed_hse_icao35_dev_placeholder.sql`, `seed_hse_riscos_config_dev_teste.sql`, `seed_hse_icao35_ptbr_v2_dev.sql`, `seed_hse_simulacao_dev.sql`, `migration_salvar_resposta_hse_dev.sql`.

## 6. Como retomar na prática
```bash
cd C:/osc_cons/cons/pseg/claude/pseg-safesign-hse          # worktree, branch feat/hse-icao35-sim
git status --short && git branch --show-current            # conferir ANTES de qualquer commit
node _dev/check-inline-js.js && node _dev/check-build.js   # sintaxe do JS inline + 21 cenários do build
node --env-file=.env build.js && npx http-server dist -p 8765   # app local contra DEV (nada é publicado)
# simulação (DEV): ver _dev/simular-hse.js --perfis ; reproduzir o F2: --setores "Produção:5:player-f2"
```
Harness sem login (Browser pane): servir cópia dos HTML com `__SUPA_URL__`/`__SUPA_ANON__` trocados pelos de DEV, substituir `sbAdmin` por um fake e chamar as funções no console —
**`sbAdmin`/`currentUser` são `let`: atribua direto (`sbAdmin = {...}`), não `window.sbAdmin`**. Testar RLS sem sessão: `set_config('request.jwt.claims', …)` + `SET LOCAL ROLE` + `ROLLBACK`.
`.claude/notes/usuarios-teste-dev.md` lista um usuário por role em DEV.

## 7. Cuidados aprendidos (não repetir)
- `psicomap-admin.html` tem ~1 MB e é editado por mais de uma sessão: **worktree próprio, nomear arquivos no `git add`, conferir `git branch --show-current`**, reler o diff.
- Tabela nova em PROD nasce com `ALL` para `anon` (default privileges) → sempre `REVOKE ALL … FROM anon`.
- `salvar_resposta`: **um arquivo de migration por ambiente** (DEV `session_id text`/3 overloads; PROD `uuid`/2 overloads); nunca criar um 3º overload. O PostgREST **continua listando overloads revogados** (`PGRST203` para 7/9 chaves).
- Conferir o **banco**, não o repo (`pg_policies`, `pg_get_functiondef`); e conferir os dois ambientes.
- "Oculto" por n mínimo nunca pode parecer "sem risco" — toda saída que oculta diz que ocultou e por quê.
- CSS do laudo vive dentro de template literal: **crase em comentário quebra o `<script>` inteiro**.
- `build.js` agora falha alto; um build sem `APP_ENV` assume `production` mas não faz o cruzamento DEV↔PROD. Confirmar no Cloudflare se `STRIPE_*` estão preenchidas (vazias ⇒ grava `""` e descarta os links de teste do código).
- O simulador recusa PROD; mesmo assim, a empresa fictícia e as respostas simuladas **nunca** vão para PROD.
- Itens HSE congelam ao publicar: mudar texto = **versão nova** do questionário (B21).
