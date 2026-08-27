# Sessão 2026-08-11 — Auth, Login, Cache e Isolamento de Dados

## Contexto

Auditoria completa do sistema de autenticação, perfis de usuário, cache em memória e
isolamento de dados. Resultado em duas PRs mergeadas na mesma sessão.

---

## PR #45 — fix: auth recovery flow + restrições de role na tela Equipe

### O que estava errado

1. **`PASSWORD_RECOVERY` não tratado** — evento disparado pelo Supabase ao clicar link
   de "Esqueci minha senha" era ignorado. Usuário ficava em estado indefinido (podia
   cair no app sem definir nova senha).

2. **`consultor` acessava tela Equipe sem restrição em `carregarUsuarios()`** — o
   `goScreen()` já bloqueava, mas a função não tinha guard próprio. Comentário dizia
   "admin e consultor podem gerenciar" — errado.

3. **Botão "Novo usuário" visível para roles sem permissão** — hardcoded no HTML sem
   ocultação condicional por role.

### O que foi feito

- `onAuthStateChange`: handler `PASSWORD_RECOVERY` → `showSetPassword('recovery')`
- `checkSession()`: detecção de `_isRecoveryFlow` via URL hash `type=recovery`
  (espelhando `_isInviteFlow`); guard em `getSession()` para não chamar `showApp()`
  no path de recovery/invite
- `showSetPassword(mode)`: adapta título e botão entre 'invite' e 'recovery'
  - Invite: "Bem-vindo ao PsicoMap. Crie uma senha para ativar sua conta." / "Ativar conta"
  - Recovery: "Digite e confirme a nova senha para a sua conta." / "Salvar nova senha"
- `carregarUsuarios()`: guard `!['admin','super_admin'].includes(role)` substitui
  check só para `cliente_viewer`
- `#usuarios-new-btn-area`: botão "Novo usuário" oculto em `aplicarRestricoesPorRole()`
  para `consultor` e `cliente_viewer`

---

## PR #45 (commit adicional) — fix: limpeza de estado no logout, isolamento viewer e melhorias de login

### Bugs críticos corrigidos

#### Cache/Isolamento (C1–C5)

**`fazerLogout()` não limpava estado** — `currentUser = null` era o único reset.
Em troca de usuário na mesma aba, dados do usuário anterior ficavam em `_empresas`,
`_ciclos`, `_links`, `_respostasCache`, `_estPerfil`, `_modulosOff`, `currentTenantId`,
`sessionStorage.pseg_empresa_ativa`.

**Fix:** nova função `_limparEstadoSessao()` chamada em `fazerLogout()`:
```js
function _limparEstadoSessao() {
  currentTenantId = null;
  _empresas = []; _ciclos = []; _links = [];
  _respostasCache = {}; _estPerfil = null;
  _modulosOff = new Set(); _showingApp = false;
  _empresaAtiva = { id: '', nome: '' };
  try { sessionStorage.removeItem('pseg_empresa_ativa'); } catch(_e) {}
}
```

**`sairModoSuporte()` incompleto** — limpava `_empresas`, `_links`, `_modulosOff`
mas esquecia `_ciclos`, `_respostasCache`, `_estPerfil`. Dados da EST visitada
ficavam em memória. Corrigido: agora limpa os três adicionais.

**`carregarLinks()` sem filtro de empresa para viewer** — todos os links do tenant
iam para o browser, JS filtrava depois. Adicionado `.eq('empresa_id', empresa_id)`
na query quando role === `cliente_viewer`.

**`carregarEmpresas()` sem filtro de empresa para viewer** — idem. Adicionado
`.eq('id', empresa_id)` e `.eq('empresa_id', empresa_id)` nas queries de empresas
e ciclos respectivamente.

#### Login (L1–L5)

**`showApp()` chamado duas vezes** — `onAuthStateChange(SIGNED_IN)` e `getSession()`
podiam disparar `showApp()` em paralelo. `loadPerfil()` e todos os carregamentos
rodavam em duplicata. Fix: guard `_showingApp` (flag bool, resetada em `_limparEstadoSessao`).

**`carregarPerfilUsuario()` redundante** — `_loginOk()` chamava essa função (query
a `perfis` por `role/nome/empresa_id`) e depois `showApp()` que chama `loadPerfil()`
(query a `perfis` por `tenant_id/empresa_id/role/nome/ativo`). Segundo sobrescreve o
primeiro. Fix: removida `carregarPerfilUsuario()` de `_loginOk()` — `showApp()` já
cobre tudo.

**Sem timeout no login** — botão ficava disabled para sempre em rede lenta.
Fix: `Promise.race` de 15s no SDK; `AbortController` de 15s no fetch fallback.
Mensagem de timeout: "O servidor demorou demais para responder."

**`#login-err` não limpava ao digitar** — erro vermelho persistia enquanto usuário
corrigia credenciais. Fix: `oninput` nos campos `#login-email` e `#login-senha`.

**`diagnosticarConexao()` em todo page load sem sessão** — 2 requests extras para
todo visitante não autenticado. Fix: só chamada no `catch` de `getSession()` (erro real).

---

## Estado pós-sessão

### O que está em PROD (main)
- ✅ Handler `PASSWORD_RECOVERY` completo com overlay adaptado
- ✅ `_limparEstadoSessao()` — logout limpo sem stale data
- ✅ `sairModoSuporte()` — limpeza completa incluindo `_respostasCache` e `_ciclos`
- ✅ `showApp()` com guard `_showingApp` — sem dupla execução
- ✅ `carregarLinks()` e `carregarEmpresas()` filtrando no banco para `cliente_viewer`
- ✅ Login com timeout 15s e auto-clear de erro
- ✅ `carregarUsuarios()` bloqueando `consultor` + botão "Novo usuário" oculto

### O que NÃO foi implementado nesta sessão
- `convidar-est`: não faz UPDATE de `perfis` após convite — intencional (tenant não
  existe ainda ao convidar o admin da nova EST; onboarding resolve depois)
- Bug `exportarCSV` (lê `r.resposta_itens` mas deveria ler `r.q`) — achado colateral,
  não implementado nesta sessão
- Bug `salvar_resposta` descarta itens fora de 1–4 em silêncio — pré-existente,
  não implementado nesta sessão
- localStorage não namespaceado por tenant (`pseg_riscos_v1`, `pseg_grupos_setor`,
  `pseg_grupos_funcao`) — risco baixo (sobrescrito por DB na sequência), deixado para
  iteração futura

---

## Referências
- PRs mergeadas: #45 (dois commits)
- Branch: `feature/convite-usuario-sistema` → `main`
- `psicomap-admin.html` é o único arquivo de código alterado
- `CLAUDE.md` recebeu documentação da segunda metodologia HSE/ICAO-35 (planejamento
  anterior de 2026-08-03 que não havia sido commitado)
