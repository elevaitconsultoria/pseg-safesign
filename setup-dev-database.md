# Setup do Banco de Dados — Ambiente DEV

Execute os scripts abaixo **nesta ordem** no SQL Editor do projeto Supabase DEV.

## Pré-requisitos
- Criar projeto no Supabase: `pseg-safesign-dev`
- Região recomendada: South America (São Paulo) — mesma do prod

---

## Ordem de execução

```
1. pseg-schema-v3.sql             ← Schema base: tabelas principais
2. pseg-admin-rls-policies.sql    ← Políticas RLS básicas
3. pseg-fix-rls-respostas.sql     ← Correção RLS respostas
4. pseg-phase1-migration.sql      ← Migração fase 1
5. pseg-phase2-migration.sql      ← Migração fase 2
6. pseg-phase3-saas-tenants.sql   ← Multi-tenant SaaS
7. pseg-phase4-billing.sql        ← Billing / assinatura
8. pseg-security-patch.sql        ← Patch de segurança v1
9. pseg-security-patch-v2.sql     ← Patch de segurança v2
10. migration_roles.sql           ← Sistema de roles
11. migration_super_admin.sql     ← Super admin
12. migration_painel_eleva.sql    ← Painel Eleva IT
13. migration_est_perfil.sql      ← Perfil da EST
14. migration_modo_teste.sql      ← Modo de teste
15. migration_rls_hardening.sql   ← Hardening RLS final
16. supabase_security_migrations.sql ← Migrações de segurança
```

## Após executar os scripts

1. **Authentication → Settings**: habilitar "Email confirmations" = OFF (para dev)
2. **Authentication → URL Configuration**: adicionar URL do preview Cloudflare
3. **Edge Functions**: fazer deploy das functions (pasta `supabase/functions/`)
4. **Criar usuário admin de teste** via Dashboard → Authentication → Users

## Credenciais a copiar para o Cloudflare Pages (branch develop)

No painel do projeto DEV:
- `Project Settings → API → Project URL` → valor para `SUPA_URL`
- `Project Settings → API → anon public` → valor para `SUPA_ANON`
