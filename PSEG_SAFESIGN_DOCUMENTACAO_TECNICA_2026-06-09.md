# PSEG SafeSign — Documentação Técnica
**Verificado em:** 2026-07-23 (análise completa do código via agente Explore — leitura integral dos dois HTMLs, 25 migrations, 3 skills, build.js)
**PROD:** `vftyiildukrpgmnbcnao` · **DEV:** `szqatgvgghxvyyncsjxl`
**Nota:** o nome do arquivo mantém a data de criação original (2026-06-09) por estabilidade de link/referência — o conteúdo é atualizado continuamente. Ver seção 17 (Changelog) para o histórico cronológico do que mudou em cada verificação.

---

## 1. Visão Geral da Arquitetura

Sistema SaaS de aplicação e análise do questionário psicossocial NR-01.

- **Frontend:** Single-file SPA — `pseg-admin-questionario.html` (painel) + `pseg-forms.html` (formulário público)
- **Backend:** Supabase (Postgres + Auth + RLS + Edge Functions)
- **Deploy:** Cloudflare Pages — branch `develop` → DEV preview; branch `main` → PROD
- **Build:** `build.js` injeta `SUPA_URL` e `SUPA_ANON_KEY` nos HTMLs antes do deploy

---

## 2. Ambientes e URLs

| Item | PROD | DEV |
|------|------|-----|
| Supabase project | `vftyiildukrpgmnbcnao` | `szqatgvgghxvyyncsjxl` |
| Região | us-east-2 (N. Virginia) | us-west-2 (Oregon) |
| Cloudflare URL | `https://pseg-safesign.pages.dev` | `https://develop.pseg-safesign.pages.dev` |
| Admin | `/pseg-admin-questionario.html` | `/pseg-admin-questionario.html` |
| Forms | `/pseg-forms.html?token=TOKEN` | `/pseg-forms.html?token=TOKEN` |

**GitHub Pages (secundário, não oficial):** `https://elevaitconsultoria.github.io/pseg-safesign/`

---

## 3. Divergências entre DEV e PROD (verificadas em 2026-07-14)

Estas divergências foram extraídas diretamente do schema dos dois bancos. Qualquer patch deve levar em conta as diferenças — um fix correto em DEV pode quebrar PROD.

| Item | PROD | DEV | Impacto |
|------|------|-----|---------|
| `respostas.session_id` tipo | `uuid` | `text` | **CRÍTICO** — ver seção 7.2 |
| `respostas.setor` nulabilidade | nullable | NOT NULL | Diferença de constraint |
| `respostas.lgpd_aceito` default | `true` NOT NULL | `false` nullable | Diferença de default |
| `respostas_raw_backup.payload` | NOT NULL | nullable | Constraint diferente |
| `respostas_raw_backup` coluna timestamp | `gravado_em` | `criado_em` | Nome diferente! |
| `est_perfil` colunas | 9 | 9 | Sincronizado via `migration_sync_est_perfil_prod.sql` (2026-07-20) — resolvido |
| GRANTs para `anon` | Completos (SELECT/INSERT/UPDATE/DELETE) em todas | Limitados — só SELECT em algumas; CRUD manual em `empresa_headcount` e `respostas_raw_backup` | Ver seção 6 |
| Policies `questionarios/questoes/questionario_questoes` escrita | Apenas `super_admin` | Qualquer `authenticated` (`USING true`) | Falha de segurança no DEV |
| `salvar_resposta` overloads | 2 (com e sem `p_device_info`) | 1 (só com `p_device_info`) | Compatibilidade |
| `perfis` — função helper | `is_tenant_consultor()` | `is_active_consultor()` | Nomes diferentes |
| Policies `super_admin_all` | Ausentes em várias tabelas | Presentes em ciclos, empresas, setores, funções, links | DEV mais permissivo para super_admin |

---

## 4. Tabelas — Schema Completo (PROD, verificado)

RLS habilitado em **todas as 21 tabelas**. Views não têm RLS próprio.

### 4.1 `tenants` (16 colunas)
```
id                  uuid        PK, gen_random_uuid()
nome                text        NOT NULL
slug                text        NOT NULL, UNIQUE
plano               text        NOT NULL, default 'trial' — CHECK IN ('trial','starter','professional','enterprise')
trial_ate           timestamptz nullable
ativo               boolean     NOT NULL, default true
max_empresas        int         nullable
max_usuarios        int         nullable
max_respostas_mes   int         nullable
logo_url            text        nullable
cor_primaria        text        nullable
stripe_customer_id  text        nullable
asaas_customer_id   text        nullable
criado_por          uuid        FK auth.users ON DELETE SET NULL
created_at          timestamptz NOT NULL, default now()
updated_at          timestamptz NOT NULL, default now()
```

### 4.2 `perfis` (8 colunas)
```
id          uuid        PK — FK auth.users ON DELETE CASCADE
nome        text        NOT NULL, default ''
role        text        NOT NULL, default 'consultor' — CHECK IN ('super_admin','admin','consultor','cliente_viewer')
empresa_id  uuid        FK empresas ON DELETE SET NULL (nullable — só preenchido para cliente_viewer)
ativo       boolean     NOT NULL, default true
created_at  timestamptz NOT NULL, default now()
updated_at  timestamptz NOT NULL, default now()
tenant_id   uuid        FK tenants ON DELETE SET NULL (nullable — NULL para super_admin)
```

### 4.3 `empresas` (13 colunas)
```
id              uuid        PK, uuid_generate_v4()
nome            text        NOT NULL
cnpj            text        nullable
contato         text        nullable
ativo           boolean     default true
criado_em       timestamptz default now()
questionario_id uuid        FK questionarios ON DELETE SET NULL
criado_por      uuid        FK auth.users ON DELETE SET NULL
tenant_id       uuid        FK tenants ON DELETE CASCADE (nullable — linhas legadas sem tenant existem)
razao_social    text        nullable
endereco        text        nullable
logo_base64     text        nullable
numero_cliente  int         nullable — código curto de referência por tenant (ver 4.23), atribuído via trigger
```

> **`excluirEmpresa()` faz HARD DELETE** (`DELETE FROM empresas`), não soft-delete — apesar de existir a coluna `ativo`, que é usada só como filtro de carregamento (`carregarEmpresas()` sempre faz `.eq('ativo', true)`), não como flag de exclusão lógica. Isso importa para `numero_cliente`: o número nunca é reatribuído a outra empresa mesmo após exclusão, porque é gerado por um contador dedicado (`tenant_contadores`), não por `MAX(numero_cliente)+1` — ver 4.23.

### 4.4 `est_perfil` (12 colunas — sincronizado entre DEV e PROD desde 2026-07-20)
```
id                    uuid        PK, uuid_generate_v4()
tenant_id             uuid        NOT NULL, UNIQUE — FK tenants
nome_empresa          text        nullable
cnpj                  text        nullable
endereco              text        nullable
responsavel_padrao    text        nullable
registro_profissional text        nullable
logo_base64           text        nullable
atualizado_em         timestamptz default now()
cor_primaria          text        nullable, default '#16a34a' — identidade visual da EST nos laudos
nome_responsavel      text        nullable
email_responsavel     text        nullable
```
> `migration_sync_est_perfil_prod.sql` aplicada em PROD em 2026-07-20 — as 3 últimas colunas, antes exclusivas de DEV, agora existem nos dois bancos. Divergência da seção 3 (linha `est_perfil colunas`) **resolvida**.

### 4.5 `ciclos` (13 colunas)
```
id                  uuid        PK, uuid_generate_v4()
empresa_id          uuid        NOT NULL, FK empresas ON DELETE CASCADE
nome                text        NOT NULL — gerado automaticamente para ciclos novos (ex: "Avaliação — Julho 2026"), não é mais digitado
data_inicio         date        nullable
data_fim            date        nullable
status              text        default 'aberto' — CHECK IN ('aberto','encerrado','laudo_gerado')
criado_em           timestamptz default now() — APENAS auditoria técnica, NUNCA usar para lógica de período
descricao           text        nullable
tenant_id           uuid        FK tenants ON DELETE CASCADE
ano_referencia      int         nullable — período que a coleta representa (fato objetivo, obrigatório na criação via UI)
mes_referencia      int         nullable — CHECK (mes_referencia BETWEEN 1 AND 12)
tipo_ciclo          text        default 'Não classificado' — classificação opcional (Linha de Base/1º Semestre/2º Semestre/Reavaliação Anual/Pós-Mudança Organizacional), editável a qualquer momento sem afetar ano/mês/vínculos
referencia_estimada boolean     default false — true quando ano/mes foram inferidos via backfill de migration (badge "⏱ estimado" na UI), false para ciclos criados após a mudança
```
> `migration_ciclos_referencia_temporal.sql` (2026-07-22). Separa fato objetivo (quando o ciclo se refere) de interpretação humana (como classificar). O critério de ordenação cronológica em `preencherSelectCiclos()` e `renderComparativo()` (Comparativo entre Ciclos) foi corrigido para usar `(ano_referencia, mes_referencia)` em vez de `data_inicio||criado_em` — o fallback antigo caía silenciosamente em ordem de CRIAÇÃO quando `data_inicio` estava vazio, não ordem de PERÍODO.

