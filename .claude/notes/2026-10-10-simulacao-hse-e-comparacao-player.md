# HSE — texto PT-BR (v2), simulação de respostas e comparação com o relatório do outro player

> Criado em 2026-10-10. Branch **`feat/hse-icao35-sim`** (worktree `../pseg-safesign-hse`), a partir de `feat/hse-icao35`.
> **Nada foi aplicado em PROD e nada foi publicado em `develop`.** Tudo abaixo é DEV.
> Fontes (do usuário, em `Downloads`): F1 = `AVALIAÇÃO - IMPRESSA HSE.pdf (1).pdf` (formulário, 35 itens em PT-BR);
> F2 = `AVALIA NR01 - Ferramenta de Indicador de Estresse.pdf` (relatório gerado, 23 páginas).
> Contexto e engenharia reversa do player: `2026-10-08-referencia-hse-player-avalia-nr01.md`.

## 1. Textos em PT-BR — questionário v2

`seed_hse_icao35_ptbr_v2_dev.sql` (**só DEV**) cria o questionário **versão 2** com os 35 enunciados do F1, **verbatim**.
Por que versão nova e não `UPDATE`: os itens congelam ao publicar e a v1 já tem respostas (regra B21: mudou uma palavra → questionário novo).
A v1 continua publicada para as respostas antigas seguirem analisáveis; links novos recebem a **maior versão publicada** (confirmado: `obter_instrumento_link` → v2).

| Mudou | Ficou igual (de propósito) |
|---|---|
| Texto dos 35 itens (PT-BR do F1) | Códigos `H01..H35` = numeração do HSE **original**, dimensão e inversão (Demandas e Relacionamentos) → o cálculo é idêntico |
| **Escala única** de frequência (Nunca · Raramente · Às vezes · Frequentemente · Sempre), tudo `parte=1`/`freq` | **Ordem original** dos itens (intercalada). O F1 os agrupa por dimensão; não copiei isso para não induzir a resposta |
| Instrução e cabeçalho reescritos (sem a frase "a escala é inversamente", que é para quem corrige a ficha em papel) | Nenhum `[RASCUNHO]` visível ao respondente |

O F1 reescreve os itens de **concordância** (24–35 do HSE) como pergunta de **frequência** ("Eu entendo claramente o que é esperado de mim?"), por isso a escala de concordância deixa de existir nesta versão.
O formulário agora **não mostra o título "Parte 1"** quando só existe uma parte.

### Defeitos de tradução do F1 — mantidos por instrução, decidir antes de qualquer uso real
| Item | Texto no F1 | Problema |
|---|---|---|
| **H22** | "Tenho pausas temporárias impossíveis de cumprir?" | Corresponde a *"I have unrealistic time pressures"* (pressão de tempo irreal). Perde o construto e repete o tema "pausas" do H16 — dois itens de Demandas medindo quase a mesma coisa |
| **H08** | "Recebo informações e suporte que me ajudam…" | Original: *"supportive FEEDBACK"* — perde "feedback" |
| **H26** | "…pedir explicações ao **chefe**…" | O F2 do mesmo player diz "questionar os **gestores**": o texto não está congelado nem versionado nem dentro do produto deles |
| H05 / H21 | "Falam ou se comportam comigo de forma dura?" / "Sou perseguido?" | Redações mais fracas que *harassment* e *bullying* |
| vários | itens de concordância como frequência | Alteram o construto (H01, H04, H11, H13…) |

**Duas coisas que dependem de você, e não são técnicas:** (a) a redação é de um **produto comercial de terceiro** — não verifiquei se pode ser reutilizada; (b) continua valendo B1 (validação por SST/psicólogo e permissão dos autores da ICAO).
Por isso `config.rascunho = true` e `config.origem` registram a procedência.

### Correção que a troca de texto exigiu (laudo)
O laudo HSE só se marcava como **RASCUNHO** quando o texto do item começava com `[RASCUNHO]`. Com a v2 (texto real, **não validado**) isso desapareceria e o documento sairia sem a marca.
Agora a marca vem de `questionarios.config.rascunho`, com **falha segura**: se a flag não puder ser lida, ou o questionário não for encontrado, assume rascunho (`_hseQuestionarioEhRascunho`).
⚠ O futuro `seed_hse_icao35_validado.sql` (go-live) precisa abortar também quando `config->>'rascunho' = 'true'`, não só quando há `[RASCUNHO]` no texto.

## 2. Ambiente de simulação (DEV)

