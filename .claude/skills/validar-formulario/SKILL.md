---
name: validar-formulario
description: >
  Valida end-to-end o fluxo de submissão do formulário psicossocial e gravação de respostas
  no PSEG SafeSign. Use SEMPRE que: (1) qualquer alteração tocar em salvar_resposta, respostas,
  resposta_itens, respostas_fila ou respostas_raw_backup; (2) antes de um merge develop→main;
  (3) após qualquer deploy em produção; (4) ao investigar erros como "resposta salva localmente",
  "operator does not exist", ou "permission denied"; (5) quando o usuário pedir para validar,
  testar ou verificar o formulário ou a gravação de respostas. Esta é a função mais crítica do
  sistema — nenhuma mudança deve ir a produção sem essa validação.
---

# Validação End-to-End — Formulário PSEG SafeSign

O formulário público (`pseg-forms.html`) é a função mais crítica do sistema. Qualquer falha
silenciosa aqui significa que respostas de funcionários se perdem sem aviso. Este skill garante
que o pipeline completo está funcionando antes de qualquer deploy.

## Pipeline de gravação

Uma submissão válida passa por **4 etapas em sequência**, todas dentro de uma única transação
no RPC `salvar_resposta` (SECURITY DEFINER):

```
pseg-forms.html → Supabase RPC salvar_resposta
  │
  ├─ 1. respostas_raw_backup  (INSERT — backup bruto, antes de qualquer validação)
  ├─ 2. respostas_fila        (INSERT status='pendente' → UPDATE status='processado')
  ├─ 3. respostas             (INSERT — registro principal)
  └─ 4. resposta_itens        (INSERT — um registro por questão respondida)
```

Se a transação falhar em qualquer etapa, **tudo é revertido** — inclusive o backup bruto.
Por isso "nenhum dado no banco" é sinal de falha no RPC, não de problema de rede.

## Checklist de validação

Execute cada item em sequência. Use o MCP do Supabase (`execute_sql`) para as queries.

### 1. Verificar tipo da coluna session_id em ambos os bancos

```sql
-- Rodar em DEV (szqatgvgghxvyyncsjxl) E PROD (vftyiildukrpgmnbcnao)
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_name IN ('respostas', 'respostas_raw_backup', 'respostas_fila')
  AND column_name = 'session_id'
ORDER BY table_name;
```

**O que verificar:** O tipo de `respostas.session_id` deve ser compatível com o parâmetro
`p_session_id uuid` do RPC. Se for `text`, o RPC precisa de cast `p_session_id::text` na
checagem de idempotência. Se for `uuid`, comparação direta. DEV e PROD **podem ter tipos
diferentes** — sempre confirme antes de editar a função.

> Lição aprendida: em 2026-07-14 DEV tinha `text` e PROD tinha `uuid`. Aplicar o fix de DEV
> em PROD sem verificar quebrou PROD temporariamente.

### 2. Verificar definição do RPC salvar_resposta

```sql
-- Rodar em DEV E PROD
SELECT pg_get_functiondef(oid)
FROM pg_proc
WHERE proname = 'salvar_resposta'
ORDER BY oid DESC LIMIT 1;
```

**O que verificar:**
- A comparação `WHERE session_id = p_session_id` usa cast correto para o tipo da coluna
- `SECURITY DEFINER` está presente (necessário para bypass do RLS no formulário público)
- `SET search_path TO 'public'` está presente (segurança contra search_path injection)
- O bloco `EXCEPTION WHEN OTHERS` atualiza `respostas_fila` com status='erro'

### 3. Verificar GRANTs das tabelas críticas

```sql
-- Rodar em DEV E PROD
SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE table_name IN ('respostas','respostas_raw_backup','respostas_fila',
                     'resposta_itens','empresa_headcount')
  AND grantee IN ('authenticated','anon')
ORDER BY table_name, grantee, privilege_type;
```

**O que verificar:** Tabelas criadas via SQL direto (não pelo dashboard) podem não ter GRANTs
automáticos. Sem o GRANT, o RLS nem chega a ser avaliado — a operação é negada antes.
`empresa_headcount` em particular precisa de SELECT/INSERT/UPDATE/DELETE para `authenticated`.

### 4. Teste de submissão real (dados de teste)

Buscar um link ativo e questões válidas:

```sql
-- Rodar em DEV (ou PROD se validando PROD)
SELECT lc.token, lc.empresa_id, lc.ciclo_id, e.nome as empresa
FROM links_coleta lc
JOIN empresas e ON e.id = lc.empresa_id
WHERE lc.ativo = true AND (lc.expira_em IS NULL OR lc.expira_em > now())
LIMIT 1;

-- Buscar questões válidas
SELECT id FROM questoes LIMIT 3;
```

Fazer a chamada de teste com `session_id` fictício único:

```sql
SELECT salvar_resposta(
  '<empresa_id>'::uuid,
  '<ciclo_id>'::uuid,   -- pode ser NULL se o link não tiver ciclo
  '<token>',
  'SETOR_TESTE_VALIDACAO',
  'CARGO_TESTE_VALIDACAO',
  'Superior',
  '[{"questao_id":"<id1>","valor":2},{"questao_id":"<id2>","valor":3}]'::jsonb,
  'aaaaaaaa-bbbb-cccc-dddd-ffffffffffff'::uuid,  -- session_id único de teste
  true,
  'validacao-pre-deploy'
);
```

**O que verificar:** Deve retornar um UUID (o `resposta_id`). Qualquer erro aqui é bloqueante.

### 5. Confirmar dados em todas as 4 tabelas

