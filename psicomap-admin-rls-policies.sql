-- ══════════════════════════════════════════════════════════
-- PSEG SafeSign — Políticas RLS para Admin Autenticado
-- Execute este arquivo no SQL Editor do Supabase
-- APÓS ter executado o pseg-schema-v3.sql
-- ══════════════════════════════════════════════════════════
-- O admin faz login via email/senha (Supabase Auth).
-- Usuários autenticados = auth.uid() IS NOT NULL
-- ══════════════════════════════════════════════════════════

-- ─────────────────────────────────────────
-- EMPRESAS — admin pode tudo
-- ─────────────────────────────────────────
CREATE POLICY "admin_all_empresas"
  ON empresas FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- ─────────────────────────────────────────
-- QUESTÕES — admin pode inserir extras e ler todas
-- ─────────────────────────────────────────
CREATE POLICY "admin_all_questoes"
  ON questoes FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- ─────────────────────────────────────────
-- QUESTIONÁRIOS — admin pode criar e gerenciar
-- ─────────────────────────────────────────
CREATE POLICY "admin_all_questionarios"
  ON questionarios FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- ─────────────────────────────────────────
-- QUESTIONÁRIO_QUESTOES — admin salva config
-- ─────────────────────────────────────────
CREATE POLICY "admin_all_qq"
  ON questionario_questoes FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- ─────────────────────────────────────────
-- LINKS_COLETA — admin cria, ativa/desativa
-- ─────────────────────────────────────────
-- Permite SELECT de todos os links (não apenas ativo=true)
DROP POLICY IF EXISTS "pub_read_link" ON links_coleta;
CREATE POLICY "pub_read_link"
  ON links_coleta FOR SELECT
  USING (ativo = true);

CREATE POLICY "admin_all_links"
  ON links_coleta FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- ─────────────────────────────────────────
-- RESPOSTAS — admin lê todas, formulário insere
-- ─────────────────────────────────────────
CREATE POLICY "admin_select_respostas"
  ON respostas FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "admin_delete_respostas"
  ON respostas FOR DELETE
  TO authenticated
  USING (true);

-- ─────────────────────────────────────────
-- RESPOSTA_ITENS — admin lê todos
-- ─────────────────────────────────────────
CREATE POLICY "admin_select_itens"
  ON resposta_itens FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "admin_delete_itens"
  ON resposta_itens FOR DELETE
  TO authenticated
  USING (true);

-- ─────────────────────────────────────────
-- CICLOS — admin gerencia ciclos de avaliação
-- ─────────────────────────────────────────
CREATE POLICY "admin_all_ciclos"
  ON ciclos FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Leitura pública de ciclos (formulário pode precisar)
CREATE POLICY "pub_read_ciclos"
  ON ciclos FOR SELECT
  USING (true);

-- ─────────────────────────────────────────
-- LAUDOS — admin cria e gerencia laudos
-- ─────────────────────────────────────────
CREATE POLICY "admin_all_laudos"
  ON laudos FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- ══════════════════════════════════════════════════════════
-- REALTIME — Habilitar para a tabela respostas
-- (necessário para a contagem em tempo real funcionar)
-- ══════════════════════════════════════════════════════════
-- Execute também no SQL Editor:
ALTER PUBLICATION supabase_realtime ADD TABLE respostas;

-- ══════════════════════════════════════════════════════════
-- VERIFICAÇÃO — liste as políticas criadas
-- ══════════════════════════════════════════════════════════
-- SELECT tablename, policyname, roles, cmd
-- FROM pg_policies
-- WHERE schemaname = 'public'
-- ORDER BY tablename, policyname;
