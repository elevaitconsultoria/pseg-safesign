# Metodologias psicossociais além da própria: HSE (ICAO-35), combo e COPSOQ

> **Status: PLANEJAMENTO — não executar ainda.**
> Documento vivo, para refinamento incremental antes da implementação.
> Criado em 2026-08-03. Atualizado em 2026-08-03 com a análise antecipada do COPSOQ (§14), a
> organização do plano em camadas (mapa abaixo), a análise de impacto (§15) e o backlog
> consolidado (§16). Nenhuma linha de código ou migration foi aplicada — planejamento apenas.

## Mapa de camadas

O plano está organizado em camadas independentes. Cada camada só faz sentido depois da anterior
estar assentada; nenhuma camada além da 0+1 tem execução autorizada hoje.

| Camada | Conteúdo | Status | Seções |
|---|---|---|---|
| **0 — Fundação compartilhada** | `metodologia` como discriminante por ciclo/resposta, escala variável, catálogo de dimensões (com direção por dimensão), padrão de RPC/RLS, motor despachado em 3 pontos. Serve de base para HSE **e** qualquer metodologia futura. | Planejada, pronta para execução | §4–§9 (banco, seed, formulário, motor) |
| **1 — HSE / ICAO-35 (metodologia #2)** | Fatia vertical coleta → cálculo → análise → laudo, no vocabulário e direção próprios do HSE. | Planejada, pronta para execução — **é a única camada com escopo fechado para começar agora** | §2 (o instrumento), §10 (análise/laudo), §11 (PRs), §12 (riscos), §15 (impacto) |
| **1.1 — HSE fase 2** | Comparativo entre ciclos, plano de ação por dimensão, exportações, tela de Metodologia HSE. | Adiada, sem desenho | Backlog B9 |
| **2 — Combo de metodologias** | Formulário único reunindo itens de várias metodologias contratadas, resultados calculados e exibidos separadamente por instrumento. | **Ideia registrada, não avaliada para execução** — problema de fadiga de resposta em aberto | §13, backlog B10 |
| **3 — COPSOQ (metodologia #3, candidata)** | Terceiro instrumento — cobre burnout, satisfação, saúde percebida e assédio, lacunas reais do HSE e do P×S. Traz uma exigência nova para a Camada 0 (direção por dimensão, não por instrumento). | **Análise antecipada concluída, decisão de seguir ainda não tomada** | §14, backlog B11 |

**Regra entre camadas:** nenhuma camada superior deve forçar retrabalho na Camada 0 além do que já
está previsto nela. A única revisão que a pesquisa do COPSOQ trouxe para a Camada 0 está marcada em
§6.1 — é uma adição de uma coluna, não uma reabertura do desenho.

**Para acompanhamento entre sessões:** §15 (análise de impacto) cobre consequências comerciais,
técnicas, operacionais, de UX e de compliance da Camada 1; §16 (backlog consolidado) é a lista
única e priorizada de pendências — não usar mais a antiga lista solta de "pontos em aberto".

---

## 1. Contexto e motivação

O PsicoMap hoje aplica **uma única metodologia** de avaliação de risco psicossocial —
personalizada, inspirada em BS 8800: 27 questões em escala 1–4, agregadas por `cd_risco`
em Probabilidade (moda da distribuição) × Severidade (fixa por risco), classificadas por
um lookup 4×4 em IRRELEVANTE → CRÍTICO. Isso está **hardcoded de ponta a ponta**: não
existe entidade "metodologia" em lugar nenhum do banco nem do código.

A necessidade de negócio é oferecer ao cliente a **escolha da metodologia**, começando
pelo HSE Management Standards Indicator Tool — instrumento reconhecido internacionalmente,
cientificamente validado, que dá defensabilidade técnica maior que uma metodologia própria
diante de auditoria e do MPT.

**Resultado pretendido:** a consultoria escolhe a metodologia ao criar o ciclo; o funcionário
recebe o instrumento correto pelo mesmo link de sempre; a análise e o laudo saem no vocabulário
próprio daquela metodologia — sem que o caminho BS 8800 existente mude de comportamento.

### Decisões já tomadas

| Decisão | Escolha |
|---|---|
| Variante | **ICAO-35** — adaptação brasileira validada do HSE MSIT (RPOT 20(3):1141-1149, 2020), 35 itens, 7 fatores confirmados por CFA. Mantém compatibilidade com os benchmarks HSE (que são de 35 itens) *e* tem referência acadêmica brasileira. |
| Classificação | **Percentis oficiais** extraídos de `analysistool.xls`; benchmark HSE 2023 (39.484 respondentes) como fallback e contexto setorial. |
| Comercial | **Escolha livre no ciclo, sem gate de módulo** nesta fase. Hook para `tenant_modulos` fica pronto para uma linha depois. |
| Escopo da 1ª entrega | **Fatia vertical**: coleta → cálculo → análise → laudo. Comparativo, plano de ação, exportações e tela de Metodologia ficam para a fase 2. |

---

## 2. Como funciona o HSE (resumo do levantamento)

Levantamento feito a partir dos PDFs oficiais do HSE (fontes primárias, §18).

- **35 itens, 7 dimensões.** Demands 8 · Control 6 · Managerial Support 5 · Peer Support 4 ·
  Relationships 4 · Role 5 · Change 3. (O HSE fala em "seis Management Standards" porque conta
  Support como um só; a pontuação usa sete.)
- **Escala Likert 1–5, com DOIS conjuntos de rótulos.** Itens 1–23: frequência
  (Nunca → Sempre). Itens 24–35: concordância (Discordo totalmente → Concordo totalmente).
  O corte é exato entre o item 23 e o 24, sem exceções.
- **12 itens invertidos:** 3, 5, 6, 9, 12, 14, 16, 18, 20, 21, 22, 34 — que são exatamente
  **Demands inteira + Relationships inteira**, e mais nada. A regra é por dimensão, não por item.
- **Inversão = `6 − posição`** (constante 6, não 5, porque a escala é 1–5). Armazenar a posição
  bruta e inverter só no cálculo.
- **Score da dimensão = média aritmética simples dos itens**, escala 1,00–5,00.
  **ALTO = MELHOR condição = MENOR risco** — direção oposta à metodologia atual.
  Não existe score global oficial das 7 dimensões.
- **Classificação por percentil** contra população de referência, em 4 faixas:
  <p20 vermelho "Ação urgente" · p20–p50 âmbar "Necessidade clara de melhoria" ·
  p50–p80 azul "Bom, mas há o que melhorar" · >p80 verde "Muito bem".
- **Janela de 6 meses** no enunciado — é parte do instrumento, não enfeite.
- **Taxa de resposta é reportável:** >50% adequada, >60% desejável, >70% boa, >80% muito boa.
  **Abaixo de 50% os dados são "apenas indicativos"** e isso precisa aparecer no laudo.
- **Amostra mínima por porte:** ≤500 → todos · 501-1.000 → 500 · 1.001-2.000 → 650 ·
  2.001-3.000 → 700 · >3.000 → 800.
- **O método não termina no questionário** — os passos 5–7 do HSE são grupos focais para
  confirmar os achados. Vender "laudo HSE" só com o survey é entregar metade do método.

### Licenciamento — confirmado

O instrumento está sob **Open Government Licence v3.0**, que permite explicitamente exploração
comercial, exigindo apenas **atribuição**. Restrições a observar:

- **Não usar o logo/brasão do HSE** (logos institucionais são excluídos da OGL).
- Não sugerir endosso oficial do HSE ou do governo britânico.
- **Não nomear o módulo "Stress Indicator Tool"** — esse é o nome do produto pago do HSE
  (vendido via books.hse.gov.uk) e geraria confusão. O que é livre é o questionário de 35 itens
  e a Analysis Tool em Excel.

Rodapé obrigatório no laudo:

> Contains public sector information published by the Health and Safety Executive and licensed
> under the Open Government Licence v3.0. © Crown copyright.

### Benchmark HSE 2023 (confirmado)

Relatório oficial de ago/2023, 39.484 respondentes, 124 avaliações. Médias gerais:

| Demands | Control | Mgr Support | Peer Support | Relationships | Role | Change |
|---|---|---|---|---|---|---|
| 3,25 | 3,72 | 3,80 | 4,01 | 4,11 | 4,16 | 3,30 |

Leitura acionável: **Demands e Change são estruturalmente as dimensões mais fracas em toda a
base mundial.** Um dashboard com corte fixo único vai acusá-las sempre — que é exatamente por
que o HSE normaliza por dimensão. O relatório também traz médias para 13 setores.

Ressalva do próprio HSE, que vale reproduzir no laudo: a base é de organizações que *escolheram*
usar a ferramenta, não é amostra representativa nacional.

---

## 3. A questão de fundo: é uma feature, um módulo, ou outro sistema?

**Não é outro sistema, e não é "mais um módulo".** É um **eixo novo de produto** — metodologia —
que encaixa na espinha dorsal existente sem tocá-la:

```
COMPARTILHADO (não muda)      tenant → empresa → GHE → ciclo → link → coleta anônima
                              RBAC, módulos por EST, adesão, branding da EST, LGPD

DIVERGE POR METODOLOGIA       banco de questões · escala · motor de cálculo · análise · laudo
```

As duas metodologias são **irreconciliáveis por álgebra**, não por parâmetro:

| | PsicoMap (BS 8800) | HSE / ICAO-35 |
|---|---|---|
| Objeto medido | evento de risco | condição organizacional |
| Agregação | moda da distribuição → P | média aritmética dos itens |
| Composição | multiplicativa (P × S via lookup 4×4) | aditiva |
| Escala | 1–4, inversão `5−v` | 1–5, inversão `6−v` |
| Direção | **alto = ruim** | **alto = bom** |
| Referência | absoluta (matriz interna) | relativa (percentil vs. população) |
| Saída | `{p, s, nivel, conduta}` | `{score, faixa, percentil}` |
| Score global | existe por perigo | **não existe oficialmente** |

### Decisão arquitetural

Não tornar `calcFatores` polimórfica nem construir um "motor genérico configurável". Isso viraria
um `switch` gigante disfarçado e deformaria as duas metodologias. Em vez disso:
`metodologia` como **discriminante de primeira classe** no ciclo, generalização **mínima** do
banco, e o caminho HSE como conjunto **paralelo** de funções, com despacho em apenas **3 pontos**
(`rodarAnalise`, `renderLaudo`, `buildQuestoes`).

### Regras de produto que decorrem disso

- **Nunca criar conversor entre as duas.** Qualquer fórmula "HSE → 1–25" é indefensável
  tecnicamente e vira passivo em auditoria. Se um cliente pedir, a resposta correta é não.
- **Nunca plotá-las no mesmo eixo.** Duas metodologias, duas telas, dois laudos.
- **A metodologia é escolhida por ciclo, nunca por resposta.** Misturar instrumentos no mesmo
  ciclo destrói a comparabilidade temporal, que é o principal valor do HSE.
- **O enquadramento comercial forte é sequencial, não excludente:** HSE diagnostica onde estão as
  fragilidades → grupos focais confirmam → os perigos entram no inventário do PGR com P×S.
  Vende-se as duas juntas, não uma contra a outra.

---

## 4. Achados de auditoria — verificados no banco, não no repo

Três bloqueios que **nenhum arquivo `.sql` do repositório documenta**. Confirmados via MCP em
PROD (`vftyiildukrpgmnbcnao`) em 2026-08-03; DEV está idêntico nestes pontos.

**1. `salvar_resposta` DESCARTA valores fora de 1–4 em silêncio.** O `INSERT` final termina em
`WHERE (item->>'valor')::int BETWEEN 1 AND 4`. Isso é **filtro, não validação**: um envio HSE
com itens em valor 5 retornaria HTTP 200, o funcionário veria "Obrigado!", e a resposta entraria
truncada — sem exceção, sem entrada de erro em `respostas_fila`. Relaxar o CHECK da tabela
**não resolve**; o descarte está no corpo da função. Verificado: `prosrc LIKE '%BETWEEN 1 AND 4%'`
= `true` nos **dois** overloads.

**2. Existem dois overloads de `salvar_resposta` em PROD** — 9 e 10 argumentos (o de 9 é morto).
Adicionar um `p_metodologia` criaria um terceiro e arriscaria `PGRST203` (ambiguidade), que
quebraria 100% do formulário. **Decisão: não adicionar parâmetro** — derivar a metodologia
server-side a partir do ciclo.

**3. A RPC resolve `questionario_id` por `empresas.questionario_id`** — um questionário *por
empresa*, enquanto a metodologia é *por ciclo*. Precisa passar a resolver pelo ciclo.

Constraints atuais confirmados: `resposta_itens_valor_check` = `valor >= 1 AND valor <= 4`;
`questoes_bloco_check` = `A|B|C|EXTRA`. Volume PROD: 27 questões, 249 respostas, 6.723 itens
(= 249 × 27 exato, sem órfãos) — migration segura.

Outros fatos úteis verificados: `anon` **não** tem policy de INSERT em `resposta_itens` (o único
caminho público é a RPC `SECURITY DEFINER`); `pub_read_questoes` = `USING (true)` e
`pub_read_ciclos` já existe, então o form público lê `ciclos.metodologia` **sem policy nova**.

---

## 5. Fase 0 — Percentis (RESOLVIDA — resultado negativo, 2026-08-04)

**Extração feita, com resultado conclusivo: os percentis 20º/50º/80º não existem em
`analysistool.xls`.** Não é falha de acesso nem de parsing — o arquivo foi baixado
(4.339.712 bytes, íntegro), convertido e todas as **10 abas** foram inspecionadas
(`Before You Start`, `Raw Data`, `Last Years Data`, `2 Years ago Data`, `Question by Question`,
`Totals`, `Summary of Results`, `New Calculations Sheet` + 2 variantes de ano — as três últimas
estavam ocultas, e foram lidas mesmo assim). Varredura de toda a planilha por qualquer constante
decimal na faixa plausível (1,50–5,00) retornou **zero resultados**.

**O que o arquivo realmente é:** uma ferramenta de auto-comparação ano-a-ano para uma única
organização, não uma tabela de referência populacional. As abas de cálculo (`Totals`,
`New Calculations Sheet`) só têm fórmulas que leem `Raw Data`/`Last Years Data`/`2 Years ago Data`
— que estão vazias no arquivo distribuído — e por isso mostram um valor de erro constante (`42`)
em vez de qualquer norma fixa. Não há aba de benchmark nacional escondida — o pressuposto do
plano original (§ antiga "Fase 0") estava errado.

**Achado colateral que valida outra parte do plano:** a aba `Totals` reproduz o texto verbatim
dos 35 itens em inglês e o agrupamento por dimensão — **bate exatamente** com o mapeamento
item→dimensão já usado neste documento (§7), incluindo os 7 itens de Demandas, os 6 de Controle,
etc. Isso fecha com alta confiança o que era um risco de "derivado por eliminação" (ver §16,
item removido do backlog).

**Conclusão prática:** os cortes de percentil do esquema oficial de 4 cores (vermelho/âmbar/
azul/verde) não são recuperáveis desta fonte. Não há evidência de que estejam publicados em
texto em nenhum lugar — a busca de 2026-08-03 já não os tinha encontrado em PDF, e agora a
suposta fonte "elas estão numa planilha" também não se confirma. **A classificação por bandas
relativas à média (`calcDimensoesHSE`, §9.3, passo 5) deixa de ser fallback e passa a ser o
método primário e único**, usando o benchmark 2023 (Min/Média/Máx, 39.484 respondentes, fonte
já confirmada em texto) como referência. O schema em §6.3 já suporta isso sem alteração —
`hse_benchmark.p20/p50/p80` simplesmente ficam `NULL` permanentemente, não como estado transitório.

Em **qualquer** cenário, seedar as 13 médias setoriais de 2023 — essas são reais e citáveis.

---

## 6. Banco — `migration_metodologia_hse_icao35.sql`

Arquivo idempotente na raiz, ao lado de `migration_tenant_modulos.sql`. **DEV primeiro, validar,
depois PROD** — e comparar `pg_policies` / `pg_constraint` / `pg_proc` nos dois bancos ao final
(CLAUDE.md §Divergências: não confiar nos `.sql` do repo).

### 6.1 Onde vive `metodologia`

| Tabela | Coluna | Papel | Por quê |
|---|---|---|---|
| `ciclos` | `metodologia TEXT NOT NULL DEFAULT 'BS8800'` | **fonte da verdade** | Ciclo já é o escopo temporal canônico (regra 5) e já é filtro de 1ª classe em `rodarAnalise`. |
| `respostas` | `metodologia TEXT NOT NULL DEFAULT 'BS8800'` | **snapshot imutável** | `respostas.ciclo_id` é nullable com `ON DELETE SET NULL` — apagar o ciclo tornaria a resposta ininterpretável. Também evita JOIN na análise. |
| `questoes` | `metodologia`, `dimensao TEXT`, `escala_max SMALLINT NOT NULL DEFAULT 4`, `escala_labels TEXT`, `direcao TEXT NOT NULL DEFAULT 'alto_ruim'` | catálogo | `dimensao` = `DEMANDS`…`CHANGE`; `escala_labels` = `'freq'` \| `'concord'`; `direcao` = `'alto_bom'` \| `'alto_ruim'`. |
| `questionarios` | `metodologia` | rotulagem | Permite a RPC resolver o questionário certo. |
| `links_coleta` | **nada** | — | Herda do ciclo. Aqui criaria 2ª fonte da verdade e a chance de link HSE em ciclo BS 8800. |

`CHECK (metodologia IN ('BS8800','HSE_ICAO35'))` nas quatro. **Sem tabela `metodologias`** — duas
linhas não justificam.

**Ajuste incorporado a partir da análise do COPSOQ (§14):** a coluna `direcao` vive em `questoes`,
não em `questionarios` — porque a pesquisa do COPSOQ revelou que a direção da escala (alto=bom ou
alto=ruim) é uma propriedade **por dimensão**, não por instrumento inteiro. Hoje, com só BS 8800
(sempre `alto_ruim`) e HSE (sempre `alto_bom`), o valor é constante dentro de cada metodologia — o
seed grava a mesma direção em todas as linhas daquele instrumento e nada no motor de cálculo muda.
O ganho é evitar uma segunda migration em `questoes` se o COPSOQ avançar algum dia, sem adicionar
lógica nova agora: é dado, não comportamento — os motores de cálculo continuam um por metodologia,
cada um lendo a direção da própria questão em vez de assumir um sinal fixo no código.

### 6.2 Relaxar os CHECKs sem afrouxar a validação

```sql
ALTER TABLE resposta_itens DROP CONSTRAINT resposta_itens_valor_check;
ALTER TABLE resposta_itens ADD CONSTRAINT resposta_itens_valor_check CHECK (valor BETWEEN 1 AND 5);
```

CHECK não aceita subquery, então o limite real por questão vira trigger:

```sql
CREATE OR REPLACE FUNCTION fn_valida_escala_item() RETURNS TRIGGER AS $$
DECLARE v_max SMALLINT;
BEGIN
  SELECT escala_max INTO v_max FROM questoes WHERE id = NEW.questao_id;
  IF v_max IS NULL THEN RAISE EXCEPTION 'questao_inexistente: %', NEW.questao_id; END IF;
  IF NEW.valor < 1 OR NEW.valor > v_max THEN
    RAISE EXCEPTION 'valor_fora_da_escala: % (esperado 1..% na questao %)', NEW.valor, v_max, NEW.questao_id;
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER tg_valida_escala_item BEFORE INSERT OR UPDATE ON resposta_itens
  FOR EACH ROW EXECUTE FUNCTION fn_valida_escala_item();
```

Custo: 1 lookup por PK por item (27 ou 35 por submissão). **A validação fica mais forte que hoje** —
`valor=5` numa questão BS 8800 passa a falhar em voz alta, o que hoje não acontece.

**`questoes.bloco` — estender com UM valor só, não com as 7 dimensões.** `bloco` alimenta o
agrupamento visual do admin (`renderQuestoes` itera `['A','B','C','EXTRA']` e indexa `BLOCOS_INFO`
em `psicomap-admin.html:4037`); 7 valores novos criariam 7 grupos quebrados.

```sql
ALTER TABLE questoes DROP CONSTRAINT questoes_bloco_check;
ALTER TABLE questoes ADD CONSTRAINT questoes_bloco_check
  CHECK (bloco IN ('A','B','C','EXTRA','HSE'));
```

As dimensões vão em `questoes.dimensao`.

### 6.3 Tabela de benchmark

```sql
CREATE TABLE IF NOT EXISTS hse_benchmark (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fonte TEXT NOT NULL,                      -- 'HSE_ANALYSISTOOL' | 'HSE_2023'
  fonte_ano INT,
  setor TEXT NOT NULL DEFAULT 'GERAL',
  dimensao TEXT NOT NULL CHECK (dimensao IN
    ('DEMANDS','CONTROL','MANAGER_SUPPORT','PEER_SUPPORT','RELATIONSHIPS','ROLE','CHANGE')),
  media NUMERIC(4,2), p20 NUMERIC(4,2), p50 NUMERIC(4,2), p80 NUMERIC(4,2),
  n_amostra INT, vigente BOOLEAN NOT NULL DEFAULT true, observacao TEXT,
  criado_em TIMESTAMPTZ DEFAULT now(),
  UNIQUE (fonte, setor, dimensao)
);
CREATE INDEX IF NOT EXISTS idx_hse_bench_lookup ON hse_benchmark(vigente, setor, dimensao);

ALTER TABLE hse_benchmark ENABLE ROW LEVEL SECURITY;
CREATE POLICY pub_read_hse_benchmark      ON hse_benchmark FOR SELECT USING (true);
CREATE POLICY super_admin_write_hse_bench ON hse_benchmark FOR ALL
  USING (is_super_admin()) WITH CHECK (is_super_admin());
```

RLS espelha exatamente o padrão de `pub_read_questoes` + `super_admin_write_questoes` já verificado
em PROD. Sem `tenant_id` — benchmark é referência externa universal.

### 6.4 Corrigir `salvar_resposta` — `CREATE OR REPLACE`, sem overload novo

Três mudanças cirúrgicas na assinatura de 10 args (base: `supabase_security_migrations.sql:47-186`):

```sql
-- (a) metodologia e questionário resolvidos pelo CICLO
SELECT c.metodologia INTO v_metodologia FROM ciclos c WHERE c.id = p_ciclo_id;
v_metodologia := COALESCE(v_metodologia, 'BS8800');
SELECT id INTO v_questionario_id FROM questionarios
 WHERE metodologia = v_metodologia AND (empresa_id = p_empresa_id OR empresa_id IS NULL)
 ORDER BY (empresa_id IS NOT NULL) DESC LIMIT 1;
IF v_questionario_id IS NULL THEN
  SELECT questionario_id INTO v_questionario_id FROM empresas WHERE id = p_empresa_id;
END IF;

-- (b) INSERT INTO respostas (..., metodologia) VALUES (..., v_metodologia);

-- (c) validar e FALHAR EM VOZ ALTA — não filtrar
IF EXISTS (SELECT 1 FROM jsonb_array_elements(p_itens) it
             JOIN questoes q ON q.id = (it->>'questao_id')::uuid
            WHERE (it->>'valor')::int NOT BETWEEN 1 AND q.escala_max)
THEN RAISE EXCEPTION 'valor_fora_da_escala'; END IF;

INSERT INTO resposta_itens(resposta_id, questao_id, valor)
SELECT v_resposta_id, (item->>'questao_id')::uuid, (item->>'valor')::int
FROM jsonb_array_elements(p_itens) AS item;   -- sem WHERE
```

O `EXCEPTION WHEN OTHERS` existente já marca `respostas_fila` como erro e re-`RAISE` — a falha fica
auditável e o form cai no retry + backup localStorage. O `DROP` do overload morto de 9 args fica
para a PR 8, depois de o novo comportamento rodar em PROD.

---

## 7. Seed das 35 questões ICAO-35

```sql
INSERT INTO questionarios (id, nome, empresa_id, metodologia, ativo)
VALUES ('00000000-0000-0000-0000-000000000002',
        'HSE Management Standards — ICAO-35', NULL, 'HSE_ICAO35', true)
ON CONFLICT (id) DO NOTHING;
```

**Mapeamento item → dimensão** (fecha em 35, sem sobreposição):

| Dimensão | Nº | Itens |
|---|---|---|
| DEMANDS | 8 | 3, 6, 9, 12, 16, 18, 20, 22 |
| CONTROL | 6 | 2, 10, 15, 19, 25, 30 |
| MANAGER_SUPPORT | 5 | 8, 23, 29, 33, 35 |
| PEER_SUPPORT | 4 | 7, 24, 27, 31 |
| RELATIONSHIPS | 4 | 5, 14, 21, 34 |
| ROLE | 5 | 1, 4, 11, 13, 17 |
| CHANGE | 3 | 26, 28, 32 |

> ⚠️ Demands e Control foram confirmados textualmente na fonte primária; os demais foram derivados
> por eliminação e conferidos um a um contra o texto verbatim de cada item. Fecha em 35 sem colisão.
> **Reverificar contra o `analysistool.xls`** junto com a extração dos percentis (Fase 0).

**Regras do seed:**
- `inversa = true` **exatamente** nos 12 itens de DEMANDS ∪ RELATIONSHIPS — a regra é por dimensão
  inteira, não por item avulso.
- `escala_labels = 'freq'` para H01–H23; `'concord'` para H24–H35.
- `escala_max = 5`, `bloco = 'HSE'`, `metodologia = 'HSE_ICAO35'`.
- `fator_id` recebe a dimensão (é `NOT NULL` e não tem semântica no caminho HSE).
- `is_ancora = false` em todas — o instrumento é fechado; marcar âncora implicaria "as outras podem
  ser removidas".
- Vincular ao questionário `…0002` em `questionario_questoes` com `ordem = 1..35`.

### Dois detalhes que evitam regressão silenciosa

**1. Seedar com `is_oficial = false`.** Todas as leituras do catálogo no caminho legado filtram
`.eq('is_oficial', true)` — `psicomap-admin.html:4162`, `:7649`, `:10341` e `psicomap-forms.html:351`.
Com `is_oficial=false`, as 35 questões HSE ficam invisíveis para o caminho antigo **sem alterar uma
única linha dessas queries**. `metodologia` é o discriminante semântico e deve ser usado nas queries
novas; `is_oficial=false` é *shim* de compatibilidade. **Documentar na migration e no CLAUDE.md** —
senão alguém "corrige" para `true` em seis meses e quebra tudo em silêncio.

**2. Códigos `H01`…`H35`, nunca `Q28`+.** `loadRespostasParaEmpresa` (`psicomap-admin.html:7653`) faz
`parseInt(codigo.replace('Q',''))` e `psicomap-forms.html:353` idem. `Q28` colidiria com o espaço de
índices do BS 8800. `parseInt('H01')` → `NaN` (filtrado); o mapa HSE usa `replace('H','')`.

**Texto dos itens:** usar a tradução validada da Escala ICAO (RPOT 20(3):1141-1149, 2020). Se ela não
estiver em mãos, **atrasar a PR do seed** — texto de instrumento psicométrico validado não se
reescreve sem invalidar a comparabilidade com o benchmark.

---

## 8. Formulário — `psicomap-forms.html`

### 8.1 Manter literal, não carregar do banco

Contra a tentação de usar a view `v_questoes_empresa` (`psicomap-schema-v3.sql:202-221`, criada e
nunca usada): ela resolve o questionário por `COALESCE(e.questionario_id, '…0001')` — **por empresa**,
enquanto a metodologia é **por ciclo**. Estruturalmente não expressa "empresa X, ciclo Y, instrumento
HSE". Além disso, o form público é o componente com maior superfície de falha (rede móvel); hoje o
texto é 100% offline e só o mapa de UUIDs vai à rede, com retry. Trocar texto por fetch adiciona ponto
de falha onde o custo é maior. O CLAUDE.md já normatiza o custo da duplicação (§Gotchas) — **estender**
essa nota, não inventar um terceiro padrão.

Do banco vem só a metodologia do ciclo — 1 campo, na query que o form já faz.

### 8.2 Mudanças

**a) Ler a metodologia** — `psicomap-forms.html:447-451`, acrescentar embed:
```js
.select('empresa_id, setor_sugerido, ciclo_id, ativo, expira_em, permite_multi_resposta,
         empresas(id, nome, logo_base64), ciclos(id, metodologia)')
```
Depois de `:482`: `metodologia = linkData.ciclos?.metodologia || 'BS8800';`
A policy `pub_read_ciclos` já existe — nenhuma policy nova é necessária.

**b) Tabela de instrumentos**, ao lado de `BLOCOS`/`LABELS`, **sem tocá-los** (ficam byte-idênticos):
```js
const LABELS_FREQ_5    = ['Nunca','Raramente','Às vezes','Frequentemente','Sempre'];
const LABELS_CONCORD_5 = ['Discordo totalmente','Discordo','Neutro','Concordo','Concordo totalmente'];
const BLOCOS_HSE = [ /* 7 dimensões; questões {id, texto, inv, lbl:'freq'|'concord'} */ ];
const INSTRUMENTOS = {
  BS8800:     { blocos: BLOCOS,     total: 27, escalaMax: 4, prefixo: 'Q', labels: () => LABELS },
  HSE_ICAO35: { blocos: BLOCOS_HSE, total: 35, escalaMax: 5, prefixo: 'H',
                labels: q => q.lbl === 'concord' ? LABELS_CONCORD_5 : LABELS_FREQ_5 },
};
let instr = INSTRUMENTOS.BS8800;
```

