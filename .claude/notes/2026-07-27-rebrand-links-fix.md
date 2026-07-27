# Lições: Rebrand PsicoMap — Links Quebrados em PROD (2026-07-27)

## Contexto

Durante o rebrand de "PSEG SafeSign" → "PsicoMap", três bugs em cadeia quebraram
os links dos formulários que já tinham sido distribuídos para funcionários via WhatsApp.

---

## Bug 1 — Arquivo deletado sem redirect

**Causa:** `pseg-forms.html` foi renomeado para `psicomap-forms.html`. O arquivo antigo
foi deletado do repo. Links do tipo `https://pseg-safesign.pages.dev/pseg-forms.html?token=...`
passaram a retornar 404 ou "Acesso não autorizado".

**Fix:** PR #35 — adicionar redirect 301 em `_redirects`:
```
/pseg-forms.html  /psicomap-forms.html  301
```

**Lição:** Nunca deletar arquivo HTML cuja URL foi distribuída externamente. Criar redirect.

---

## Bug 2 — `_redirects` não chegava ao deploy

**Causa:** O arquivo `_redirects` estava na raiz do repo, mas o Cloudflare Pages serve a partir
de `dist/`. O `build.js` não copiava `_redirects` para `dist/`. Resultado: os redirects do PR #35
não entravam em vigor em produção — o arquivo simplesmente era ignorado.

**Fix:** PR #36 — adicionar `_redirects` e `_headers` ao array `staticFiles` em `build.js`:
```js
const staticFiles = ['404.html', 'index.html', 'login-bg.jpg', 'favicon.ico', '_redirects', '_headers'];
```

**Lição:** Todo arquivo de configuração do Cloudflare Pages (`_redirects`, `_headers`, `_worker.js`)
precisa estar em `dist/`. Verificar `staticFiles` em `build.js` a cada mudança de routing.

---

## Bug 3 — Variante sem extensão não coberta

**Causa:** O Cloudflare Pages ativa **Pretty URLs** por padrão: `pseg-forms.html` também é
acessível como `/pseg-forms` (sem extensão). Links distribuídos no formato
`/pseg-forms?token=llsp0tkayih` (sem `.html`) não eram cobertos pelo redirect do PR #35.

**Fix:** PR #37 — adicionar variante sem extensão ao `_redirects`:
```
/pseg-forms  /psicomap-forms.html  301
```

**Lição:** Qualquer redirect de compatibilidade precisa cobrir AMBAS as variantes — com e sem `.html`.

---

## Validação do pipeline de respostas

Após os 3 fixes, validação completa em PROD via SQL (7 passos da skill `/validar-formulario`):

| Passo | Resultado |
|-------|-----------|
| 1. session_id tipo em PROD | `uuid` — correto |
| 2. Definição da RPC `salvar_resposta` | SECURITY DEFINER + search_path + exception block — OK |
| 3. GRANTs nas tabelas | SELECT/INSERT/UPDATE/DELETE para `authenticated` e `anon` — OK |
| 4. Submissão de teste real | Retornou UUID sem erro |
| 5. Dados em 4 tabelas | Todas com COUNT > 0 |
| 6. Idempotência | Segunda chamada retornou mesmo UUID, COUNT = 1 |
| 7. Limpeza | Todos os registros de teste removidos |

**Conclusão:** O rebrand não afetou o pipeline de submissão de respostas.

---

## Checklist para próximos rebrands

- [ ] Nunca deletar arquivo HTML com URL distribuída — criar redirect 301
- [ ] Cobrir variante com `.html` E sem `.html` em cada redirect
- [ ] Confirmar que `_redirects` está em `staticFiles` do `build.js`
- [ ] Rodar `/validar-formulario` após deploy
- [ ] Testar link real distribuído antes de fechar o ciclo

---

## PRs criados (todos mergeados)

| PR | Branch | Descrição |
|----|--------|-----------|
| #35 | `fix/redirect-pseg-forms` | Redirect 301 para link distribuído quebrado |
| #36 | `fix/redirects-no-dist` | `_redirects` + `_headers` copiados para `dist/` no build |
| #37 | `fix/redirect-sem-extensao` | Cobertura dupla (com e sem `.html`) no `_redirects` |
| #38 | `docs/licoes-rebrand` | CLAUDE.md: checklist rebrand + gotchas de routing |

> Nota: PRs #35–#38 foram criados via REST API (`Invoke-RestMethod`) porque `gh pr create`
> estava retornando GraphQL 500 errors nessa sessão.