### 4.6 `links_coleta` (11 colunas)
```
id                      uuid        PK, uuid_generate_v4()
empresa_id              uuid        NOT NULL, FK empresas ON DELETE CASCADE
ciclo_id                uuid        FK ciclos ON DELETE SET NULL (nullable)
token                   text        NOT NULL, UNIQUE — gerado automaticamente: encode(gen_random_bytes(16),'hex')
setor_sugerido          text        nullable
ativo                   boolean     default true
expira_em               timestamptz nullable (NULL = sem expiração)
criado_em               timestamptz default now()
tenant_id               uuid        FK tenants ON DELETE CASCADE
is_teste                boolean     NOT NULL, default false
permite_multi_resposta  boolean     nullable, default false — quando true, a trava de "1 resposta por dispositivo" (localStorage no formulário) é liberável pelo respondente via botão "Liberar para o próximo colaborador" na tela de sucesso. Uso: notebook/tablet compartilhado por vários funcionários (ex.: trabalhadores de campo sem dispositivo próprio).
```
> `migration_links_multi_resposta.sql` (2026-07-21). Flag por link, não por empresa — o consultor decide caso a caso. A trava em si continua sendo puramente client-side (`localStorage`); a coluna só habilita/desabilita a exibição do botão de liberação. Nenhuma constraint de banco depende disso — `session_id` de `respostas` já é gerado novo a cada carregamento de página, então não há necessidade de mudança na idempotência do `salvar_resposta`.

> **REGRA CRÍTICA:** `token` é UNIQUE (1 link por empresa/ciclo), mas N funcionários usam o mesmo link.
> `respostas.link_token` NÃO é UNIQUE. NUNCA adicionar UNIQUE em `respostas.link_token`.

### 4.7 `respostas` (15 colunas)

| Coluna | PROD | DEV |
|--------|------|-----|
| `session_id` | `uuid` nullable | `text` nullable |
| `setor` | `text` nullable | `text` NOT NULL |
| `lgpd_aceito` | `boolean NOT NULL default true` | `boolean nullable default false` |

```
id              uuid        PK, uuid_generate_v4()
empresa_id      uuid        NOT NULL, FK empresas ON DELETE CASCADE
ciclo_id        uuid        FK ciclos ON DELETE SET NULL
link_token      text        nullable
questionario_id uuid        FK questionarios
setor           text        [PROD: nullable | DEV: NOT NULL]
funcao          text        nullable
escolaridade    text        nullable
fonte           text        default 'formulario_web' — CHECK IN ('formulario_web','import_csv')
respondido_em   timestamptz default now()
tenant_id       uuid        FK tenants ON DELETE CASCADE
session_id      [PROD: uuid | DEV: text] nullable
lgpd_aceito     boolean     [PROD: NOT NULL default true | DEV: nullable default false]
lgpd_aceito_em  timestamptz nullable
device_info     text        nullable — ex: "Mobile | Android | Chrome | 390px"
```

### 4.8 `resposta_itens` (4 colunas)
```
id          uuid      PK, uuid_generate_v4()
resposta_id uuid      NOT NULL, FK respostas ON DELETE CASCADE, UNIQUE com questao_id
questao_id  uuid      NOT NULL, FK questoes
valor       smallint  NOT NULL — CHECK (valor >= 1 AND valor <= 4)
UNIQUE (resposta_id, questao_id)
```

### 4.9 `respostas_fila` (9 colunas)
```
id            uuid        PK, gen_random_uuid()
empresa_id    uuid        NOT NULL
link_token    text        NOT NULL
payload_json  jsonb       NOT NULL
status        text        NOT NULL, default 'pendente' — CHECK IN ('pendente','processado','erro')
tentativas    int         NOT NULL, default 0
erro_msg      text        nullable
criado_em     timestamptz NOT NULL, default now()
processado_em timestamptz nullable
```

### 4.10 `respostas_raw_backup` (6 colunas)

| Coluna | PROD | DEV |
|--------|------|-----|
| timestamp | `gravado_em timestamptz NOT NULL` | `criado_em timestamptz nullable` |
| `payload` | `jsonb NOT NULL` | `jsonb nullable` |

```
id          uuid        PK, gen_random_uuid()
[PROD: gravado_em | DEV: criado_em]  timestamptz  [PROD: NOT NULL | DEV: nullable], default now()
session_id  uuid        nullable  [PROD: uuid | DEV: text via GRANT]
empresa_id  uuid        nullable
link_token  text        nullable
payload     jsonb       [PROD: NOT NULL | DEV: nullable]
```

> **Atenção:** O nome da coluna de timestamp é diferente entre os bancos. Queries com `criado_em` falham em PROD; usar `gravado_em` em PROD.

### 4.11 `empresa_setores` (7 colunas)
```
id          uuid        PK, gen_random_uuid()
empresa_id  uuid        NOT NULL, FK empresas ON DELETE CASCADE
nome        text        NOT NULL
ordem       int         NOT NULL, default 0
ativo       boolean     NOT NULL, default true
created_at  timestamptz NOT NULL, default now()
tenant_id   uuid        FK tenants ON DELETE CASCADE
UNIQUE (empresa_id, nome)
```

### 4.12 `empresa_funcoes` (8 colunas)
```
id          uuid        PK, gen_random_uuid()
empresa_id  uuid        NOT NULL, FK empresas ON DELETE CASCADE
nome        text        NOT NULL
ordem       int         NOT NULL, default 0
ativo       boolean     NOT NULL, default true
created_at  timestamptz NOT NULL, default now()
tenant_id   uuid        FK tenants ON DELETE CASCADE
setor_id    uuid        FK empresa_setores ON DELETE SET NULL (nullable — NULL = universal)
UNIQUE (empresa_id, setor_id, nome)  ← permite mesmo cargo em setores diferentes
```

> Constraint alterado de `UNIQUE(empresa_id, nome)` para `UNIQUE(empresa_id, setor_id, nome)` em 2026-07-13.
> Cargos com `setor_id IS NULL` são "universais" — aparecem em todos os setores no formulário.

### 4.13 `empresa_headcount` (7 colunas)
```
id          uuid        PK, gen_random_uuid()
empresa_id  uuid        NOT NULL, FK empresas ON DELETE CASCADE
tenant_id   uuid        NOT NULL, FK tenants ON DELETE CASCADE
setor       text        NOT NULL
funcao      text        nullable  (NULL = headcount total do setor, sem distinção de função)
quantidade  int         NOT NULL, CHECK (quantidade >= 0)
criado_em   timestamptz NOT NULL, default now()
UNIQUE INDEX uq_empresa_headcount ON (empresa_id, setor, COALESCE(funcao,''))
```

> Criada via SQL direto (não pelo dashboard). Em DEV requereu GRANT manual. Ver seção 6.

### 4.14 `questoes` (10 colunas)
```
id                    uuid     PK, uuid_generate_v4()
codigo                text     NOT NULL, UNIQUE — ex: 'A01', 'B03'
texto                 text     NOT NULL
bloco                 text     NOT NULL — CHECK IN ('A','B','C','EXTRA')
fator_id              text     NOT NULL
inversa               boolean  default false
is_ancora             boolean  default false
is_oficial            boolean  default true
criada_por_empresa_id uuid     FK empresas ON DELETE SET NULL (nullable — NULL = questão oficial)
criado_em             timestamptz default now()
```

### 4.15 `questionarios` (5 colunas)
```
id          uuid        PK, uuid_generate_v4()
nome        text        NOT NULL
empresa_id  uuid        FK empresas ON DELETE CASCADE (nullable — NULL = questionário padrão)
ativo       boolean     default true
criado_em   timestamptz default now()
```

### 4.16 `questionario_questoes` (5 colunas)
```
id              uuid     PK, uuid_generate_v4()
questionario_id uuid     NOT NULL, FK questionarios ON DELETE CASCADE
questao_id      uuid     NOT NULL, FK questoes ON DELETE CASCADE
ordem           int      NOT NULL, default 0
ativa           boolean  default true
UNIQUE (questionario_id, questao_id)
```

### 4.17 `laudos` (8 colunas)
```
id            uuid        PK, uuid_generate_v4()
empresa_id    uuid        NOT NULL, FK empresas ON DELETE CASCADE
ciclo_id      uuid        FK ciclos ON DELETE SET NULL
gerado_por    text        nullable
gerado_em     timestamptz default now()
snapshot_json jsonb       NOT NULL
pdf_url       text        nullable
tenant_id     uuid        FK tenants ON DELETE CASCADE
```

### 4.18 `riscos_config` (9 colunas)
```
id            uuid        PK, gen_random_uuid()
empresa_id    uuid        FK empresas ON DELETE CASCADE
cd_risco      int         NOT NULL
nome          text        NOT NULL
categoria     text        nullable
severidade    int         nullable — CHECK (severidade >= 1 AND severidade <= 4)
consequencias text        nullable
updated_at    timestamptz NOT NULL, default now()
tenant_id     uuid        FK tenants ON DELETE CASCADE
UNIQUE (tenant_id, empresa_id, cd_risco)
```

### 4.19 `planos_config` (8 colunas)
```
plano              text     PK — CHECK IN ('trial','starter','professional','enterprise')
nome_exibicao      text     NOT NULL
valor_mensal_brl   numeric  nullable
max_empresas       int      nullable
max_usuarios       int      nullable
max_respostas_mes  int      nullable
features           jsonb    NOT NULL, default '[]'
ordem              int      NOT NULL, default 0
```