**c) Seis generalizações triviais:**

| Local | Hoje | Depois |
|---|---|---|
| `buildQuestoes:752` | `BLOCOS.forEach` | `instr.blocos.forEach` |
| `:767` | `[1,2,3,4].map(…${LABELS[i]})` | `Array.from({length:instr.escalaMax},(_,i)=>i+1).map(…${instr.labels(q)[i]})` |
| `updateProgress:792` | `const total = 27` | `const total = instr.total` |
| `coletarRespostas:808` | `BLOCOS.flatMap` | `instr.blocos.flatMap` |
| `_validarItens:835` | `valor <= 4` | `valor <= instr.escalaMax` |
| `:935` | `v>=1 && v<=4` | `v>=1 && v<=instr.escalaMax` |
| `carregarMapaQuestoes:348-355` | `.eq('is_oficial',true)`, `replace('Q','')` | `.eq('metodologia', metodologia)`, `replace(instr.prefixo,'')` |

**d) ⚠️ Ordem de boot.** `init()` chama `carregarMapaQuestoes()` **antes** de resolver o token (`:429`).
Como o mapa agora depende da metodologia, **mover a chamada** para depois de `:482` e antes de
`showForm()`. O retry em `:877-885` continua válido porque `metodologia` já é global ali.

**e) CSS.** Cinco opções em 360 px é o risco visual real. `.q-scale` com
`grid-template-columns: repeat(var(--n-opts),1fr)` e `--n-opts` inline; classe `.q-scale--5` com
`.q-opt-lbl { hyphens:auto; word-break:break-word; font-size:9px }` (os rótulos de concordância são
longos).

