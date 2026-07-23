---
name: validar-importacao-ghe
description: >
  Confronta os dados importados de GHE (setores/funções/headcount) de uma empresa no PSEG
  SafeSign contra a planilha Excel original enviada pelo cliente, ANTES do envio de qualquer
  laudo ou entrega. Use SEMPRE que: (1) o usuário anexar uma planilha de colaboradores/GHE e
  pedir para "confrontar", "validar", "conferir" ou "bater" com o que foi cadastrado; (2) o
  usuário relatar um GAP de dados reportado por um cliente; (3) antes de enviar um laudo ou
  entrega final para um cliente cuja base foi importada via planilha; (4) depois de reimportar
  uma planilha para confirmar que a correção realmente resolveu o GAP. A validação cobre SETOR,
  FUNÇÃO/CARGO e QTD (quantidade de colaboradores por par setor+cargo) — as três dimensões que
  já causaram GAPs reais em produção (ver seção de armadilhas conhecidas abaixo).
---

# Validação de Importação GHE — Planilha × Sistema

Esta skill audita se tudo que está na planilha do cliente também está, corretamente, no banco
do PSEG SafeSign. Nasceu de um GAP real reportado por cliente em 2026-07 (Udinese e Assa Abloy
Shared Services), causado por um bug de mapeamento cargo→setor 1:1 que descartava vínculos
quando o mesmo cargo aparecia em setores diferentes na planilha. Ver seção 11 do
`PSEG_SAFESIGN_DOCUMENTACAO_TECNICA_2026-06-09.md` para o histórico completo.

**Formato assumido da planilha (atual):** uma linha por colaborador, com pelo menos uma coluna
de Setor e uma coluna de Cargo/Função. QTD não é uma coluna — é **derivada** contando quantas
linhas cada par (Setor, Cargo) aparece. Se o usuário avisar que o formato mudou (ex.: planilha
já vier agregada com uma coluna de quantidade), ajuste a extração de acordo — não force o
padrão "uma linha por colaborador" se o próprio usuário disse que isso vai mudar.

## Visão geral do pipeline

```
Planilha do cliente (1 linha = 1 colaborador)
  │  Setor        Cargo
  │  ─────        ─────
  │  Financeiro    Analista Jr
  │  Financeiro    Analista Jr        ← 2 colaboradores no mesmo par
  │  Financeiro    Coordenador
  ▼
Import no admin (pseg-admin-questionario.html → GHE)
  │
  ├─ empresa_setores      (catálogo de setores únicos)
  ├─ empresa_funcoes      (catálogo de cargos únicos, setor_id pode ser NULL = universal)
  └─ empresa_headcount    (setor, funcao, quantidade — agregado)
```

Uma validação completa precisa bater as **três tabelas** contra a planilha, não só uma. Um
GAP pode existir em qualquer camada isoladamente (ex.: catálogo completo mas headcount errado).

## Passo 1 — Extrair os dados da planilha

Use Python com `openpyxl` via Bash (não existe parser de xlsx nativo nas ferramentas). Gere um
JSON temporário no scratchpad para consulta posterior:

```python
import openpyxl, json, collections

wb = openpyxl.load_workbook('<caminho-da-planilha>', data_only=True)
ws = wb.active

# Identificar as colunas de Setor e Cargo pelo cabeçalho (linha 1) — os nomes exatos
# variam por planilha (ex: "Setor"/"Cargo", "Departamento"/"Função"). Inspecionar
# ws[1] antes de fixar os índices.
headers = [c.value for c in ws[1]]
col_setor = headers.index('Setor')  # ajustar conforme cabeçalho real
col_cargo = headers.index('Cargo')  # ajustar conforme cabeçalho real

pares = collections.Counter()
for row in ws.iter_rows(min_row=2, values_only=True):
    setor = (row[col_setor] or '').strip() if row[col_setor] else None
    cargo = (row[col_cargo] or '').strip() if row[col_cargo] else None
    if setor:
        pares[(setor, cargo)] += 1

out = [{"setor": s, "cargo": c, "qtd_planilha": n} for (s, c), n in sorted(pares.items())]
json.dump(out, open('<scratchpad>/planilha_pares.json', 'w'), ensure_ascii=False, indent=2)
print(f"{len(out)} pares únicos, {sum(pares.values())} colaboradores totais")
```

**Importante:** não normalize agressivamente os nomes de setor/cargo aqui (sem lowercase, sem
remover acentos) — a comparação deve ser o mais literal possível para pegar diferenças reais de
grafia entre planilha e banco. Normalização (trim + espaço colapsado + lowercase) só entra na
**etapa de matching** (passo 4), nunca na exibição do resultado.

## Passo 2 — Localizar a empresa no banco

```sql
SELECT id, nome, numero_cliente FROM empresas WHERE nome ILIKE '%<nome-do-cliente>%';
```

Confirme com o usuário se houver mais de um resultado — nunca assuma qual empresa é a certa
quando o nome for ambíguo (ex.: "Assa Abloy Shared Services" vs outra unidade "Assa Abloy").

## Passo 3 — Extrair os dados do sistema

Rodar no projeto correto (DEV `szqatgvgghxvyyncsjxl` ou PROD `vftyiildukrpgmnbcnao` — perguntar
se não estiver claro, GAPs de cliente real geralmente são sobre PROD):

