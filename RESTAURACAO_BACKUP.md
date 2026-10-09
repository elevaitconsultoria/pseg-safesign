# Guia de Restauração — PsicoMap

**Quando usar:** tabela `respostas` ou `resposta_itens` corrompida, dropada acidentalmente, ou com dados faltando.

**Onde executar:** Supabase Dashboard → SQL Editor  
**Projeto:** `vftyiildukrpgmnbcnao` (psicomap)  
**URL:** https://supabase.com/dashboard/project/vftyiildukrpgmnbcnao/sql/new

---

## Entendendo o backup

Cada resposta recebida pelo formulário é gravada em **3 camadas independentes**:

| Camada | Tabela | Descrição |
|---|---|---|
| 1ª (mais segura) | `respostas_raw_backup` | JSON completo, sem FKs, nunca falha |
| 2ª | `respostas_fila` | Fila de processamento com retry automático |
| 3ª (principal) | `respostas` + `resposta_itens` | Tabelas estruturadas usadas pelos relatórios |

A restauração usa a **1ª camada** para reconstruir a **3ª**.

> ⚠️ **Respostas HSE/ICAO-35 (desde a segunda metodologia).** Os Passos 3–4 abaixo restauram **apenas
> respostas BS 8800**. O backup bruto de uma resposta HSE tem `itens[].item_id`/`questao_id` apontando
> para `hse_itens` e valores 1–5. Rodar o Passo 4 sobre elas **descarta os itens em silêncio** (o filtro
> `BETWEEN 1 AND 4` os ignora e o `JOIN` não os encontra), e o Passo 3 as gravaria como `BS8800`
> (default da coluna). Por isso os passos 3 e 4 filtram por metodologia, e os passos **3-HSE** e
> **4-HSE** logo depois cuidam das respostas HSE. A metodologia vem do **ciclo** do payload, nunca
> do formato dos itens.


---

## Passo 1 — Confirmar que o backup tem os dados

```sql
SELECT 
  COUNT(*)            AS total_respostas_backup,
  MIN(gravado_em)     AS primeira_resposta,
  MAX(gravado_em)     AS ultima_resposta
FROM respostas_raw_backup;
```

✅ Se retornar dados, o backup está íntegro e a restauração é possível.

---

## Passo 2 — Inspecionar o que está no backup

```sql
SELECT 
  id,
  gravado_em,
  empresa_id,
  link_token,
  payload->>'setor'        AS setor,
  payload->>'funcao'       AS funcao,
  payload->>'lgpd_aceito'  AS lgpd,
  jsonb_array_length(payload->'itens') AS qtd_itens
FROM respostas_raw_backup
ORDER BY gravado_em DESC
LIMIT 50;
```

Use para confirmar visualmente que os dados fazem sentido antes de restaurar.

---

## Passo 3 — Restaurar a tabela `respostas`

```sql
INSERT INTO respostas (
  empresa_id,
  ciclo_id,
  link_token,
  session_id,
  setor,
  funcao,
  escolaridade,
  lgpd_aceito,
  lgpd_aceito_em,
  respondido_em
)
SELECT
  (payload->>'empresa_id')::uuid,
  (payload->>'ciclo_id')::uuid,
  payload->>'link_token',
  (payload->>'session_id')::uuid,
  payload->>'setor',
  payload->>'funcao',
  payload->>'escolaridade',
  (payload->>'lgpd_aceito')::boolean,
  gravado_em,
  gravado_em
FROM respostas_raw_backup rb
WHERE COALESCE((SELECT c.metodologia FROM ciclos c
                 WHERE c.id = (rb.payload->>'ciclo_id')::uuid), 'BS8800') = 'BS8800'
  AND NOT EXISTS (
  SELECT 1 FROM respostas r
  WHERE r.session_id = (rb.payload->>'session_id')::uuid
);
```

O `WHERE NOT EXISTS` garante que registros já existentes não sejam duplicados.  
Pode rodar mais de uma vez com segurança.

---

## Passo 4 — Restaurar a tabela `resposta_itens`

```sql
INSERT INTO resposta_itens (resposta_id, questao_id, valor)
SELECT
  r.id,
  (item->>'questao_id')::uuid,
  (item->>'valor')::int
FROM respostas_raw_backup rb
JOIN respostas r
  ON r.session_id = (rb.payload->>'session_id')::uuid
CROSS JOIN jsonb_array_elements(rb.payload->'itens') AS item
WHERE (item->>'valor')::int BETWEEN 1 AND 4
  AND (item->>'questao_id') IS NOT NULL
  AND r.metodologia = 'BS8800'
  AND NOT EXISTS (
    SELECT 1 FROM resposta_itens ri
    WHERE ri.resposta_id = r.id
  );
```

---

## Passo 3-HSE e 4-HSE — Restaurar respostas HSE/ICAO-35

Só necessário se houver ciclos HSE. Descubra antes se há backups HSE a restaurar:

