# COPSOQ (rascunho) implementado em DEV — 2026-10-28

> Pedido do usuário: "implemente também a opção COPSOQ". Feito **só em DEV, como RASCUNHO**. PROD não tem o questionário (nem a linha em `instrumentos`), então a opção **não aparece lá**.
> Base: `2026-10-19-copsoq-avaliacao-documentos-e-generalizacao.md` (os PDFs do player são adaptação livre, não o texto validado).

## O que existe
- **Banco (DEV):** `seed_copsoq_dev_rascunho.sql` — instrumento `COPSOQ_II` (sensível), **17 dimensões em 7 domínios**, questionário v1 publicado com os **40 itens do documento de terceiro** (`config.rascunho=true`), 20 itens invertidos, ordem **intercalada** entre fatores (códigos C01..C40 = numeração do documento). `seed_copsoq_simulacao_dev.sql` — campanha "Avaliação COPSOQ — Simulação" (empresa fictícia do HSE), link `simcopsoq001`, **40 respostas pela RPC real** (1.600 itens).
- **Admin:** bloco `COPSOQ (S10)` — `calcDimensoesCOPSOQ` (motor próprio: média das médias dos itens, inversão por item, índice 0–100 = (média−1)/4, zonas fixas, fav/desf), tela **Resultados** (geral/setor/agrupamento/GHE, supressão complementar, impressão) e **Laudo** (preview = PDF; capa, metodologia, resultados por domínio, **saúde e bem-estar em seção própria**, comparação entre recortes, glossário próprio, limitações, referências). Telas **Gráficos, Plano, Auditoria** e Comparativo: aviso "tela ainda não disponível" (registro `telas: ['resultados','laudo']` + `_metSemMotor(cicloId, tela)`).
- **Formulário:** nada novo — o genérico já cobre (escala de 5 rótulos, `config.aviso` sobre saúde).
- **Testes:** `npm run test:copsoq` (32 casos: inversão, limites das zonas, média das médias, versões por código, sensível, consistência do seed) e harness (`?auto=laudocop`).

## Decisões de desenho (todas sobre o documento do terceiro — validar com a fonte)
1. O documento tem 7 "fatores" com **direção mista** (ex.: "esgotado" × "satisfeito") → fatores divididos em **dimensões de direção única**; `inversa = dimensão alto_pior`.
2. Itens 31–32 ("já sofreu tratamento injusto / já foi desrespeitado") ficam em **OFENSAS** (sensível), não em "segurança no emprego".
3. **Sensíveis** (LGPD art. 5º II): OFENSAS, ESTRESSE, SAUDE_GERAL — só aparecem com `N_MIN_SENSIVEL` = max(10, 2×n mínimo) respondentes (**provisório**), em tela, laudo e comparação entre recortes.
4. **Sem nível de risco P×S**: saúde/estresse são desfecho; o laudo diz isso. Sem referência nem corte validado: a cor é a zona fixa (≥75/40–74,99/<40), declarada como referência interna; compara-se ciclos e recortes da própria empresa.
5. Glossário **próprio** (`COPSOQ_GLOSSARIO`), no lugar do texto de "interpretação" do player (decisão do usuário).
6. Rótulo "COPSOQ (rascunho)": o nome só vale em produção com texto validado + licença por escrito (ND).

## Não faz / pendente
- Texto validado, licença, mapa item→dimensão da fonte, RIPD/consentimento específico (ver nota de contato/jurídico).
- Telas Gráficos/Plano/Auditoria/Comparativo e CSV para o COPSOQ; plano de ação e referências por dimensão (SST).
- Valor de `N_MIN_SENSIVEL` (jurídico). Item binário "de quem" (não há no documento).
- Nada disto foi para PROD nem `develop`; branch `feat/hse-integracao-develop` (push só desta branch → preview do Cloudflare = DEV).

## Para homologar no preview (DEV)
Cliente **SIMULAÇÃO HSE (fictícia)** → campanha **Avaliação COPSOQ — Simulação**: Resultados (Geral e Por setor — Logística tem n=10, no limite das dimensões sensíveis), Relatório (pré-checagem + preview), "Nova campanha" (3 cartões) e formulário `psicomap-forms.html?token=simcopsoq001`.
