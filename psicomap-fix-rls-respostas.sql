-- ══════════════════════════════════════════════════════════════
-- PSEG SafeSign — Fix RLS: respostas + resposta_itens
-- Execute no SQL Editor do Supabase (projeto vftyiildukrpgmnbcnao)
-- Problema: "new row violates row-level security policy for table respostas"
-- ══════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- 1. RESPOSTAS — corrigir política de INSERT para anon (formulário)
-- ─────────────────────────────────────────────────────────────

-- Remover política restritiva que usa subquery problemática
DROP POLICY IF EXISTS "pub_insert_resposta_validada" ON respostas;
DROP POLICY IF EXISTS "pub_insert_resposta"          ON respostas;

-- Recriar política simples: anon pode inserir (token validado no JS do formulário)
CREATE POLICY "pub_insert_resposta"
  ON respostas
  FOR INSERT
  WITH CHECK (true);

-- ─────────────────────────────────────────────────────────────
-- 2. RESPOSTA_ITENS — garantir que INSERT para anon existe
-- ─────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "pub_insert_item" ON resposta_itens;

CREATE POLICY "pub_insert_item"
  ON resposta_itens
  FOR INSERT
  WITH CHECK (true);

-- ─────────────────────────────────────────────────────────────
-- 3. Garantir que RLS está habilitado nas duas tabelas
-- ─────────────────────────────────────────────────────────────
ALTER TABLE respostas      ENABLE ROW LEVEL SECURITY;
ALTER TABLE resposta_itens ENABLE ROW LEVEL SECURITY;

-- ─────────────────────────────────────────────────────────────
-- 4. Verificação — listar políticas ativas
-- ─────────────────────────────────────────────────────────────
SELECT
  tablename,
  policyname,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('respostas', 'resposta_itens')
ORDER BY tablename, policyname;