```sql
-- Catálogo completo setor × cargo (inclui cargos universais, setor_id NULL, em todos os setores)
SELECT es.nome AS setor, ef.nome AS cargo
FROM empresa_setores es
LEFT JOIN empresa_funcoes ef ON ef.setor_id = es.id AND ef.ativo = true
WHERE es.empresa_id = '<empresa_id>' AND es.ativo = true
UNION ALL
SELECT es.nome AS setor, ef.nome AS cargo
FROM empresa_funcoes ef
CROSS JOIN empresa_setores es
WHERE ef.setor_id IS NULL AND ef.empresa_id = '<empresa_id>' AND ef.ativo = true
  AND es.empresa_id = '<empresa_id>' AND es.ativo = true
ORDER BY 1, 2;

-- Headcount agregado (a fonte de QTD)
SELECT setor, funcao, quantidade
FROM empresa_headcount
WHERE empresa_id = '<empresa_id>'
ORDER BY setor, funcao;
```

Salve os dois resultados em JSON no scratchpad da mesma forma que o passo 1, para comparar
programaticamente em vez de visualmente (planilhas reais têm centenas de linhas — comparação
visual erra).

## Passo 4 — Comparar (setor, cargo, qtd)

Faça o diff em Python/JS a partir dos JSONs salvos. Para o **matching** de chaves (não para
exibição), aplique a mesma normalização conservadora usada pelo importador (`_gheNorm` em
`pseg-admin-questionario.html`: trim + colapso de espaços + lowercase) — isso evita falsos
positivos por diferença de maiúscula/espaço duplo, que não é um GAP real de dado.

Gere três listas:
1. **Só na planilha, ausente no catálogo** (`empresa_setores`/`empresa_funcoes`) — GAP de
   catálogo, o par nunca foi importado ou foi perdido.
2. **Só no sistema, ausente na planilha** — pode ser dado de uma importação anterior/diferente,
   ou lixo a limpar. Reportar mas não tratar automaticamente como erro sem confirmar com o
   usuário.
3. **Presente nos dois lados, mas QTD diverge** — comparar `qtd_planilha` (contagem de linhas)
   contra `empresa_headcount.quantidade`. Se o par não existir em `empresa_headcount` mas existir
   no catálogo, reportar como "catalogado mas sem headcount" (headcount pode ter sido importado
   separadamente ou nunca populado).

## Passo 5 — Relatar

Estruture a resposta como uma tabela markdown, ordenada por Setor:

| Setor | Cargo | Qtd planilha | Qtd sistema | Status |
|-------|-------|--------------|-------------|--------|
| Financeiro | Analista Jr | 2 | 2 | ✅ bate |
| Financeiro | Coordenador | 1 | 0 | ❌ ausente no sistema |
| TI | Suporte | — | 3 | ⚠️ só no sistema |

Ao final, um resumo objetivo: total de pares únicos na planilha, quantos batem, quantos têm
GAP de catálogo, quantos têm GAP de quantidade. Se houver GAP, isso é bloqueante para envio ao
cliente — diga isso explicitamente e não sugira "enviar mesmo assim".

## Armadilhas conhecidas (não repetir os bugs já corrigidos)

- **Cargo repetido em setores diferentes na planilha** (ex.: "Aprendiz Administrativo" em 14
  setores distintos) — o importador já foi corrigido para tratar `cargo→setor` como mapeamento
  1:N (era 1:1 e descartava vínculos, causando o GAP real de Udinese/Assa Abloy em 2026-07). Se
  a validação encontrar pares ausentes no catálogo que seguem esse padrão (mesmo cargo, setor
  diferente da última ocorrência na planilha), é forte indício de que a importação foi feita
  ANTES da correção — a ação correta é reimportar a planilha pelo admin, não editar o banco na
  mão.
- **Wipe silencioso do GHE** — `salvarGHE()` já tem salvaguarda contra apagar setores/cargos
  existentes sem confirmação quando a extração da planilha resultar vazia. Se a comparação
  mostrar catálogo totalmente zerado onde antes havia dados, suspeitar desse cenário histórico
  (caso real: ELEVA IT CONSULTORIA) em vez de assumir que a planilha nunca foi importada.
- **Sem agrupamento automático** — o sistema NUNCA agrupa/mescla nomes de setor automaticamente
  durante import (o campo `grupo` só é preenchido por ação manual opt-in). Se a planilha tem
  "TI" e "T.I." como setores diferentes, o sistema vai catalogar como dois setores diferentes
  também — isso é esperado, não é bug, a menos que o cliente peça deduplicação manual.
- **Limite de 1000 linhas do Supabase** — se a empresa tiver uma base grande, consultas em
  `empresa_headcount`/`empresa_funcoes` sem paginação truncam silenciosamente em 1000 linhas.
  As queries deste skill usam filtro por `empresa_id`, que normalmente fica bem abaixo desse
  limite, mas para empresas muito grandes confirme o `COUNT(*)` antes de assumir que trouxe tudo.

## Depois da validação

Se houver GAP: recomendar reimportar a planilha via admin (tela GHE da empresa) — isso já usa o
pipeline corrigido — e então rodar esta mesma validação de novo para confirmar 100% de match
antes de liberar o envio ao cliente. Não editar `empresa_setores`/`empresa_funcoes`/
`empresa_headcount` manualmente via SQL para "tapar" o GAP — isso mascara o sintoma sem
confirmar que o pipeline de import está correto para a próxima planilha.
