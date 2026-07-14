-- ══════════════════════════════════════════════════════════════════════
-- migration_fix_empresa_funcoes_unique.sql
-- Corrige unicidade de nome de cargo: era por empresa inteira, deveria
-- ser por setor. Aplicado em DEV e PROD em 2026-07-13.
-- ══════════════════════════════════════════════════════════════════════

-- Problema: UNIQUE (empresa_id, nome) impedia o mesmo cargo (ex.
-- "Operador") de existir em dois setores diferentes da mesma empresa —
-- cenário comum no mundo real (mesmo cargo em setores/departamentos
-- distintos). O salvarGHE() do admin não valida essa colisão entre
-- setores diferentes antes de salvar (só dentro do mesmo setor +
-- universais), então o INSERT em lote falhava com "duplicate key value
-- violates unique constraint empresa_funcoes_empresa_id_nome_key".

ALTER TABLE empresa_funcoes DROP CONSTRAINT IF EXISTS empresa_funcoes_empresa_id_nome_key;
ALTER TABLE empresa_funcoes ADD CONSTRAINT empresa_funcoes_empresa_id_setor_id_nome_key
  UNIQUE (empresa_id, setor_id, nome);

-- Nota: cargos universais (setor_id NULL) não ganham unicidade de nome
-- garantida pelo banco (Postgres trata NULL como distinto em UNIQUE),
-- mas a UI (adicionarGHEUniversal) já impede duplicata nesse caso.
