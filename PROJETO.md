# PsicoMap — Documentação do Projeto

> Plataforma de avaliação de riscos psicossociais (NR-17 / NR-01 / BS 8800)  
> Stack: HTML estático + Supabase (PostgreSQL + Auth + RLS + Edge Functions) + Cloudflare Pages

---

## 1. Visão Geral

O PsicoMap é uma aplicação web Single-Page sem framework de build. Toda a lógica reside em dois arquivos HTML auto-contidos:

| Arquivo | Papel |
|---|---|
| `psicomap-admin.html` | Painel da consultoria (admin) |
| `psicomap-forms.html` | Formulário de coleta para funcionários |

**Fluxo principal:**
```
Consultoria (admin)
  → cadastra empresa + GHE (setores/funções) + ciclo
  → gera link de coleta com token único
  → compartilha via WhatsApp / QR Code / cópia de URL

Funcionário (anon)
  → abre link no celular
  → responde 27 questões em escala 1-4
  → envia (salvo em Supabase + localStorage fallback)

Consultoria (admin)
  → vê respostas em tempo real
  → analisa por empresa/setor/função/nível
  → exporta CSV / gera relatório PDF
```

---

## 2. URLs

| Ambiente | Admin | Formulário |
|---|---|---|
| **PROD (Cloudflare Pages — branch main)** | `https://psicomap.pages.dev/psicomap-admin.html` | `https://psicomap.pages.dev/psicomap-forms.html?token=TOKEN` |
| **DEV (Cloudflare Pages — branch develop)** | `https://develop.psicomap.pages.dev/psicomap-admin.html` | `https://develop.psicomap.pages.dev/psicomap-forms.html?token=TOKEN` |
| **GitHub Pages (secundário, não oficial)** | `https://elevaitconsultoria.github.io/psicomap/psicomap-admin.html` | — |
| **Local** | `http://localhost:3788/psicomap-admin.html` | `http://localhost:3788/psicomap-forms.html?token=TOKEN` |

Servidor local: `npx serve -p 3788 .` (ver `.claude/launch.json`)

---

## 3. Acesso ao Painel Admin

A tela de login oferece três opções:

| Botão | O que faz | Permissões |
|---|---|---|
| **E-mail + senha** | Auth real via Supabase | Leitura + escrita completa |
| **⚙ Admin sem login** | Usa chave anon (sem sessão) | Apenas leitura (RLS bloqueia writes) |
| **👁 Ver demonstração** | Dados simulados, sem Supabase | Demo local, sem persistência |

> **Para o fluxo completo de teste, use e-mail + senha.**

---

## 4. Banco de Dados (Supabase)

### Projeto

| Ambiente | Project ID | URL |
|----------|-----------|-----|
| PROD | `vftyiildukrpgmnbcnao` | `https://vftyiildukrpgmnbcnao.supabase.co` |
| DEV | `szqatgvgghxvyyncsjxl` | `https://szqatgvgghxvyyncsjxl.supabase.co` |

Chave pública (anon): presente nos arquivos HTML após build (seguro — read-only por padrão para anon).

### Schema completo (PROD, verificado 2026-07-23)

RLS habilitado em todas as 23 tabelas. Trigger DDL `rls_auto_enable` garante RLS em novas tabelas.