### 4.20 `subscriptions` (14 colunas)
```
id               uuid        PK, gen_random_uuid()
tenant_id        uuid        NOT NULL, FK tenants ON DELETE CASCADE
provider         text        NOT NULL — CHECK IN ('stripe','asaas','manual')
provider_sub_id  text        nullable
plano            text        NOT NULL — CHECK IN ('trial','starter','professional','enterprise')
status           text        NOT NULL, default 'trialing' — CHECK IN ('trialing','active','past_due','canceled','unpaid')
periodo_inicio   timestamptz nullable
periodo_fim      timestamptz nullable
valor_centavos   int         nullable
moeda            text        NOT NULL, default 'BRL'
cancelado_em     timestamptz nullable
motivo_cancel    text        nullable
created_at       timestamptz NOT NULL, default now()
updated_at       timestamptz NOT NULL, default now()
```

### 4.21 `pagamentos` (19 colunas)
```
id                  uuid        PK, gen_random_uuid()
tenant_id           uuid        NOT NULL, FK tenants ON DELETE CASCADE
subscription_id     uuid        FK subscriptions ON DELETE SET NULL
provider            text        NOT NULL — CHECK IN ('stripe','asaas','manual')
provider_payment_id text        nullable
valor_centavos      int         NOT NULL
moeda               text        NOT NULL, default 'BRL'
status              text        NOT NULL, default 'pending' — CHECK IN ('pending','paid','failed','refunded','expired')
metodo              text        nullable
pix_qr_code         text        nullable
pix_qr_code_base64  text        nullable
pix_expira_em       timestamptz nullable
boleto_url          text        nullable
boleto_linha        text        nullable
boleto_expira_em    timestamptz nullable
cartao_ultimos4     text        nullable
cartao_bandeira     text        nullable
pago_em             timestamptz nullable
created_at          timestamptz NOT NULL, default now()
```

### 4.23 `tenant_contadores` (2 colunas — nova, 2026-07-22)
```
tenant_id          uuid  PK, FK tenants ON DELETE CASCADE
contador_empresas  int   NOT NULL, default 0
```
> Contador atômico por tenant para gerar `empresas.numero_cliente` (código curto de referência, ex: `CLI-007`). Usado exclusivamente pelo trigger `fn_atribuir_numero_cliente` (ver 7.3) — nunca acessada diretamente pelo frontend. RLS habilitado **sem nenhuma policy** intencionalmente (nenhum role deveria conseguir ler/escrever direto; `SECURITY DEFINER` do trigger contorna RLS). Isso gera um achado INFO no advisor de segurança (`rls_enabled_no_policy`) que é esperado, não um bug.
>
> **Por que não usar `MAX(numero_cliente)+1`:** `excluirEmpresa()` faz hard delete. Se o número fosse `MAX+1`, excluir a última empresa cadastrada faria a próxima nova empresa reaproveitar o número da excluída — problemático se aquele código já foi comunicado a alguém (ex.: "seu código de cliente é CLI-007"). O contador dedicado garante que o número nunca é reutilizado, mesmo com exclusões.

### 4.22 Views (sem RLS próprio)
```
tenant_usage           — uso atual vs limites do plano por tenant
v_cobertura_questionario — cobertura de questões por fator
v_questoes_empresa     — questões ativas de uma empresa com contexto
v_respostas_admin      — respostas com empresa e ciclo desnormalizados
v_subscription_ativa   — subscription ativa por tenant com dias de trial restantes
```

---

## 5. RLS Policies — PROD (verificado)

RLS habilitado em todas as 21 tabelas. Padrão geral:
- `authenticated` acessa dados do próprio tenant via `get_my_tenant_id()`
- `public`/`anon` acessa apenas o necessário para o formulário (via links ativos)
- `super_admin` tem policies ALL em tudo via `is_super_admin()`
- `cliente_viewer` tem policies RESTRICTIVE `viewer_readonly_*` (UPDATE bloqueado) e `viewer_empresa_select_*` (SELECT limitado à própria empresa)

### ciclos
| Policy | Role | Cmd | Condição |
|--------|------|-----|----------|
| `auth_select_ciclos` | authenticated | SELECT | `tenant_id = get_my_tenant_id()` |
| `auth_insert_ciclos` | authenticated | INSERT | `tenant_id = get_my_tenant_id()` |
| `auth_update_ciclos` | authenticated | UPDATE | `tenant_id = get_my_tenant_id()` |
| `auth_delete_ciclos` | authenticated | DELETE | `tenant_id = get_my_tenant_id() AND is_tenant_admin()` |
| `pub_read_ciclos` | public | SELECT | `id IN (SELECT ciclo_id FROM links_coleta WHERE ativo=true)` |
| `viewer_empresa_select_ciclos` | authenticated | SELECT | role ≠ viewer OR empresa_id = get_my_empresa_id() |
| `viewer_readonly_ciclos` | authenticated | UPDATE | role ≠ cliente_viewer (RESTRICTIVE) |

### empresas
| Policy | Role | Cmd | Condição |
|--------|------|-----|----------|
| `auth_select_empresas` | authenticated | SELECT | `tenant_id = get_my_tenant_id()` |
| `auth_insert_empresa` | authenticated | INSERT | `tenant_id = get_my_tenant_id()` |
| `auth_update_empresa` | authenticated | UPDATE | `tenant_id = get_my_tenant_id() AND (is_tenant_admin() OR criado_por = auth.uid())` |
| `auth_delete_empresa` | authenticated | DELETE | `tenant_id = get_my_tenant_id() AND is_tenant_admin()` |
| `pub_read_empresa_ativa` | public | SELECT | `ativo=true AND id IN (links_coleta ativos)` |
| `viewer_readonly_empresas` | authenticated | UPDATE | role ≠ cliente_viewer (RESTRICTIVE) |

### empresa_setores / empresa_funcoes
| Policy | Role | Cmd | Condição |
|--------|------|-----|----------|
| `auth_manage_*` | authenticated | ALL | `tenant_id = get_my_tenant_id()` |
| `pub_read_*` | public | SELECT | `ativo=true AND empresa_id IN (links ativos)` |
| `viewer_empresa_select_*` | authenticated | SELECT | role ≠ viewer OR empresa_id = get_my_empresa_id() |

### empresa_headcount
| Policy | Role | Cmd | Condição |
|--------|------|-----|----------|
| `auth_select_empresa_headcount` | authenticated | SELECT | `tenant_id = get_my_tenant_id()` |
| `auth_insert_empresa_headcount` | authenticated | INSERT | `tenant_id = get_my_tenant_id()` |
| `auth_update_empresa_headcount` | authenticated | UPDATE | `tenant_id = get_my_tenant_id()` |
| `auth_delete_empresa_headcount` | authenticated | DELETE | `tenant_id = get_my_tenant_id()` |
| `viewer_empresa_select_headcount` | authenticated | SELECT | role ≠ viewer OR empresa_id = get_my_empresa_id() |
| `viewer_readonly_empresa_headcount` | authenticated | UPDATE | role ≠ cliente_viewer (RESTRICTIVE) |

### links_coleta
| Policy | Role | Cmd | Condição |
|--------|------|-----|----------|
| `auth_select_links` | authenticated | SELECT | `tenant_id = get_my_tenant_id()` |
| `auth_insert_links` | authenticated | INSERT | `tenant_id = get_my_tenant_id()` |
| `auth_update_links` | authenticated | UPDATE | `tenant_id = get_my_tenant_id()` |
| `auth_delete_links` | authenticated | DELETE | `tenant_id = get_my_tenant_id()` |
| `links_coleta_tenant_all` | authenticated | ALL | `tenant_id = get_my_tenant_id()` |
| `links_coleta_anon_select` | anon | SELECT | `ativo = true` |
| `pub_read_link` | public | SELECT | `ativo = true` |
| `viewer_empresa_select_links` | authenticated | SELECT | role ≠ viewer OR empresa_id = get_my_empresa_id() |
| `viewer_readonly_links_coleta` | authenticated | UPDATE | role ≠ cliente_viewer (RESTRICTIVE) |

### perfis
| Policy | Role | Cmd | Condição |
|--------|------|-----|----------|
| `perfil_self_select` | authenticated | SELECT | `id = auth.uid()` |
| `perfil_self_update` | authenticated | UPDATE | `id = auth.uid()` WITH CHECK `role = get_my_role()` (não pode mudar próprio role) |
| `admin_tenant_select_perfis` | authenticated | SELECT | `tenant_id = get_my_tenant_id() AND is_tenant_admin()` |
| `admin_tenant_insert_perfis` | authenticated | INSERT | `tenant_id = get_my_tenant_id() AND is_tenant_admin()` |
| `admin_tenant_update_perfis` | authenticated | UPDATE | `tenant_id = get_my_tenant_id() AND is_tenant_admin() AND id ≠ auth.uid()` |
| `admin_tenant_delete_perfis` | authenticated | DELETE | `tenant_id = get_my_tenant_id() AND is_tenant_admin() AND id ≠ auth.uid()` |
| `consultor_select_tenant_perfis` | authenticated | SELECT | `tenant_id = get_my_tenant_id() AND is_tenant_consultor()` |
| `consultor_update_member_perfis` | authenticated | UPDATE | tenant + role ≠ admin + id ≠ auth.uid() + is_tenant_consultor() |
| `perfis_super_admin_all` | authenticated | ALL | `is_super_admin()` |
| `perfis_tenant_select` | authenticated | SELECT | `is_super_admin() OR tenant_id = current_tenant_id()` |
| `perfis_update` | authenticated | UPDATE | admin no tenant OR self |
| `perfis_admin_delete/insert` | authenticated | DELETE/INSERT | admin no tenant |
| `viewer_readonly_perfis` | authenticated | UPDATE | role ≠ cliente_viewer (RESTRICTIVE) |

