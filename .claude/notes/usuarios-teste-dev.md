# Usuários de Teste — DEV (szqatgvgghxvyyncsjxl)

> **Projeto:** pseg-safesign-dev  
> **URL admin DEV:** https://develop.pseg-safesign.pages.dev/pseg-admin-questionario.html (ou preview do CF Pages)  
> **Criados via:** Supabase Dashboard → Authentication → Users → "Add user"  
> **Após criar:** executar SQL abaixo para definir o role e tenant corretos na tabela `perfis`.

---

## Credenciais

| Role | E-mail | Senha | tenant_id | empresa_id |
|------|--------|-------|-----------|------------|
| super_admin | eleva.it.consultoria@gmail.com | _(senha real — não alterar)_ | NULL | NULL |
| super_admin | oscarbdados@gmail.com | _(senha real)_ | fe756d06 (Eleva IT) | NULL |
| admin | admin-teste@example.com | Pseg@Dev2026! | fe756d06 (Eleva IT) | NULL |
| consultor | consultor-teste@pseg-dev.com | Pseg@Dev2026! | fe756d06 (Eleva IT) | NULL |
| cliente_viewer | viewer-teste@example.com | Pseg@Dev2026! | fe756d06 (Eleva IT) | e37221dc (Empresa Teste DEV) |

**Tenant Eleva IT:** `fe756d06-f953-42eb-b13b-c20512d63a61`  
**Empresa Teste DEV:** `e37221dc-8762-4b37-81f0-17b2b73b3893`  
**Empresa Teste:** `e916010e-a835-45b0-a48a-664b1975a77e`

---

## Passo a passo para criar

### 1. Criar usuários no Supabase Dashboard

Ir em **Authentication → Users → Add user** e criar os 3 usuários abaixo:

| E-mail | Senha |
|--------|-------|
| admin-teste@pseg-dev.com | Pseg@Dev2026! |
| consultor-teste@pseg-dev.com | Pseg@Dev2026! |
| viewer-teste@pseg-dev.com | Pseg@Dev2026! |

Marcar "Auto Confirm User" para não precisar de e-mail de confirmação.

---

### 2. Pegar o tenant_id e empresa_id disponíveis no DEV

```sql
-- Ver tenants disponíveis em DEV
SELECT id, nome FROM tenants ORDER BY created_at LIMIT 5;

-- Ver empresas disponíveis em DEV
SELECT id, nome, tenant_id FROM empresas ORDER BY created_at LIMIT 10;
```

---

### 3. Atualizar perfis dos usuários criados

Executar no SQL Editor do DEV **depois de criar os usuários acima**:

```sql
-- Substituir os UUIDs pelos IDs reais dos usuários criados
-- e o TENANT_ID / EMPRESA_ID pelos valores do passo 2

-- Admin
UPDATE perfis SET
  role = 'admin',
  nome = 'Admin Teste',
  tenant_id = 'TENANT_ID_AQUI',
  empresa_id = NULL,
  ativo = true
WHERE id = (SELECT id FROM auth.users WHERE email = 'admin-teste@pseg-dev.com');

-- Consultor
UPDATE perfis SET
  role = 'consultor',
  nome = 'Consultor Teste',
  tenant_id = 'TENANT_ID_AQUI',
  empresa_id = NULL,
  ativo = true
WHERE id = (SELECT id FROM auth.users WHERE email = 'consultor-teste@pseg-dev.com');

-- Viewer (precisa de empresa_id — viewer vê apenas 1 empresa)
UPDATE perfis SET
  role = 'cliente_viewer',
  nome = 'Viewer Teste',
  tenant_id = 'TENANT_ID_AQUI',
  empresa_id = 'EMPRESA_ID_AQUI',
  ativo = true
WHERE id = (SELECT id FROM auth.users WHERE email = 'viewer-teste@pseg-dev.com');
```

---

### 4. Verificar

```sql
SELECT u.email, p.role, p.nome, p.tenant_id, p.empresa_id, p.ativo
FROM perfis p
JOIN auth.users u ON u.id = p.id
WHERE u.email IN (
  'admin-teste@pseg-dev.com',
  'consultor-teste@pseg-dev.com',
  'viewer-teste@pseg-dev.com'
);
```

---

## Checklist de testes RBAC

### Consultor
- [ ] Login como `consultor-teste@pseg-dev.com`
- [ ] Sidebar **não** deve mostrar: Perfil da EST, Plano de Ação, Equipe, Configurar Riscos, Assinatura
- [ ] Tentar `goScreen('est-perfil', null)` no console → toast "Acesso restrito"
- [ ] Tentar `salvarEstPerfil()` no console → toast "Apenas administradores..."
- [ ] Consegue ver: Clientes, GHE, Links, Análise, Gráficos, Comparativo, Auditoria, Relatório, Metodologia

### Viewer
- [ ] Login como `viewer-teste@pseg-dev.com`
- [ ] Sidebar **deve mostrar apenas**: Dashboard, Links de Coleta, Resultados, Distribuição, Relatório
- [ ] Sidebar **não** deve mostrar: Comparativo, Auditoria, Clientes, GHE, Questionário, Equipe, qualquer Config
- [ ] Em Links: **não** deve aparecer botão "Novo link", "Nova empresa", "Desativar", "Excluir"
- [ ] Tentar `goScreen('comparativo', null)` no console → toast "Acesso restrito"
- [ ] Tentar `goScreen('auditoria', null)` no console → toast "Acesso restrito"
- [ ] Dados exibidos devem ser apenas da empresa vinculada ao viewer

### Admin
- [ ] Login como `admin-teste@pseg-dev.com`
- [ ] Sidebar **não** deve mostrar: Gestão de ESTs
- [ ] Consegue ver e editar: Perfil da EST, Equipe, Plano de Ação, Configurar Riscos, Assinatura

### Super Admin
- [ ] Login como `eleva.it.consultoria@gmail.com`
- [ ] Tudo visível, incluindo Gestão de ESTs