```
tenants
  id uuid PK | nome text | slug text UNIQUE | plano text | ativo bool | trial_ate timestamptz
  max_empresas int | max_usuarios int | max_respostas_mes int | criado_em timestamptz

perfis
  id uuid PK→auth.users | tenant_id uuid→tenants | empresa_id uuid→empresas (nullable, só viewer)
  role text (super_admin/admin/consultor/cliente_viewer) | ativo bool | nome text | email text

empresas
  id uuid PK | tenant_id uuid→tenants | nome text | razao_social text | cnpj text
  logo_base64 text | questionario_id uuid | numero_cliente int | criado_em timestamptz

ciclos
  id uuid PK | empresa_id uuid→empresas | tenant_id uuid→tenants | nome text (gerado auto)
  data_inicio date | data_fim date | ano_referencia int | mes_referencia int (1-12)
  tipo_ciclo text | referencia_estimada bool | criado_em timestamptz

links_coleta
  id uuid PK | token text UNIQUE | empresa_id uuid→empresas | tenant_id uuid→tenants
  ciclo_id uuid→ciclos | setor_sugerido text | ativo bool | expira_em timestamptz
  is_teste bool | permite_multi_resposta bool (default false) | criado_em timestamptz

questoes
  id uuid PK | codigo text (A1-C7) | texto text | bloco text | is_oficial bool
  is_ancora bool | inversa bool | cd_risco text | severidade int | ordem int

questionarios / questionario_questoes   ← configuração de questionário por empresa

respostas
  id uuid PK | empresa_id uuid | tenant_id uuid | ciclo_id uuid | link_token text
  setor text | funcao text | escolaridade text | session_id uuid (PROD) / text (DEV)
  lgpd_aceito bool | device_info text | respondido_em timestamptz

resposta_itens
  id uuid PK | resposta_id uuid→respostas | questao_id uuid→questoes | valor int (1-4)

respostas_fila      ← fila de processamento (status: pendente/processado/erro)
respostas_raw_backup ← backup bruto por session_id

empresa_setores
  id uuid PK | empresa_id uuid | tenant_id uuid | nome text | grupo text | ordem int | ativo bool

empresa_funcoes
  id uuid PK | empresa_id uuid | tenant_id uuid | setor_id uuid→empresa_setores (nullable=universal)
  nome text | ordem int | ativo bool
  UNIQUE (empresa_id, setor_id, nome)

empresa_headcount
  id uuid PK | empresa_id uuid | tenant_id uuid | setor text | funcao text | quantidade int
  UNIQUE (empresa_id, setor, COALESCE(funcao, ''))

laudos              ← registro de laudos gerados (metadados, não o conteúdo)
riscos_config       ← configuração P×S por tenant (empresa_id nullable = global do tenant)
est_perfil          ← branding da EST (logo, cor primária, nome/email do responsável)
tenant_contadores   ← contador sequencial de clientes por tenant (CLI-001, CLI-002...)
pagamentos          ← histórico de pagamentos (Stripe / Asaas PIX)
subscriptions       ← planos ativos por tenant
planos_config       ← configuração de planos (limites, preços)
```

### Migrations aplicadas

| Migration | DEV | PROD | Conteúdo |
|-----------|-----|------|---------|
| `psicomap-phase1-migration.sql` | ✅ | ✅ | perfis, criado_por, ciclos, riscos_config, RLS base |
| `psicomap-phase2-migration.sql` | ✅ | ✅ | empresa_setores, empresa_funcoes, RLS GHE |
| `psicomap-phase3-saas-tenants.sql` | ✅ | ✅ | multitenancy, tabela tenants |
| `psicomap-phase4-billing.sql` | ✅ | ✅ | pagamentos, subscriptions, planos_config |
| `migration_empresa_headcount.sql` | ✅ | ✅ | tabela empresa_headcount + RLS |
| `migration_fix_empresa_funcoes_unique.sql` | ✅ | ✅ | UNIQUE por (empresa_id, setor_id, nome) |
| `migration_rbac_viewer_hardening.sql` | ✅ | ✅ | trigger tg_guard_perfil_update + policies viewer RESTRICTIVE |
| `migration_sync_est_perfil_prod.sql` | N/A | ✅ | sincroniza colunas est_perfil entre DEV e PROD |
| `migration_links_multi_resposta.sql` | ✅ | ✅ | links_coleta.permite_multi_resposta |
| `migration_empresas_numero_cliente.sql` | ✅ | ✅ | empresas.numero_cliente + tenant_contadores + trigger |
| `migration_ciclos_referencia_temporal.sql` | ✅ | ✅ | ciclos.ano_referencia/mes_referencia/tipo_ciclo/referencia_estimada |

### RLS resumida (modelo de acesso)

RLS é scoped por `tenant_id` — dados de uma consultoria nunca são visíveis para outra.

| Tabela | anon | consultor/admin | super_admin |
|--------|------|----------------|-------------|
| empresas | — | CRUD próprio tenant | ALL |
| ciclos | — | CRUD próprio tenant | ALL |
| links_coleta | SELECT (ativo=true) | CRUD próprio tenant | ALL |
| respostas | INSERT via RPC | SELECT próprio tenant | ALL |
| resposta_itens | INSERT via RPC | SELECT próprio tenant | ALL |
| empresa_setores/funcoes | SELECT (ativo=true) | CRUD próprio tenant | ALL |
| empresa_headcount | — | CRUD próprio tenant | ALL |
| perfis | — | Self SELECT/UPDATE | ALL |
| tenants | — | Self SELECT | ALL |

