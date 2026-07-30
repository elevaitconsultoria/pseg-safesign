# PsicoMap — Guia para o Agente

## Contexto de negócio

O PsicoMap é uma **plataforma SaaS de avaliação de riscos psicossociais ocupacionais**,
voltada a consultorias de segurança do trabalho que precisam aplicar e analisar questionários
exigidos pela **NR-01, NR-17 e BS 8800** nas empresas clientes.

**Atores principais:**
- **Consultoria (admin)** — cadastra empresas, importa estrutura organizacional (GHE), gera links
  de coleta e analisa resultados.
- **Funcionário (anon)** — acessa o formulário pelo link, responde as 27 questões em escala 1–4,
  envia. Sem login, sem cadastro.
- **Cliente viewer** — acesso read-only futuro (backlog) para a empresa ver seus próprios
  resultados sem intermediação da consultoria.

**Fluxo central:**
```
Consultoria → cadastra empresa + GHE (setores/funções) + ciclo
           → gera link com token único por empresa/ciclo
           → compartilha via WhatsApp / QR Code

Funcionário → abre link no celular → responde → envia (Supabase + localStorage fallback)

Consultoria → vê respostas em tempo real
           → analisa por empresa / setor / função / nível de risco
           → gera laudo PDF e exporta CSV
```

**O que NÃO é o sistema:** não é um RH, não gerencia contratos, não emite certificados. É
exclusivamente um instrumento de coleta e análise de risco psicossocial.

## Regras de negócio críticas

1. **Um link ≠ um funcionário.** O `link_token` é compartilhado com múltiplos funcionários do
   mesmo setor/ciclo. Idempotência é por `session_id` (não por token). Nunca tratar token como
   identificador individual.

2. **Respostas são anônimas.** O sistema coleta setor, função e escolaridade — nunca nome ou CPF.
   Qualquer mudança que associe resposta a identidade pessoal viola a premissa de anonimato e pode
   conflitar com LGPD.

3. **GHE é pré-requisito para o formulário funcionar.** Sem setores/funções cadastrados via GHE,
   o formulário público exibe combos vazios. A importação é feita pelo admin antes de distribuir
   os links.

4. **O catálogo reflete a planilha — não o contrário.** A fonte da verdade do quadro de
   colaboradores é sempre a planilha Excel do cliente. O banco deve espelhar a planilha, nunca
   ser editado manualmente para "tapar" divergências. Usar `/validar-importacao-ghe` antes de
   qualquer entrega.

5. **Ciclos definem o escopo temporal de uma coleta.** Respostas de ciclos diferentes não se
   misturam na análise. Um ciclo representa uma rodada de avaliação (ex: semestral, anual).

6. **Score de risco = P × S (probabilidade × severidade), escala 1–25.** Classificação:
   IRRELEVANTE (1–2) / BAIXO (3–6) / MÉDIO (7–12) / ALTO (13–19) / CRÍTICO (20–25).
   Questões invertidas têm seu valor espelhado antes do cálculo (valor = 5 − valor_original).

7. **Multi-tenant.** Cada empresa pertence a um `tenant` (consultoria). RLS garante que dados
   de uma consultoria nunca vazam para outra. `super_admin` pode ver todos os tenants.

8. **`currentTenantId` é a variável global de contexto de tenant** para todo INSERT e query JS com
   filtro explícito. Para `admin`/`consultor`/`viewer` é o tenant do usuário logado. Para
   `super_admin` em modo suporte (`entrarComoEST`) é o `tenantId` da EST visitada; ao sair
   (`sairModoSuporte`) volta a `null`. **Nunca hardcodar tenant_id em queries — sempre usar
   `currentTenantId`.**

## Arquitetura

- **SPA de arquivo único**: `psicomap-admin.html` (painel admin) e `psicomap-forms.html`
  (formulário público). Toda lógica JS é inline — sem bundler, sem build step nos arquivos.
- **Backend**: Supabase. PROD: `vftyiildukrpgmnbcnao`. DEV: `szqatgvgghxvyyncsjxl`.
- **Deploy**: Cloudflare Pages. `develop` → DEV. `main` → PROD. `main` tem branch protection —
  PRs criados via `gh` CLI (autenticado — conta `elevaitconsultoria`, token no keyring Windows).
  Usar skill `/commitar-e-pr` para o fluxo completo.
- **Build**: `build.js` injeta `SUPA_URL` e `SUPA_ANON_KEY` nos HTMLs antes do deploy no CF Pages.

## Divergências DEV ↔ PROD (não ignorar)

