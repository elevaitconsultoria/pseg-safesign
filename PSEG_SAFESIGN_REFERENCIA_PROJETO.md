# PSEG SafeSign — Referência Rápida do Projeto

> Documento de consulta rápida: URLs, variáveis, parâmetros, constantes e fluxos operacionais.  
> Para arquitetura completa, ver `PSEG_SAFESIGN_DOCUMENTACAO_TECNICA_2026-06-09.md`.  
> Para guia do agente, ver `CLAUDE.md`.

---

## 1. URLs e Ambientes

| Recurso | PROD | DEV |
|---------|------|-----|
| **Admin** | https://pseg-safesign.pages.dev/pseg-admin-questionario.html | https://develop.pseg-safesign.pages.dev/pseg-admin-questionario.html |
| **Formulário** | https://pseg-safesign.pages.dev/pseg-forms.html?token=TOKEN | https://develop.pseg-safesign.pages.dev/pseg-forms.html?token=TOKEN |
| **Supabase dashboard** | https://supabase.com/dashboard/project/vftyiildukrpgmnbcnao | https://supabase.com/dashboard/project/szqatgvgghxvyyncsjxl |
| **Supabase API** | https://vftyiildukrpgmnbcnao.supabase.co | https://szqatgvgghxvyyncsjxl.supabase.co |
| **Cloudflare Pages** | https://dash.cloudflare.com (projeto pseg-safesign, branch main) | (branch develop) |
| **GitHub** | https://github.com/elevaitconsultoria/pseg-safesign | — |
| **GitHub Pages (secundário)** | https://elevaitconsultoria.github.io/pseg-safesign/ | — |

---

## 2. Identificadores de Projeto

| Item | Valor |
|------|-------|
| Supabase project ID — PROD | `vftyiildukrpgmnbcnao` |
| Supabase project ID — DEV | `szqatgvgghxvyyncsjxl` |
| GitHub repo | `elevaitconsultoria/pseg-safesign` |
| Branch PROD | `main` |
| Branch DEV | `develop` |
| Cloudflare project name | `pseg-safesign` |

---

## 3. Variáveis de Ambiente (Cloudflare Pages)

Configuradas em cada environment do Cloudflare Pages (Settings → Environment variables):

| Variável | Obrigatória | Descrição |
|----------|-------------|-----------|
| `SUPA_URL` | Sim | URL do projeto Supabase (ex: `https://vftyiildukrpgmnbcnao.supabase.co`) |
| `SUPA_ANON` | Sim | Chave anon pública do Supabase (JWT) |
| `APP_ENV` | Não | `development` → ativa banner laranja de DEV. Ausente ou outro valor = sem banner |
| `STRIPE_PAYMENT_LINKS` | Não | JSON com links de pagamento Stripe por plano. Se ausente, build usa links hardcoded de teste |

**Como o build.js usa essas variáveis:**
- `pseg-admin-questionario.html`: substitui placeholders `__SUPA_URL__` e `__SUPA_ANON__` via `replaceAll()`
- `pseg-forms.html`: substitui via **regex** (diferente — risco: se o código mudar, regex falha silenciosamente)
- Banner DEV: injeta `<div id="dev-banner">` após `<body>` quando `APP_ENV=development`

---

## 4. Parâmetros do RPC `salvar_resposta`

Chamado pelo formulário público em `enviarResposta()` e `reenviarPendentes()`.

```sql
salvar_resposta(
  p_empresa_id    uuid,
  p_ciclo_id      uuid,        -- nullable (link sem ciclo vinculado)
  p_link_token    text,
  p_setor         text,        -- default '' | max 120 chars
  p_funcao        text,        -- default '' | max 120 chars
  p_escolaridade  text,        -- default '' | max 60 chars
  p_itens         jsonb,       -- [{questao_id: uuid, valor: int(1-4)}] × 27
  p_session_id    uuid,        -- PROD: uuid | DEV: text (divergência crítica)
  p_lgpd_aceito   boolean,     -- sempre true no código atual
  p_device_info   text         -- max 300 chars: "Tipo | OS | Browser | WIDTHpx"
)
RETURNS uuid  -- id da resposta inserida
SECURITY DEFINER
```

**Overloads em PROD:** 2 versões (com e sem `p_device_info`). **Em DEV:** apenas a versão com `p_device_info`.