```sql
-- Substituir pelo session_id usado no teste
SELECT 'respostas_raw_backup' as tabela, COUNT(*) FROM respostas_raw_backup
  WHERE session_id::text = 'aaaaaaaa-bbbb-cccc-dddd-ffffffffffff'
UNION ALL
SELECT 'respostas_fila', COUNT(*) FROM respostas_fila
  WHERE payload_json->>'session_id' LIKE '%aaaaaaaa-bbbb-cccc-dddd-ffffffffffff%'
UNION ALL
SELECT 'respostas', COUNT(*) FROM respostas
  WHERE session_id::text = 'aaaaaaaa-bbbb-cccc-dddd-ffffffffffff'
UNION ALL
SELECT 'resposta_itens', COUNT(*) FROM resposta_itens
  WHERE resposta_id = (
    SELECT id FROM respostas WHERE session_id::text = 'aaaaaaaa-bbbb-cccc-dddd-ffffffffffff' LIMIT 1
  );
```

**O que verificar:** Todas as 4 tabelas devem ter contagem > 0. Se `respostas_raw_backup` tem
registro mas as outras não, o RPC falhou após o INSERT do backup (mas antes do COMMIT — na
prática isso não acontece pois é tudo uma transação, mas indica rollback).

### 6. Verificar idempotência (segunda submissão com mesmo session_id)

```sql
-- Chamar com EXATAMENTE o mesmo session_id
SELECT salvar_resposta(
  '<empresa_id>'::uuid,
  '<ciclo_id>'::uuid,
  '<token>',
  'SETOR_TESTE_IDEMPOTENCIA',
  'CARGO_DIFERENTE',
  'Fundamental',
  '[{"questao_id":"<id1>","valor":4}]'::jsonb,
  'aaaaaaaa-bbbb-cccc-dddd-ffffffffffff'::uuid,  -- mesmo session_id
  true,
  'validacao-idempotencia'
);

-- Deve retornar o MESMO resposta_id da chamada anterior
-- E respostas deve continuar com apenas 1 registro para esse session_id
SELECT COUNT(*) FROM respostas WHERE session_id::text = 'aaaaaaaa-bbbb-cccc-dddd-ffffffffffff';
```

**O que verificar:** A segunda chamada deve retornar o mesmo UUID e NÃO criar nova linha em
`respostas`. Se criar duplicata, o mecanismo de idempotência está quebrado.

### 7. Limpar dados de teste

```sql
-- SEMPRE limpar após validação
DELETE FROM respostas_raw_backup
  WHERE session_id::text = 'aaaaaaaa-bbbb-cccc-dddd-ffffffffffff';

DELETE FROM resposta_itens
  WHERE resposta_id IN (
    SELECT id FROM respostas WHERE session_id::text = 'aaaaaaaa-bbbb-cccc-dddd-ffffffffffff'
  );

DELETE FROM respostas_fila
  WHERE payload_json->>'session_id' LIKE '%aaaaaaaa-bbbb-cccc-dddd-ffffffffffff%';

DELETE FROM respostas
  WHERE session_id::text = 'aaaaaaaa-bbbb-cccc-dddd-ffffffffffff';
```

### 8. Teste via formulário real (opcional mas recomendado)

Abrir o link de formulário no browser e submeter uma resposta completa. Verificar no banco:

```sql
-- Última resposta recebida (rodar logo após submeter)
SELECT r.id, r.setor, r.funcao, r.respondido_em,
       COUNT(ri.id) as total_itens,
       rf.status as fila_status
FROM respostas r
LEFT JOIN resposta_itens ri ON ri.resposta_id = r.id
LEFT JOIN respostas_fila rf ON rf.empresa_id = r.empresa_id
  AND rf.payload_json->>'session_id' = r.session_id
WHERE r.respondido_em > now() - interval '10 minutes'
GROUP BY r.id, r.setor, r.funcao, r.respondido_em, rf.status
ORDER BY r.respondido_em DESC LIMIT 5;
```

## Resultado esperado (tudo OK)

| Item | Esperado |
|------|----------|
| `session_id` tipo | Compatível entre coluna e parâmetro RPC |
| RPC `salvar_resposta` | SECURITY DEFINER + search_path correto |
| GRANTs | SELECT/INSERT/UPDATE/DELETE para `authenticated` em todas as tabelas |
| Submissão de teste | Retorna UUID sem erro |
| 4 tabelas | Todas com COUNT > 0 |
| Idempotência | Segunda chamada retorna mesmo UUID, COUNT=1 |
| Limpeza | Todos os registros de teste removidos |

## Quando algo falhar

| Erro | Causa provável | Ação |
|------|---------------|------|
| `operator does not exist: text = uuid` | `session_id` é `text`, sem cast no RPC | Adicionar `::text` na checagem de idempotência |
| `operator does not exist: uuid = text` | `session_id` é `uuid`, cast errado | Remover `::text` da checagem |
| `permission denied for table X` | GRANT ausente | `GRANT SELECT,INSERT,UPDATE,DELETE ON X TO authenticated,anon` |
| `token_invalido` | Link não existe ou expirou | Usar outro link ativo |
| Sem dados em nenhuma tabela | Falha antes do primeiro INSERT ou rollback total | Verificar logs do Supabase |
| `respostas_raw_backup` com dados, resto vazio | Impossível (transação única) — verificar se tabelas são as corretas | Conferir schema |

## IDs dos projetos Supabase

- **DEV**: `szqatgvgghxvyyncsjxl` (branch `develop` do Cloudflare)
- **PROD**: `vftyiildukrpgmnbcnao` (branch `main` do Cloudflare)