**f) Janela de 6 meses.** Cabeçalho do instrumento acima do 1º bloco, **só no caminho HSE**:
"As perguntas a seguir referem-se aos **últimos 6 meses** de trabalho."

### 8.3 ⚠️ Gotcha do `build.js`

`build.js:59-66` substitui as credenciais por **regex de conteúdo**, não por número de linha. Portanto
**inserir código acima ou abaixo das linhas 333-334 é seguro**. O que quebra em silêncio: usar aspas
duplas ou template literal, quebrar a declaração em várias linhas, ou trocar `const` por `let`.
**Regra da PR: as linhas 333-334 não podem aparecer no diff.** A falha é silenciosa — o build passa e
o DEV serve o Supabase de PROD.

---

## 9. Motor de cálculo HSE — `psicomap-admin.html`

Bloco novo logo **depois** de `calcFatores` (após `:6506`). Nada acima é tocado.

### 9.1 Generalizar a carga de dados (a única concessão no caminho legado)

`loadRespostasParaEmpresa` (`:7638-7698`) não calcula nada — pivota `resposta_itens` para `r.q`.
Duplicá-la significaria duplicar cache, exclusão de links de teste e a normalização
`setor||'Geral'` / `funcao||'—'`, que tem comentário explícito de alinhamento crítico com os combos
em `:5352-5355`. Generalizar custa 3 linhas:

