# PsicoMap

Plataforma SaaS de avaliação de riscos psicossociais ocupacionais (NR-01 / NR-17 / BS 8800), voltada a consultorias de segurança do trabalho. Permite aplicar questionários com 27 questões em escala 1–4, analisar resultados por empresa/setor/função, gerar laudos PDF e exportar dados.

## URLs

| Ambiente | Admin | Formulário público |
|----------|-------|--------------------|
| **PROD** | https://psicomap.pages.dev/psicomap-admin.html | https://psicomap.pages.dev/psicomap-forms.html?token=TOKEN |
| **DEV** | https://develop.psicomap.pages.dev/psicomap-admin.html | https://develop.psicomap.pages.dev/psicomap-forms.html?token=TOKEN |

## Arquivos principais

| Arquivo | Papel |
|---------|-------|
| `psicomap-admin.html` | Painel da consultoria (requer login) |
| `psicomap-forms.html` | Formulário público acessado via link com token |
| `build.js` | Script de build: injeta variáveis de ambiente antes do deploy |

## Deploy (Cloudflare Pages)

O projeto usa **Cloudflare Pages** com CI automático por branch:

- Branch `develop` → ambiente DEV
- Branch `main` → PROD (branch protegida — PR obrigatório)

O `build.js` injeta as variáveis de ambiente nos arquivos HTML antes do deploy. Configure as seguintes variáveis em cada environment no Cloudflare Pages:

| Variável | Obrigatória | Descrição |
|----------|-------------|-----------|
| `SUPA_URL` | Sim | URL do projeto Supabase |
| `SUPA_ANON` | Sim | Chave anon pública do Supabase |
| `APP_ENV` | Não | `development` ativa banner visual de DEV |
| `STRIPE_PAYMENT_LINKS` | Não | JSON com links de pagamento por plano |

## Banco de Dados (Supabase)

| Ambiente | Project ID |
|----------|-----------|
| PROD | `vftyiildukrpgmnbcnao` |
| DEV | `szqatgvgghxvyyncsjxl` |

Para configurar um novo ambiente Supabase, aplique as migrations na raiz do projeto em ordem (`psicomap-phase1-migration.sql` → `psicomap-phase2-migration.sql` → demais `migration_*.sql`), depois crie o primeiro usuário admin e promova-o via SQL:

```sql
UPDATE perfis SET role = 'admin' WHERE id = '<UUID do usuário>';
```

## Documentação

| Documento | Conteúdo |
|-----------|----------|
| `CLAUDE.md` | Guia para o agente: contexto de negócio, regras críticas, convenções |
| `PSICOMAP_REFERENCIA_PROJETO.md` | URLs, parâmetros, RPCs, localStorage, comandos SQL |
| `PSICOMAP_DOCUMENTACAO_TECNICA_2026-06-09.md` | Arquitetura completa, schema, divergências DEV/PROD, changelog |
| `PROJETO.md` | Módulos do painel admin, fluxo técnico detalhado, histórico de versões |
