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
WHERE NOT EXISTS (
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
  AND NOT EXISTS (
    SELECT 1 FROM resposta_itens ri
    WHERE ri.resposta_id = r.id
  );
```

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