| Campo | DEV | PROD |
|-------|-----|------|
| `respostas.session_id` | `text` (qualquer string) | `uuid` (UUID v4 válido) — **CRÍTICO** |
| `respostas.setor` | NOT NULL | nullable |
| `perfis` — função helper | `is_active_consultor()` | `is_tenant_consultor()` |
| Variáveis CF env | podem estar desatualizadas | fonte da verdade |

**Antes de qualquer deploy que toque o pipeline de submissão de respostas: rodar `/validar-formulario`.**

## Pipeline GHE (importação de estrutura organizacional)

Três tabelas formam o catálogo de uma empresa:
- `empresa_setores` — setores únicos
- `empresa_funcoes` — cargos únicos, com `setor_id` (FK) ou `NULL` (cargo universal)
- `empresa_headcount` — par `(setor text, funcao text, quantidade int)` — texto desnormalizado, sem FK

**Cargo→setor é mapeamento 1:N** (corrigido 2026-07). Se a validação encontrar pares ausentes com
padrão "mesmo cargo, setor diferente", a importação foi feita antes do fix — reimportar pelo admin.

**`salvarGHE()` tem duas salvaguardas:**
1. Catálogo populado + estrutura nova vazia → `confirm()` (não bloqueia; usuário decide)
2. Nenhum setor + cargos presentes → `confirm()`

**Ao limpar catálogo, `empresa_headcount` também é deletado** (fix 2026-07-22). Sem isso,
headcount fica órfão (mostra "207 func." com 0 setores/0 cargos).

**Dedup de acentuação** (fix 2026-07-23): `_gheNormStrong` (strip de diacríticos via NFD) é
usado como chave de matching durante o import — `"Producao"` e `"Produção"` colapsam para a
mesma entrada. `_ghePrefAcentuado` garante que a forma mais acentuada (grafia correta pt-BR) é
sempre preservada. Ocorre **só no momento do import** — dados já no banco não são reprocessados.
Capitalização não é normalizada — responsabilidade do cliente na planilha.

**Antes de enviar laudo para cliente com base importada: rodar `/validar-importacao-ghe`.**

## Formulário público (`psicomap-forms.html`)

- `carregarGHEEmpresa()` faz fetch do banco a cada load — sem cache local. Reimportar pelo admin
  reflete imediatamente; não é necessário gerar novo link.
- Setores e cargos são ordenados alfabeticamente (pt-BR, `localeCompare`) no carregamento.
  "Outro" sempre inserido por último, fora do sort.
- `link_token` não é único por funcionário — idempotência é por `session_id`.

## Checklist de rebrand (aprendido no rebrand PsicoMap, 2026-07)

Ao renomear arquivos HTML que têm URLs distribuídas publicamente (WhatsApp, QR Code, e-mail):

1. **Nunca deletar** — sempre redirecionar. Adicionar 301 em `_redirects` antes de remover o arquivo.
2. **Cobrir ambas as variantes** — o CF Pages serve `foo.html` também como `/foo`:
   ```
   /pseg-forms.html  →  /psicomap-forms.html  301
   /pseg-forms       →  /psicomap-forms.html  301
   ```
3. **Copiar `_redirects` para `dist/`** — confirmar que está no array `staticFiles` de `build.js`.
4. **Rodar `/validar-formulario`** após deploy para confirmar que o pipeline de submissão está intacto.
5. **Testar um link real** (distribuído antes do rebrand) antes de fechar o ciclo.

**Alternativa mais segura:** mudar apenas o conteúdo dos arquivos HTML sem renomeá-los —
elimina toda a categoria de bugs de link quebrado.

## Skills disponíveis

| Skill | Quando usar |
|-------|-------------|
| `/validar-formulario` | Antes de qualquer deploy que toque submissão de respostas |
| `/validar-importacao-ghe` | Antes de enviar laudo; após reimportar planilha de cliente |
| `/commitar-e-pr` | Sempre que houver mudanças prontas — faz add, commit, push e abre PR documentada |

## Convenções de código

- Funções de salvamento críticas usam pattern **"salvaguarda + confirm"** para ações destrutivas —
  nunca hard-block sem escape hatch para ações intencionais.
- Normalização de texto: `_gheNorm` (trim + espaços + lowercase) para matching simples;
  `_gheNormStrong` (idem + strip de diacríticos via NFD) para dedup com tolerância a acentuação
  — ex: pipeline GHE. Nunca usar para exibição ou persistência.
- Queries Supabase têm limite silencioso de 1000 linhas. Para empresas grandes, verificar
  `COUNT(*)` antes de assumir resultado completo. Use `_fetchAllSupabase()` / `_fetchAllGHE()`
  (helpers de paginação já existentes) em vez de queries simples quando o volume for incerto.
