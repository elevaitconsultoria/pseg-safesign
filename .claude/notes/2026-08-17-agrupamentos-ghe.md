# Agrupamentos GHE — Tela dedicada + Toggle de 3 granularidades (2026-08-17)

## O que foi feito

Feature completa de Agrupamentos GHE para fins de análise e relatório, sem tocar na
hierarquia de cargos da empresa (`respostas.setor`, `empresa_setores`, `empresa_funcoes`
permanecem intactos).

### Migration SQL — `migration_grupos_setor.sql`

Nova tabela `grupos_setor` aplicada em **DEV e PROD**:

```sql
CREATE TABLE IF NOT EXISTS grupos_setor (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id uuid NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  tenant_id  uuid NOT NULL REFERENCES tenants(id)  ON DELETE CASCADE,
  tipo       text NOT NULL DEFAULT 'setor' CHECK (tipo IN ('setor', 'funcao')),
  nome       text NOT NULL,
  itens      text[] NOT NULL DEFAULT '{}',
  ordem      int  NOT NULL DEFAULT 0,
  criado_em  timestamptz NOT NULL DEFAULT now(),
  atualizado_em timestamptz NOT NULL DEFAULT now()
);
```

Duas policies RLS:
- `grupos_setor_select` — qualquer membro do tenant + `super_admin`
- `grupos_setor_write` — somente `admin`, `consultor` ou `super_admin`

Tabela `empresa_setores.grupo` (já existente) **não foi usada**: reimportação GHE apagaria
as atribuições sem aviso. O `grupos_setor` é persiste independente do catálogo GHE.

### Nova tela `#sc-agrupamentos`

Adicionada ao sidebar entre "GHE" e "Links de Coleta":
- `nb-agrupamentos` → `goScreen('agrupamentos')` → `_setupTelaAgrupamentos()`
- Dois painéis side-by-side: **Grupos de Setores** | **Grupos de Funções**
- Select de empresa no header (propagado via array `['agrup-empresa']`)
- KPIs inline (N grupos setor / N grupos função)
- Reutiliza o modal `#modal-grupo` já existente para criar/editar grupos

**RBAC**: `'agrupamentos'` adicionado a `restritos.cliente_viewer` — viewer não acessa a tela.
RLS garante que viewer não escreve mesmo que acesse via URL direta.

### Fonte de itens no modal de criação

Mudança de `_respostasCache` → `_empresas[].hierarquia[]` (catálogo `empresa_setores`/`empresa_funcoes`):

```js
const emp = _empresas.find(e => e.id === _empresaAtiva?.id);
const hierarquia = emp?.hierarquia || [];
// tipo === 'setor'
items = hierarquia.map(h => h.nome).filter(n => n).sort((a,b) => a.localeCompare(b,'pt-BR'));
// tipo === 'funcao'
const todas = [...new Set(hierarquia.flatMap(h => h.funcoes || []))];
items = todas.filter(f => f).sort((a,b) => a.localeCompare(b,'pt-BR'));
```

Motivo: catálogo tem todos os setores/funções mesmo sem nenhuma resposta. Antes era impossível
configurar grupos antes de receber respostas.

### Toggle de 3 modos na tela de Análise

Estendido de 2 para 3 modos:

| Botão | `_segMode` | Comportamento |
|-------|------------|---------------|
| Por Setor | `'segregado'` | Um bloco por setor raw (comportamento original) |
| Por Agrupamento | `'agrupado'` | Um bloco por grupo GHE; setores sem grupo = bloco individual |
| Geral | `'consolidado'` | Tudo consolidado (comportamento original) |

O botão "Por Agrupamento" fica **desabilitado** (opacity 0.4, not-interativo) quando não há
grupos cadastrados para a empresa ativa. Tooltip: "Configure agrupamentos GHE primeiro".

Funções atualizadas para tratar o novo modo:
- `renderViewGrafica()` — novo case `'agrupado'`
- `renderViewRisco()` — novo case `'agrupado'`
- `renderViewQuestao()` — explicit case `'segregado'` adicionado (antes caía em `else`)