### respostas
| Policy | Role | Cmd | Condição |
|--------|------|-----|----------|
| `auth_select_respostas` | authenticated | SELECT | `tenant_id = get_my_tenant_id()` |
| `auth_insert_respostas` | authenticated | INSERT | `tenant_id = get_my_tenant_id()` |
| `auth_delete_respostas` | authenticated | DELETE | `tenant_id = get_my_tenant_id() AND is_tenant_admin()` |
| `pub_insert_resposta_validada` | public | INSERT | link ativo + empresa_id bate com link |
| `respostas_tenant_select` | authenticated | SELECT | empresa_id IN (empresas do tenant) |
| `viewer_empresa_select_respostas` | authenticated | SELECT | role ≠ viewer OR empresa_id = get_my_empresa_id() |

### resposta_itens
| Policy | Role | Cmd | Condição |
|--------|------|-----|----------|
| `auth_select_resposta_itens` | authenticated | SELECT | resposta_id → respostas.tenant_id = get_my_tenant_id() |
| `auth_insert_resposta_itens` | authenticated | INSERT | resposta_id → respostas.tenant_id = get_my_tenant_id() |
| `auth_delete_resposta_itens` | authenticated | DELETE | is_tenant_admin() + resposta → tenant correto |
| `resposta_itens_tenant_select` | authenticated | SELECT | resposta_id → empresa → tenant do usuário |

> Sem policy de INSERT para `public`/`anon` em `resposta_itens` — correto, pois só `salvar_resposta` (SECURITY DEFINER) insere.

### respostas_fila
| Policy | Role | Cmd | Condição |
|--------|------|-----|----------|
| `respostas_fila_select_super_admin` | authenticated | SELECT | `is_super_admin()` |

> Apenas super_admin pode ler a fila diretamente. Todo o resto passa pelo RPC.

### respostas_raw_backup
| Policy | Role | Cmd | Condição |
|--------|------|-----|----------|
| `super_admin_select_raw_backup` | public | SELECT | `is_super_admin()` |

> Só super_admin lê. Não há policy de INSERT — correto, inserção só via `salvar_resposta`.
> Policy `raw_backup_select` que vazava dados para qualquer autenticado foi removida em PROD (2026-07-13).

### est_perfil
| Policy | Role | Cmd | Condição |
|--------|------|-----|----------|
| `est_perfil_tenant_rls` | public | ALL | `tenant_id = perfis.tenant_id WHERE id = auth.uid()` |
| `viewer_readonly_est_perfil` | authenticated | UPDATE | role ≠ cliente_viewer (RESTRICTIVE) |

### tenants
| Policy | Role | Cmd | Condição |
|--------|------|-----|----------|
| `tenant_select_own` | authenticated | SELECT | `id = get_my_tenant_id()` |
| `tenant_update_admin` | authenticated | UPDATE | `id = get_my_tenant_id() AND is_tenant_admin()` |
| `tenants_super_admin_all` | authenticated | ALL | `is_super_admin()` |

### questoes / questionarios / questionario_questoes (PROD)
| Policy | Role | Cmd | Condição |
|--------|------|-----|----------|
| `pub_read_*` | public | SELECT | `true` |
| `super_admin_write_*` | authenticated | ALL | `is_super_admin()` |

> **DEV tem falha:** políticas de escrita usam `USING true` — qualquer autenticado pode alterar questões. PROD está correto (só super_admin).

### laudos
CRUD padrão por `tenant_id = get_my_tenant_id()` + is_tenant_admin para DELETE. viewer_empresa_select e viewer_readonly presentes.

### pagamentos / subscriptions / riscos_config / planos_config
- `pagamentos`: só SELECT por tenant
- `subscriptions`: SELECT por tenant + INSERT por admin
- `riscos_config`: ALL por tenant
- `planos_config`: SELECT para todos authenticated; escrita só super_admin

---

## 6. GRANTs (verificado)

### PROD
Todas as tabelas têm GRANTs completos (SELECT, INSERT, UPDATE, DELETE + REFERENCES, TRIGGER, TRUNCATE) para `anon`, `authenticated` e `service_role`. RLS é o único enforcement de acesso.

### DEV — divergências importantes

| Tabela | anon | authenticated |
|--------|------|---------------|
| `ciclos` | REFERENCES/TRIGGER/TRUNCATE apenas | Completo |
| `empresa_funcoes` | + SELECT | Completo |
| `empresa_headcount` | **Completo** (GRANT manual 2026-07-13) | Completo |
| `empresa_setores` | + SELECT | Completo |
| `empresas` | + SELECT | Completo |
| `est_perfil` | REFERENCES/TRIGGER/TRUNCATE apenas | Completo |
| `laudos` | REFERENCES/TRIGGER/TRUNCATE apenas | Completo |
| `links_coleta` | + SELECT | Completo |
| `pagamentos` | REFERENCES/TRIGGER/TRUNCATE apenas | Completo |
| `perfis` | + SELECT | Completo |
| `planos_config` | + SELECT | Completo |
| `questionario_questoes` | + SELECT | Completo |
| `questionarios` | + SELECT | Completo |
| `questoes` | + SELECT | Completo |
| `resposta_itens` | REFERENCES/TRIGGER/TRUNCATE apenas | Completo |
| `respostas` | REFERENCES/TRIGGER/TRUNCATE apenas | Completo |
| `respostas_fila` | REFERENCES/TRIGGER/TRUNCATE apenas | Completo |
| `respostas_raw_backup` | **Completo** (GRANT manual 2026-07-13) | Completo |
| `riscos_config` | REFERENCES/TRIGGER/TRUNCATE apenas | Completo |
| `subscriptions` | REFERENCES/TRIGGER/TRUNCATE apenas | Completo |
| `tenants` | REFERENCES/TRIGGER/TRUNCATE apenas | Completo |

> Em DEV, a maioria das tabelas não tem GRANTs de SELECT/INSERT/UPDATE/DELETE para `anon`. Isso não é problema porque o formulário público usa `salvar_resposta` (SECURITY DEFINER, ignora GRANTs), e o admin usa `authenticated`. Mas difere de PROD onde todos têm tudo (RLS faz o controle).

---

## 7. Funções e RPCs — PROD (verificado)

Todas são SECURITY DEFINER exceto `fn_proteger_ancora` e `set_updated_at`.

### 7.1 Funções callable via RPC

| Função | Argumentos | Retorno | Descrição |
|--------|-----------|---------|-----------|
| `salvar_resposta` | ver assinatura abaixo | `uuid` | Pipeline completo de submissão do formulário |
| `auth_role()` | — | `text` | Role do usuário autenticado |
| `auth_empresa_id()` | — | `uuid` | empresa_id do usuário autenticado |
| `get_my_tenant_id()` | — | `uuid` | tenant_id do usuário logado (usada em RLS) |
| `get_my_empresa_id()` | — | `uuid` | empresa_id do usuário logado (para viewers) |
| `get_my_role()` | — | `text` | role do usuário logado |
| `is_super_admin()` | — | `bool` | boolean — verifica role super_admin |
| `is_tenant_admin()` | — | `bool` | boolean — verifica role admin |
| `is_tenant_consultor()` | — | `bool` | boolean — verifica role consultor (PROD) |
| `current_tenant_id()` | — | `uuid` | alias de get_my_tenant_id |
| `criar_tenant(p_nome, p_slug)` | text, text | `uuid` | Cria novo tenant após convite EST |
| `convidar_membro(p_user_id, p_role)` | uuid, text | `void` | Vincula usuário a um tenant |
| `aplicar_plano_tenant(...)` | uuid, text, text, text, timestamptz | `void` | Aplica plano a um tenant |
| `verificar_limite_tenant(p_tenant_id, p_recurso)` | uuid, text | `jsonb` | Verifica se tenant atingiu limite do plano |
| `reprocessar_fila()` | — | `int4` | Reprocessa itens com status='erro' na fila |
| `super_admin_stats()` | — | `jsonb` | Estatísticas gerais (apenas super_admin) |
| `super_admin_tenant_details()` | — | `record` | Detalhes de tenants (apenas super_admin) |

### 7.2 `salvar_resposta` — função crítica

Existe em **duas versões sobrecarregadas** em PROD:

```sql
-- Versão legada (sem device_info):
salvar_resposta(p_empresa_id, p_ciclo_id, p_link_token, p_setor, p_funcao,
                p_escolaridade, p_itens, p_session_id, p_lgpd_aceito)

-- Versão atual (com device_info):
salvar_resposta(p_empresa_id, p_ciclo_id, p_link_token, p_setor, p_funcao,
                p_escolaridade, p_itens, p_session_id, p_lgpd_aceito, p_device_info)
```

> DEV tem apenas a versão com `p_device_info`.

**Comparação de tipos crítica:**

| Parâmetro | PROD `respostas.session_id` | DEV `respostas.session_id` | Comparação no RPC |
|-----------|----------------------------|---------------------------|-------------------|
| `p_session_id uuid` | `uuid` = comparação direta | `text` = precisa `::text` cast | PROD: `session_id = p_session_id` / DEV: `session_id = p_session_id::text` |

```sql
-- Assinatura completa (versão atual):
SELECT salvar_resposta(
  p_empresa_id   => 'uuid'::uuid,
  p_ciclo_id     => 'uuid'::uuid,         -- nullable
  p_link_token   => 'token',
  p_setor        => 'nome do setor',       -- default '', max 120 chars
  p_funcao       => 'nome da funcao',      -- default '', max 120 chars
  p_escolaridade => 'escolaridade',        -- default '', max 60 chars
  p_itens        => '[{"questao_id":"uuid","valor":3}]'::jsonb,  -- obrigatório, não vazio
  p_session_id   => 'uuid'::uuid,          -- nullable, garante idempotência
  p_lgpd_aceito  => true,                  -- deve ser true
  p_device_info  => 'Mobile | Android | Chrome | 390px'  -- nullable, max 300 chars
);
-- Retorna: uuid da resposta (nova ou existente se session_id já submeteu)
```