- Não editar `empresa_setores`/`empresa_funcoes`/`empresa_headcount` manualmente via SQL para
  "tapar" GAPs — isso mascara bugs de importação. A ação correta é sempre reimportar.
- Guard obrigatório contra empresa_id nulo antes de qualquer operação de banco:
  `if (!empresaId || empresaId === 'null') return;`
- Ao inserir via Supabase, sempre incluir no `.select()` de retorno TODOS os campos novos que
  serão usados na UI — omitir causa "campo some até recarregar" (bug real 2026-07-21).
- Toggles custom: colocar lógica no `onchange` do `<input>`, nunca no `onclick` do `<label>`
  que o envolve — 1 clique físico gera 2 eventos se a lógica estiver no label (bug real 2026-07-21).

## RBAC — Matriz de acesso por role (2026-07-24)

| Tela | super_admin | admin | consultor | cliente_viewer |
|------|-------------|-------|-----------|----------------|
| dashboard | ✅ | ✅ | ✅ | ✅ |
| empresas (Clientes) | ✅ | ✅ | ✅ | ❌ |
| ghe (Setores/Funções) | ✅ | ✅ | ✅ | ❌ |
| links de coleta | ✅ | ✅ | ✅ | ✅ leitura |
| questionário | ✅ | ✅ | ✅ | ❌ |
| analise / graficos | ✅ | ✅ | ✅ | ✅ |
| comparativo | ✅ | ✅ | ✅ | ❌ |
| auditoria | ✅ | ✅ | ✅ | ❌ |
| laudo (relatório) | ✅ | ✅ | ✅ | ✅ |
| plano de ação | ✅ | ✅ | ❌ | ❌ |
| usuarios (equipe) | ✅ | ✅ | ❌ | ❌ |
| riscos / assinatura | ✅ | ✅ | ❌ | ❌ |
| est-perfil (Perfil EST) | ✅ | ✅ | ❌ | ❌ |
| gestao-ests | ✅ | ❌ | ❌ | ❌ |

**Duas camadas de proteção no frontend:**
1. `aplicarRestricoesPorRole()` — oculta itens do sidebar no boot
2. `goScreen()` — verifica `restritos[role]` em tempo de navegação e bloqueia com toast

**Três camadas para funções críticas** (ex: `salvarEstPerfil`): sidebar + goScreen + guard no início da função.

**super_admin — sidebar dinâmico:**
- Boot normal: mostra apenas Gestão de ESTs + Equipe
- Após `entrarComoEST()`: expande para visão admin (sem gestao-ests)
- Após `sairModoSuporte()`: colapsa de volta

**cliente_viewer — isolamento de dados:**
- JS: `carregarEmpresas()` filtra por `currentUser.empresa_id`
- Banco: policy RESTRICTIVE `viewer_empresa_select_empresas` em `empresas`
- Botões de escrita ocultos: `links-action-btns` e `dash-hdr-actions`

**Policies RESTRICTIVE do viewer no banco** (DEV + PROD, `migration_viewer_write_hardening.sql`):
- INSERT/DELETE bloqueados em: `links_coleta`, `laudos`, `empresa_headcount`, `ciclos`
- SELECT em `empresas` scoped a `get_my_empresa_id()`
- UPDATE em tabelas operacionais (migration anterior `migration_rbac_viewer_hardening.sql`)

## Módulos por EST — feature flags (2026-07-29)

**Eixo independente do role.** Role responde "quem é você"; módulo responde "o que está ligado
para esta EST". Serve para segurar recursos ainda em desenvolvimento diante de um cliente
específico, sem criar mais um role. **Nunca criar role novo para recortar visibilidade** — as
policies RESTRICTIVE existentes testam literalmente `<> 'cliente_viewer'`, então um role novo
nasceria com escrita liberada em tudo.

- Tabela `tenant_modulos (tenant_id, modulo, habilitado, updated_at, updated_by)` —
  `migration_tenant_modulos.sql`. **SELECT** por qualquer usuário do tenant; **escrita só
  `is_super_admin()`**.
- **Não colocar os flags em `tenants`**: a policy `tenant_update_admin` deixa o admin da própria
  EST fazer UPDATE naquela linha — ele religaria os módulos via API.
- **Ausência de linha = habilitado.** Nenhum seed necessário; EST nova e módulo novo nascem
  ligados. Ao salvar pelo modal, grava-se linha para todos os módulos do catálogo (religar é
  UPDATE, não DELETE).
- `MODULOS_CATALOGO` (catálogo do modal) e `MODULO_POR_TELA` (tela→módulo) em
  `psicomap-admin.html`. Acrescentar módulo ao catálogo é seguro.
