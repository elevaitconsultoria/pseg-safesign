# Bug: `cliente_viewer` convidado pelo sistema loga e vê tela em branco

**Data:** 2026-09-11
**Ambiente:** PROD (`vftyiildukrpgmnbcnao`)
**Caso real:** `phelipe.barbosa@psegsst.com.br` — convidado 11:15 UTC, primeiro login 13:34 UTC,
painel vazio (nenhuma empresa, nenhum dado da EST).
**Branch:** `fix/acesso-viewer-empresa-id`

## Sintoma

Usuário recebe o convite, define a senha, entra — e o painel carrega sem nenhum erro visível e
sem nenhum dado. Não há toast, não há mensagem, o console não acusa falha: as queries retornam
`[]` com HTTP 200.

## Causa raiz

A Edge Function `convidar-usuario` **nunca grava `empresa_id`**. Depois do
`inviteUserByEmail`, ela corrige o perfil default criado pelo trigger `handle_new_user()`:

```ts
.update({ nome, role, tenant_id: tenantId })   // supabase/functions/convidar-usuario/index.ts
```

`empresa_id` não está no update e não existe no body aceito pela function. O modal de convite
(`abrirModalNovoUsuario` / `salvarNovoUsuario`, `psicomap-admin.html`) também não tem campo de
empresa — envia só `{ email, nome, role, tenant_id }`.

Resultado: **todo `cliente_viewer` criado pelo sistema nasce com `empresa_id = NULL`**, e o
role `cliente_viewer` é justamente o único cuja visibilidade inteira depende desse campo.

## Por que isso zera a tela (e não dá erro)

`empresas` tem a policy **RESTRICTIVE** `viewer_empresa_select_empresas`:

```sql
(auth_role() <> 'cliente_viewer') OR (id = get_my_empresa_id())
```

Para este usuário: `auth_role() = 'cliente_viewer'` e `get_my_empresa_id() = NULL`, então o
segundo ramo vira `id = NULL` → **NULL**, que nunca é `true`. Policy RESTRICTIVE reprovada →
zero linhas. Como `empresas` é a raiz de todo o carregamento, tudo que depende dela cai junto.

Reproduzido com o JWT real do usuário (`set_config('request.jwt.claims', …)` + `ROLLBACK`):

| | |
|---|---|
| `auth_role()` | `cliente_viewer` |
| `get_my_tenant_id()` | `00000000-…-0099` (tenant válido, EST existe) |
| `get_my_empresa_id()` | `NULL` |
| `empresas` visíveis | **0** |
| `ciclos` visíveis | **0** |
| `links_coleta` visíveis | **0** |
| `respostas` visíveis | **0** |

O tenant está correto — o problema é exclusivamente `empresa_id`.

Não há erro porque RLS filtrando tudo é indistinguível de "não há dados": o PostgREST devolve
`[]` com 200, e `carregarEmpresas()` renderiza o estado vazio normal.

## Achado colateral — o guard do frontend falha ABERTO

`psicomap-admin.html:5582`:

```js
const isViewer = currentUser?.role === 'cliente_viewer' && currentUser?.empresa_id;
```

Com `empresa_id = NULL`, `isViewer` é falsy e o JS **não aplica** o `.eq('id', empresa_id)` —
ou seja, a camada JS pede todas as empresas do tenant. Quem segura é só o RLS.

Hoje isso não vaza nada (a policy RESTRICTIVE barra), mas a lógica está invertida: um viewer
sem empresa deveria ver **nada** por decisão explícita, não por sorte da policy. A mesma
construção aparece em `:5595`, `:5622` e `:9012`.

## Mitigação imediata (dado, não código)

Já existe UI para corrigir: na tela **Equipe**, botão **"Reconfigurar"** (visível só para
`super_admin`) → `abrirModalReconfVinculo` → `salvarReconfVinculo`, que grava `tenant_id` e
`empresa_id`. Basta apontar o viewer para a empresa dele.

## Correções propostas (código)

1. **`convidar-usuario`**: aceitar `empresa_id` no body e **exigi-lo quando
   `role === 'cliente_viewer'`** — rejeitar o convite (400) em vez de criar um perfil que não
   funciona. Validar que a empresa pertence ao `tenantId` resolvido (nunca confiar no body).
2. **Modal de convite**: campo "Empresa" que aparece quando `nu-role = cliente_viewer`,
   populado com as empresas do tenant (mesmo padrão de `reconfCarregarEmpresas`), obrigatório.
3. **Guard do frontend**: separar as duas condições — `role === 'cliente_viewer'` sempre
   restringe; sem `empresa_id` o resultado é vazio **por decisão**, com aviso na tela
   ("Seu acesso ainda não foi vinculado a uma empresa — fale com a consultoria") em vez de um
   painel mudo.
4. **Tela Equipe**: sinalizar `cliente_viewer` com `empresa_id` nulo como pendência
   (mesma ideia do badge "Convite pendente").

## Nota sobre este caso específico

`phelipe.barbosa@psegsst.com.br` é e-mail da **própria consultoria** (PSEG), não de uma empresa
cliente. `cliente_viewer` é o acesso read-only do cliente final, escopado a uma empresa. Se a
intenção era dar acesso a um membro da equipe PSEG, o role correto é `consultor` ou `admin` —
que não dependem de `empresa_id` e não caem neste bug. Confirmar a intenção antes de apenas
preencher o `empresa_id`.
