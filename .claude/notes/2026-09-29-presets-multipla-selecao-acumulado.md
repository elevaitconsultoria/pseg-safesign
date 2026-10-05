# Presets de filtro com múltipla seleção (acumulado) — 2026-09-29

Estado: **em PROD** desde 2026-09-29, via PR
[#85](https://github.com/elevaitconsultoria/pseg-safesign/pull/85) (merge commit `324e4c1`).
Commits próprios: `2909965` (Resultados) e `2bc5fa3` (Gráficos + Relatório).
Sem migration — o formato de `filtro_presets.config` não mudou.

⚠️ **Gráficos e Relatório foram para PROD sem homologação do usuário** — só com os testes
descritos na seção 7. Resultados foi homologado em DEV antes de subir.

---

## 1. O pedido

> "O usuário gostaria de selecionar mais de um preset que foi feito para trazer um acumulado
> dos filtros que aplicou."

E, na segunda rodada, o critério de aceite explícito:

> "O usuário precisa acumular os setores e funções para fazer um novo preset ALL-GERAL, da
> empresa/ciclo avaliado. A ideia é poder gerar esse resultado geral onde as quantidades de
> respostas serão iguais à soma dos presets de filtros feitos separados."

Ou seja: **n(ALL-GERAL) = Σ n(presets)**. Não é "mostre os dois recortes", é "some e confira".

## 2. A armadilha que definiu o desenho

Dentro de um combo a seleção é **OR**; **entre combos é AND** (ver o `filter` de
`_filtroResultados`). Unir seleção a seleção, portanto, **não** é unir recortes:

```
Preset A = setor{Produção} + função{Operador}
Preset B = setor{RH}       + função{Analista}
União por eixo → setor{Produção,RH} × função{Operador,Analista}
               → inclui "Produção/Analista", que nenhum preset pediu
```

O acumulado fica **maior** que a soma — quebrando o critério de aceite — sempre que a mesma
função existir em mais de um setor selecionado.

**Por que mesmo assim a união por eixo foi a escolha certa:** a alternativa (união de
conjuntos de resposta, A ∪ B de verdade) exigiria que a cadeia de filtro das três telas
aceitasse uma *lista* de recortes, incluindo `gerarLaudoPDF` e as exportações. E, pior, o
resultado **não seria salvável**: um registro de `filtro_presets` guarda seleções por eixo,
então um preset ALL-GERAL gravado a partir de uma união de recortes voltaria como união por
eixo na próxima vez que fosse aplicado. O recurso existe justamente para ser salvo.

No caso real do usuário — um preset por setor, eixo de função aberto — não há extra nenhum e
o total bate exato.

**A decisão: medir em vez de presumir.** `_conferirAcumulado` mede o acumulado contra a soma
dos presets sobre os dados reais e declara a diferença, nomeando os pares responsáveis. O
critério de aceite virou uma asserção verificada a cada aplicação, não uma esperança.

## 3. A regra que quase passou despercebida: vazio = universo

`_grupoValoresFiltro` retorna `null` (sem filtro) quando **nenhum ou todos** estão
selecionados, e o `filter` das telas trata `length === 0` como "todos incluídos". Então:

```
Preset A: combo-funcao = []            → SEM FILTRO (todas as funções)
Preset B: combo-funcao = ['Operador']
União ingênua (Set) → ['Operador']     → MAIS ESTREITO que A
```

Um `Set` cru produziria um acumulado **menor** que um dos presets somados — o oposto literal
de acumular, e sem erro nenhum na tela. Daí a regra em `_mesclarConfigs`:

> Eixo aberto (vazio **ou** cobrindo o universo) em **qualquer** um dos presets ⇒ eixo aberto
> no acumulado.

E aberto é gravado como **universo inteiro marcado**, não como lista vazia: as duas formas são
equivalentes para o filtro, mas a primeira aparece como `Todos (N)` na pílula do combo,
enquanto a segunda leria como "nenhum selecionado".

## 4. O que foi construído

### Fonte única de recorte por tela

`_filtroResultados(cfg, todos)`, `_filtroGraficos(cfg, todos)`, `_filtroLaudo(cfg, todos)` —
produzem o recorte a partir de uma **configuração** (o mesmo objeto que um preset guarda), não
do estado dos combos. Cada uma é usada **pelo render da tela e pela conferência**. Duas
implementações divergiriam e o acumulado "não bateria" com a soma sem nenhum erro visível.

`_grupoValoresFiltro` e `_filtroPorGhe` ganharam um `selOverride` opcional (retrocompatível)
para poderem ser avaliados a partir de uma configuração salva.

Dois cuidados que preservam comportamento anterior, e que **não podem ser "limpados"**:
- No Relatório o `gheParesF` é calculado sobre **todas** as linhas, não sobre as do ciclo —
  é a ordem que `renderLaudo` já fazia.
- `combo-ld-nivel` **não** entra no recorte de linhas: ele recorta os *fatores* do documento.
  Somá-lo mudaria o `n` da capa do laudo.

### Mescla

`_mesclarConfigs(cfgs, tela)`:
- **Combos**: união por eixo, com a regra do universo (seção 3).
- **Ciclo**: todos iguais → preserva; divergente → cai para "todos os ciclos" + aviso.
- **O resto é por tela**, via `PRESET_TELAS[tela].mesclar(cfgs, avisos)`.

### Descritor `PRESET_TELAS` cresceu

Ganhou `empresaSel`, `filtrar` e `mesclar`, ao lado de `combos`/`ciclo`/`render`/`capturar`/
`aplicar` que já existiam. **Campo de valor único é responsabilidade do descritor, não de um
`if/else` dentro da mescla** — o histórico deste arquivo mostra que espalhar isso é como
combos ficaram fora de `COMBOS_AUTO_APPLY` (2026-08-28).

| Tela | Campo extra | Regra da mescla |
|---|---|---|
| Resultados | `segmentacao` | valor único → último marcado, avisa se divergiu |
| Gráficos | — | nada |
| Relatório | `granularidade` | valor único → último marcado, avisa se divergiu |
| Relatório | `secoes` | **SOMAM** — união em ordem canônica de `LAUDO_SECOES` |

**Seções somam de propósito.** "Valeu a última" faria o acumulado *perder* uma seção que um
dos presets somados tinha — o mesmo erro de direção da seção 3, agora no documento entregue.

### Conferência

`_conferirAcumulado(cfgs, cfgMesclado, tela)` mede sobre os dados reais e devolve
`{nUniao, nMesclado, nExtras, pares}`. Vale para as três telas; no Relatório o segundo eixo é
**escolaridade**, com o mesmo risco de cartesiano que setor × função nas outras duas.

Detalhe que importa: `getLinhasParaAnalise` é chamado **uma vez só** e o mesmo array alimenta
as duas medições — a comparação é por identidade de linha.

O toast resultante:

```
Acumulado T2 - eletrica + Teste1 - ADm Obras: 47 respostas (soma dos presets: 47).
```

e, quando há extra:

```
... Atenção: 3 resposta(s) a mais que a soma dos presets — pares que nenhum preset
selecionou: Produção — Analista (2), RH — Auxiliar (1).
```

### UI

O `<select>` virou `<div class="preset-list">` com checkbox por preset, nas três telas. O
caminho legado (`aplicarPreset` singular, `preset-sel-*`, o ramo `<select>` de
`renderPresets`) foi **removido**, não mantido como fallback: com as três telas na lista ele
seria código morto, e código morto em paralelo é exatamente como os dois catálogos de ação
divergiram (ver `CATALOGO_ACOES` no CLAUDE.md).

`_togglePreset` **não repinta a lista** — só marca o item e sincroniza o botão Excluir.
Repintar dentro do `onchange` destruiria o próprio checkbox que recebeu o clique. Mesma
armadilha já documentada em `_gheeSetFuncao` e `_adAtualizarTabela`.

Outras decisões de UI:
- **Desmarcar tudo não limpa a tela.** O recorte vigente continua valendo — zerá-lo
  descartaria ajustes manuais feitos depois de aplicar o preset.
- **Excluir exige alvo único** (`_presetAtivoUnico`): com dois marcados, qual seria apagado?
- **Salvar torna o recém-salvo a única seleção.** O acumulado agora tem nome próprio; manter
  os parciais marcados sugeriria que ainda estão sendo somados.
- `carregarPresets` zera `_presetSel` — outra empresa, outros presets.

## 5. Fluxo do usuário (o que isto resolve)

```
Consultor já tem: preset "Elétrica", preset "Adm Obras", preset "Produção"
  → marca os três na lista
  → toast confirma: acumulado = soma dos três
  → "Salvar atual" com o nome "ALL-GERAL"
  → o ALL-GERAL passa a ser um preset normal, reaplicável em um clique
```

## 6. Limitação conhecida e intencional

O acumulado é **união por eixo**, não união de recortes. Quando os presets diferem em dois ou
mais eixos, o resultado pode conter combinações que nenhum preset selecionou — e o sistema
**diz isso em voz alta** em vez de esconder. Não há correção automática: restringir por par
exigiria um filtro oculto que a sidebar não mostra, e um recorte que o usuário não consegue
ver nem editar é pior que um número explicado.

Se isso aparecer na prática com dado de cliente, a saída é o usuário desmarcar na mão os pares
apontados pelo toast — os combos estão visíveis e editáveis.

## 7. Como foi verificado

Sem sessão autenticada disponível (ver `feedback_auth_impersonation_blocked`), a validação foi
feita **executando as funções reais extraídas do HTML**, não reimplementando a lógica:

- **12 casos** nas três telas: soma exata com eixo aberto; detecção do cartesiano em cada tela
  (no Relatório via escolaridade); presets sobrepostos somando sem duplicata; ciclos
  divergentes caindo para "todos"; `combo-ld-nivel` fora do recorte de linhas; seções somando
  em ordem canônica; granularidade e segmentação divergentes avisando.
- **DOM real no navegador**: as três listas presentes, zero `<select>` remanescente, três
  toggles seguidos no mesmo checkbox sem o elemento ser destruído, Excluir habilitando só com
  um marcado, nome de preset com `<b>` saindo escapado, sem erro de console.
- Check de sintaxe dos `<script>` (o do CLAUDE.md) após cada etapa.

**Um teste falhou primeiro por erro do próprio teste**: o universo de escolaridade do harness
omitia `'Não informado'`, que faz parte de `ESCOLARIDADE_ORDEM`. Corrigido o harness, não o
código — vale registrar porque o sintoma ("nível recorta linhas") apontava para o lugar errado.

## 8. O release — e o que ele ensinou

A PR #85 foi aberta com **4 commits**. Quatro minutos depois o range `main..develop` tinha
**15**: outra sessão mergeou as PRs #71/#73/#74/#75/#76 (auditoria de acessos, com 3
migrations) direto na `develop`. O usuário havia autorizado o merge olhando os 4.