### 7.3 Triggers

| Trigger | Tabela | Função | Descrição |
|---------|--------|--------|-----------|
| `handle_new_user` | `auth.users` | `handle_new_user()` | Cria perfil automaticamente ao criar usuário |
| `tg_guard_perfil_update` | `perfis` | `fn_guard_perfil_update()` | Bloqueia alteração do próprio role — **confirmado presente em DEV e PROD** (aplicada via `migration_rbac_viewer_hardening.sql`, item removido da lista de pendências) |
| `fn_proteger_ancora` | `questoes` | `fn_proteger_ancora()` | Protege questões âncora de exclusão |
| `set_updated_at` | Várias | `set_updated_at()` | Atualiza updated_at automaticamente |
| `rls_auto_enable` | (event trigger) | `rls_auto_enable()` | Habilita RLS automaticamente em novas tabelas |
| `trg_numero_cliente` | `empresas` | `fn_atribuir_numero_cliente()` | **Nova (2026-07-22).** `BEFORE INSERT`, só dispara quando `numero_cliente IS NULL`. Atribui o próximo número via `tenant_contadores` (UPSERT atômico). Se `NEW.tenant_id IS NULL` (linhas legadas sem tenant), não atribui número — evita violar a PK de `tenant_contadores`. `SECURITY DEFINER`, mas `REVOKE EXECUTE ... FROM PUBLIC, anon, authenticated` aplicado explicitamente — funções `RETURNS trigger` são naturalmente não-invocáveis fora de um trigger real, mas o Postgres concede `EXECUTE` a `PUBLIC` por padrão em toda função nova, o que apareceria como achado no advisor de segurança (`anon/authenticated_security_definer_function_executable`) se não fosse revogado. |

---

## 8. Edge Functions

| Function | Endpoint PROD | Endpoint DEV |
|----------|--------------|-------------|
| `convidar-est` | `https://vftyiildukrpgmnbcnao.supabase.co/functions/v1/convidar-est` | `https://szqatgvgghxvyyncsjxl.supabase.co/functions/v1/convidar-est` |

Requer JWT de `super_admin`. Verifica role via `auth_role()` RPC.

---

## 9. Pipeline de Respostas — Fluxo Detalhado

```
pseg-forms.html → supabase.rpc('salvar_resposta', params)
  │
  ├─ Validações iniciais: empresa_id ≠ null, link_token ≠ '', itens ≠ [], lgpd_aceito = true
  ├─ Trunca campos: setor(120), funcao(120), escolaridade(60), device_info(300)
  │
  ├─ [1] INSERT respostas_raw_backup  ← backup antes de validar o link
  │
  ├─ Valida link: SELECT FROM links_coleta WHERE token = p_link_token
  │              → RAISE se nulo, inativo ou expirado
  │
  ├─ [2] Checagem idempotência: pg_advisory_xact_lock + SELECT FROM respostas WHERE session_id = ...
  │       → se já existe: RETURN resposta_id existente (sem inserir nada)
  │
  ├─ [3] INSERT respostas_fila (status='pendente')
  ├─ [4] INSERT respostas
  ├─ [5] INSERT resposta_itens (um por questão, filtra valor 1-4 e questao_id não nulo)
  ├─ [6] UPDATE respostas_fila (status='processado')
  │
  └─ EXCEPTION: UPDATE respostas_fila (status='erro', erro_msg=SQLERRM) + RAISE
```

Toda a sequência é **uma transação**. Falha em qualquer etapa = rollback de tudo, incluindo o raw_backup.

---

## 10. Hierarquia de Usuários e RBAC

```
super_admin  → tenant_id = NULL, empresa_id = NULL  — acesso total cross-tenant
admin        → tenant_id = <EST>, empresa_id = NULL  — gerencia toda a EST
consultor    → tenant_id = <EST>, empresa_id = NULL  — coleta + análise
cliente_viewer → tenant_id = <EST>, empresa_id = <ID>  — leitura de 1 empresa
```

`cliente_viewer` DEVE ter `empresa_id` preenchido — sem ele não vê dados nas telas de análise.

### Menus por role

| Tela | super_admin | admin | consultor | cliente_viewer |
|------|-------------|-------|-----------|----------------|
| dashboard | ✅ | ✅ | ✅ | ✅ |
| empresas (clientes) | ✅ | ✅ | ✅ | ❌ |
| links de coleta | ✅ | ✅ | ✅ | ✅ |
| análise / gráficos / comparativo / auditoria | ✅ | ✅ | ✅ | ✅ |
| laudo (relatório) | ✅ | ✅ | ✅ | ✅ |
| plano de ação | ✅ | ✅ | ❌ | ❌ |
| usuários (equipe) | ✅ | ✅ | ❌ | ❌ |
| riscos / est-perfil / assinatura | ✅ | ✅ | ❌ | ❌ |
| gestao-ests | ✅ | ❌ | ❌ | ❌ |

---

## 11. GHE — Gestão de Setores, Funções e Headcount

Tela de tela cheia (96vw × 92vh) para consultores cadastrarem a estrutura organizacional.

### Fluxo de import de planilha

1. Detecta coluna de setor por sinônimos: `setor`, `depto`, `área`, `lotação`, `centro de custo`, `estabelecimento`, `local de trabalho`, `filial`
2. Cargos sem setor reconhecido → "Universais" (`setor_id = NULL`)
3. Salva: (1) setores, (2) funções com setor_id resolvido, (3) headcount

### Funções principais no frontend

| Função | Descrição |
|--------|-----------|
| `abrirModalGHE(empresaId)` | Guard contra `null` ou string `"null"` |
| `salvarGHE()` | Snapshot `empId/tenantId` no início (evita race condition) |
| `carregarAdesaoGHE(empresaId, cicloId)` | Chama `calcRepresentatividade`, popula painel |
| `calcRepresentatividade(empId, cicloId?)` | Cruza `empresa_headcount` × `respostas`; cicloId opcional |
| `_gheNorm(s)` | trim + lowercase + collapse spaces |
| `_gheCorAdesao(pct)` | ≥70% verde / 30-69% âmbar / <30% vermelho |

### Salvaguardas implementadas

- Guard nulo em `abrirModalGHE`, `mudarEmpresaGHE`, `salvarGHE` (garante empresa_id real)
- Wipe safeguard 1 (2026-07-22): bloqueia `salvarGHE()` **sem opção de confirmar** quando a estrutura atual está totalmente vazia (nem setor nem cargo) e já existe catálogo no banco — evita apagar tudo com "sucesso" falso na tela quando a coluna do arquivo não é reconhecida
- Wipe safeguard 2 (pré-existente): quando setores vêm vazios mas cargos existem (tudo cairia em "universal"), pede confirmação antes de substituir
- Race condition: captura `empId = _gheEmpresaId` antes dos awaits assíncronos
- Erro de headcount: lança exception visível (não engole silenciosamente)
- `_parseGHECSV` (2026-07-22): parser char-a-char respeitando aspas (RFC4180-like) — antes fazia `split()` ingênuo por delimitador, corrompendo linhas silenciosamente quando um valor de setor/cargo continha o próprio delimitador entre aspas. Só afetava `.csv`; `.xlsx`/`.xls` sempre usou `XLSX.utils.sheet_to_json`, que já tratava aspas corretamente
- `_gheImportCargoSetor` (2026-07-22): mapa cargo→setor **mudou de 1:1 para 1:N** (`Set` de setores). Antes, um cargo genérico existindo em vários setores da planilha (ex: "Aprendiz Administrativo" em 14 setores) só ficava vinculado ao ÚLTIMO setor lido — cada linha nova sobrescrevia a anterior no mapa. Ver seção 17 (22/07) para o caso real que expôs o bug

### Investigação de GAP de importação (2026-07-22)

Cliente reportou setores/cargos importados não aparecendo no formulário. Comparação exata (planilha original × banco) confirmou:
- **Setores: sempre 100% corretos.** Nenhuma perda de setor foi encontrada em nenhuma empresa auditada.
- **Cargos: perda real**, causada pelo bug do `_gheImportCargoSetor` acima — cargos que se repetem em múltiplos setores na planilha só chegavam a UM setor no banco.
- **Não existe agrupamento automático** ("agrupamento de setores") durante import — o campo `grupo` de `empresa_setores` só é preenchido manualmente ou via botão opt-in "Sugerir grupos" (`_gheSugerirGrupos`), nunca automaticamente no fluxo de import.

**Metodologia de auditoria** (reaproveitável para futuras investigações de gap): extrair pares únicos `(setor, cargo)` da planilha original via `openpyxl` em Python, comparar com `SELECT es.nome, ef.nome FROM empresa_setores es LEFT JOIN empresa_funcoes ef ON ef.setor_id=es.id WHERE es.empresa_id=...` no banco — diff de conjuntos revela exatamente o que falta, sem depender de contagem de linhas (que sempre diverge, já que a planilha tem 1 linha por funcionário e o catálogo é deduplicado).

