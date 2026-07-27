# Sessão 2026-07-24 — Revisão RBAC completa + Isolamento de tenant

## Contexto

Revisão geral de permissões e acessos por role (super_admin, admin, consultor, cliente_viewer).
Objetivo: cada role vê apenas o que lhe é permitido; viewer com acesso mínimo; super_admin
gerencia ESTs e opera no contexto de uma EST via modo suporte com isolamento correto de dados.

Branch: `feature/rbac-access-review` → PR #30 (mergeada em `main` durante a sessão)

---

## O que foi descoberto e corrigido

### GAPs de segurança no frontend (pseg-admin-questionario.html)

| GAP | Severidade | Problema | Fix |
|-----|-----------|----------|-----|
| GAP-1 | CRÍTICO | Consultor conseguia acessar e **salvar** `sc-est-perfil` (logo, CNPJ, responsável) — sem bloqueio em nenhuma camada | 3 camadas: sidebar + goScreen + guard em `salvarEstPerfil()` |
| GAP-2 | ALTO | Viewer acessava `sc-comparativo` e `sc-auditoria` (uso interno da consultoria) | Removidos de `permitidosViewer` e adicionados a `restritos.cliente_viewer` |
| GAP-3 | ALTO | Viewer via API REST conseguia ler todas as empresas do tenant (não só a sua) | Policy RESTRICTIVE `viewer_empresa_select_empresas` + filtro JS em `carregarEmpresas()` |
| GAP-4 | MÉDIO | Botões de escrita visíveis para viewer na tela Links e Dashboard | `links-action-btns` e `dash-hdr-actions` ocultos no bloco viewer |
| GAP-5 | MÉDIO | Consultor tinha acesso a `sc-gestao-ests` (visível na sidebar) | Adicionado a `restritos` no sidebar e no `goScreen` |
| GAP-6 | UX | `nb-est-perfil` flutuava sem cabeçalho de seção para admin (após `.sa-only` hidden) | Movido para seção "Conta" |
| GAP-7 | UX | Super_admin sidebar mostrava todos os itens no boot, mas telas ficavam vazias (`carregarEmpresas` nunca chamado) | Sidebar colapsada para só mostrar Gestão de ESTs + Equipe no boot |
| GAP-8 | SEGURANÇA | `sairModoSuporte()` chamava `carregarEmpresas()` sem filtro → `_empresas` sujo com dados cross-tenant | Removida a chamada; `_empresas = []`, `_links = []` |
| GAP-9 | **CRÍTICO** | Super_admin em modo suporte criava registros com `tenant_id = null` → dados órfãos | `entrarComoEST()` seta `currentTenantId = tenantId`; `sairModoSuporte()` restaura `null` |
| GAP-10 | MÉDIO | `toggleAtivoUsuario()` só bloqueava `cliente_viewer` — consultor podia chamar via console | Guard reescrito: exige `admin` ou `super_admin` |
| GAP-11 | MÉDIO | `carregarUsuarios()` sem filtro JS de tenant — depende 100% do RLS | `.eq('tenant_id', currentTenantId)` para roles não-super_admin |
| GAP-12 | MÉDIO | `carregarRiscosDB()` sem filtro de tenant | `.eq('tenant_id', currentTenantId)` quando disponível |

### GAPs de segurança no banco (migration_viewer_write_hardening.sql)

Aplicado em DEV e PROD (`vftyiildukrpgmnbcnao`). 9 policies RESTRICTIVE:

| Tabela | Op bloqueada para viewer |
|--------|--------------------------|
| `links_coleta` | INSERT, DELETE |
| `laudos` | INSERT, DELETE |
| `empresa_headcount` | INSERT, DELETE |
| `ciclos` | INSERT, DELETE |
| `empresas` | SELECT (scoped a `get_my_empresa_id()`) |

---

## Arquivos modificados

- `pseg-admin-questionario.html` — todas as funções de RBAC, sidebar, modo suporte
- `migration_viewer_write_hardening.sql` — 9 novas policies RESTRICTIVE
- `.claude/notes/usuarios-teste-dev.md` — credenciais de teste DEV + checklist RBAC

---

## Verificação executada

```sql
-- Rodado em DEV e PROD ao final da sessão
SELECT 'empresas' as tabela, COUNT(*) as orfaos FROM empresas WHERE tenant_id IS NULL
UNION ALL SELECT 'links_coleta', COUNT(*) FROM links_coleta WHERE tenant_id IS NULL
UNION ALL SELECT 'ciclos', COUNT(*) FROM ciclos WHERE tenant_id IS NULL
UNION ALL SELECT 'laudos', COUNT(*) FROM laudos WHERE tenant_id IS NULL
UNION ALL SELECT 'empresa_setores', COUNT(*) FROM empresa_setores WHERE tenant_id IS NULL
UNION ALL SELECT 'empresa_funcoes', COUNT(*) FROM empresa_funcoes WHERE tenant_id IS NULL
UNION ALL SELECT 'empresa_headcount', COUNT(*) FROM empresa_headcount WHERE tenant_id IS NULL;
-- Resultado: 0 órfãos em todas as tabelas nos dois bancos ✅
```

---

## Estado final das RLS policies (DEV + PROD sincronizados)

Todas as 9 policies de `migration_viewer_write_hardening.sql` confirmadas presentes em PROD:
`viewer_no_insert_links`, `viewer_no_delete_links`, `viewer_no_insert_laudos`,
`viewer_no_delete_laudos`, `viewer_no_insert_headcount`, `viewer_no_delete_headcount`,
`viewer_no_insert_ciclos`, `viewer_no_delete_ciclos`, `viewer_empresa_select_empresas`

---

## Pendências remanescentes (não bloqueantes)

- Criar usuários de teste DEV (`admin-teste@pseg-dev.com`, `consultor-teste@pseg-dev.com`,
  `viewer-teste@pseg-dev.com`) via Supabase Dashboard e executar SQL de `.claude/notes/usuarios-teste-dev.md`
- Testar fluxo completo de modo suporte no DEV após merge: entrar como EST, criar empresa,
  verificar `tenant_id` correto no banco, sair e verificar sidebar colapsada