---

## 5. Módulos do Painel Admin

### 5.1 Dashboard (`sc-dashboard`)
- KPIs globais: nº empresas, respostas totais, links ativos, trial status
- Cards de empresas com status visual: respostas, adesão, link para análise direta

### 5.2 Clientes / Empresas (`sc-empresas`)
- Toggle Grade/Lista com busca em tempo real por nome/CNPJ
- Código sequencial por tenant: CLI-001, CLI-002... (nunca reaproveitado mesmo após exclusão)
- Botões por empresa: **GHE**, **Ciclos**, **Links**, **Resultados**
- Edição inline de nome da empresa; modal de perfil (logo, CNPJ)
- Exclusão com hard delete — **irreversível**, sem soft-delete

### 5.3 Links de Coleta (`sc-links`)
- Gerar link por empresa + ciclo + setor opcional; flag `permite_multi_resposta` por link
- Geração em lote por setor (todos os setores da empresa de uma vez)
- Por link: **Copiar**, **WhatsApp**, **QR Code** (inline, download PNG), **Ativar/Desativar**, **Excluir**
- Realtime: contador de respostas atualiza ao vivo (Supabase Realtime, só na tela de links)
- Painel de adesão por link: % de resposta por setor vs. headcount cadastrado

### 5.4 GHE — Setores, Funções & Headcount (`sc-ghe`)
- Tela cheia (96vw × 92vh), não mais modal
- Toggle Árvore/Tabela para visualização da hierarquia
- CRUD de setores e funções com edição inline; funções universais (sem setor)
- Import de planilha CSV/XLSX com parser robusto (RFC 4180); templates por segmento
- Mapeamento cargo→setor 1:N (um cargo pode estar em múltiplos setores)
- Painel de adesão: cruza `empresa_headcount` × respostas por ciclo
- Salvaguardas contra wipe acidental; headcount limpo junto com catálogo quando esvaziado

### 5.5 Ciclos (modal por empresa)
- Selects de Mês + Ano (não mais campo de texto livre); nome gerado automaticamente: "Avaliação — Julho 2026"
- Classificação do ciclo: Linha de Base / 1º Semestre / 2º Semestre / Reavaliação Anual / Pós-Mudança Organizacional
- Badge "estimado" para ciclos com referência inferida do campo `data_inicio` (backfill)
- Ordenação cronológica por `ano_referencia/mes_referencia` (não por data de criação)

### 5.6 Questionário (`sc-q`)
- 27 questões oficiais NR-01 em 3 blocos: A (Demandas), B (Relações), C (Organizacional)
- Questões extras configuráveis; parâmetros: severidade (S), cd_risco, invertida
- Questões âncora protegidas de exclusão (trigger no banco)

### 5.7 Análise / Resultados (`sc-analise`)
- Filtros: empresa, ciclo, setor (multi), função (multi), escolaridade, nível de risco
- Modos de visualização: Gráfica / Tabela, Por Risco / Por Questão, Segregado / Consolidado
- Score P×S por fator de risco; distribuição de frequência por questão
- Exportação CSV e PDF (jsPDF + html2canvas); botão de impressão

### 5.8 Gráficos (`sc-graficos`)
- Gráficos Chart.js por bloco: barras de distribuição, evolução por questão
- Exportação individual (PNG) e em lote (PDF)
- Filtros por setor e função

### 5.9 Comparativo entre Ciclos (`sc-comparativo`)
- Dashboard de evolução: compara dois ciclos de uma empresa lado a lado
- Ordenação cronológica correta por `ano_referencia/mes_referencia`
- Variação de score por fator (melhora/piora com delta colorido)

### 5.10 Auditoria de Respostas (`sc-auditoria`)
- Tabela bruta: todas as respostas com 27 colunas de valor + metadados
- Filtros: empresa, ciclo, setor, função; painel recolhível
- Linha de médias no rodapé; exportação CSV (UTF-8 BOM)