**Empresas com dados incompletos no banco no momento da correção** (precisam reimportar a planilha original para corrigir os cargos que faltam, já que o bug era write-time, não corrompeu o que já foi salvo corretamente):
- **Udinese** — 71 pares setor-cargo faltando (de 200)
- **Assa Abloy (Shared Services)** — 15 pares faltando (de 163), incluindo "Suporte Tecnico a Vendas" totalmente sem cargo
- **ELEVA IT CONSULTORIA** — caso mais severo, não relacionado a este bug: `empresa_setores`/`empresa_funcoes` zerados por completo (ver seção 17, pendência antiga desde 14/07, agravada por um wipe total sem aviso corrigido pela salvaguarda 1 acima)

---

## 12. Consultas SQL de Referência

### 12.1 Saúde geral

```sql
SELECT 'tenants'              AS tabela, COUNT(*) AS n FROM tenants
UNION ALL SELECT 'empresas',             COUNT(*) FROM empresas
UNION ALL SELECT 'perfis',               COUNT(*) FROM perfis
UNION ALL SELECT 'links_coleta',         COUNT(*) FROM links_coleta
UNION ALL SELECT 'respostas',            COUNT(*) FROM respostas
UNION ALL SELECT 'resposta_itens',       COUNT(*) FROM resposta_itens
UNION ALL SELECT 'respostas_fila',       COUNT(*) FROM respostas_fila
UNION ALL SELECT 'respostas_raw_backup', COUNT(*) FROM respostas_raw_backup
UNION ALL SELECT 'empresa_setores',      COUNT(*) FROM empresa_setores
UNION ALL SELECT 'empresa_funcoes',      COUNT(*) FROM empresa_funcoes
UNION ALL SELECT 'empresa_headcount',    COUNT(*) FROM empresa_headcount
ORDER BY tabela;
```

```sql
-- Status da fila
SELECT status, COUNT(*), MAX(criado_em) AS ultimo FROM respostas_fila GROUP BY status;

-- Respostas com erro
SELECT id, empresa_id, link_token, erro_msg, tentativas FROM respostas_fila WHERE status='erro';

-- Respostas sem itens (deve ser zero)
SELECT id, respondido_em, setor FROM respostas
WHERE NOT EXISTS (SELECT 1 FROM resposta_itens ri WHERE ri.resposta_id = respostas.id);

-- Duplicatas por session_id (deve ser zero)
SELECT session_id::text, COUNT(*) FROM respostas
WHERE session_id IS NOT NULL GROUP BY session_id::text HAVING COUNT(*) > 1;
```

### 12.2 Validação pré-deploy (mínimo obrigatório)

```sql
-- 1. Confirmar tipo de session_id (PROD=uuid, DEV=text)
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_name='respostas' AND column_name='session_id';

-- 2. Confirmar nome da coluna timestamp em respostas_raw_backup (PROD=gravado_em, DEV=criado_em)
SELECT column_name FROM information_schema.columns
WHERE table_name='respostas_raw_backup' AND column_name IN ('gravado_em','criado_em');

-- 3. GRANTs das tabelas críticas
SELECT grantee, table_name, string_agg(privilege_type,', ') AS priv
FROM information_schema.role_table_grants
WHERE table_name IN ('respostas','resposta_itens','respostas_fila',
                     'respostas_raw_backup','empresa_headcount')
  AND grantee IN ('authenticated','anon')
GROUP BY grantee, table_name ORDER BY table_name, grantee;

-- 4. Verificar definição do RPC (cast correto de session_id)
SELECT pg_get_functiondef(oid) FROM pg_proc
WHERE proname='salvar_resposta' ORDER BY oid DESC LIMIT 1;
```

### 12.3 Respostas

```sql
-- Todas as respostas (últimas primeiro)
SELECT r.id, e.razao_social AS empresa, r.setor, r.funcao, r.escolaridade,
       r.respondido_em AT TIME ZONE 'America/Sao_Paulo' AS respondido_brt,
       r.device_info, r.lgpd_aceito,
       (SELECT COUNT(*) FROM resposta_itens ri WHERE ri.resposta_id=r.id) AS itens
FROM respostas r LEFT JOIN empresas e ON e.id=r.empresa_id
ORDER BY r.respondido_em DESC;
```

```sql
-- Média por questão de uma empresa
SELECT q.codigo, q.texto, ROUND(AVG(ri.valor),2) AS media, COUNT(*) AS n
FROM resposta_itens ri
JOIN questoes q ON q.id=ri.questao_id
JOIN respostas r ON r.id=ri.resposta_id
JOIN empresas e ON e.id=r.empresa_id
WHERE e.razao_social ILIKE '%nome%'
GROUP BY q.id, q.codigo, q.texto, q.ordem ORDER BY q.ordem;
```

### 12.4 GHE e headcount

```sql
-- Estrutura de setores e funções
SELECT es.nome AS setor, ef.nome AS funcao, ef.setor_id IS NULL AS universal
FROM empresa_setores es
LEFT JOIN empresa_funcoes ef ON ef.setor_id=es.id
WHERE es.empresa_id='uuid' ORDER BY es.nome, ef.nome;

-- Headcount cadastrado
SELECT setor, COALESCE(funcao,'(total)') AS funcao, quantidade
FROM empresa_headcount WHERE empresa_id='uuid' ORDER BY setor, funcao;
```

### 12.5 Links de coleta

```sql
SELECT l.token, e.razao_social, l.ativo,
       l.expira_em AT TIME ZONE 'America/Sao_Paulo' AS expira_brt,
       COUNT(r.id) AS respostas
FROM links_coleta l
LEFT JOIN empresas e ON e.id=l.empresa_id
LEFT JOIN respostas r ON r.link_token=l.token
GROUP BY l.id, l.token, e.razao_social, l.ativo, l.expira_em
ORDER BY l.criado_em DESC;
```

---

## 13. Migrations Aplicadas

| Migration | DEV | PROD | Descrição |
|-----------|-----|------|-----------|
| `migration_empresa_headcount.sql` | ✅ | ✅ | Tabela headcount + RLS |
| `migration_fix_empresa_funcoes_unique.sql` | ✅ | ✅ | UNIQUE por (empresa_id, setor_id, nome) |
| `migration_fix_grants_dev.sql` | ✅ | N/A | GRANTs para empresa_headcount e respostas_raw_backup em DEV |
| `migration_rbac_viewer_hardening.sql` | ✅ | ✅ **confirmado 2026-07-22** | Trigger `tg_guard_perfil_update` + 7 policies viewer RESTRICTIVE |
| `migration_sync_est_perfil_prod.sql` | N/A | ✅ **aplicada 2026-07-20** | Colunas cor_primaria, nome_responsavel, email_responsavel em est_perfil |
| `migration_links_multi_resposta.sql` | ✅ | ✅ **2026-07-21** | `links_coleta.permite_multi_resposta` — trava de dispositivo opcional por link |
| `migration_empresas_numero_cliente.sql` | ✅ | ✅ **2026-07-22** | `empresas.numero_cliente` + tabela `tenant_contadores` + trigger `trg_numero_cliente` |
| `migration_ciclos_referencia_temporal.sql` | ✅ | ✅ **2026-07-22** | `ciclos.ano_referencia/mes_referencia/tipo_ciclo/referencia_estimada` + backfill |

---

## 14. Pendências Abertas

| Item | Ambiente | Prioridade | Observação |
|------|----------|-----------|------------|
| Merge PR develop→main | GitHub | **Urgente** | 5 commits acumulados em develop (fix 1:N GHE, fix orphan headcount, fix salvaguarda 1, sorting formulário, doc). PR manual em `https://github.com/elevaitconsultoria/pseg-safesign/compare/main...develop` |
| Reimportar Assa Abloy (Shared Services) | PROD | Alta | `empresa_id=5453fd8f-8da2-4296-b821-0fe3b01e0362` — catálogo zerado (0 setores/0 cargos/0 headcount). Reimportar planilha pelo admin e validar com `/validar-importacao-ghe` |
| Reimportar ELEVA IT CONSULTORIA | PROD | Média | Catálogo zerado — wipe acidental sem soft-delete, sem recuperação. Reimportar quando disponível planilha atualizada |
| Case mismatch no headcount | PROD | Baixa | "Tecnologia da Informacao" (sem acento, minúsculo) vs "TECNOLOGIA DA INFORMACAO" (maiúsculo) em 2 registros de `empresa_headcount` (Silvana Campina Grande e Treinamento - Udinese). Opções: (1) UPDATE strings ou (2) tornar `calcRepresentatividade()` case-insensitive |
| Alinhar policies escrita DEV | DEV | Média | `questoes/questionarios/questionario_questoes`: DEV permite qualquer autenticado escrever; PROD só super_admin — divergência de segurança |
| Teste e2e onboarding nova EST | DEV | Produto | Fluxo não validado desde implementação |

> **Resolvido 2026-07-23:** Udinese reimportada e validada — 200/200 pares, 100% match com planilha (skill `/validar-importacao-ghe`).  
> As migrations `migration_rbac_viewer_hardening.sql` e `migration_sync_est_perfil_prod.sql` foram confirmadas aplicadas em PROD (2026-07-22) — removidas desta lista.

---

## 15. Erros Conhecidos e Soluções