**Idempotência:** advisory lock + verificação de `session_id` dentro do RPC. O frontend faz 2 tentativas, mas o banco protege contra duplicatas mesmo se ambas chegarem simultaneamente.

---

## 5. Formato do `link_token`

```
Regex de validação (frontend): /^[a-z0-9]{10,16}$/
Exemplos reais: 744f07y07cq, 63pjw74t54
Geração: Math.random().toString(36).substr(2, 12)  (ou similar)
```

O token é compartilhado com múltiplos funcionários do mesmo setor/ciclo — **não é identificador individual**.

---

## 6. Roles do RBAC

| Role | Acesso |
|------|--------|
| `super_admin` | Tudo — cross-tenant, vê todos os tenants (tela `sc-gestao-ests`) |
| `admin` | Tenant completo — CRUD de empresas, usuários, links, GHE, ciclos |
| `consultor` | Tenant — leitura + criação de links e análise; sem gestão de usuários |
| `cliente_viewer` | Empresa específica — read-only (empresa vinculada via `perfis.empresa_id`) |

Função helper no banco:
- PROD: `is_tenant_consultor()` 
- DEV: `is_active_consultor()` ← **nome diferente!**

---

## 7. Tabelas Principais — Referência Rápida

```
tenants              → empresas-clientes da plataforma (ESTs — Empresas de ST)
perfis               → usuários (vinculados a tenant; cliente_viewer vinculado também a empresa)
empresas             → clientes da EST (ex: Udinese, Assa Abloy)
ciclos               → rodadas de avaliação (ex: "Avaliação — Julho 2026")
links_coleta         → links compartilhados com funcionários (token único por link)
respostas            → uma por funcionário (anônima: setor, função, escolaridade, session_id)
resposta_itens       → 27 linhas por resposta (questao_id + valor 1-4)
empresa_setores      → catálogo de setores da empresa (GHE)
empresa_funcoes      → catálogo de cargos (setor_id FK ou NULL = universal)
empresa_headcount    → quadro de funcionários agregado (setor text, funcao text, qtd int)
laudos               → registro de laudos gerados (metadados, não o conteúdo)
riscos_config        → configuração P×S por tenant
est_perfil           → branding da EST (logo, cor, responsável)
tenant_contadores    → contador sequencial de clientes por tenant (CLI-001, CLI-002...)
pagamentos           → histórico de pagamentos
subscriptions        → planos ativos por tenant
planos_config        → configuração de planos (limites, preços)
```

---

## 8. Scores de Risco (Matriz P×S)

```
P (Probabilidade): moda das respostas ajustadas por questão (1-4)
S (Severidade): definido em RISCOS_DETALHES por cd_risco (1-4)
Score = P × S  (range: 1-16)

Classificação:
  1-2   → IRRELEVANTE
  3-6   → BAIXO
  7-12  → MÉDIO
  13-19 → ALTO
  20-25 → CRÍTICO  (nota: score máximo real é 4×4=16, não 25)

Questões invertidas: valor_ajustado = 5 - valor_original
```

---

## 9. Estrutura das Questões

27 questões oficiais em 3 blocos, hardcoded em **dois lugares independentes**:

| Arquivo | Constante | Linha aprox. |
|---------|-----------|-------------|
| `pseg-admin-questionario.html` | `QS_OFICIAIS` | ~3989 |
| `pseg-forms.html` | `BLOCOS` | ~30 |

**Qualquer atualização de texto de questão deve ser feita nos dois arquivos simultaneamente.**  
A tabela `questoes.texto` no banco existe mas não é fonte de verdade do admin — serve apenas como índice de UUID para o pipeline de respostas.

| Bloco | Nome | Questões | Cor |
|-------|------|----------|-----|
| A | Demandas de Trabalho | Q1–Q7 | `#5b4fcf` |
| B | Relações Interpessoais | Q8–Q17 | `#185fa5` |
| C | Fatores Organizacionais | Q18–Q27 | `#b7600a` |

Escala de resposta: `1=Nunca | 2=Às vezes | 3=Frequente | 4=Sempre`

---

## 10. Edge Functions

| Nome | Endpoint | Propósito |
|------|---------|-----------|
| `criar-checkout` | `/functions/v1/criar-checkout` | Gera sessão Stripe ou QR code PIX Asaas |
| `convidar-est` | `/functions/v1/convidar-est` | Convida nova EST (requer JWT super_admin) |