### 5.11 Laudo (`sc-laudo`)
- Preview e impressão do laudo NR-01 com metodologia + riscos + ações recomendadas
- Seções configuráveis (toggle por checkbox); filtros de empresa/ciclo/setor
- Exportação PDF via jsPDF + html2canvas; registro em `laudos` (metadados)

### 5.12 Plano de Ação (`sc-plano`)
- 5W2H gerado a partir dos riscos identificados na análise (ALTO e CRÍTICO)
- Exportação CSV

### 5.13 Riscos & Severidade (`sc-riscos`)
- Configuração da tabela de riscos por tenant: nome, categoria, severidade (S), consequências, medidas
- Persiste em `riscos_config` (empresa_id nullable = configuração global do tenant)

### 5.14 Assinatura / Billing (`sc-assinatura`)
- Planos: Trial, Starter, Professional, Enterprise (limites: empresas, usuários, respostas/mês)
- Pagamento via Stripe (cartão) e Asaas (PIX) — integrado via Edge Function `criar-checkout`
- Barras de uso: empresas/usuários/respostas vs. limite do plano
- Histórico de pagamentos

### 5.15 Equipe / Usuários (`sc-usuarios`)
- Listagem de usuários do tenant: nome, role, status
- Convidar novos membros via e-mail (Supabase Auth invite)
- Alterar role (admin/consultor/cliente_viewer); ativar/desativar
- `cliente_viewer`: vinculado a uma empresa específica (acesso read-only a uma empresa)

### 5.16 Perfil da EST (`sc-est-perfil`)
- Configurações de branding da consultoria: logo, cor primária, nome/e-mail do responsável
- Persiste em `est_perfil`

### 5.17 Metodologia (`sc-metodologia`)
- Documentação da metodologia P×S com mapa visual de questões por bloco
- Matriz de risco interativa; referências normativas (NR-01, NR-17, BS 8800)

### 5.18 Gestão de ESTs (`sc-gestao-ests`) — super_admin only
- Visão cross-tenant: lista de todas as consultorias, KPIs globais
- Ativar/desativar tenant; entrar em modo suporte (impersonação)
- Convidar nova EST via Edge Function `convidar-est`

---

## 6. Formulário de Coleta (`psicomap-forms.html`)

### Fluxo técnico
```
1. URL: /psicomap-forms.html?token=XXXX
2. init() → carregarMapaQuestoes() [async, não bloqueante]
3. Valida token → links_coleta (ativo=true, não expirado)
4. carregarGHEEmpresa() → empresa_setores + empresa_funcoes [parallel]
5. showForm()
   → popularMetaFuncao() — select dinâmico com funções da empresa
   → popularMetaSetor() — exibido somente se link sem setor_sugerido
6. Funcionário responde 27 questões (escala 1-4)
7. enviarResposta()
   → INSERT respostas (link_token, setor, funcao, escolaridade)
   → INSERT resposta_itens[] (questao_id UUID, valor)
   → localStorage.setItem('pseg_respondido_' + token)  ← 1 resp/dispositivo
```

### Fallback offline
- Toda resposta é salva em `localStorage` antes do envio ao Supabase
- Se falhar, dado fica disponível para reenvio posterior

### Metadados coletados
- `setor`: do link (fixo) ou escolhido pelo funcionário (se link sem setor)
- `funcao`: selecionado da lista da empresa ou fallback padrão
- `escolaridade`: opcional
- `respondido_em`: timestamp ISO
- `fonte`: `"formulario_web"`

---

## 7. Variáveis de Estado Global (Admin)

```javascript
let _empresas   = []  // Array de { id, nome, cnpj, ativo, setores[], funcoes[] }
let _ciclos     = []  // Array de { id, empresa_id, nome, descricao }
let _links      = []  // Array de { id, empresa_id, token, ativo, respostas, ... }
let _empresaAtiva     // { id, nome } — empresa selecionada globalmente
let _respostasCache   // { empresa_id: [respostas] } — cache por empresa
let sbAdmin           // Supabase client (anon key)
let currentUser       // { email, role, id } do usuário logado
let isDemoMode        // bool — true = dados simulados, sem Supabase writes
let questoes          // Array de questões ativas
let ativas            // Set<id> das questões ativas
```

---

## 8. Combos de Filtro

Implementação custom sem biblioteca:
```
comboState  { 'combo-setor': Set<string>, ... }  ← itens selecionados
comboItems  { 'combo-setor': () => string[], ... } ← função que retorna todos os itens
```