```js
async function loadRespostasParaEmpresa(empresaId, metodologia = 'BS8800') {
  const cacheKey = metodologia + '|' + empresaId;          // R12
  const prefixo  = metodologia === 'HSE_ICAO35' ? 'H' : 'Q';
  const { data: qs } = await sbAdmin.from('questoes')
    .select('id, codigo, dimensao, inversa, escala_max, direcao')
    .eq('metodologia', metodologia);      // substitui .eq('is_oficial', true) — linha 7649
  … parseInt(q.codigo.replace(prefixo, '')) …
  // e no select de respostas: .eq('empresa_id', empresaId).eq('metodologia', metodologia)
}
```

`getLinhasParaAnalise(empresaId, metodologia)` idem. O default mantém **todos** os call-sites atuais
sem edição, e o formato `r.q = {int: valor}` é preservado.

### 9.2 Contrato de retorno

```js
/** Motor HSE. Direção: ALTO = MELHOR. Inversão: (escalaMax+1) - v. Score = média aritmética.
 *  NÃO é intercambiável com calcFatores() — vocabulários e direções opostos. */
function calcDimensoesHSE(linhas, opts = {}) → {
  meta: { n, headcount, taxaResposta, indicativo /* true se <0.5 */,
          amostraMinima: { exigida, atingida },
          benchmark: { fonte, ano, setor, temPercentis }, metodologia: 'HSE_ICAO35' },
  dimensoes: [{
    id: 'DEMANDS', nome: 'Demandas', n_itens: 8, n_itens_efet: 8, n,
    score: 3.42,
    scoreItens: [{ codigo:'H03', texto, inv:true, media:3.1, dist:{1..5}, n }],
    faixa: 'AMBAR', faixaLabel: 'Necessidade clara de melhoria', faixaAcao, cor,
    ref: { p20, p50, p80, media, fonte }, gapVsMedia: +0.17, percentilAprox: 34
  }, … 7 ]
}
```

### 9.3 Algoritmo

1. Por item: `v = inv ? (escalaMax + 1 - r.q[i]) : r.q[i]` — **derivar de `escalaMax + 1`, nunca
   literal `6`** (evita o copy-paste de `5−v` do `calcFatores`).
2. `mediaItem = Σv / n_do_item`.
3. `score = Σ mediaItem / n_itens_efetivos` — **média das médias**, casando com a escolha já feita em
   `calcFatores` (`Nefetivo = distQuestoes.length`, `:6468`). Documentar no cabeçalho.
4. **Com percentis:** `< p20 → VERMELHO` · `< p50 → ÂMBAR` · `< p80 → AZUL` · senão `VERDE`.
5. **Sem percentis (fallback):** `< media−0.50 → VERMELHO` · `< media → ÂMBAR` · `< media+0.40 → AZUL`
   · senão `VERDE`. Com `temPercentis=false`, o laudo imprime a ressalva.
6. `taxaResposta = n / Σ empresa_headcount.quantidade`; vazio → `null` + nota "sem headcount
   cadastrado".

**Rótulos das 4 faixas:** Ação urgente · Necessidade clara de melhoria · Bom, mas há o que melhorar ·
Muito bem.

### 9.4 Despacho — 3 pontos, nada mais

`rodarAnalise` (`:5382`), logo após `:5386`:
```js
const metodologia = _metodologiaDoFiltro();
if (metodologia === 'HSE_ICAO35') return rodarAnaliseHSE({ emp, cicloId, setores, funcoes });
```

`_metodologiaDoFiltro()`: com ciclo selecionado, usa `c.metodologia`. Com "Todos os ciclos" numa
empresa que tem ciclos de **ambas** as metodologias → `alert-y` *"Selecione um ciclo — esta empresa
tem ciclos de metodologias diferentes"* e retorna. **Misturar metodologias na mesma análise deve ser
bloqueado, não silenciado** — é o caso de borda que mais provavelmente geraria laudo errado ao cliente.

Os outros 9 consumidores de `calcFatores` (`renderViewGrafica`, `renderViewRisco`, `renderGraficos`,
`renderComparativo`, `renderPlanoAcao`, `exportarCSV`, `renderTelaAuditoria`, …) **não são tocados** —
ficam inalcançáveis no caminho HSE nesta fase.

**Hook comercial (1 linha na fase 2):** acrescentar `{ id:'hse', … }` a `MODULOS_CATALOGO`
(`:4019`). Nesta entrega, só o comentário + `data-modulo="hse"` no seletor de metodologia —
`aplicarModulos()` age por `[data-modulo]`, então o gate liga sozinho quando quisermos. **Não** entra
em `MODULO_POR_TELA` (não é tela).

---

## 10. Análise e laudo

### 10.1 Tela de análise — reaproveitar a casca, trocar o miolo

**Não** criar `sc-analise-hse`. Renderizar em `#resultado-panel`, na mesma tela `analise`. Isso
preserva de graça: seletores de empresa/ciclo, combos com a normalização crítica de `:5352-5355`,
RBAC de `goScreen`, gate de módulos e `_esconderElementosModulos()`.

- **Reaproveitar:** `.card`, `.alert`, `.tag`, `.risk-badge`, `agruparPorGrupos()`, toggle
  "Por setor / Geral".
- **Não reaproveitar:** `combo-nivel` (níveis BS 8800 — ocultar), toggle "Por risco / Por questão",
  `NIVEIS_CORES`.

`renderAnaliseHSE` produz:
1. Cabeçalho com `n`, taxa de resposta e **badge vermelho + "dados apenas indicativos"** quando <50%.
2. Barras horizontais 1→5 com as 3 marcas de percentil sobrepostas — mais legível que radar e sem
   biblioteca nova.
3. Tabela dimensão · score · faixa · média de referência · gap · nº de itens, **ordenada por score
   crescente** (pior primeiro — inverso de `calcFatores`).
4. Drill-down por item, colapsável.

**Paleta fixa do padrão HSE:** VERMELHO `#d32f2f` · ÂMBAR `#f9a825` · AZUL `#1976d2` ·
VERDE `#2e7d32`. **Nunca reusar `NIVEIS_CORES`** — os significados são opostos e reutilizá-las
convida ao erro de leitura.

### 10.2 Laudo — `_buildLaudoHSEHTML`

`renderLaudo` (`:8651`) despacha após resolver `emp`/`linhas`.

**Reaproveitar integralmente:** `_barPrint()` / `gerarLaudoPDF()`; CSS `.laudo-preview`,
`.laudo-section`, `.laudo-sec-title`, `.metodologia-block`; branding via `_estPerfil.nome_empresa`
e `estPerfil?.nome_empresa || 'PsicoMap'` (regra do CLAUDE.md); bloco LGPD; responsável técnico;
persistência em `laudos.snapshot_json` (`:9003`); e o mecanismo `laudoSecoesAtivas` — porém com
catálogo próprio `LAUDO_SECOES_HSE` (`capa`, `metodologia_hse`, `amostra`, `resultados_dimensoes`,
`interpretacao`, `itens`, `recomendacoes`, `referencias`), trocando o `Set` conforme a metodologia.
**Não misturar as duas listas no mesmo `Set`.**

**Do zero (~150-200 linhas, não 450):**
- Seção metodologia HSE: 7 Management Standards, escala 1–5, direção alto=bom, os 4 níveis de ação,
  origem do benchmark. **Nenhuma linha da prosa BS 8800 de `:9027-9484` é aproveitável** — ela fala de
  P×S, severidade, matriz e conduta administrativa; adaptar deixaria jargão errado no laudo do cliente.
- Seção amostra: `n`, headcount, taxa de resposta, tabela de amostra mínima por porte, e selo
  **"dados apenas indicativos"** em destaque quando a taxa for <50%.
- Tabela + gráfico das 7 dimensões.
- Recomendação de **grupos focais** como etapa seguinte.
- **Rodapé fixo obrigatório** (OGL v3.0 + © Crown copyright), **sem o logo do HSE**.
- Referência: Escala ICAO, RPOT 20(3):1141-1149, 2020.
- Se `temPercentis === false`, parágrafo explicando as bandas derivadas.

⚠️ A capa tem **`Metodologia Mulhausen & Damiano / BS 8800` hardcoded em `:8687`** — trocar por
"HSE Management Standards / Escala ICAO-35" no caminho HSE. É o tipo de detalhe que vaza para o
cliente.

---

## 11. Sequência de PRs

Antes de começar: `git log origin/develop..origin/main --oneline` e, se preciso,
`git push origin origin/main:develop` (CLAUDE.md — `develop` já ficou 31 commits atrás sem aviso).
Usar a skill `/commitar-e-pr` em cada passo. **Invariante: PROD funcional após cada merge; nenhuma PR
sozinha muda o comportamento do caminho BS 8800.**

**Runbook da PR 1 em PROD** (ver §12.1): (a) confirmar PITR ativo no Dashboard Supabase antes de
aplicar; (b) aplicar fora de janela de coleta ativa de cliente — o sistema está recebendo
respostas reais continuamente; (c) a `ALTER TABLE` é rápida no volume atual (~7.800 linhas em
`resposta_itens`), mas ainda assim não rodar durante pico de submissões.

| # | PR | Conteúdo | Risco | Por que PROD continua ok |
|---|---|---|---|---|
| 1 | `migration: metodologia + escala HSE` | Colunas, relaxamento dos 2 CHECKs, trigger `fn_valida_escala_item`, `hse_benchmark` + RLS. Sem seed, sem JS. | Baixo | Defaults `'BS8800'`/`4`; nada no front lê as colunas novas; o trigger só endurece. |
| 2 | `fix: salvar_resposta não descarta valores fora da escala` | `CREATE OR REPLACE`. Sem drop do overload. | **Alto** — pipeline de submissão | `/validar-formulario` em DEV **e** PROD; testar com link `is_teste=true`. **Merge isolado.** |
| 3 | `seed: 35 questões placeholder + questionário + benchmark` | Seed **só em DEV** (ver §11.1), `is_oficial=false`, `H01–H35`. | Baixo | Nunca aplicado em PROD nesta fase — não há o que quebrar. |
| 4 | `feat(admin): seletor de metodologia no ciclo` | `abrirModalCiclo:11314`, `renderCiclosModal:11354`, `salvarCiclo:11402` (incluir `metodologia` no `.select()` de retorno — gotcha "campo some até recarregar"), `carregarCiclos:4739`. | Baixo | Dirigido por banco, sem texto — pode ir a `main`. Ciclos existentes viram `'BS8800'`. |
| 5 | `feat(forms): instrumento HSE 35 itens, escala 1–5` | §8 completo. Linhas 333-334 intocadas. | Médio-alto + **conteúdo** (ver §11.1) | Fica em `develop` até B1 resolver — texto vive hardcoded no JS, não no banco. |
| 6 | `feat(admin): motor + tela de análise HSE` | `calcDimensoesHSE` + `renderAnaliseHSE` + despacho. | Médio | Dirigido por banco. Tecnicamente poderia ir a `main`, mas ver §11.1 — recomendado manter em `develop` junto com o resto da Camada 1. |
| 7 | `feat(admin): laudo HSE` | `_buildLaudoHSEHTML` + `LAUDO_SECOES_HSE`. | Baixo | Idem PR 6 — só alcançável por ciclo HSE, que só existe em DEV nesta fase. |
| 8 | `chore: remove overload morto` + `docs: CLAUDE.md` | `DROP FUNCTION salvar_resposta(…9 args)` + documentação. | Baixo | Só depois de 2 e 5 rodarem em PROD por um ciclo real. |