| Erro | Causa | Solução |
|------|-------|---------|
| `operator does not exist: text = uuid` | `session_id` é `text` (DEV), RPC sem cast | `WHERE session_id = p_session_id::text` |
| `operator does not exist: uuid = text` | `session_id` é `uuid` (PROD), cast errado | Remover `::text` |
| `resposta salva localmente` (frontend) | Falha silenciosa no RPC | Verificar console do browser; erro real estará lá |
| `permission denied for table X` | GRANT ausente (tabela criada via SQL direto) | `GRANT SELECT,INSERT,UPDATE,DELETE ON X TO authenticated,anon` |
| `null value in column "empresa_id"` | Template literal `'${emp.id}'` gera string "null" | Guard: `if (!empresaId \|\| empresaId === 'null')` |
| `duplicate key violates unique constraint empresa_funcoes_empresa_id_nome_key` | Constraint antigo ainda ativo | Verificar se migration foi aplicada: `UNIQUE(empresa_id, setor_id, nome)` |
| `column "criado_em" does not exist` (em respostas_raw_backup em PROD) | PROD tem `gravado_em`, não `criado_em` | Usar `gravado_em` em PROD |
| Cargos todos como universais após import | Coluna de setor não reconhecida na planilha | Cabeçalho deve ter: setor, depto, área, lotação, etc. |
| Toggle/checkbox custom "não responde ao clique" (liga e desliga sozinho) | `onclick` no `<label>` que envolve um `<input>` — 1 clique físico gera 2 eventos (o real + o reenvio nativo do navegador pro input associado) | Nunca colocar a lógica de toggle no `onclick` do label; usar `onchange` do `<input>` (dispara 1x por interação real) |
| Campo recém-criado via `insert()` "some" da UI até recarregar a página | `.select()` de retorno do insert não incluía o campo novo, e/ou o objeto local (array em memória) não foi atualizado com ele | Sempre incluir TODOS os campos novos no `.select()` pós-insert e atualizar o objeto local imediatamente, não só o banco |
| Import GHE: cargo genérico (ex: "Aprendiz Administrativo") aparece só em 1 setor no banco, mas existe em vários na planilha | `_gheImportCargoSetor` era um mapa 1:1 (cargo→setor); cada linha nova com o mesmo cargo sobrescrevia a anterior | Corrigido 22/07: mapa agora é cargo→`Set` de setores. Empresas importadas antes disso precisam reimportar a planilha |
| Import GHE: linha de setor/cargo corrompida silenciosamente (colunas deslocadas) num arquivo `.csv` | `_parseGHECSV` fazia `split()` ingênuo por delimitador; um valor entre aspas contendo o próprio delimitador (ex: `"Produção, Turno A"`) quebrava o alinhamento das colunas seguintes | Corrigido 22/07: parser char-a-char respeitando aspas. Só afetava `.csv` — `.xlsx`/`.xls` sempre foi seguro |
| Import GHE apaga catálogo inteiro de setores/cargos com toast de "sucesso" | `salvarGHE()` sempre fazia DELETE antes de INSERT; se a estrutura vinda do import estivesse totalmente vazia (nem setor nem cargo — arquivo errado, coluna não reconhecida), nada era reinserido depois do DELETE | Corrigido 22/07: nova salvaguarda bloqueia o save (sem opção de confirmar) quando tudo vem vazio e já existe catálogo — mostra aviso em vez de apagar. Sem soft-delete, dados apagados antes desta correção não são recuperáveis (caso real: ELEVA IT CONSULTORIA) |

---

## 16. Skills Disponíveis

| Skill | Arquivo | Acionar quando |
|-------|---------|---------------|
| `/validar-formulario` | `.claude/skills/validar-formulario/SKILL.md` | Qualquer mudança em `salvar_resposta`, `respostas_*`, antes de merge develop→main, deploy PROD, erros `operator does not exist` / `permission denied` |
| `/validar-importacao-ghe` | `.claude/skills/validar-importacao-ghe/SKILL.md` | Planilha de cliente anexada, GAP de setor/cargo reportado, antes de enviar laudo, após reimportar planilha |

`/validar-formulario` contém checklist de 8 passos para validar o pipeline de respostas. `/validar-importacao-ghe` extrai pares (setor, cargo, qtd) da planilha via Python/openpyxl, compara contra `empresa_setores`/`empresa_funcoes`/`empresa_headcount` no banco, e gera relatório tabular de GAPs.

---

## 16.5 Fragilidades Arquiteturais Conhecidas

Mapeadas na análise completa de 2026-07-23. Não são bugs ativos — são riscos latentes a considerar antes de mudanças nessas áreas.

| # | Fragilidade | Risco | Área |
|---|-------------|-------|------|
| 1 | **Textos de questões hardcoded em dois lugares independentes** — `QS_OFICIAIS` (admin, ln ~3989) e `BLOCOS` (forms, ln ~30). A tabela `questoes.texto` existe mas o admin não a consome para exibição. Uma atualização de texto que toque só um arquivo cria versões inconsistentes. | Alto — incidente real em 2026-07-20 (hotfix em `main` sem voltar para `develop`) | pseg-admin-questionario.html + pseg-forms.html |
| 2 | **Credenciais PROD hardcoded em `pseg-forms.html`** (linhas 332–333: URL e JWT anon). O `build.js` substitui via regex — se o código ao redor mudar, o regex falha silenciosamente e o build DEV usa credenciais PROD. O admin usa placeholders seguros (`__SUPA_URL__`); o forms não. | Médio — falha silenciosa, sem erro visível | pseg-forms.html, build.js |
| 3 | **Sem soft-delete** — hard delete em `empresas`, `links_coleta`, `riscos_config`. Sem `deleted_at` ou lixeira. | Médio — caso real: ELEVA IT CONSULTORIA (dados irrecuperáveis após wipe) | pseg-admin-questionario.html ln ~4996 |
| 4 | **Cache de respostas sem TTL** — `_respostasCache` é um objeto em memória. `limparCacheRespostas()` é chamado manualmente em alguns pontos, mas não há invalidação automática. Dados ficam stale até reload manual enquanto colaboradores respondem. | Baixo-Médio | pseg-admin-questionario.html ln ~7569 |
| 5 | **Realtime parcial** — ativo apenas para contagem de `respostas` em `sc-links`. Análise, comparativo, GHE e dashboard são estáticos por sessão até navegação manual. | Baixo | pseg-admin-questionario.html ln ~6913 |
| 6 | **`window._analiseData` como estado global** — dependência implícita de ordem de execução; não há verificação de `!= null` uniforme antes de usar. | Baixo | pseg-admin-questionario.html |
| 7 | **Sem SRI em CDNs** — nenhuma lib CDN (Chart.js, jsPDF, html2canvas, xlsx, qrcodejs) usa hash `integrity`. | Baixo (segurança supply-chain) | ambos HTMLs |
| 8 | **Rate limiting apenas no frontend** — `_RATE_LIMIT_MS = 15000` (forms, ln 825) pode ser contornado por cliente que ignore o JS. Sem throttle no RPC `salvar_resposta` nem no Supabase/Cloudflare. | Baixo | pseg-forms.html |
| 9 | **Três blocos `<script>` no admin** — constantes do bloco 1 são usadas por funções do bloco 4. A ordem de execução é top-down e funciona, mas cria dependência frágil de posicionamento. | Baixo | pseg-admin-questionario.html |
| 10 | **Validação de limite de plano casuística** — `verificarLimiteTenant()` é chamada em alguns pontos de criação mas não em todos. Sem tela/modal padrão de "limite atingido". | Baixo-Médio (produto) | pseg-admin-questionario.html |

---

## 17. Changelog — Sessões de Trabalho (cronológico)

Fluxo de trabalho padrão do projeto: alterações de schema sempre em DEV primeiro → validar → PROD. Deploy de frontend via push em `develop`/`main` no Cloudflare Pages (branch `main` = produção). Toda mudança de banco vira uma migration versionada (`migration_*.sql`) na raiz do repo, mesmo depois de aplicada — funciona como changelog de schema.

### 2026-07-13 — Ciclo hierarquia organizacional / GHE tela cheia
Validação profunda de setores/funções/headcount + integração formulários + redesenho UX da tela GHE (modal → tela cheia 96vw×92vh com toggle Árvore/Tabela). Guard contra `empresa_id`/`tenant_id` nulo em `salvarGHE`, salvaguarda contra wipe de setores no import. Auditoria de segurança RLS: removida policy `raw_backup_select` que vazava payload bruto de respostas entre tenants (crítico, só existia em PROD); corrigido INSERT sem escopo em `resposta_itens`. Constraint de `empresa_funcoes` alterado de `UNIQUE(empresa_id, nome)` para `UNIQUE(empresa_id, setor_id, nome)` — permite mesmo cargo em setores diferentes.

### 2026-07-14 — Correção crítica do pipeline de respostas
`salvar_resposta` recebia `p_session_id uuid` e comparava sem cast — quebrava em DEV, onde `session_id` era `text`. Corrigido com `::text` só em DEV (PROD já era `uuid`, nunca esteve quebrado). Criada a skill `/validar-formulario`.

### 2026-07-20 — `est_perfil` sincronizado
`migration_sync_est_perfil_prod.sql` aplicada em PROD — colunas `cor_primaria`, `nome_responsavel`, `email_responsavel`, antes só em DEV.

### 2026-07-20/21 — Revisão de texto das 27 questões (NR-01) + descoberta de hotfix paralelo
Documento da Diretoria trouxe redação revisada de 25 das 27 questões oficiais. Durante o merge `develop→main`, descoberto que um hotfix anterior (`e554358`, 06/07) já havia reformulado 10 dessas mesmas questões direto em `main`, sem nunca voltar para `develop` — gerou conflito real de merge. Por decisão do usuário, a revisão da Diretoria prevaleceu. Resolvido manualmente preservando as demais mudanças de `main` (renomeação de âncoras "Ideal→Adequado", "Crítico→Elevado"). Corrigido também Q18, que estava categorizada no bloco temático errado (Relações Interpessoais → Fatores Organizacionais).
**Lição:** textos de questão em `pseg-admin-questionario.html` (`QS_OFICIAIS`) e `pseg-forms.html` (`BLOCOS`) são hardcoded em dois lugares independentes — nenhuma mudança de texto é lida do banco (`questoes.texto` existe mas não é consumido pelo admin, só serve de índice de UUID). Renomear questão hoje é seguro (não quebra vínculo com respostas, que são só `questao_id`+`valor`), mas precisa editar os dois arquivos e nunca só um.