Combos presentes: `combo-setor`, `combo-funcao`, `combo-nivel`, `combo-gf-setor`, `combo-gf-funcao`, `combo-ld-setor`, `combo-audit-setor`, `combo-audit-funcao`

---

## 9. Modo Demo

Ativado por `isDemoMode = true` (via botão "👁 Ver demonstração").

Dados simulados:
- 2 empresas (Construtora ABC, Indústria XYZ) com setores e funções pré-definidos
- 3 ciclos
- ~40 respostas sintéticas cobrindo todos os setores/funções/scores
- Links de demo

Todas as operações de escrita são feitas em memória (não persistem).

---

## 10. Repositório e Deploy

**Repo:** `elevaitconsultoria/psicomap`

| Branch | Ambiente | Observação |
|--------|----------|-----------|
| `develop` | DEV (Cloudflare Pages) | Branch de trabalho — push livre |
| `main` | PROD (Cloudflare Pages) | Branch protegida — PR obrigatório |

O Cloudflare Pages detecta push em cada branch e executa `build.js` automaticamente com as variáveis de ambiente configuradas por environment.

### Fluxo de deploy

```
git push origin develop          → DEV atualiza automaticamente
                                    (https://develop.psicomap.pages.dev)

PR manual via GitHub:
https://github.com/elevaitconsultoria/psicomap/compare/main...develop
→ Usuário faz merge → PROD atualiza automaticamente
                       (https://psicomap.pages.dev)
```

> `gh` CLI não está autenticado — PRs sempre criados manualmente pela URL acima.

---

## 11. Dependências (CDN)

```html
<!-- Supabase JS v2 -->
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>

<!-- Chart.js 4.4.1 (gráficos) -->
<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.min.js"></script>

<!-- jsPDF 2.5.1 (exportação PDF) -->
<script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js"></script>

<!-- Fontes: Inter + JetBrains Mono (admin) | Plus Jakarta Sans + Barlow Condensed (form) -->
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700..."/>

<!-- QR Code: API externa (modal inline) -->
<!-- https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=URL -->
```

---

## 12. Configuração Supabase (hardcoded nos HTMLs)

```javascript
const SUPA_URL  = 'https://vftyiildukrpgmnbcnao.supabase.co';
const SUPA_ANON = 'eyJhbGc...';  // chave pública anon — seguro expor
```

> A `service_role` key **nunca** aparece no código cliente.

---

## 13. Checklist para Nova Instalação

```
[ ] 1. Criar projeto Supabase (PROD e DEV separados)
[ ] 2. Aplicar migrations em ordem no SQL Editor do Supabase:
       psicomap-phase1-migration.sql
       psicomap-phase2-migration.sql
       psicomap-phase3-saas-tenants.sql
       psicomap-phase4-billing.sql
       migration_*.sql (demais, em ordem cronológica pelo nome)
[ ] 3. Criar primeiro usuário em Authentication → Users → Add user
[ ] 4. O trigger on_auth_user_created cria o perfil automaticamente (role='consultor')
[ ] 5. Promover para admin:
       UPDATE perfis SET role = 'admin' WHERE id = '<UUID do usuário>';
[ ] 6. Criar tenant inicial via RPC (ou diretamente via SQL):
       SELECT criar_tenant('Nome da EST', 'slug-da-est');
[ ] 7. Conectar o perfil ao tenant:
       UPDATE perfis SET tenant_id = '<tenant_id>', role = 'admin' WHERE id = '<UUID>';
[ ] 8. Configurar variáveis de ambiente no Cloudflare Pages:
       SUPA_URL, SUPA_ANON (obrigatórias)
       APP_ENV=development (só no environment DEV)
       STRIPE_PAYMENT_LINKS (se usar billing)
[ ] 9. Push em `develop` → aguardar build do Cloudflare Pages
[ ] 10. Acessar admin DEV → login → criar empresa → GHE → link
[ ] 11. Testar formulário com o link gerado
[ ] 12. PR develop→main para deploy em PROD
```

---

## 14. Backlog / Pendências

### 🔴 Operacionais (PROD — ação manual necessária)