PRs 1–2 podem ir a PROD imediatamente — são inertes e independentes de conteúdo. PRs 3–7 formam
um único pacote de conteúdo (ver §11.1) e ficam represados em `develop` até B1 resolver.

### 11.1 Desacoplar engenharia de conteúdo (decisão de 2026-08-04)

A pedido do usuário: adiantar todo o trabalho técnico (schema, motor de cálculo, telas, laudo)
usando texto placeholder para as 35 questões, deixando a troca pelo texto validado da ICAO-35
(B1) como o último passo antes de ir ao ar — em vez de B1 travar o início da programação.

**Por que isso funciona:** o motor de cálculo (`calcDimensoesHSE`, §9) nunca lê o conteúdo da
questão — só `dimensao`, `inversa`, `escala_max`, `direcao`. A tela de análise e o laudo puxam
`questoes.texto` do banco em tempo de consulta. Nada disso depende de o texto estar correto para
funcionar ou ser testado.

**Onde a separação limpa quebra — e por que só um PR fica retido:** ao contrário do admin, o
formulário público (`psicomap-forms.html`) mantém as questões **literais no JavaScript**
(`BLOCOS_HSE`, decisão de §8.1, para funcionar offline em celular sem depender de fetch). Isso
significa que o texto das 35 questões, nessa PR específica, fica **dentro do código-fonte
versionado** — e este repositório faz deploy automático de `main` para PROD. Mergear a PR 5 em
`main` com texto placeholder publicaria esse texto para funcionários reais no próximo deploy. Não
é um risco de seed de banco — é o próprio formulário público.

**Regra de execução:**
- PRs 1–2: sem mudança, seguem para `main`/PROD normalmente.
- PR 3 (seed): aplicar **só em DEV**. Nomear o arquivo de forma que não seja reaplicado em PROD
  por hábito (ex.: `seed_hse_icao35_dev_placeholder.sql`, não o nome final da migration). Texto
  placeholder marcado de forma inconfundível — ex.: prefixo `[RASCUNHO]` seguido do item original
  em inglês do HSE entre parênteses, nunca uma frase em português que possa passar por definitiva.
- PRs 4, 6, 7: código pode ser desenvolvido e revisado normalmente. Tecnicamente seguro mergear em
  `main` mesmo antes de B1 (são dirigidos por banco, e o catálogo HSE só existe em DEV nesta fase)
  — mas a recomendação é manter todo o pacote 3–7 junto em `develop`, para não expor no admin de
  PROD uma metodologia "selecionável" cujas telas seguintes ficam vazias por falta de seed. Isso
  é sobre experiência de uso, não sobre vazamento de dado.
- **PR 5 é a única com bloqueio real de merge para `main`** — fica em `develop` até o texto
  validado (B1) estar pronto.
- **Passo de go-live**, quando B1 resolver: substituir o texto placeholder (banco + `BLOCOS_HSE`)
  pelo texto validado num único PR de conteúdo, rodar `/validar-formulario` de novo, refazer o
  teste de aceite ponta-a-ponta (§12), e só então promover `develop` → `main`.

**CLAUDE.md (PR 8):** §Gotchas passa a "textos em **três** lugares" (`QS_OFICIAIS`, `BLOCOS`,
`BLOCOS_HSE`); seção nova "Metodologias" (direção invertida, onde vive `metodologia`, por que
`calcFatores` e `calcDimensoesHSE` **não** devem ser unificadas); o shim `is_oficial=false` com o
aviso de não "corrigir"; e anotar que a **regra de negócio 6 (score P×S) passa a valer só para
BS 8800**.

---

## 12. Riscos e verificação

| # | Risco | Como se manifesta | Teste |
|---|---|---|---|
| R1 | Valor 5 descartado em silêncio | Resposta HSE salva com 20–30 itens; nenhum erro em lugar nenhum; scores sobre dados truncados | PR 2 **antes** da 5. Enviar 35 itens com 4s e 5s em DEV e assertar 35 linhas em `resposta_itens`. Negativo: `valor=5` em `Q0x` deve levantar `valor_fora_da_escala`. |
| R2 | Colisão de índice de questão | `Q28`+ sobrescreve o espaço BS 8800; instrumentos se misturam | `select codigo from questoes where codigo ~ '^Q(2[89]\|[3-9][0-9])$'` → 0 linhas. |
| R3 | Overload ambíguo | `PGRST203` — form quebra 100% em PROD | Não adicionar parâmetro. Após PR 2, `pg_proc` deve seguir com exatamente 2 linhas (9 e 10 args). |
| R4 | Regex do `build.js` falha em silêncio | DEV aponta para o Supabase de PROD; testes contaminam a base real | `git diff psicomap-forms.html` na PR 5 **sem** as linhas 333-334. Pós-deploy DEV: DevTools deve mostrar `szqatgvgghxvyyncsjxl`. |
| R5 | Divergência DEV ↔ PROD | Funciona em DEV, quebra em PROD (precedente real no CLAUDE.md) | Comparar via MCP nos dois projetos: `pg_constraint` (os 2 CHECKs), `pg_policies` (`hse_benchmark`), `information_schema.triggers`, `pg_proc`. **Não confiar nos `.sql`.** |
| R6 | `session_id` `text` em DEV vs `uuid` em PROD | Teste passa em DEV, falha em PROD | `crypto.randomUUID()` (o form já usa). Item de `/validar-formulario`. |
| R7 | Metodologias misturadas na análise | "Todos os ciclos" com BS 8800 + HSE → scores sem sentido, laudo errado ao cliente | Bloqueio em `_metodologiaDoFiltro` + `.eq('metodologia',…)`. Teste: empresa com um ciclo de cada, "Todos os ciclos" → `alert-y`. |
| R8 | Direção invertida lida como a antiga | Score 4,2 pintado de vermelho, ou `NIVEIS_CORES` reaproveitado | Paleta separada. Dataset sintético todos=5 → 7 VERDE; todos=1 → 7 VERMELHO. |
| R9 | Inversão com `5−v` em vez de `6−v` | Scores ~1,0 fora do lugar; copy-paste plausível de `calcFatores` | Derivar de `escalaMax+1`. Teste: item invertido 1→5, 5→1, 3→3. |
| R10 | Percentis não extraídos | Classificação sem base oficial | Portão da Fase 0 + ressalva no laudo. Não bloqueia a entrega. |
| R11 | `.eq('is_oficial',true)` → `.eq('metodologia',…)` na linha 7649 | Análise BS 8800 vazia se a migration não rodou no ambiente | Contar respondentes na tela de análise antes/depois em DEV. **Único ponto legado com query alterada.** |
| R12 | Cache sem chave de metodologia | Trocar de ciclo mostra dados do instrumento anterior | Chave `metodologia+'\|'+empresaId`. Alternar ciclos e conferir o `n`. |

**`/validar-formulario` é obrigatório antes dos merges das PRs 2 e 5.** A comparação
`pg_policies` / `pg_constraint` / `pg_proc` entre DEV e PROD via MCP é o padrão de auditoria que já
pegou duas divergências reais neste repositório.

**Teste end-to-end de aceite (após PR 7):** criar empresa de teste em DEV com GHE e headcount →
criar ciclo com metodologia HSE → gerar link `is_teste=true` → responder 3 sessões pelo formulário
(35 itens, conferindo os dois conjuntos de rótulos) → abrir a tela de análise e conferir as 7
dimensões com as faixas de cor → gerar o laudo e verificar rodapé OGL, referência ICAO, ausência do
logo do HSE, e o selo "dados apenas indicativos". Depois, criar um ciclo BS 8800 na **mesma** empresa
e confirmar que a análise continua idêntica ao comportamento anterior e que "Todos os ciclos" bloqueia.

### 12.1 Verificação pré-implantação — reauditoria de PROD em 2026-08-04

Reaudito direto do banco de produção (não repetição do documentado em §4), para responder à
pergunta "há algo que impeça implantar isso com o sistema já rodando?" — e para checar que nada
mudou desde a auditoria de 2026-08-03.

**Sistema está ativo agora, não é uma foto parada.** Volume subiu de 249 → **288 respostas** e de
6.723 → **7.776 itens** em menos de 24h entre as duas auditorias. Contagem exata:
`288 × 27 = 7.776`, **zero órfãos**. Duas implicações: (1) o formulário atual está em uso real
neste momento — a migration deve ser agendada fora de janela de coleta ativa de algum cliente, não
só "quando der"; (2) a integridade referencial hoje é perfeita, e é essa integridade que a
migration precisa preservar, não recriar.

**Garantia estrutural contra perda de dado — verificada nas FKs reais de PROD, não presumida:**

| Relação | `ON DELETE` em PROD | Garantia |
|---|---|---|
| `resposta_itens.questao_id → questoes` | **`NO ACTION`** (sem FK de cascade) | O banco **recusa fisicamente** apagar qualquer uma das 27 questões atuais enquanto houver resposta histórica citando-a. Não depende de disciplina de código. |
| `respostas.questionario_id → questionarios` | **`NO ACTION`** | Mesma proteção para o questionário padrão. |
| `resposta_itens.resposta_id → respostas` | `CASCADE` | Pré-existente, não alterado por esta migration. |
| `respostas.empresa_id → empresas` | `CASCADE` | Pré-existente (é o hard-delete de empresa já documentado no CLAUDE.md como risco conhecido — não é introduzido por este plano). |

A migration de §6 só faz `ADD COLUMN ... DEFAULT` e troca a definição de dois `CHECK` — nenhuma
operação em `respostas`, `resposta_itens` ou nas 27 `questoes` atuais apaga, move ou reescreve
linha existente.