- Aplicação: `carregarModulosTenant()` preenche `_modulosOff` → `aplicarModulos()` marca
  `[data-modulo]` com a classe `.modulo-off` (`display:none!important`).
  **`aplicarModulos()` roda sempre DEPOIS de `aplicarRestricoesPorRole()`**, que começa
  resetando `display=''` em todos os `.nav-item` — a ordem inversa não gruda.
- Classe, não `style.display`: reversível e não atropela displays inline pré-existentes.
- Conteúdo gerado por template string precisa de `_esconderElementosModulos()` no fim do render
  (já feito em `renderLinks()`, `_renderGHETabela()` e `goScreen()`). Para condicionais dentro de
  template use o helper `moduloOn('id')`.
- **O gate é client-side (cosmético)** — adequado para módulo imaturo, não é fronteira de
  segurança. Bloqueio real exige policy RESTRICTIVE na tabela de dados do módulo.
- `carregarModulosTenant()` **falha aberto**: erro de leitura loga warn e mantém tudo visível,
  em vez de esconder o app inteiro se a migration não estiver aplicada.
- Módulo `adesao` não é tela: guard em `carregarAdesaoGHE()` força `_gheAdesaoData = null` (o
  detail pane e a tabela já degradam nesse caminho) + `data-modulo` no `#ghe-adesao-row`, nas
  duas colunas da tabela GHE e no botão "Ver adesão" da tela de Links.

## Modo Suporte (super_admin — `entrarComoEST`)

O super_admin opera normalmente na tela Gestão de ESTs. Para inspecionar/operar no contexto de
uma EST específica, usa o botão "Entrar como":

```
entrarComoEST(tenantId, nome)
  → _supportMode = true
  → _supportTenant = { id, nome }
  → currentTenantId = tenantId      ← INSERTs usam tenant correto
  → carregarEmpresas() com filtro   ← SELECTs filtrados pelo tid
  → aplicarRestricoesPorRole()      ← sidebar expande (visão admin)
  → banner amarelo visível

sairModoSuporte()
  → _supportMode = false
  → _supportTenant = null
  → currentTenantId = null          ← super_admin não tem tenant
  → _empresas = [], _links = []     ← limpa sem carregar cross-tenant
  → aplicarRestricoesPorRole()      ← sidebar colapsa
  → goScreen('gestao-ests')
```

`entrarComoEST` também chama `carregarModulosTenant()` (antes de
`aplicarRestricoesPorRole`) e `sairModoSuporte` limpa `_modulosOff` — sem isso os flags da EST
visitada continuariam valendo fora do modo suporte.

**Por que `currentTenantId = tenantId` é crítico**: todos os INSERTs do sistema usam
`currentTenantId` como `tenant_id`. Sem isso, registros criados em modo suporte teriam
`tenant_id = null` e ficariam órfãos (invisíveis para o admin da EST).

## Gotchas críticos de arquitetura

- **Textos de questões hardcoded em dois lugares**: `QS_OFICIAIS` (admin, ln ~3989) e `BLOCOS`
  (forms, ln ~30). Qualquer atualização de texto **deve ser feita nos dois arquivos** — nunca
  só em um. A tabela `questoes.texto` existe mas não é fonte de verdade do admin.
- **`psicomap-forms.html` tem credenciais PROD hardcoded** (linhas 332–333). O `build.js` substitui
  via regex — se o código ao redor mudar, o regex falha silenciosamente sem erro. O admin usa
  placeholders seguros (`__SUPA_URL__`); o forms não. Cuidado ao reformatar essas linhas.
- **Hard delete sem soft-delete**: `excluirEmpresa()` (ln ~4996) é irreversível com CASCADE.
  Dados apagados não são recuperáveis (caso real: ELEVA IT CONSULTORIA 2026-07-22).
- **`_redirects` e `_headers` devem estar em `dist/`**: o Cloudflare Pages serve a partir de
  `dist/`. Sem copiar esses arquivos no `build.js` (array `staticFiles`), nenhum redirect
  ou header de segurança chega ao deploy. Verificar `staticFiles` em `build.js` sempre que
  adicionar regras de routing.
- **Cloudflare Pretty URLs**: o CF Pages serve `foo.html` também como `/foo` (sem extensão).
  Qualquer redirect de compatibilidade deve cobrir **ambas** as variantes (`/foo.html` e `/foo`).
- **Branding nos exports usa `_estPerfil.nome_empresa` — nunca string hardcoded**: `exportarResultadosPrint()`,
  export de Gráficos e toolbar do `_buildLaudoHTML` usam o nome dinâmico da EST. Se ausente, o campo
  some (sem fallback para "Eleva IT" ou outro nome de consultoria). O corpo do laudo usa
  `estPerfil?.nome_empresa || 'PsicoMap'` — fallback para o nome do produto, não da consultoria.