| O quê | Valor |
|---|---|
| Empresa fictícia | `SIMULAÇÃO HSE (fictícia)` — `aaaa0000-0000-4000-8000-0000000000a1`, tenant Eleva IT |
| Setores / quadro | Produção 60 (Operador 45 + Supervisor 15) · Administrativo 30 · Logística 30 = **120** |
| Ciclo | `Avaliação HSE — Simulação` (HSE_ICAO35) |
| Link | `simhse000001` — **não** é link de teste (link de teste é excluído das análises) |
| Criar | `seed_hse_simulacao_dev.sql` (idempotente) |
| Remover tudo | `DELETE FROM empresas WHERE id='aaaa0000-0000-4000-8000-0000000000a1';` |

### Simulador — `_dev/simular-hse.js`
Envia respostas pela **RPC real `salvar_resposta`** (mesma validação do formulário público: 35 itens, 1..5, sem duplicar), então o caminho completo é exercitado. **Recusa rodar se `SUPA_URL` for PROD.**

```bash
node --env-file=.env _dev/simular-hse.js --perfis                                      # lista os perfis
node --env-file=.env _dev/simular-hse.js --perfil mediana --n 40                       # 50/30/20% em Produção/Admin/Logística
node --env-file=.env _dev/simular-hse.js --setores "Produção:36:critico-demandas,Administrativo:18:bom-gestor,Logística:12:conflito" --seed 2026
node --env-file=.env _dev/simular-hse.js --setores "Produção:5:player-f2"             # reproduz o relatório F2
node --env-file=.env _dev/simular-hse.js ... --dry                                     # só mostra os escores esperados
```
Perfis: `mediana` (benchmark 2023) · `otimo` · `pessimo` · `critico-demandas` · `bom-gestor` · `conflito` · `player-f2` (exatamente o exemplo do F2, sem ruído). `--seed` torna o sorteio reprodutível; `--ruido` controla a dispersão (padrão 0,8).
O script imprime o **escore esperado por dimensão** para comparar com a tela. Convenção: escore = "alto é melhor" **depois** da inversão; em Demandas/Relacionamentos o simulador grava o bruto espelhado (`6 − escore`), como um respondente de verdade.
Limpeza das respostas (SQL): `DELETE FROM respostas / respostas_fila / respostas_raw_backup WHERE empresa_id='aaaa0000-0000-4000-8000-0000000000a1'`.

**Estado atual em DEV:** 66 respostas simuladas (seed 2026: Produção 36 `critico-demandas`, Administrativo 18 `bom-gestor`, Logística 12 `conflito`) = **55% do quadro** (taxa "adequada"). Esperado e conferido em SQL independente: Demandas 2,468 · Controle 3,770 · Apoio 3,948 · Colegas 3,750 · Relacionamentos 3,705 · Papel 4,212 · Mudanças 2,641.
Por setor: Produção Demandas 1,83 / Mudanças 2,06 · Logística Relacionamentos 2,04 / Colegas 2,56 · Administrativo Apoio da gestão 4,39.

## 3. Comparação com o relatório F2 (o que foi reproduzido)

Exemplo do F2 reproduzido de ponta a ponta: simulador → RPC → banco → cálculo. **As 7 dimensões batem exatamente**, também no cálculo em SQL independente e no motor JS da tela.

| Dimensão | Média | Índice (média−1)/4 | F2 | Zona fixa |
|---|---|---|---|---|
| Demandas | 1,125 | 3,1% | 3,1% | vermelha |
| Controle | 4,667 | 91,7% | 91,7% | verde |
| Apoio da gestão | 4,600 | 90,0% | 90,0% | verde |
| Suporte dos colegas | 3,750 | 68,8% | 68,8% | amarela |
| Relacionamentos | 4,250 | 81,3% | 81,3% | verde |
| Clareza de papel | 2,600 | 40,0% | 40,0% | amarela (limite) |
| Mudanças | 1,667 | 16,7% | 16,7% | vermelha |
| Média simples | 3,237 | **55,9%** | 55,9% | — |

Também batem: o item de prazo (2,0 → 25% → vermelha), os limites das zonas (2,60 → 40,00% fica **amarela**, sem ruído de ponto flutuante: arredonda a 2 casas antes de comparar) e as **7 de 7 linhas do inventário do PGR** do F2 pelo método do player (P por %, S do exemplo, matriz 5×5 como lookup).

### O que a tela e o laudo passaram a mostrar (aditivo, rotulado como referência)
- **Índice de favorabilidade 0–100** e **zona fixa** (≥75 verde · 40–74,99 amarela · <40 vermelha) por dimensão **e por item**; **média simples das 7 dimensões** ao fim do bloco, em tom discreto, dizendo que o HSE não define score global.
- Laudo HSE: coluna "Índice · zona fixa" nas tabelas de dimensão e de item, e nota explicando que a **classificação do documento é a "Leitura"** (relativa ao benchmark), não a zona fixa.
- **A classificação oficial do PsicoMap não mudou:** continua a faixa relativa ao benchmark HSE 2023. Mostrar as duas ao lado é para você comparar com relatórios de terceiros; **zona fixa não é o método do HSE**.

