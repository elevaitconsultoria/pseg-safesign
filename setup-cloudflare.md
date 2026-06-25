# Configuração Cloudflare Pages — Ambientes

## 1. Alterar o Build Command no projeto Cloudflare Pages

No painel do Cloudflare Pages → seu projeto → **Settings → Builds & deployments**:

| Campo | Valor |
|-------|-------|
| Build command | `node build.js` |
| Build output directory | `dist` |
| Root directory | `/` (raiz) |

---

## 2. Variáveis de ambiente — Branch `main` (PRODUÇÃO)

**Settings → Environment variables → Production**

| Variável | Valor |
|----------|-------|
| `APP_ENV` | `production` |
| `SUPA_URL` | `https://vftyiildukrpgmnbcnao.supabase.co` |
| `SUPA_ANON` | `eyJhbGci...` ← chave anon do projeto PROD |
| `STRIPE_MODE` | `live` |
| `STRIPE_STARTER` | `https://buy.stripe.com/...` ← link live Starter |
| `STRIPE_PRO` | `https://buy.stripe.com/...` ← link live Professional |
| `STRIPE_ENT` | `https://buy.stripe.com/...` ← link live Enterprise |

---

## 3. Variáveis de ambiente — Branch `develop` (DEV/STAGING)

**Settings → Environment variables → Preview** (ou configurar por branch específica)

| Variável | Valor |
|----------|-------|
| `APP_ENV` | `development` |
| `SUPA_URL` | `https://szqatgvgghxvyyncsjxl.supabase.co` |
| `SUPA_ANON` | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN6cWF0Z3ZnZ2h4dnl5bmNzanhsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI0MTc1MjksImV4cCI6MjA5Nzk5MzUyOX0.svoU5xRbookipSKjHPmAIakx11r_phcA_b6qnl0wlQk` |
| `STRIPE_MODE` | `test` |
| `STRIPE_STARTER` | `https://buy.stripe.com/test_dRm00lgJA9lGfk2fEH57W00` |
| `STRIPE_PRO` | `https://buy.stripe.com/test_bJe6oJbpggO8fk2eAD57W01` |
| `STRIPE_ENT` | `https://buy.stripe.com/test_eVqcN7790btO7RAfEH57W02` |

> ⚠️ No Cloudflare, variáveis de "Preview" se aplicam a todas as branches que não são a de produção.
> Para isolar `develop` de branches de feature (`feat/*`), configure as variáveis como "Production" = main e "Preview" = todo o resto (develop + feat/*). Isso é aceitável — branches feat/* são temporárias e não têm tráfego real.

---

## 4. Domínio customizado (se aplicável)

- `main` → seu domínio de produção (ex: `app.pseg.com.br`)
- `develop` → subdomínio de staging (ex: `staging.pseg.com.br`) ou URL automática do Cloudflare

---

## 5. Verificar após configurar

Após o próximo deploy em cada branch, verifique no log de build:
```
[build] ✅ HTML gerado → dist/pseg-admin-questionario.html
[build] Ambiente: production | Supabase: https://vftyii... | Stripe: live
```