### Seletor de granularidade no Laudo PDF

Adicionado `<select id="laudo-granularidade">` no painel de filtros de `#sc-laudo`:

```
Por Agrupamento GHE  ← default quando há grupos
Por Setor            ← default quando não há grupos (comportamento pré-feature)
Geral                ← tudo consolidado
```

`_buildLaudoHTML()` lê o select e decide:
- `'agrupado'` → `agruparPorGrupos(setoresAtivos, gruposSetor)` (comportamento já existente)
- `'segregado'` → cada setor raw é seu próprio grupo
- `'consolidado'` → seção única "Todos os setores"

`onLaudoFiltro()` auto-seleciona o valor correto quando empresa muda.

### Remoção de blocos inline nos filtros de Análise

Os divs `#grupos-setor` e `#grupos-funcao` que existiam inline nos filtros da tela de Análise
foram removidos. O acesso aos grupos agora é exclusivamente pela tela Agrupamentos.

`carregarGruposSetor()` permanece em `onEmpresaChange()` — os dados de grupos ainda são
necessários para o toggle de análise e o laudo.

## Commits

- `0cb15e0` — `feat: Agrupamentos GHE — tela dedicada + toggle 3 granularidades` (branch `develop`)
- PR #46 em `feature/convite-usuario-sistema` (precisa atualizar descrição para v2)

## Bugs corrigidos pós-deploy (2026-08-17)

### 1. `permission denied for table grupos_setor` (GRANT ausente)

**Sintoma**: Erro ao salvar agrupamento mesmo com RLS configurado corretamente.

**Causa**: A migration habilitava RLS e criava as policies, mas não incluía
`GRANT SELECT, INSERT, UPDATE, DELETE ON grupos_setor TO authenticated`. Sem
o GRANT, o Postgres bloqueia na camada de privilégio antes de checar RLS.

**Correção**: GRANT aplicado diretamente via MCP no banco DEV. `migration_grupos_setor.sql`
atualizado para incluir o GRANT (commit `e429918`). Deve ser aplicado também em PROD junto
com a migration.

**Padrão**: Toda nova tabela precisa de `GRANT ... TO authenticated` além de `ENABLE ROW LEVEL SECURITY`.

### 2. Lista de grupos vazia apesar de KPI mostrar 2 (função `e()` inexistente)

**Sintoma**: KPI exibia "2 grupos de setores" mas lista mostrava "Nenhum grupo criado ainda."

**Causa**: `renderTabelaAgrupamentos()` usava `e(g.nome)` e `e(it)` no template — função `e()`
não existe no codebase. O `ReferenceError` fazia a atribuição ao `innerHTML` falhar silenciosamente.
O KPI (renderizado antes, sem `e()`) ficava correto; a lista (renderizada depois, com `e()`) ficava
com o conteúdo anterior.

**Correção**: Substituído `e(g.nome)` por `g.nome` e `e(it)` por `it`, igual ao padrão do
restante do código. Adicionado `(g.itens||[])` como guard extra.

**Commit**: `e429918` — push para `develop`.

## Deploy

- **DEV**: commits `0cb15e0` (feature) + `e429918` (fixes) em `develop`
- **PROD**: pendente — criar PR de `feature/convite-usuario-sistema` → `main`

## O que NÃO muda

- `respostas.setor` — intocado
- `empresa_setores` / `empresa_funcoes` — intocados
- `psicomap-forms.html` — zero alterações
- `salvar_resposta` RPC — zero alterações
- Análise sem grupos: "Por Agrupamento" = "Por Setor" (backward compatible via `agruparPorGrupos(setores, [])`)

## Bugs colaterais descobertos (não corrigidos aqui)

1. `exportarCSV` lê `r.resposta_itens` mas `loadRespostasParaEmpresa` retorna `r.q` — CSV de respostas sai vazio. Documentado em CLAUDE.md (Segunda metodologia, 2026-08-03).
2. `salvar_resposta` RPC descarta silenciosamente itens com `valor` fora de 1–4 (filtro, não validação). Documentado em CLAUDE.md.