```sql
SELECT count(*) AS backups_hse
FROM respostas_raw_backup rb
JOIN ciclos c ON c.id = (rb.payload->>'ciclo_id')::uuid
WHERE c.metodologia = 'HSE_ICAO35';
```

**3-HSE — `respostas`** (grava `metodologia` e o questionário HSE publicado):

```sql
INSERT INTO respostas (empresa_id, ciclo_id, questionario_id, tenant_id, link_token, session_id,
                       setor, funcao, escolaridade, lgpd_aceito, lgpd_aceito_em, respondido_em, metodologia)
SELECT (rb.payload->>'empresa_id')::uuid, (rb.payload->>'ciclo_id')::uuid,
       (SELECT id FROM questionarios WHERE metodologia='HSE_ICAO35' AND publicado ORDER BY versao DESC LIMIT 1),
       (SELECT tenant_id FROM empresas WHERE id = (rb.payload->>'empresa_id')::uuid),
       rb.payload->>'link_token', (rb.payload->>'session_id')::uuid,
       rb.payload->>'setor', rb.payload->>'funcao', rb.payload->>'escolaridade',
       (rb.payload->>'lgpd_aceito')::boolean, rb.gravado_em, rb.gravado_em, 'HSE_ICAO35'
FROM respostas_raw_backup rb
JOIN ciclos c ON c.id = (rb.payload->>'ciclo_id')::uuid AND c.metodologia = 'HSE_ICAO35'
WHERE NOT EXISTS (SELECT 1 FROM respostas r WHERE r.session_id = (rb.payload->>'session_id')::uuid);
```

**4-HSE — `resposta_itens_hse`** (escala 1–5; o id do item vem de `item_id` **ou** `questao_id`):

```sql
INSERT INTO resposta_itens_hse (resposta_id, item_id, valor)
SELECT r.id,
       lower(COALESCE(item->>'item_id', item->>'questao_id'))::uuid,
       (item->>'valor')::int
FROM respostas_raw_backup rb
JOIN respostas r ON r.session_id = (rb.payload->>'session_id')::uuid AND r.metodologia = 'HSE_ICAO35'
CROSS JOIN jsonb_array_elements(rb.payload->'itens') AS item
WHERE (item->>'valor')::int BETWEEN 1 AND 5
  AND NOT EXISTS (SELECT 1 FROM resposta_itens_hse x WHERE x.resposta_id = r.id)
ON CONFLICT DO NOTHING;
```

Conferência obrigatória: cada resposta HSE restaurada deve ter **35 itens** (ou o total publicado em
`hse_itens`). `SELECT resposta_id, count(*) FROM resposta_itens_hse GROUP BY 1 HAVING count(*) <> 35;`
deve voltar vazio. Se `hse_itens` do questionário original não existir mais, **pare**: itens HSE são
`ON DELETE RESTRICT` e o texto é congelado, então isso indicaria um problema maior que a restauração.

---

## Passo 5 — Verificar a restauração

```sql
SELECT
  COUNT(DISTINCT r.id)  AS respostas_restauradas,
  COUNT(ri.id)          AS itens_restaurados,
  COUNT(DISTINCT r.empresa_id) AS empresas_afetadas
FROM respostas r
LEFT JOIN resposta_itens ri ON ri.resposta_id = r.id;
```

(Conta só BS 8800; as respostas HSE se conferem pela consulta do Passo 4-HSE.)

Compare com o total do Passo 1. Os números devem bater.

---

## Passo 6 (opcional) — Verificar por empresa

```sql
SELECT
  e.nome AS empresa,
  COUNT(DISTINCT r.id) AS respostas,
  COUNT(ri.id)         AS itens
FROM respostas r
JOIN empresas e ON e.id = r.empresa_id
LEFT JOIN resposta_itens ri ON ri.resposta_id = r.id
GROUP BY e.nome
ORDER BY respostas DESC;
```

---

## Fluxo resumido

```
1. SQL Editor no Supabase
2. Passo 1 → confirmar que respostas_raw_backup tem dados
3. Passo 2 → inspecionar amostra visual
4. Passo 3 → restaurar tabela respostas
5. Passo 4 → restaurar tabela resposta_itens
6. Passo 5 → verificar contagens
7. Sistema restaurado — testar no admin panel
```

**Tempo estimado:** 5 a 15 minutos para qualquer volume de dados.

---

## Observações importantes

- O `session_id` é a chave de vínculo entre o backup raw e as tabelas principais. Respostas gravadas antes da coluna `session_id` existir (registros legados com `session_id = NULL`) não são restauráveis por este método — use `respostas_fila` como fonte alternativa nesses casos.
- A tabela `respostas_raw_backup` é **append-only** — nunca delete registros dela.
- Em caso de dúvida, execute apenas o Passo 1 e 2 antes de qualquer restauração para entender o que existe.

---

*Gerado em 2026-06-22 | PsicoMap — Eleva IT Consultoria*