**Risco que constava como "a verificar" e foi descartado nesta reauditoria:** suspeita de um
caminho de importação de CSV gravando `resposta_itens` diretamente, fora da RPC — o que tornaria o
trigger `fn_valida_escala_item` (§6.2) um risco de quebrar um fluxo não mapeado. Busca no código e
`pg_proc` confirma: **não existe**. `fonte='import_csv'` está na `CHECK` da tabela desde a criação
do schema mas tem **0 linhas** em produção, e nenhuma função em `psicomap-admin.html` insere em
`resposta_itens` fora das duas assinaturas de `salvar_resposta`. Superfície de risco do trigger
menor do que o documentado em §6.2.

**Ponto técnico real de atenção — não é perda de dado, é janela de execução, e não estava no
plano original:** `ALTER TABLE ... DROP/ADD CONSTRAINT` toma lock `ACCESS EXCLUSIVE` breve em
`questoes` e `resposta_itens` durante a validação da constraint contra as linhas existentes. Com o
volume atual (27 e ~7.800 linhas, poucos MB), essa validação é da ordem de milissegundos — não é
risco de indisponibilidade prolongada. Ainda assim, **aplicar a migration fora de horário de pico
de resposta de algum cliente**, nunca durante uma campanha de coleta ativa — vira item explícito do
runbook da PR 1.

**Dependência que não pode ser verificada por consulta SQL:** confirmar manualmente no Dashboard do
Supabase que o **PITR (point-in-time recovery)** está ativo no projeto PROD
(`vftyiildukrpgmnbcnao`) antes de rodar qualquer migration ali — mesmo sendo, por desenho,
não-destrutiva. É rede de segurança padrão, não um passo que a migration "não precisar" dispensa.

**Reconfirmado sem drift desde 2026-08-03:** os dois `CHECK` (`resposta_itens_valor_check`,
`questoes_bloco_check`) são idênticos em DEV e PROD; DEV segue com volume trivial (2 respostas,
54 itens) e livre para testar sem risco.

---

## 13. Fase 3 (ideia registrada, não avaliada para execução) — "combo" de metodologias

Ideia trazida pelo usuário em 2026-08-03, via transcrição de áudio: em vez de o cliente escolher
**uma** metodologia por ciclo, oferecer um modo "combo" onde o formulário reúne as questões de
**todas** as metodologias contratadas (ex.: 27 do BS 8800 + 35 do HSE/ICAO + ~19 do COPSOQ —
Copenhagen Psychosocial Questionnaire, versão curta), o respondente preenche uma vez, e o sistema
calcula e apresenta os resultados de **cada** metodologia separadamente, lado a lado, para quem
monta o laudo comparar. Uma segunda variante da ideia — deduplicar perguntas semanticamente
parecidas entre metodologias, unificando-as num item só — foi levantada no mesmo momento.

**Explicitamente colocado pelo usuário como evolução futura, não para execução agora.** Registrado
aqui só para não perder o raciocínio.

### 13.1 Avaliação — concatenar questões e separar resultados (1ª variante)

**Compatível com a arquitetura já desenhada, sem violar a regra "nunca converter, nunca plotar no
mesmo eixo".** É importante notar a diferença em relação ao que já foi descartado: isso não
converte um score HSE em score P×S — coleta uma vez e roda os motores de cálculo em **paralelo**
sobre subconjuntos diferentes das respostas, cada um no seu próprio vocabulário e direção,
apresentados em blocos separados. Encaixaria no modelo de dados como um terceiro valor de
`metodologia` (ex. `COMBO_BS8800_HSE_COPSOQ`) cujo banco de questões é a união dos três, cada
questão mantendo a tag de qual motor a processa (`fk` para a metodologia de origem). No cálculo:
separar as respostas por origem e chamar `calcFatores` para o bloco BS 8800,
`calcDimensoesHSE` para o bloco HSE, e um terceiro motor `calcCopsoq` para o bloco COPSOQ — cada
um intocado. O laudo mostra as três seções lado a lado. **Não é uma nova álgebra, é orquestração.**

**O risco real não é técnico, é metodológico — fadiga de resposta.** Validação psicométrica
assume **condições padronizadas de aplicação**: o HSE foi validado com pessoas respondendo só
aquele questionário, o ICAO-35 também. Emendar 27 + 35 + ~19 = ~81 itens num formulário só
introduz fadiga de resposta — efeito documentado em pesquisa de survey, em que respondentes
tendem a marcar de forma mais automática/menos refletida nos blocos finais. Isso é
particularmente sensível aqui porque:

- O próprio HSE exige taxa de resposta mínima de 50% para os dados serem considerados
  confiáveis — questionário mais longo tende a reduzir tanto a taxa de resposta quanto a
  completude, não só a qualidade das respostas individuais.
- Se a fadiga distorcer as respostas do bloco que vem por último na sequência, o score deixa de
  ser comparável ao benchmark oficial daquele instrumento (39.484 respondentes para o HSE, por
  exemplo) — porque o benchmark não tem esse efeito de fadiga embutido. Perde-se comparabilidade
  justamente com o instrumento que só tem valor *por ser* comparável.

Isso não invalida a ideia — significa que ela tem um design real a resolver antes de virar
produto: ordem dos blocos (aleatorizar? fixar o mais curto por último?), permitir responder em
sessões separadas, ou — mais provável — posicionar o "combo" como um **produto de avaliação
anual/aprofundada**, distinto do ciclo recorrente leve de uma metodologia só. Não é "só juntar
as perguntas".

### 13.2 Avaliação — deduplicar perguntas similares entre metodologias (2ª variante)

**Não recomendado.** Estruturalmente pior do que o conversor de score já descartado no §3: um
conversor distorce a *interpretação* de um número já calculado; isso distorce o *instrumento* na
entrada. No momento em que se reescreve ou funde a redação de um item do HSE/ICAO com um item de
outra metodologia, ele deixa de ser o HSE/ICAO — vira um instrumento novo, não validado, e perde
de uma vez: o direito de citar o benchmark oficial, a validação psicométrica da ICAO
(RPOT 20(3), 2020), e a defensabilidade em auditoria que é justamente o motivo de oferecer HSE em
primeiro lugar. Mesmo problema do conversor, aplicado à coleta em vez do cálculo — só que sem
alternativa de reverter, porque o dado bruto já nasce contaminado.

### 13.3 Terceira metodologia mencionada: COPSOQ

Confirmado pelo usuário como a metodologia de ~19 questões citada na transcrição original.
Pesquisa antecipada concluída em 2026-08-03 — ver §14.

---

## 14. COPSOQ — análise antecipada (candidata a metodologia #3)

Pesquisa feita a pedido do usuário, com o mesmo rigor de fonte primária aplicado ao HSE. Fontes
lidas na íntegra: artigo de validação brasileira (Rev Saúde Pública/USP, 2021) e o guideline
oficial de licenciamento do COPSOQ III (rede internacional, 2021). Objetivo: identificar se há
algum impeditivo real, não decidir se entra no roadmap.

### 14.1 O número "~19 itens" não corresponde a nenhuma variante confirmada

Não existe, em nenhuma fonte primária consultada (COPSOQ I, II ou III, qualquer idioma), uma
variante com exatamente 19 itens. O COPSOQ III não tem versão curta fixa internacionalmente — o
guideline oficial é explícito: *"CORE items can never stand alone and DO NOT constitute a SHORT
version of COPSOQ"* — cada país define a própria versão curta, com contagens vistas de 23 a 44
itens conforme o idioma. **A versão relevante para o Brasil tem 40 itens**, não 19 (§14.3). Tratar
o número original como impreciso, não como requisito.

### 14.2 Existe validação brasileira publicada — e mais de uma, com escopos diferentes

- **Gonçalves, Moriguchi, Chaves & Sato (2021)**, *Rev Saúde Pública* 55:69 (USP, Qualis A) —
  validação da **versão curta do COPSOQ II para o Brasil**, amostra de 211 (teste) + 157
  (reteste). **Esta é a candidata natural** para o produto.
- Lima et al. (2019), *Work* 62(2) — versão **média** (70 itens, 13 dimensões), base na adaptação
  espanhola ISTAS21 II.
- Silva, Wendt & Argimon (2017), *REGE* 24 — versão curta do **COPSOQ I** (geração anterior,
  linhagem diferente), amostra de 1.615. Nomenclatura ambígua entre as fontes sobre se é
  "curta" ou "média" — não é a mesma linhagem do COPSOQ II-Br e não deveria ser misturada com ele.

Existência de validação com rigor acadêmico: **confirmada**. Escolha, se avançar: COPSOQ II-Br
curto (Gonçalves et al. 2021) — é a mais recente, mais próxima em desenho da ICAO-35 (mesma lógica
de tradução + retrotradução + EFA + Cronbach), e a mais citável.

### 14.3 Estrutura — COPSOQ II-Br curto

**40 questões, 11 dimensões em 7 domínios**, confirmado por EFA na amostra brasileira:

| Domínio | Dimensão | Itens | α de Cronbach |
|---|---|---|---|
| Demands at work | Demands at work | 6 | 0,76 |
| Work organization and content | Influence and development | 4 | 0,70 |
| | Meaning and commitment | 4 | 0,75 |
| Interpersonal relationships | Interpersonal relationships | 6 | 0,86 |
| | Leadership | 4 | 0,87 |
| Work-individual interface | Job satisfaction | 1 | — |
| | Work family conflicts | 2 | 0,86 |
| Values at the workplace | Values at the workplace | 4 | 0,85 |
| Health and wellness | General health | 1 | — |
| | Burnout and stress | 4 | 0,87 |
| Offensive behaviours | Offensive behaviours | 4 | **0,54 — abaixo do aceitável** |

### 14.4 Escala e itens invertidos

Likert de 5 pontos. Como o HSE, **múltiplos conjuntos de rótulos por família de item**
(frequência, intensidade, concordância/satisfação, saúde percebida, e um par binário sim/não +
"de quem" nos itens de assédio) — estruturalmente igual ao que já foi resolvido para o HSE, não é
atrito novo. Itens invertidos existem, mas são poucos: **apenas 1 na versão curta brasileira**
(item "1B", sobre tempo suficiente para tarefas).

### 14.5 Direção da escala — a mudança arquitetural real

**O COPSOQ não tem direção uniforme por instrumento — tem direção por dimensão**, confirmado
textualmente no guideline oficial: *"each scale is scored in the direction indicated by the scale
name"*. "Demandas", "Burnout e estresse" e "Conflito trabalho-família" → alto = pior. "Influência",
"Apoio social", "Sentido do trabalho", "Satisfação" → alto = melhor. **Isso é diferente tanto do
P×S (sempre alto=ruim) quanto do HSE/ICAO-35 já planejado (sempre alto=bom).** É a única mudança
real que a pesquisa do COPSOQ trouxe para a Camada 0 — incorporada em §6.1 como a coluna
`questoes.direcao`, sem reabrir o resto do desenho.

### 14.6 Cálculo do score