| Item | Detalhe |
|------|---------|
| **PR develop→main** | 5 commits acumulados em develop ainda não em PROD. URL: `https://github.com/elevaitconsultoria/psicomap/compare/main...develop` |
| **Reimportar Assa Abloy (Shared Services)** | Catálogo zerado — reimportar planilha pelo admin + validar com `/validar-importacao-ghe` |
| **Reimportar ELEVA IT CONSULTORIA** | Catálogo zerado após wipe acidental sem soft-delete |

### 🟡 Produto (não iniciado)

| Item | Descrição |
|------|-----------|
| **Portal do Cliente** | Acesso direto da empresa aos seus resultados sem intermediação da consultoria. Schema suporta (`perfis.role = 'cliente_viewer'`, `perfis.empresa_id`); UI não implementada |
| **Ajuste de Probabilidade pelo Consultor** | Permitir editar o P calculado antes de fechar o laudo |
| **Personalização do Questionário por empresa** | Banco já suporta (`questionarios`, `questionario_questoes`); UI tem esqueleto em `sc-q` mas não é usada em produção |
| **Notificações & Alertas** | E-mail ao consultor em nova resposta; alerta de link expirando |
| **Landing Page** | Site de marketing separado do painel admin |

### ⚙️ Débito técnico

| Item | Descrição |
|------|-----------|
| **Credenciais PROD hardcoded em `psicomap-forms.html`** | Linhas 332–333 têm URL e JWT como literais; substituição é via regex no build.js — risco de falha silenciosa se formatação mudar. Admin usa placeholders seguros (`__SUPA_URL__`) |
| **Sem soft-delete** | Hard delete em empresas, links e riscos. Dados apagados são irrecuperáveis (caso real: ELEVA IT CONSULTORIA) |
| **QR Code depende de CDN externo** | `qrcodejs` via CDN sem hash SRI; se CDN cair ou for comprometido, QR codes param de funcionar |
| **Cache de respostas sem TTL** | `_respostasCache` em memória, sem invalidação automática. Dados ficam stale até reload |
| **Rate limiting só no frontend** | `_RATE_LIMIT_MS = 15000` ms no forms.html pode ser contornado via chamada direta ao RPC |

---

## 15. Histórico de Desenvolvimento (resumo de sessões)

| Entrega | Descrição |
|---|---|
| v0.1 | Estrutura inicial: login, empresas, links, questionário |
| v0.2 | Fix navegação (SyntaxError aspas simples em onclick) |
| v0.3 | Tela Auditoria de Respostas com tabela bruta, filtros, CSV |
| v0.4 | GHE (Setores & Funções): modal CRUD + integração nos combos |
| v0.5 | Tela Backlog; formulário dinâmico (meta-setor/funcao por empresa) |
| v0.6 | Migration SQL Fase 2; Migration Fase 1 aplicada |
| v1.0 | Auth real Supabase; Tela Empresas; Ciclos; QR inline; WhatsApp share; URL fix GitHub Pages |
| v1.1 | Production hardening: criado_por, realtime guard, refresh pós-save, escape onclick |
| v1.2 | Filtro por ciclo em Resultados + Distribuição + Auditoria; date pickers no modal de ciclos; "Esqueci minha senha"; badge de empresas no sidebar |
| v1.3 | **Multi-tenant RBAC** completo: roles `super_admin`/`admin`/`consultor`/`cliente_viewer`, tela Equipe (ESTs), tela Perfil de EST, menu por role, RLS com tenant isolation. **Billing**: integração Stripe, planos, subscriptions, tela Assinatura, tela Plano, `tenant_contadores`. **Código cliente** para empresas (`numero_cliente`). **GHE como tela cheia** (96vw×92vh, substituiu modal). **Comparativo entre Ciclos**: dashboard temporal para ≥ 2 ciclos. **Plano de Ação 5W2H**: geração a partir de riscos identificados. **Referência temporal em Ciclos**: campos `ano_referencia`/`mes_referencia`/`tipo_ciclo`; seletor Mês+Ano substitui campo texto livre; nome gerado automaticamente. Bug fixes: cargo→setor 1:N (era 1:1, descartava vínculos), headcount órfão ao limpar catálogo, salvaguarda GHE via `confirm()` em vez de hard-block, ordenação alfabética pt-BR em setores/cargos no formulário público, dedup de acentuação no import GHE. |

---

*Documentação atualizada em 2026-07-23 — v1.3*
