# PSEG SafeSign — Documentação do Projeto

> Plataforma de avaliação de riscos psicossociais (NR-17 / NR-01 / BS 8800)  
> Stack: HTML estático + Supabase (PostgreSQL + Auth + Realtime) + GitHub Pages

---

## 1. Visão Geral

O SafeSign é uma aplicação web Single-Page sem framework de build. Toda a lógica reside em dois arquivos HTML auto-contidos:

| Arquivo | Papel |
|---|---|
| `pseg-admin-questionario.html` | Painel da consultoria (admin) |
| `pseg-forms.html` | Formulário de coleta para funcionários |

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
| **GitHub Pages (produção)** | `https://elevaitconsultoria.github.io/pseg-safesign/pseg-admin-questionario.html` | `https://elevaitconsultoria.github.io/pseg-safesign/pseg-forms.html?token=TOKEN` |
| **Local (dev)** | `http://localhost:3788/pseg-admin-questionario.html` | `http://localhost:3788/pseg-forms.html?token=TOKEN` |

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
- **ID:** `vftyiildukrpgmnbcnao`
- **URL:** `https://vftyiildukrpgmnbcnao.supabase.co`
- **Chave pública (anon):** presente nos arquivos HTML (seguro — read-only por padrão)

### Schema completo

```
empresas
  id uuid PK | nome text | cnpj text | contato text
  ativo bool | criado_em timestamptz | criado_por uuid→auth.users | questionario_id uuid

ciclos
  id uuid PK | empresa_id uuid→empresas | nome text | descricao text
  data_inicio date | data_fim date | status text | criado_em timestamptz

empresa_setores          ← Fase 2 (GHE)
  id uuid PK | empresa_id uuid→empresas | nome text | ordem int | ativo bool | created_at

empresa_funcoes          ← Fase 2 (GHE)
  id uuid PK | empresa_id uuid→empresas | nome text | ordem int | ativo bool | created_at

links_coleta
  id uuid PK | empresa_id uuid→empresas | ciclo_id uuid→ciclos
  token text UNIQUE | setor_sugerido text | ativo bool | expira_em timestamptz | criado_em

respostas
  id uuid PK | empresa_id uuid | ciclo_id uuid | link_token text
  setor text | funcao text | escolaridade text | fonte text | respondido_em timestamptz
  questionario_id uuid

resposta_itens
  id uuid PK | resposta_id uuid→respostas | questao_id uuid→questoes | valor int(1-4)

questoes
  id uuid PK | codigo text (Q1-Q27) | texto text | bloco text | invertida bool | is_oficial bool

questionarios / questionario_questoes   ← estrutura de questionário configurável
laudos                                  ← relatórios gerados
perfis                                  ← roles dos usuários (admin / consultor / cliente_viewer)
riscos_config                           ← tabela de riscos por empresa
```

### Migrations aplicadas

| Arquivo | Status | Conteúdo |
|---|---|---|
| `pseg-phase1-migration.sql` | ✅ Aplicada | perfis, criado_por, ciclos colunas, riscos_config, RLS base |
| `pseg-phase2-migration.sql` | ✅ Aplicada | empresa_setores, empresa_funcoes, RLS GHE |

### RLS resumida

| Tabela | Público (anon) | Autenticado |
|---|---|---|
| empresas | SELECT onde ativo=true | SELECT/INSERT/UPDATE próprias |
| ciclos | SELECT todos | ALL |
| links_coleta | SELECT onde ativo=true | ALL |
| respostas | INSERT validado por token | SELECT/DELETE |
| resposta_itens | INSERT livre | SELECT/DELETE |
| empresa_setores | SELECT onde ativo=true | ALL (próprias empresas) |
| empresa_funcoes | SELECT onde ativo=true | ALL (próprias empresas) |
| questoes | SELECT todos | ALL |
| perfis | — | Self SELECT/UPDATE + admin ALL |

---

## 5. Módulos do Painel Admin

### 5.1 Dashboard
- KPIs: nº empresas, respostas totais, links ativos, links sem resposta
- Cards por empresa com status visual e link para análise

### 5.2 Empresas (`sc-empresas`) ← novo
- Grid de cards por empresa: links ativos, respostas, setores, ciclos
- Botões por card: **GHE**, **Ciclos**, **Links**, **Resultados**
- "Nova empresa" → salva com `criado_por` → abre GHE automaticamente

### 5.3 Links de Coleta (`sc-links`)
- Gerar link com token aleatório por empresa + ciclo + setor opcional
- Por link: **📋 Copiar**, **💬 WhatsApp**, **📷 QR Code**, **Ativar/Desativar**
- Modal QR Code inline com download PNG
- Realtime: contador de respostas atualiza sem F5 (quando autenticado)

### 5.4 GHE — Setores & Funções (modal)
- Acessível via botão "GHE" no card de empresa ou toolbar de Links
- CRUD de setores e funções por empresa
- Persiste em `empresa_setores` / `empresa_funcoes` (prod) ou `_empresas[x]` (demo)
- Atualiza combos de filtro em todas as telas ao salvar

### 5.5 Ciclos (modal)
- Acessível via botão "Ciclos" no card de empresa
- Criar ciclo com nome + período
- Listar/remover ciclos existentes

### 5.6 Questionário (`sc-q`)
- 27 questões oficiais NR-17 em 3 blocos (A: Demandas, B: Relações, C: Organizacional)
- Questões extras configuráveis por empresa
- Parâmetros: probabilidade (P), severidade (S), bloco

