# Revisão de UX — Fase 1 (2026-10-09)

Branch `claude/ajustes-gerais-matriz-5q7ln4`. Escopo e garantias: zero migration, zero escrita nova.

## Feito
- Menu reagrupado em 6 seções + Administração; rótulos de seção sincronizados com a visibilidade dos itens.
- Vocabulário único (Cliente / Laudo / Distribuição); título de tela = rótulo de menu.
- Toasts com severidade única; `'green'` inexistente corrigido.
- Riscos: sucesso só após o banco responder; `excluirRisco` usava `.match({empresa_id:null})` (não casa) → `.is()`.
- Erro de carga ≠ vazio (`_respostasErro`); `_registrarLaudo`/`limparHeadcount` não engolem erro.
- `_comFeedback` em 5 botões; confirmações (desativar link/usuário, remover agrupamento, GHE menor que o gravado).
- Cabeçalhos: 4 telas (assinatura, metodologia, comparativo, plano) levadas ao molde `.page-hdr-left`
  — visualmente idêntico (sem ações o CSS não muda), só estrutura. `sc-ghe` NÃO migrou: `.ghe-hdr` é
  barra de ferramentas com seletor de cliente, não só título; migrar seria redesenho.

## Decisões / desvios do plano
- `removerGHECargo`/`removerGHEUniversal` não ganharam confirmação: só alteram o rascunho do modal, que
  só grava em "Salvar estrutura" (onde a salvaguarda 3 agora protege).
- `sincronizarQuestoes` mantido silencioso (segundo plano).

## Verificação
- Sintaxe dos scripts; harness RBAC por role (8 cenários) idêntico entre commit B e final; 19 itens de
  menu apontam para telas existentes; `_comFeedback` testado (duplo clique, restauração, erro).
- NÃO testado em navegador autenticado/DEV: fluxos de salvar com rede real. Fazer na homologação.

## Pendente
- Fase 1b (filtros), Fase 2 (campanha), 3 (onboarding), 4 (estruturais) — ver plano.
- Bug `riscos_config` (acima). Decisão "EST → Consultoria".

## Fase 3a — Guia "Como usar" (mesma branch)
Tela própria + convite pulável no 1º acesso; ver seção no CLAUDE.md. Testado por harness: passos e botões
coerentes com o menu de cada role (super_admin, modo suporte, admin, consultor, viewer, módulos desligados);
todo "Ir para" aponta para tela existente e visível; convite não aparece com role não resolvido, em modo
suporte, para super_admin, com storage quebrado, nem para quem já dispensou; usuário B não herda o "já vi"
de A. RBAC do menu idêntico ao anterior em 8 cenários, exceto o novo item `nb-ajuda` (visível a todos).
Não testado em navegador logado/DEV.

## Fase 1b — Filtros (mesma branch, commits separados)
Ver seção "Filtros — Fase 1b" no CLAUDE.md. Testado por harness: cascata de Resultados idêntica à de `main`;
Gráficos filtra funções por setor e ciclo; preset restaura função de outro setor sem perda; Auditoria filtra
função por setor, aplica Agrupamento de Setores (A+B=3 de 4 linhas) e mostra erro de carga com retry.
Não testado em navegador logado/DEV.

## Fase 2 — Campanhas (mesma branch)
Ver seção "Campanhas" no CLAUDE.md. Sem schema. Descobertas que mudaram o desenho: FKs de ciclo são SET NULL
em 3 tabelas (apagar ciclo zerava o ciclo das respostas); `respostas` sem policy de UPDATE (inviabiliza
"associar link antigo" pela tela); cascata de exclusão de empresa estoura 60s em DEV (investigar à parte).
Testado por harness: agrupamento (todos/filtrado/vazio/sem campanha/viewer), finalizarCampanha, gerarLink
sem e com campanha, filtros por ciclo com o sentinela, opções do select, menu (visibilidade idêntica) e guia.
Não testado em navegador logado/DEV com o banco real.

## Fase 3b — Passo a passo por cliente (mesma branch)
Ver seção "Passo a passo por cliente" no CLAUDE.md. Harness: 8 perfis de cliente (vazio → laudo emitido)
dão feitos/próximo esperados; teste não conta; `quadro`/`laudos` nulos viram "desconhecido" e nunca "próximo";
módulos desligados removem passos; cartão (grade e lista) e modal renderizam; cada botão chama a função certa;
`_statusEmpresa` inalterado; menu/RBAC idêntico. Não testado: RLS real de `laudos`; navegador logado em DEV.

## Fase 4 (2026-10-09)
Botão "Links por setor" em Campanhas; campanha obrigatória no lote; `ciclo_id` no objeto de `_links`; `applyCombo` removida. `onboarding-overlay` mantido (é o overlay de criação de tenant). Testado: lote recusa sem campanha, cria 2 links com `ciclo_id` com campanha; RBAC do menu idêntico ao baseline.

## Encerramento da sessão (2026-10-09)
- Entrega: PR #92 mergeado em `develop` (`07b7c43`). Fases 1, 1b, guia, 2, 3b e 4 — ver seções acima e o CLAUDE.md.
  Fase 3 do plano original foi dividida em 3a (guia, pedido durante a sessão) e 3b (checklist por cliente).
- Decisões do usuário: fatiar em fases; checklist por cliente; campanha = promover `ciclos`; filtros como 1b;
  visual só cabeçalhos; proteção de ciclo só no painel; guia pulável, tela própria, "já vi" por usuário no navegador.
- Método de teste: harnesses Playwright (menu/RBAC com baseline JSON por role, guia, filtros, campanhas, passo a
  passo, lote) + checagem de sintaxe dos `<script>`. Nada foi testado contra banco real autenticado.
- Lições: (1) renomear separador de menu quebrava RBAC por comparação de texto — resolvido por
  `_sincronizarSecoesSidebar`; (2) respostas sem ciclo sumiam de filtros por ciclo — `_linhasDoCiclo` único;
  (3) `respostas` não tem UPDATE para admin, o que inviabilizou "associar link antigo a campanha" pela tela;
  (4) objeto local criado após INSERT precisa de todos os campos usados pelo agrupamento (`ciclo_id`);
  (5) `#onboarding-overlay` parecia morto mas é o fluxo de criação de tenant — verificar chamadores antes de remover.
- Pendências: lista em "Revisão de UX — estado de release e pendências" no CLAUDE.md.