---

## 11. localStorage — Chaves Usadas

### pseg-forms.html

| Chave | Propósito |
|-------|-----------|
| `pseg_respondido_${linkToken}` | Flag "já respondeu neste dispositivo" (bloqueio de 2ª resposta) |
| `pseg_offline_${timestamp}` | Resposta salva localmente quando RPC falha (reenvio posterior) |

### pseg-admin-questionario.html

| Chave | Propósito |
|-------|-----------|
| `pseg_riscos_v1` | Cache local de configuração de riscos |
| `pseg_grupos_setor` | Agrupamentos de setor para análise |
| `pseg_grupos_funcao` | Agrupamentos de função para análise |

### sessionStorage (admin)

| Chave | Propósito |
|-------|-----------|
| `pseg_empresa_ativa_id` | Empresa ativa no chip dropdown (persiste na sessão do browser) |
| `pseg_empresa_ativa_nome` | Nome da empresa ativa |

---

## 12. Dependências Externas (CDN)

### pseg-admin-questionario.html

| Biblioteca | Versão | Propósito |
|-----------|--------|-----------|
| `@supabase/supabase-js` | @2 (latest minor) | Cliente Supabase |
| `Chart.js` | 4.4.1 (pinned) | Gráficos de distribuição |
| `qrcodejs` | 1.0.0 | Geração de QR codes |
| `jspdf` | 2.5.1 | Geração de PDF do laudo |
| `html2canvas` | 1.4.1 | Captura de canvas para PDF |
| `xlsx` | 0.18.5 | Leitura de planilhas XLSX/CSV no import GHE |
| Google Fonts | — | Inter, JetBrains Mono, Playfair Display, DM Sans |

### pseg-forms.html

| Biblioteca | Versão | Propósito |
|-----------|--------|-----------|
| `@supabase/supabase-js` | @2 | Cliente Supabase |
| Google Fonts | — | Plus Jakarta Sans, Barlow Condensed |

> Nenhuma lib CDN usa hash `integrity` (SRI) — risco de supply chain a considerar futuramente.

---

## 13. Funções RPC do Banco (PROD)

| Função | Propósito | Segurança |
|--------|-----------|-----------|
| `salvar_resposta(...)` | Pipeline completo de submissão de resposta | SECURITY DEFINER |
| `get_my_tenant_id()` | tenant_id do usuário logado (usada em RLS) | SECURITY DEFINER |
| `get_my_empresa_id()` | empresa_id (para viewer) | SECURITY DEFINER |
| `get_my_role()` | role do usuário logado | SECURITY DEFINER |
| `is_super_admin()` | Verifica role super_admin | SECURITY DEFINER |
| `is_tenant_admin()` | Verifica role admin | SECURITY DEFINER |
| `is_tenant_consultor()` | Verifica role consultor (**PROD** — DEV usa `is_active_consultor()`) | SECURITY DEFINER |
| `criar_tenant(p_nome, p_slug)` | Cria novo tenant (EST) | SECURITY DEFINER |
| `convidar_membro(p_user_id, p_role)` | Vincula usuário ao tenant | SECURITY DEFINER |
| `verificar_limite_tenant(p_tenant_id, p_recurso)` | Verifica limite do plano | SECURITY DEFINER |
| `super_admin_stats()` | KPIs cross-tenant | SECURITY DEFINER |
| `super_admin_tenant_details()` | Detalhes de todos os tenants | SECURITY DEFINER |
| `aplicar_plano_tenant(...)` | Aplica plano a tenant | SECURITY DEFINER |
| `reprocessar_fila()` | Reprocessa `respostas_fila` com status='erro' | SECURITY DEFINER |
| `fn_atribuir_numero_cliente()` | Trigger — número sequencial CLI-NNN por tenant | SECURITY DEFINER + REVOKE PUBLIC |

---

## 14. Triggers

| Trigger | Tabela | Quando | Função |
|---------|--------|--------|--------|
| `handle_new_user` | `auth.users` | AFTER INSERT | Cria perfil automaticamente |
| `tg_guard_perfil_update` | `perfis` | BEFORE UPDATE | Bloqueia auto-elevação de role; protege último admin |
| `fn_proteger_ancora` | `questoes` | BEFORE DELETE | Protege questões âncora de exclusão |
| `set_updated_at` | várias | BEFORE UPDATE | Atualiza `updated_at` |
| `rls_auto_enable` | event trigger | DDL | Habilita RLS em novas tabelas automaticamente |
| `trg_numero_cliente` | `empresas` | BEFORE INSERT | Atribui `numero_cliente` sequencial (só quando NULL) |

