# PSEG SafeSign — Documentação Técnica
**Verificado em:** 2026-07-14 (consultado diretamente dos bancos DEV e PROD)
**PROD:** `vftyiildukrpgmnbcnao` · **DEV:** `szqatgvgghxvyyncsjxl`

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
| `est_perfil` colunas | 9 | 12 | DEV tem `cor_primaria`, `nome_responsavel`, `email_responsavel` |
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

### 4.3 `empresas` (12 colunas)
```
id              uuid        PK, uuid_generate_v4()
nome            text        NOT NULL
cnpj            text        nullable
contato         text        nullable
ativo           boolean     default true
criado_em       timestamptz default now()
questionario_id uuid        FK questionarios ON DELETE SET NULL
criado_por      uuid        FK auth.users ON DELETE SET NULL
tenant_id       uuid        FK tenants ON DELETE CASCADE
razao_social    text        nullable
endereco        text        nullable
logo_base64     text        nullable
```

### 4.4 `est_perfil` (9 colunas em PROD, 12 em DEV)
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
-- Apenas em DEV:
cor_primaria          text        nullable
nome_responsavel      text        nullable
email_responsavel     text        nullable
```

### 4.5 `ciclos` (9 colunas)
```
id          uuid        PK, uuid_generate_v4()
empresa_id  uuid        NOT NULL, FK empresas ON DELETE CASCADE
nome        text        NOT NULL
data_inicio date        nullable
data_fim    date        nullable
status      text        default 'aberto' — CHECK IN ('aberto','encerrado','laudo_gerado')
criado_em   timestamptz default now()
descricao   text        nullable
tenant_id   uuid        FK tenants ON DELETE CASCADE
```

### 4.6 `links_coleta` (10 colunas)
```
id              uuid        PK, uuid_generate_v4()
empresa_id      uuid        NOT NULL, FK empresas ON DELETE CASCADE
ciclo_id        uuid        FK ciclos ON DELETE SET NULL (nullable)
token           text        NOT NULL, UNIQUE — gerado automaticamente: encode(gen_random_bytes(16),'hex')
setor_sugerido  text        nullable
ativo           boolean     default true
expira_em       timestamptz nullable (NULL = sem expiração)
criado_em       timestamptz default now()
tenant_id       uuid        FK tenants ON DELETE CASCADE
is_teste        boolean     NOT NULL, default false
```

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
| `fn_guard_perfil_update` | `perfis` | `fn_guard_perfil_update()` | Bloqueia alteração do próprio role (DEV; PROD pendente) |
| `fn_proteger_ancora` | `questoes` | `fn_proteger_ancora()` | Protege questões âncora de exclusão |
| `set_updated_at` | Várias | `set_updated_at()` | Atualiza updated_at automaticamente |
| `rls_auto_enable` | (event trigger) | `rls_auto_enable()` | Habilita RLS automaticamente em novas tabelas |

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
- Wipe safeguard: não limpa setores/cargos se import vier vazio
- Race condition: captura `empId = _gheEmpresaId` antes dos awaits assíncronos
- Erro de headcount: lança exception visível (não engole silenciosamente)

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
| `migration_rbac_viewer_hardening.sql` | ✅ | ❌ **pendente** | Trigger fn_guard_perfil_update + 7 policies viewer RESTRICTIVE |
| `migration_sync_est_perfil_prod.sql` | N/A | ❌ pendente | Colunas cor_primaria, nome_responsavel, email_responsavel em est_perfil |

---

## 14. Pendências Abertas

| Item | Ambiente | Prioridade | Observação |
|------|----------|-----------|------------|
| Aplicar `migration_rbac_viewer_hardening.sql` | PROD | Alta | Trigger de proteção de role pendente |
| Aplicar `migration_sync_est_perfil_prod.sql` | PROD | Baixa | Só ao implementar identidade visual |
| Reimportar catálogo ELEVA IT CONSULTORIA | PROD | Média | 0 setores, 98 funções universais — não afeta outros clientes |
| Alinhar policies de `questoes/questionarios/questionario_questoes` DEV | DEV | Média | DEV permite qualquer autenticado escrever (PROD só super_admin) |
| Teste e2e onboarding nova EST | DEV | Produto | |

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

---

## 16. Skill de Validação

A skill `/validar-formulario` (`.claude/skills/validar-formulario/SKILL.md`) contém o checklist de 8 passos para validar o pipeline de respostas antes de qualquer deploy. Dispara automaticamente ao mencionar formulário, salvar_resposta, "resposta salva localmente" ou "permission denied".