Dois métodos coexistem na literatura: soma dos itens (0–3/0–4/0–6/0–8 conforme o nº de itens) ou
média — o COPSOQ III internacional resolve isso mapeando cada opção de resposta direto para um
valor 0–100 na própria tabela de codificação, e o score da dimensão é a média desses valores.
**Não há score de risco global** — é deliberadamente multidimensional, sem índice composto, igual
ao HSE nesse ponto.

### 14.7 Classificação — mesmo risco documental do HSE

Existe um esquema conceitual de "farol" (verde/amarelo/vermelho) citado na literatura secundária,
mas **os valores de corte numéricos para a versão brasileira não foram localizados em texto** em
nenhuma fonte primária consultada — mesma situação do HSE, cujos percentis estão presos numa
planilha Excel não textual (§5). A própria rede internacional assume que a interpretação é
relativa a uma população de referência, não a cortes absolutos universais — só a norma dinamarquesa
original (Kristensen et al. 2005) tem ampla divulgação; uma tabela de referência brasileira
publicável não foi confirmada.

### 14.8 Licenciamento — sem impeditivo comercial, com uma restrição de marca análoga ao HSE

Fonte: *COPSOQ III License*, 18/ago/2021, assinada pelo Steering Committee da rede internacional.

- **CC BY-NC-ND 4.0 com exceção comercial explícita**: *"no fee can be charged for the use of the
  questionnaire per se, but fees for assessment, advice, analysis, training etc. are allowed"* —
  cobrar pela plataforma/laudo/análise é permitido; cobrar pelo questionário em si, não. Não é
  bloqueio para um SaaS.
- **Restrição de marca (ND — No Derivatives)**: se o conteúdo for adaptado/remixado (esperado, para
  integrar com a UI do produto), **o resultado não pode ostentar o nome "COPSOQ"** sem ficar fora
  da licença — mesmo problema já mapeado para o HSE com "Stress Indicator Tool" (§10.2), mas aqui
  os termos são explícitos por escrito.
- **Coordenação com a equipe nacional**: a licença pede contato com "a national COPSOQ team" antes
  de implementar, para evitar versões concorrentes no mesmo idioma — carga de governança, não
  barreira técnica ou financeira.
- Itens de *Work Engagement* (WE1-WE3, escala de terceiro — Triple i/Schaufeli-Utrecht) têm uso
  comercial restrito à parte, mas **não fazem parte da versão curta brasileira** — não afeta o
  escopo relevante aqui.

**Conclusão: nenhum impeditivo de licenciamento bloqueante.** O risco é de governança de nome e
fidelidade de conteúdo, da mesma família do que já existe para o HSE — não algo novo a resolver.

### 14.9 Comparação estrutural com o que já está planejado

| Eixo | HSE/ICAO-35 | P×S próprio | COPSOQ II-Br curto |
|---|---|---|---|
| Itens | 35 | 27 | 40 |
| Dimensões | 7 | — | 11 (em 7 domínios) |
| Escala | 1–5 | 1–4 × 1–4 | 1–5 |
| Direção | alto=bom (todo o instrumento) | alto=ruim (todo o instrumento) | **mista, por dimensão** |
| Agregação | média por dimensão | P×S por item → classificação | soma ou média (dois métodos na literatura) |
| Referência | percentil vs. banco nacional | faixas fixas 1–25 | farol citado; cortes numéricos não confirmados |
| Score global | não existe | existe por item | não existe |

O padrão de "motor por instrumento, despachado em poucos pontos" (§3) continua servindo — o
COPSOQ não pede um motor genérico, pede que o motor dele leia `direcao` por dimensão em vez de
assumir um sinal fixo, o que já está refletido no ajuste de §6.1.

### 14.10 Overlap — o argumento real para (ou contra) ter os três

**Sobreposição alta com o HSE** em risco de exposição: Demandas, Influência/Controle,
Relacionamentos/Liderança respondem por conceitos já cobertos pelo HSE. Se o objetivo fosse
"mais um instrumento de risco de exposição", o ROI de manter três motores em paralelo seria
questionável.

**O que o COPSOQ cobre que HSE e P×S não cobrem hoje** — este é o argumento que sustenta a
adição, se ela vier a acontecer:
- **Burnout e estresse** (sintoma autorreportado, não exposição) — categoria que o HSE evita por
  desenho.
- **Conflito trabalho-família**.
- **Satisfação no trabalho** e **saúde percebida geral**.
- **Comportamentos ofensivos** (assédio sexual, ameaça, violência física, bullying) — ausente do
  HSE e do P×S atual, potencialmente relevante para NR-1 e due diligence de compliance — mas é a
  dimensão com pior confiabilidade (α=0,54) e forte efeito piso (69% respondendo "nunca") na
  amostra brasileira, o que pede cautela na forma como seria comunicada num laudo.

### 14.11 Veredito da análise antecipada

**Nenhum impeditivo técnico, de licenciamento ou de validação foi encontrado.** O único ajuste que
a pesquisa exige na Camada 0 já foi incorporado (§6.1, coluna `direcao` em `questoes`). A decisão
de negócio real não é "dá para fazer" — é se o valor incremental (burnout, satisfação, assédio,
saúde percebida) justifica manter um terceiro motor de cálculo e uma terceira seção de laudo, dado
o overlap alto com o HSE nas dimensões de exposição a risco. Isso é uma decisão de portfólio, não
uma questão técnica — **não recomendo iniciar a implementação do COPSOQ agora**; a Camada 1 (HSE)
ainda não foi validada em produção, e é o teste real de que o padrão "motor paralelo por
metodologia" funciona no mundo real antes de replicá-lo uma terceira vez.

---

## 15. Análise de impacto

Cobre os efeitos da Camada 0 + Camada 1 (fundação + HSE, §4–§12) sobre o produto e a operação —
não repete os riscos técnicos já listados em §12, que são sobre correção; esta seção é sobre
consequência.

### 15.1 Impacto comercial

- **Upside real**: diferenciação frente a consultorias que hoje aplicam HSE/ICAO em papel ou
  Excel manualmente — migrar esse fluxo para o SaaS é um gancho de aquisição, não só de upsell
  para a base atual. A arquitetura de módulos já existente (`tenant_modulos`) permite precificar
  a metodologia como item separado a qualquer momento, sem mudança de schema.
- **Risco de canibalização de percepção**: se o HSE for apresentado como "mais científico" (é,
  de fato, um instrumento validado internacionalmente com benchmark de 39 mil respondentes), o
  cliente pode passar a enxergar a metodologia própria (BS 8800) como secundária. Isso não é um
  problema técnico — é um problema de **material de posicionamento**: precisa existir uma
  explicação comercial de quando usar cada uma (a ideia do fluxo sequencial do §3 — HSE
  diagnostica, P×S alimenta o inventário do PGR — é esse material, mas ainda não existe em forma
  vendável, só em raciocínio de arquitetura).
- **Escolha livre sem gate** (decisão já tomada) significa que, na prática, todo cliente ganha
  acesso ao HSE de graça na primeira entrega. Se a intenção for monetizar o HSE separadamente no
  futuro, o momento de ligar o gate importa: ligar depois que clientes já usaram de graça gera
  fricção de "downgrade" — vale decidir a estratégia de gate **antes** do lançamento, não depois.

### 15.2 Impacto técnico e de manutenção

- **O monólito cresce mais.** `psicomap-admin.html` já tem ~14,9 mil linhas / 847 KB sem
  bundler nem lazy load. A Camada 1 adiciona, por estimativa grosseira, ~1.200–1.800 linhas
  (motor de cálculo, tela de análise, laudo, textos de metodologia) — a Camada 1.1 (fase 2) e uma
  eventual Camada 3 (COPSOQ) adicionariam mais. Isso **não é causado** pela feature — é um
  problema estrutural pré-existente do produto — mas a feature o **acelera**. Vale que o time
  decida em algum momento se o monólito aguenta uma quarta metodologia sem dividir em módulos
  carregados sob demanda; não é bloqueio para a Camada 1.
- **Superfície de teste dobra.** Qualquer mudança futura em telas compartilhadas (RBAC, módulos
  por EST, exportações) passa a exigir verificação em pelo menos dois caminhos de metodologia,
  não um. Os 3 pontos de despacho (§9.4) limitam isso, mas não eliminam.
- **Blast radius da migration é o produto inteiro, não só o HSE.** A migration da Camada 0
  altera `resposta_itens` e `questoes` — tabelas usadas por **toda** submissão e toda leitura de
  questionário do sistema, incluindo o caminho BS 8800 em produção agora. Um erro na migration
  não é um bug isolado do módulo novo; é um incidente de produção geral. Justifica o cuidado do
  §11 (PRs 1–3 inertes antes de qualquer JS) e o §12 (R5, R11).
- **Dívida técnica deliberada, dependente de manutenção documental.** O shim `is_oficial=false`
  (§7) e a coluna `direcao` adicionada preventivamente (§6.1) só funcionam enquanto alguém souber
  por que existem. Ambos precisam permanecer documentados no CLAUDE.md (já previsto no item de PR
  8, §11) — o risco não é técnico, é de **conhecimento se perder** em uma reescrita futura por
  alguém sem este contexto.

### 15.3 Impacto operacional (equipe da consultoria, suporte)

- **Treinamento necessário antes do lançamento**: quem opera o painel (`admin`/`consultor`)
  precisa entender, na prática, por que um score HSE de 4,2 é bom e um score P×S de 4,2 (numa
  escala 1–25, hipotético) seria baixo — a inversão de direção é o erro de leitura mais fácil de
  cometer (já é o risco R8 do §12, do ponto de vista de teste; aqui é o mesmo risco do ponto de
  vista humano, não de código).
- **Dobra de superfície de suporte**: dúvidas de clientes finais sobre "por que essa metodologia
  dá números diferentes da outra" são esperadas e precisam de resposta pronta — a comparação do
  §3 é a base, mas precisa virar um material de apoio ao suporte, não ficar só neste documento
  técnico.

### 15.4 Impacto em UX e taxa de resposta

- Formulário HSE tem **35 itens contra 27 hoje** — sessão mais longa, tipicamente em celular,
  com risco de abandono maior que o caminho atual. Combinado com o requisito oficial do próprio
  HSE de taxa de resposta mínima de 50% para os dados serem válidos (§2), a taxa de conclusão
  real do formulário HSE deveria ser **monitorada explicitamente após o lançamento** — não é
  algo para assumir que "vai dar certo" só porque o BS 8800 funciona hoje com 27 itens.
- Se a Camada 2 (combo, §13) avançar algum dia, esse mesmo problema se agrava para ~80 itens —
  reforça a recomendação já registrada de tratá-lo como produto de avaliação aprofundada, não
  como opção dentro do ciclo leve recorrente.

### 15.5 Impacto de compliance e legal