---

## 15. Fluxo de Deploy

```
1. Desenvolver em local (ou direto no arquivo)
2. git push origin develop
   → Cloudflare Pages executa build.js com vars DEV
   → DEV URL: https://develop.pseg-safesign.pages.dev

3. Validar com /validar-formulario se mudou pipeline de respostas

4. Criar PR: https://github.com/elevaitconsultoria/pseg-safesign/compare/main...develop
   (gh CLI não autenticado — PR manual)
5. Usuário faz merge no GitHub

6. Cloudflare Pages executa build.js com vars PROD
   → PROD URL: https://pseg-safesign.pages.dev
```

**Pré-requisito:** variáveis de ambiente configuradas em cada environment do Cloudflare Pages (seção 3).

---

## 16. Comandos SQL Frequentes

### Encontrar empresa por nome
```sql
SELECT id, nome, tenant_id, numero_cliente FROM empresas WHERE nome ILIKE '%nome%';
```

### Contar setores/cargos/headcount de uma empresa
```sql
SELECT
  (SELECT COUNT(*) FROM empresa_setores WHERE empresa_id = 'UUID' AND ativo = true) AS setores,
  (SELECT COUNT(*) FROM empresa_funcoes WHERE empresa_id = 'UUID' AND ativo = true) AS cargos,
  (SELECT COUNT(*) FROM empresa_headcount WHERE empresa_id = 'UUID') AS headcount,
  (SELECT SUM(quantidade) FROM empresa_headcount WHERE empresa_id = 'UUID') AS total_func;
```

### Ver pares setor×cargo com QTD (para validação)
```sql
SELECT es.nome AS setor, ef.nome AS cargo, eh.quantidade
FROM empresa_headcount eh
LEFT JOIN empresa_setores es ON es.nome = eh.setor AND es.empresa_id = eh.empresa_id AND es.ativo = true
LEFT JOIN empresa_funcoes ef ON ef.nome = eh.funcao AND ef.empresa_id = eh.empresa_id AND ef.ativo = true
WHERE eh.empresa_id = 'UUID'
ORDER BY eh.setor, eh.funcao;
```

### Ver respostas de uma empresa/ciclo
```sql
SELECT r.setor, r.funcao, r.escolaridade, r.respondido_em,
       COUNT(ri.id) AS itens
FROM respostas r
LEFT JOIN resposta_itens ri ON ri.resposta_id = r.id
WHERE r.empresa_id = 'UUID' AND r.ciclo_id = 'UUID'
GROUP BY r.id
ORDER BY r.respondido_em DESC;
```

### Limpar headcount órfão
```sql
-- Identificar
SELECT empresa_id, COUNT(*) as hc_rows
FROM empresa_headcount eh
WHERE NOT EXISTS (
  SELECT 1 FROM empresa_setores es WHERE es.empresa_id = eh.empresa_id AND es.ativo = true
)
GROUP BY empresa_id;

-- Remover (com cautela)
DELETE FROM empresa_headcount
WHERE empresa_id = 'UUID';
```

---

## 17. Configuração do Cliente Supabase no Formulário

```js
// pseg-forms.html — isolamento intencional da sessão admin
const sb = supabase.createClient(SUPABASE_URL, SUPABASE_ANON, {
  auth: {
    persistSession: false,
    autoRefreshToken: false,
    detectSessionInUrl: false
  }
});
```

Evita que uma sessão admin aberta no mesmo browser interfira com o formulário público.

---

## 18. Ciclos — Formato do Nome Gerado

```js
// Meses em português (índice 1-12)
const MES_NOME = ['', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
                  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];

// Nome gerado automaticamente na criação
nome = `Avaliação — ${MES_NOME[mes]} ${ano}`;
// ex: "Avaliação — Julho 2026"
```

**Tipos de ciclo disponíveis:**
`Não classificado` | `Linha de Base` | `1º Semestre` | `2º Semestre` | `Reavaliação Anual` | `Pós-Mudança Organizacional`

---

*Referência gerada em 2026-07-23 — baseada em análise integral do codebase.*