### Onde PsicoMap e player divergem sobre o MESMO exemplo (por desenho)
| Dimensão | Índice | Faixa PsicoMap (benchmark) | Player: P×S → nível | PsicoMap: P×S → nível¹ |
|---|---|---|---|---|
| Demandas | 3,1% | Ação urgente | P5×S4 → Intolerável | P4×S3 → ALTO |
| Controle | 91,7% | Muito bem | P1×S1 → Trivial | P1×S2 → BAIXO |
| Apoio da gestão | 90,0% | Muito bem | P1×S1 → Trivial | P1×S2 → BAIXO |
| Suporte dos colegas | 68,8% | Necessidade clara | P3×S3 → Moderado | P3×S2 → MÉDIO |
| Relacionamentos | 81,3% | Bom, mas há o que melhorar | P2×S4 → Moderado | P2×S3 → MÉDIO |
| Clareza de papel | 40,0% | Ação urgente | P4×S4 → Substancial | P4×S2 → ALTO |
| Mudanças | 16,7% | Ação urgente | P5×S4 → Intolerável | P4×S2 → ALTO |

¹ Com a severidade **de TESTE** de DEV (não validada). O nível do PsicoMap depende da severidade que a SST assinar.
Diferenças estruturais: o player usa P por faixas fixas de % (90/75/60/40) e matriz **5×5**, com S **variável** por dimensão (indício de que depende do resultado — ver nota de referência §5.2); o PsicoMap usa P pela **faixa do benchmark**, S **fixa por dimensão** (assinada por SST) e a matriz **4×4**. Nenhum dos dois é "o HSE": é critério adotado pela consultoria.
**Efeito do desenho do benchmark:** no exemplo, Clareza de papel (40,0%) é **amarela** no player e **"Ação urgente"** no PsicoMap, porque a média de referência mundial de Papel é alta (4,16) — o amarelo do player é o estado "normal" de uma organização mediana (nota de referência §3).

## 4. Testes feitos (harness + banco real de DEV)
- Formulário v2 (browser): 35 itens em PT-BR, escala única, sem "Parte 1", sem `[RASCUNHO]`; envio completo → HTTP 200, 35 itens, "Obrigado!".
- Banco: 5/5 e 66/66 respostas gravadas pela RPC real na v2; média por dimensão em SQL = esperada do simulador (3 casas).
- Motor/tela/laudo: 7 dimensões × índice × zona = F2; média simples 3,237/55,9%; n=4 continua oculto; laudo com Logística (n=4) omitida, sem placeholder, com selo RASCUNHO; flag de rascunho (validado / falha de leitura / questionário ausente).
- **Não testado:** sessão logada real no admin (carregamento com RLS) e PDF impresso; a análise de tela foi exercida sobre as funções, não clicando na tela logada.

## 5. Como rodar localmente (sem publicar nada)
```bash
cd ../pseg-safesign-hse            # worktree desta branch (o .env de DEV já foi copiado)
node --env-file=.env build.js && npx http-server dist -p 8765
# admin:       http://localhost:8765/psicomap-admin.html   → cliente "SIMULAÇÃO HSE (fictícia)" → ciclo "Avaliação HSE — Simulação"
# formulário:  http://localhost:8765/psicomap-forms.html?token=simhse000001
```
Para a tela de severidade e o laudo HSE gerar é preciso, como super_admin, cadastrar/validar a severidade (Gestão de ESTs). Sem isso o laudo não gera (erro de checagem) — comportamento intencional.

## 6. Pendências / decisões suas
1. **Texto**: manter o F1 verbatim ou corrigir H22/H08/H26? Redação de terceiro é reutilizável? (B1)
2. **Ordem dos itens**: intercalada (atual) ou agrupada por dimensão como no F1?
3. Mostrar **média simples** na manchete do laudo? (hoje só nota discreta na tela; o laudo não a destaca — D3)
4. **Ponte PGR**: manter 4×4 + severidade fixa assinada por SST, ou adotar a 5×5 do player? (hoje: a nossa)
5. O diretório principal `pseg-safesign` tem alterações não commitadas de **outra sessão** em `psicomap-admin.html` (preset de laudo); este trabalho foi feito num worktree separado justamente para não varrê-las. Integração com `develop` (que renomeou ciclo→campanha) continua pendente.
