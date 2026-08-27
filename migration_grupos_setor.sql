-- ══════════════════════════════════════════════════════════════════════════
-- PsicoMap — Agrupamentos de setores/funções para geração de relatórios
-- Executar no Supabase Dashboard → SQL Editor (ou via MCP apply_migration)
-- Ordem: DEV (szqatgvgghxvyyncsjxl) primeiro, PROD (vftyiildukrpgmnbcnao) depois
-- ══════════════════════════════════════════════════════════════════════════
--
-- POR QUÊ UMA TABELA SEPARADA (e não empresa_setores.grupo):
-- A coluna `grupo` já existe em `empresa_setores` (selecionada em showApp()) mas
-- foi descartada como solução porque:
--   1. Reimportação GHE (evento frequente — "catálogo reflete a planilha") pode
--      sobrescrever as linhas e apagar as atribuições de grupo sem aviso.
--   2. CLAUDE.md: "O catálogo reflete a planilha — não o contrário."
--
-- SEMÂNTICA:
-- - Um grupo mapeia um nome legível → N nomes de setor (texto livre, idêntico a
--   respostas.setor). Nenhum FK para empresa_setores — o match é por texto.
-- - Setores fora de qualquer grupo aparecem individualmente na análise (fallback
--   idêntico ao comportamento atual quando grupos = []).
-- - Escopo: por empresa (não por ciclo). O consultor configura uma vez; persiste
--   entre ciclos.
-- - A tabela também suporta agrupamentos de FUNÇÕES (funcao = texto em respostas)
--   pelo campo `tipo`: 'setor' | 'funcao'.
--
-- RBAC:
-- - SELECT:  qualquer membro do tenant (inclui cliente_viewer — lê efeito no laudo)
-- - WRITE:   apenas admin e consultor (viewer bloqueado pela ausência de policy de escrita)
-- - super_admin: bypass total
--
-- IMPACTO EM PRODUÇÃO: zero — tabela nova sem dados. O frontend usa `agruparPorGrupos()`
-- que já trata grupos=[] retornando cada setor individualmente (comportamento atual).

-- ── Tabela ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS grupos_setor (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id    uuid        NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  tenant_id     uuid        NOT NULL REFERENCES tenants(id)  ON DELETE CASCADE,
  tipo          text        NOT NULL DEFAULT 'setor' CHECK (tipo IN ('setor', 'funcao')),
  nome          text        NOT NULL,
  itens         text[]      NOT NULL DEFAULT '{}',
  ordem         int         NOT NULL DEFAULT 0,
  criado_em     timestamptz NOT NULL DEFAULT now(),
  atualizado_em timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_grupos_setor_empresa ON grupos_setor (empresa_id, tipo);

ALTER TABLE grupos_setor ENABLE ROW LEVEL SECURITY;

-- GRANT: sem isso o Postgres bloqueia antes de checar RLS
GRANT SELECT, INSERT, UPDATE, DELETE ON grupos_setor TO authenticated;

-- ── Policies ─────────────────────────────────────────────────────────────────

-- SELECT: qualquer membro autenticado do tenant (inclui viewer)
-- OR is_super_admin(): super_admin tem tenant_id NULL — sem isso a comparação falha.
DROP POLICY IF EXISTS "grupos_setor_select" ON grupos_setor;
CREATE POLICY "grupos_setor_select" ON grupos_setor
  FOR SELECT TO authenticated
  USING (tenant_id = get_my_tenant_id() OR is_super_admin());

-- WRITE (ALL): admin, consultor e super_admin. Viewer não passa — sem policy de
-- INSERT/UPDATE/DELETE que o cubra, o RLS bloqueia por padrão.
DROP POLICY IF EXISTS "grupos_setor_write" ON grupos_setor;
CREATE POLICY "grupos_setor_write" ON grupos_setor
  FOR ALL TO authenticated
  USING (
    (tenant_id = get_my_tenant_id() AND auth_role() IN ('admin', 'consultor'))
    OR is_super_admin()
  )
  WITH CHECK (
    (tenant_id = get_my_tenant_id() AND auth_role() IN ('admin', 'consultor'))
    OR is_super_admin()
  );

-- ── Comentários ───────────────────────────────────────────────────────────────
COMMENT ON TABLE grupos_setor IS
  'Agrupamentos de setores ou funções por empresa, usados exclusivamente para geração '
  'de relatórios. Não afeta respostas, empresa_setores nem links_coleta.';
COMMENT ON COLUMN grupos_setor.tipo IS
  '''setor'' ou ''funcao'' — determina se os itens são nomes de respostas.setor ou respostas.funcao.';
COMMENT ON COLUMN grupos_setor.itens IS
  'Array de nomes (texto exato igual a respostas.setor ou respostas.funcao). '
  'Match feito por igualdade de string no frontend, igual ao comportamento atual.';

-- ── Verificação ───────────────────────────────────────────────────────────────
SELECT tablename, policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'grupos_setor'
ORDER BY policyname;