### 2026-07-21 — Flag "multi-resposta" por link + série de bugs de UI encontrados e corrigidos
Implementada a flag `permite_multi_resposta` (ver 4.6) para liberar a trava de 1-resposta-por-dispositivo em notebooks compartilhados. Durante testes reais do usuário, três bugs reais foram encontrados e corrigidos na mesma sessão:
1. **Toggles (checkbox custom) não respondiam ao clique** — causa raiz: `onclick` no `<label>` que envolve o `<input>` causava DOIS eventos de clique por clique físico (o clique real + o reenvio nativo do navegador pro input associado, que bubbleia de volta pelo label), fazendo `classList.toggle()` cancelar a si mesmo. Afetava os 4 toggles do sistema, incluindo um bug pré-existente em "Questão inversa" não relacionado a esta feature. Fix: lógica movida do `onclick` do label para o `onchange` do input.
2. **Modal "Novo link" não herdava a empresa ativa/filtrada** — `abrirModalLink()` nunca sincronizava `nl-empresa` com `link-f-empresa` (filtro da tela) ou `_empresaAtiva` (estado global), sempre resetando pra "Selecione...". Gerava links pro cliente errado sem o usuário perceber.
3. **Botão "Salvar" do modal de empresa travava permanentemente após o 1º uso** — `salvarPerfilCliente()` setava `disabled=true` antes do save mas só revertia no `catch` (erro); no caminho de sucesso o botão ficava travado até recarregar a página inteira. Bug secundário junto: `textContent` apagava o ícone SVG do botão.

Padrão identificado nesta sessão, relevante para código futuro: **sempre incluir os campos novos no `.select()` de retorno de um `insert()`**, e atualizar o objeto local imediatamente — bugs de "campo sumiu até recarregar a página" (badge de link de teste, e o padrão que motivou a checagem no fix de multi-resposta) vêm de esquecer isso.

### 2026-07-22 — Lista de clientes + código curto, referência temporal de ciclos
1. **Tela "Clientes" — visualização em lista + código curto** (`CLI-001`, `CLI-002`...): grade de cards ficava difícil de escanear com muitos clientes. Adicionado toggle Grade/Lista (reaproveitando `.seg-toggle-group`, mesmo componente já usado no toggle da Análise), busca por nome/CNPJ em tempo real, e código sequencial por tenant via contador dedicado (`tenant_contadores`, ver 4.23) — nunca reaproveitado mesmo com exclusão de cliente (hard delete confirmado).
2. **Ciclos — referência temporal estruturada**: campo `nome` livre (misturava "2026", "julho/2026", "1ª avaliação") substituído por selects de Mês/Ano obrigatórios na criação, com `nome` gerado automaticamente. Campo `tipo_ciclo` opcional, editável a qualquer momento via select inline (não existia nenhum fluxo de edição de ciclo antes — só criar/excluir). Corrigido bug real de ordenação: Comparativo entre Ciclos e o filtro de ciclo ordenavam por `criado_em` quando `data_inicio` estava vazio, misturando ordem de criação com ordem de período.
3. Criado checkpoint git (`checkpoint-antes-ciclos-ref-temporal`, tag no commit `3b38c3b`) antes da feature de ciclos, para rollback fácil se necessário.
4. Ambas migrations aplicadas e validadas em DEV antes de PROD, seguindo o fluxo padrão. Achado de segurança corrigido: `fn_atribuir_numero_cliente` (função de trigger) ficava exposta como RPC público por padrão do Postgres (`EXECUTE` concedido a `PUBLIC` em toda função nova) — `REVOKE` aplicado explicitamente nos dois bancos.

### 2026-07-22 (continuação) — Investigação e correção do GAP de importação GHE
Usuário reportou setores/cargos importados não aparecendo completos no formulário, e enviou as planilhas originais de Udinese e Assa Abloy (Shared Services) para conferência. Metodologia: extrair pares únicos `(setor, cargo)` da planilha via Python/openpyxl e comparar por diff de conjuntos contra o banco (ver seção 11 para a query). Resultado: setores sempre 100% corretos; **não existe agrupamento automático** de setores no import (hipótese inicial do usuário, descartada — `grupo` só é preenchido manualmente ou via botão opt-in "Sugerir grupos"). Três bugs reais encontrados e corrigidos no pipeline de import (`pseg-admin-questionario.html`, funções `_processarGHEImport`/`confirmarGHEImport`/`salvarGHE`/`_parseGHECSV`):

1. **Bug principal, explica o GAP reportado**: `_gheImportCargoSetor` era um mapa 1:1 cargo→setor; um cargo genérico existindo em vários setores na planilha (ex: "Aprendiz Administrativo" em 14 setores da Udinese) só ficava vinculado ao ÚLTIMO setor lido — cada linha nova sobrescrevia a anterior. Fix: mapa virou cargo→`Set` de setores. Validado reprocessando os 464 funcionários reais da planilha da Udinese pelo pipeline corrigido: resultado bateu exatamente 200/200 pares esperados (contra 129 que estavam no banco).
2. **Achado durante a mesma investigação, não relacionado ao GAP reportado mas com o mesmo padrão de risco**: `salvarGHE()` sempre fazia DELETE incondicional de `empresa_setores`/`empresa_funcoes` antes de reinserir; se a estrutura do import viesse totalmente vazia (nem setor nem cargo — arquivo errado, coluna não reconhecida), nada era reinserido depois do delete, e a tela mostrava "GHE salvo com sucesso!" — falso positivo. Isso explica por que **ELEVA IT CONSULTORIA** tinha `empresa_funcoes` zerado (antes eram 98 cargos "universais", já um problema conhecido desde 14/07 — algo apagou até isso). Fix: nova salvaguarda bloqueia o save (sem opção de confirmar, diferente da salvaguarda parcial já existente) quando tudo vem vazio e já existe catálogo no banco.
3. **`_parseGHECSV` reescrito** com parser char-a-char respeitando aspas — o `split()` ingênuo por delimitador quebrava silenciosamente o alinhamento de colunas quando um valor continha o próprio delimitador entre aspas. Só afetava `.csv`.

**Pendência real deixada**: Udinese e Assa Abloy (Shared Services) precisam ser **reimportadas** — o bug era write-time (corrompia o que era salvo), não fez os dados já salvos ficarem inconsistentes de outra forma, mas os dados já salvos continuam incompletos até rodar o import de novo com o código corrigido. ELEVA IT também precisa de reimport (pendência antiga, sem dado pra recuperar — sem soft-delete).

### 2026-07-23 — Análise completa do código + validação Udinese + documentação

1. **Nova skill `/validar-importacao-ghe`** (`.claude/skills/validar-importacao-ghe/SKILL.md`): pipeline completo de confronto planilha × banco. Extrai pares (setor, cargo, qtd) via Python/openpyxl, compara contra as 3 tabelas GHE, gera relatório tabular de GAPs. Cobre o cenário que causou o bug de Udinese/Assa Abloy e tem armadilhas conhecidas documentadas.

2. **Bug: `empresa_headcount` ficava órfão ao limpar catálogo** — `salvarGHE()` só deletava `empresa_headcount` quando `_gheImportHeadcount.length > 0`. Limpar catálogo sem reimportar deixava headcount antigo intacto (caso real: "207 func." com "0 setores / 0 cargos"). Fix: `else if (setorNomes.length === 0 && todosCargos.length === 0)` força DELETE mesmo sem novo import. Limpeza: 335 linhas órfãs deletadas em PROD (172 ELEVA IT + 163 Assa Abloy Shared Services).

3. **Bug: Salvaguarda 1 de `salvarGHE()` bloqueava limpeza intencional** — hard-block sem escape hatch para ações legítimas (trocar planilha, resetar empresa). Fix: substituído por `confirm()` com texto explicativo. Usuário pode cancelar (preserva) ou confirmar (apaga).

4. **Ordenação alfabética no formulário público** — setores e cargos passam a ser ordenados por `localeCompare('pt-BR')` em `carregarGHEEmpresa()` e `popularMetaFuncao()`. "Outro" sempre inserido por último, fora do sort.

5. **Validação Udinese 100% confirmada** — após reimport, skill `/validar-importacao-ghe` rodada com a planilha original: 200/200 pares, 0 GAP, 0 QTD diverge. Udinese liberada para entrega ao cliente.

6. **Análise técnica completa do codebase** — leitura integral de `pseg-admin-questionario.html` (14.523 linhas), `pseg-forms.html` (1.152 linhas), 25 migrations, build.js, 3 skills. Resultado documentado em seção 16.5 (fragilidades) e em `PSEG_SAFESIGN_REFERENCIA_PROJETO.md` (novo).

7. **Criação de `CLAUDE.md`** na raiz do projeto — contexto de negócio, regras críticas, arquitetura, divergências DEV/PROD, convenções. Primeiro arquivo para onboarding de agentes.

8. **Criação de `.claude/notes/2026-07-23-resumo.md`** — changelog desta sessão com decisões e porquê.