### 5.7 Resultados / Análise (`sc-analise`)
- Filtros por empresa, setor, função, nível de risco
- Tabela de riscos com score P×S calculado
- Distribuição por nível: IRRELEVANTE / BAIXO / MÉDIO / ALTO / CRÍTICO

### 5.8 Distribuição (`sc-graficos`)
- Gráficos Chart.js: barras por bloco, radar, tendência
- Filtros por setor e função

### 5.9 Auditoria de Respostas (`sc-auditoria`)
- Tabela bruta: todas as respostas com 27+ colunas (setor, função, Q1–Q22)
- Filtros empresa/setor/função
- Linha de médias no rodapé
- Exportação CSV (UTF-8 BOM)

### 5.10 Relatório (`sc-laudo`)
- Documento completo com metodologia + resultados + ações recomendadas
- Exportação PDF via jsPDF

### 5.11 Riscos & Severidade (`sc-riscos`)
- Tabela de riscos com probabilidade e severidade configuráveis
- Persiste em `riscos_config`

### 5.12 Usuários (`sc-usuarios`)
- Listagem de perfis com role e status
- Alterar role (admin / consultor / cliente_viewer)
- Ativar/desativar usuário

### 5.13 Metodologia (`sc-metodologia`)
- Documentação técnica: NR-01, NR-17, BS 8800
- Calculadora P×S, interpretação, referências

### 5.14 Backlog (`sc-backlog`)
- Portal do Cliente (dashboard read-only por empresa)
- Personalização do questionário por empresa
- Notificações automáticas
- Plano de Ação 5W2H

---

## 6. Formulário de Coleta (`pseg-forms.html`)

### Fluxo técnico
```
1. URL: /pseg-forms.html?token=XXXX
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

## 10. Repositórios Git

| Repo | Branch | Conteúdo |
|---|---|---|
| `elevaitconsultoria/site_rep` | `claude/jovial-euler` | Desenvolvimento ativo |
| `elevaitconsultoria/pseg-safesign` | `gh-pages` | GitHub Pages (produção) |
| `elevaitconsultoria/pseg-safesign` | `main` | Branch principal safesign |

### Deploy
```bash
# Desenvolvimento
git push origin claude/jovial-euler

# Publicar no GitHub Pages (feito automaticamente pelos scripts de deploy)
git push https://github.com/elevaitconsultoria/pseg-safesign.git gh-pages:gh-pages
```

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
[ ] 1. Criar projeto Supabase
[ ] 2. Atualizar SUPA_URL e SUPA_ANON nos dois HTMLs
[ ] 3. Executar pseg-phase1-migration.sql no SQL Editor
[ ] 4. Executar pseg-phase2-migration.sql no SQL Editor
[ ] 5. Criar usuário admin em Authentication → Users → Add user
[ ] 6. O trigger on_auth_user_created cria perfil automaticamente com role='consultor'
[ ] 7. Promover para admin:
       UPDATE perfis SET role='admin' WHERE id='<UUID>';
[ ] 8. Publicar os HTMLs (GitHub Pages, Vercel, Netlify ou servidor estático)
[ ] 9. Acessar /pseg-admin-questionario.html → login → criar empresa → GHE → link
[ ] 10. Testar formulário com o link gerado
```

---

## 14. Backlog / Pendências

### 🔴 Alta prioridade

| Item | Descrição | Notas |
|---|---|---|
| **Teste E2E real** | Executar o fluxo completo com login Supabase real: login → empresa → GHE → link → form → auditoria | Ambiente de produção pronto; precisa de execução manual |
| **Validação RLS consultor** | Testar que consultor só vê suas próprias empresas (não as de outros consultores) | Depende de ter 2+ usuários |

### 🟡 Média prioridade

| Item | Descrição |
|---|---|
| **Tela Empresas — edição inline** | Editar nome/CNPJ diretamente no card sem abrir modal |
| **Exportação PDF** | Testar jsPDF com dados reais — verificar formatação e quebra de página |
| **Modo offline robusto** | Reenviar respostas salvas em localStorage quando conexão restaurada |
| **Comparativo entre ciclos** | Dashboard temporal quando há ≥ 2 ciclos com respostas — gráfico de evolução |

### 🟢 Baixa prioridade (Backlog documentado na tela)

| Item | Descrição |
|---|---|
| **Portal do Cliente** | Área read-only para empresa ver seus resultados sem consultoria intermediar |
| **Personalização do questionário** | Ativar/desativar/adicionar questões por empresa |
| **Notificações automáticas** | E-mail ao consultor em nova resposta; alerta de link expirando |
| **Plano de Ação 5W2H** | Geração a partir dos riscos identificados |
| **Comparativo entre ciclos** | Dashboard temporal quando há ≥ 2 ciclos com respostas |

### ⚙️ Débito técnico

| Item | Descrição |
|---|---|
| **Variáveis de ambiente** | SUPA_URL e SUPA_ANON estão hardcoded nos HTMLs; mover para processo de build ou endpoint seguro em produção com múltiplos clientes |
| **Build step** | O projeto tem ~6700 linhas por arquivo; à medida que cresce considerar Vite + módulos ES |
| **Testes automatizados** | Nenhum teste unitário ou E2E; considerar Playwright para smoke tests do fluxo |
| **QR Code offline** | Atualmente usa API externa (qrserver.com); se offline, imagem não carrega |
| **Carregamento questões** | `carregarMapaQuestoes()` no forms.html não é awaited (race condition teórica) |

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

---

*Documentação atualizada em 2026-04-16 — v1.2*
