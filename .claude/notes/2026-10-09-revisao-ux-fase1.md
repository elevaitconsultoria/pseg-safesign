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