Duas consequências práticas:

1. **Reconferir `git log origin/main..origin/develop --oneline` imediatamente antes de
   mergear**, não só antes de abrir a PR. E corrigir o corpo da PR, que fica desatualizado.
2. **Checar a migration no banco decide o risco.** Consultar `pg_policies` em PROD mostrou que
   as políticas das 3 migrations (`viewer_no_*`, `est_perfil_*_admin`, `riscos_config_*_admin`)
   **já estavam aplicadas**: o lote era o *código alcançando* um banco já endurecido, não DDL
   novo indo para produção. Isso mudou a recomendação — vale checar antes de alarmar.

Mergeado com **merge commit** (`324e4c1`), seguido de `git push origin origin/main:develop`:
as duas branches ficaram com **0 commits de diferença nos dois sentidos**.

## 9. Pendências

1. **Homologar Gráficos e Relatório em PROD** — foram com os testes acima, não com validação
   do usuário. Marcar dois presets em cada tela e conferir que os dois números do toast batem.
2. **`webhook-billing` agora é fail-closed** (veio no lote da PR #72). Confirmar que
   `STRIPE_WEBHOOK_SECRET` e `ASAAS_WEBHOOK_TOKEN` estão configurados no projeto PROD — sem
   eles o endpoint responde 500 e os webhooks de cobrança param. O merge **não** deploya a
   Edge Function; `supabase/functions/` vai por deploy próprio.
3. **A tela de Relatório continua sem filtro de Funções**, enquanto Resultados e Gráficos têm.
   Assimetria pré-existente, já registrada na nota de 2026-09-18 — o acumulado a herda.