- **Atribuição obrigatória e permanente.** O rodapé OGL v3.0 + © Crown copyright (§10.2) e a
  referência acadêmica à Escala ICAO precisam sobreviver a qualquer refatoração futura do laudo —
  vale um item de checklist de release para o laudo HSE (algo como "todo PDF gerado tem o rodapé
  de atribuição"), porque nada no schema força isso — é texto de template, silenciosamente
  removível num refactor descuidado.
- **Nome comercial**: confirmado que não pode usar "Stress Indicator Tool" (marca do produto pago
  do HSE) nem, se o COPSOQ um dia entrar, "COPSOQ" sobre conteúdo adaptado (§14.8). Ambos ainda
  sem nome definitivo — ver backlog item B5.
- Nenhum impacto novo de LGPD identificado — o formulário HSE segue exatamente o mesmo modelo de
  coleta anônima já em produção (regra de negócio 2 do CLAUDE.md); não se coleta identidade em
  nenhum caminho.

### 15.6 Impacto de performance

Marginal e não bloqueante: o trigger de validação de escala (`fn_valida_escala_item`, §6.2) faz um
lookup por item por submissão — 27 a 35 lookups extras por envio de formulário, desprezível frente
ao volume atual (249 respostas em ~2 anos de produção). Nenhuma mudança de infraestrutura
(Cloudflare Pages, Supabase) é necessária.

---

## 16. Backlog consolidado

Substitui a antiga lista de "pontos em aberto" por um backlog com prioridade, o que bloqueia, e a
camada a que pertence — para acompanhamento entre sessões de planejamento.

| ID | Item | Camada | Prioridade | Bloqueia | Status |
|---|---|---|---|---|---|
| B1 | Obter o texto validado dos 35 itens da ICAO-35. O artigo RPOT 20(3):1141-1149, 2020 **não publica os 35 itens** (verificado por leitura direta em 2026-08-04 — só 7 exemplos, um por dimensão). Autores identificados: **Paula Andréa Prata Ferreira, Clarissa Pinto Pizarro de Freitas, Rita Pimenta de Devotto, Bruno Figueiredo Damasio**. Próximo passo concreto: contatar os autores (Lattes/ResearchGate/e-mail institucional) pedindo o material suplementar/pool de itens — prática comum para uso de escala validada em pesquisa brasileira. Alternativa se não houver resposta: tradução profissional dos 35 itens originais do HSE (texto em inglês já confirmado verbatim, §7) por psicólogo(a) do trabalho, citando o HSE como fonte primária em vez da ICAO — perde a validação psicométrica brasileira, mantém a validação do HSE original. **Deixou de bloquear o início da programação (decisão de 2026-08-04, §11.1)** — a engenharia avança com texto placeholder em DEV/`develop`; B1 passa a bloquear só o merge final para `main`. | 1 | **Alta** | Merge de `develop` → `main` (go-live) — não bloqueia mais o começo do trabalho técnico | Aberto — ação concreta definida |
| B13 | Trocar o texto placeholder das 35 questões (banco em DEV + `BLOCOS_HSE` em `psicomap-forms.html`) pelo texto validado, num único PR de conteúdo, quando B1 resolver — depois disso, refazer `/validar-formulario` e o teste de aceite ponta-a-ponta (§12) antes de promover `develop` → `main` (§11.1) | 1 | **Alta** | Go-live em PROD | Depende de B1 |
| B2 | ~~Extrair os 21 percentis do `analysistool.xls`~~ — **RESOLVIDO com resultado negativo em 2026-08-04** (§5): arquivo baixado e todas as 10 abas (inclusive 3 ocultas) inspecionadas por script; confirmado que a planilha é uma ferramenta de auto-comparação ano-a-ano sem tabela de norma populacional embutida. Não bloqueia mais nada — a classificação por bandas relativas à média (benchmark 2023) passa a ser o método definitivo, não fallback. | 1 | — | Nenhum | **Fechado** |
| B3 | ~~Confirmar o mapeamento item→dimensão~~ — **RESOLVIDO em 2026-08-04**: a aba `Totals` do `analysistool.xls` reproduz o texto verbatim dos 35 itens com o agrupamento por dimensão da fonte oficial, batendo exatamente com o mapeamento já usado neste documento. Deixa de ser "derivado por eliminação" — confirmado contra dado primário. | 1 | — | Nenhum | **Fechado** |
| B4 | Decidir estratégia de gate comercial antes do lançamento (§15.1) — mesmo mantendo "escolha livre" agora, decidir *quando* ligar o gate se for monetizar depois | 1 | Média | Nada tecnicamente — decisão de produto | Aberto |
| B5 | Definir nome comercial do módulo HSE (não pode ser "Stress Indicator Tool") | 1 | Baixa | Cosmético — pode sair depois do MVP técnico | Aberto |
| B6 | Preparar material de posicionamento comercial (quando usar HSE vs. metodologia própria) e material de suporte (por que os números divergem) — ver §15.1 e §15.3 | 1 | Média | Lançamento comercial, não a entrega técnica | Aberto |
| B7 | Monitorar taxa de conclusão do formulário HSE após lançamento (§15.4) | 1 | Média | Nada — item de acompanhamento pós-lançamento | Aberto (pós-lançamento) |
| B8 | Checklist de release do laudo HSE garantindo rodapé de atribuição OGL + referência ICAO (§15.5) | 1 | Baixa | Nenhuma PR específica — processo de release | Aberto |
| B12 | Confirmar manualmente no Dashboard Supabase que PITR está ativo em PROD (`vftyiildukrpgmnbcnao`) antes da PR 1 (§12.1). Confirmado em 2026-08-04: a API do MCP (`get_project`) não expõe essa informação — é configuração de plano/dashboard, não consultável por SQL nem por esta ferramenta. Só o usuário (ou alguém com acesso ao Dashboard) pode checar. | 1 | **Alta** | PR 1 em PROD — único item de segurança que não pode ser verificado via SQL/MCP | Aberto — depende de ação humana fora desta sessão |
| B9 | Fase 1.1 — comparativo entre ciclos, plano de ação por dimensão, exportações, tela de Metodologia HSE (ver mapa de camadas) | 1.1 | Baixa | Depende da Camada 1 estar em produção | Adiado |
| B10 | Decidir se e como avançar a Camada 2 (combo) — resolver design de fadiga de resposta antes de estimar esforço (§13) | 2 | Baixa | Nada hoje — ideia registrada | Não avaliado |
| B11 | Decidir se e como avançar a Camada 3 (COPSOQ) — decisão de portfólio, sem impeditivo técnico (§14.11) | 3 | Baixa | Recomendado não iniciar antes da Camada 1 validar em produção | Não avaliado |

**Regra de sequenciamento do backlog**: B1 é o único item que bloqueia hard a Camada 1. B2 e B3
podem correr em paralelo à implementação de banco/formulário (§11, PRs 1 e 2 não dependem deles).
B4–B8 são itens de produto/processo, não de código — podem ser resolvidos por quem não está
mexendo no repositório. B9–B11 não têm data.

---

## 17. Fora de escopo — achado colateral

`exportarCSV` (`psicomap-admin.html:5498-5510`) monta as colunas de itens com
`(r.resposta_itens || []).find(...)`, mas as linhas de `loadRespostasParaEmpresa` (`:7674-7689`)
expõem `r.q = {int: valor}` e **não** `r.resposta_itens`. As colunas de resposta do CSV saem sempre
vazias. Bug pré-existente e independente deste plano — corrigir em PR separada (`r.q[q.id]`), sem
misturar com a entrega HSE.

---

## 18. Fontes

### COPSOQ

- Gonçalves JS, Moriguchi CS, Chaves TC, Sato TO. Cross-cultural adaptation and psychometric
  properties of the short version of COPSOQ II-Brazil. Rev Saude Publica. 2021;55:69. DOI:
  10.11606/s1518-8787.2021055003123 — lido na íntegra.
- COPSOQ III. License. 18 ago. 2021. COPSOQ International Network. —
  https://www.copsoq-network.org/assets/Uploads/COPSOQ-network-guidelines-an-questionnaire-COPSOQ-III-180821.pdf
  — lido na íntegra, incluindo Anexo 1 (itens/escalas completos).
- Burr H, Berthelsen H, Moncada S, et al. The Third Version of the Copenhagen Psychosocial
  Questionnaire. Saf Health Work. 2019;10(4):482-503. —
  https://www.copsoq-network.org/assets/Uploads/The-Third-Version-of-the-Copenhagen-Psychosocial-Questionnaire.pdf
- Pejtersen JH, Kristensen TS, Borg V, Bjorner JB. The second version of the Copenhagen
  Psychosocial Questionnaire. Scand J Public Health. 2010. —
  https://journals.sagepub.com/doi/10.1177/1403494809349858
- Lima IAX, Parma GOC, Cotrim TMCP, Moro ARP. Psychometric properties of a medium version of the
  Copenhagen Psychosocial Questionnaire (COPSOQ II) for southern Brazil. Work. 2019;62(2):175-84.
- Silva MA, Wendt GW, Argimon IIL. Propriedades psicométricas das medidas do Questionário
  Psicossocial de Copenhague I (COPSOQ I), versão curta. REGE Rev Gestão. 2017;24:348-59.
- COPSOQ International Network — Licence, Guidelines & Questionnaire (página oficial). —
  https://www.copsoq-network.org/licence-guidelines-and-questionnaire

### HSE / ICAO-35

- HSE Management Standards Indicator Tool (questionário oficial, 35 itens) —
  https://www.hse.gov.uk/stress/assets/docs/indicatortool.pdf
- HSE Indicator Tool — User Manual — https://www.hse.gov.uk/stress/assets/docs/indicatortoolmanual.pdf
- Notes on the Indicator Tool (alerta sobre inversão) —
  https://www.hse.gov.uk/stress/standards/notesindicatortool.htm
- Downloads, licenciamento OGL v3.0 e `analysistool.xls` —
  https://www.hse.gov.uk/stress/standards/downloads.htm
- Stress Indicator Tool Benchmarking report, agosto/2023 (HSE/TSO) —
  https://books.hse.gov.uk/gempdf/HSE_Stress_Indicator_Tool_Benchmarking_Report_2023.pdf
- Versões em outros idiomas (inclui português) —
  https://www.hse.gov.uk/stress/standards/languages/index.htm
- Open Government Licence v3.0 —
  https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/
- **Escala ICAO** (adaptação brasileira validada), Revista Psicologia: Organizações e Trabalho,
  20(3):1141-1149, 2020 —
  https://pepsic.bvsalud.org/scielo.php?script=sci_arttext&pid=S1984-66572020000300012
- Cousins et al., 'Management Standards' and work-related stress in the UK —
  https://www.hse.gov.uk/stress/assets/docs/techpart2.pdf
- Edwards & Webster — Psychometric analysis of the MSIT — https://oro.open.ac.uk/24981
