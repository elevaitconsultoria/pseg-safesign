-- ══════════════════════════════════════════════════════════════════════════
-- PsicoMap — De-para de nomenclatura (apelidos) por empresa
-- Executar no Supabase Dashboard → SQL Editor (ou via MCP apply_migration)
-- Ordem: DEV (szqatgvgghxvyyncsjxl) primeiro, PROD (vftyiildukrpgmnbcnao) depois
-- Aplicar JUNTO com migration_grupos_setor_ghe.sql, antes do HTML novo.
-- ══════════════════════════════════════════════════════════════════════════
--
-- PROBLEMA QUE RESOLVE:
-- O catálogo da empresa (empresa_setores/empresa_funcoes) vem da planilha de
-- colaboradores que o cliente manda. A matriz de GHE vem do PGR da empresa —
-- outro documento, mantido por outra pessoa, quase sempre com nomenclatura
-- defasada. O mesmo cargo é "Supervisor RH" num e "Coordenador de RH" no outro.
-- Sem memória desse casamento, o consultor refaz o de-para de cabeça a cada
-- importação, para cada empresa.
--
-- SEMÂNTICA:
-- - apelido  = grafia como aparece na planilha de GHE (externa), crua.
-- - canonico = grafia como está no catálogo da empresa, crua.
-- - Direção única: externo → catálogo. Nunca o contrário (o catálogo reflete a
--   planilha do cliente — CLAUDE.md, regra 4).
-- - Escopo por EMPRESA. Decisão explícita de não haver dicionário global do
--   tenant: "Supervisor" em duas empresas pode ser cargo diferente, e uma
--   sugestão errada aplicada em massa é pior que digitar de novo.
--
-- POR QUE `apelido_norm` É COLUNA E NÃO EXPRESSÃO:
-- O banco não tem unaccent nem citext. Toda normalização do projeto é
-- client-side (_gheNormStrong: trim + colapso de espaço + lowercase + NFD +
-- strip de diacríticos). Um índice funcional em lower(apelido) NÃO colapsaria
-- acento e deixaria passar "Produção"/"Producao" como apelidos distintos.
-- A coluna é gravada pelo frontend com o MESMO _gheNormStrong usado na leitura,
-- garantindo que import e consulta concordem.
--
-- POR QUE TEXTO E NÃO FK PARA empresa_funcoes/empresa_setores:
-- salvarGHE() apaga e recria as duas tabelas a cada reimportação de estrutura
-- e regenera todos os id. Uma FK apagaria o de-para justamente no evento em que
-- ele é mais necessário. Mesmo motivo do cabeçalho de migration_grupos_setor.sql.
--
-- RBAC (espelha grupos_setor):
-- - SELECT: qualquer membro do tenant (inclui cliente_viewer)
-- - WRITE:  admin e consultor; super_admin por bypass
--
-- IMPACTO EM PRODUÇÃO: zero — tabela nova, sem dados.

-- ── Tabela ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS empresa_apelidos (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  empresa_id   uuid        NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  tenant_id    uuid        NOT NULL REFERENCES tenants(id)  ON DELETE CASCADE,
  tipo         text        NOT NULL CHECK (tipo IN ('setor', 'funcao')),
  apelido      text        NOT NULL,
  apelido_norm text        NOT NULL,
  canonico     text        NOT NULL,
  criado_em    timestamptz NOT NULL DEFAULT now(),
  atualizado_em timestamptz NOT NULL DEFAULT now()
);

-- Chave de resolução: o frontend consulta por (empresa, tipo, forma normalizada).
CREATE UNIQUE INDEX IF NOT EXISTS uq_empresa_apelidos
  ON empresa_apelidos (empresa_id, tipo, apelido_norm);

CREATE INDEX IF NOT EXISTS idx_empresa_apelidos_tenant
  ON empresa_apelidos (tenant_id);

ALTER TABLE empresa_apelidos ENABLE ROW LEVEL SECURITY;

-- GRANT: sem isso o Postgres bloqueia antes de checar RLS (achado real na
-- criação de grupos_setor — "permission denied" com policies corretas).
GRANT SELECT, INSERT, UPDATE, DELETE ON empresa_apelidos TO authenticated;

-- REVOKE explícito do anon — NÃO é redundante em PROD.
-- Achado real 2026-09-11: o schema `public` do projeto PROD tem ALTER DEFAULT PRIVILEGES
-- concedendo ALL ao `anon` em toda tabela nova (DEV não tem). Sem este REVOKE, a tabela
-- nasce em PROD com CRUD completo para o papel anônimo, e o RLS vira a ÚNICA linha de
-- defesa — as duas policies acima são `TO authenticated`, então o anon recebe [] no SELECT
-- e é barrado no INSERT, mas por RLS, não por privilégio.
-- Nenhum consumidor anônimo existe: o formulário público não lê esta tabela.
REVOKE ALL ON empresa_apelidos FROM anon;

-- ── Policies ─────────────────────────────────────────────────────────────────

-- SELECT: qualquer membro autenticado do tenant (inclui viewer).
-- OR is_super_admin(): super_admin tem tenant_id NULL — sem isso a comparação falha.
DROP POLICY IF EXISTS "empresa_apelidos_select" ON empresa_apelidos;
CREATE POLICY "empresa_apelidos_select" ON empresa_apelidos
  FOR SELECT TO authenticated
  USING (tenant_id = get_my_tenant_id() OR is_super_admin());

-- WRITE (ALL): admin, consultor e super_admin. Viewer não passa — sem policy de
-- INSERT/UPDATE/DELETE que o cubra, o RLS bloqueia por padrão.
DROP POLICY IF EXISTS "empresa_apelidos_write" ON empresa_apelidos;
CREATE POLICY "empresa_apelidos_write" ON empresa_apelidos
  FOR ALL TO authenticated
  USING (
    (tenant_id = get_my_tenant_id() AND auth_role() IN ('admin', 'consultor'))
    OR is_super_admin()
  )
  WITH CHECK (
    (tenant_id = get_my_tenant_id() AND auth_role() IN ('admin', 'consultor'))
    OR is_super_admin()
  );

-- ── Comentários ──────────────────────────────────────────────────────────────
COMMENT ON TABLE empresa_apelidos IS
  'De-para de nomenclatura por empresa: nome como aparece na matriz de GHE do PGR '
  '(apelido) → nome como está no catálogo da empresa (canonico). Alimentado pela '
  'conciliação da importação de Agrupamentos GHE. Não afeta empresa_setores, '
  'empresa_funcoes nem respostas.';
COMMENT ON COLUMN empresa_apelidos.apelido IS
  'Grafia CRUA vinda da planilha externa (matriz de GHE).';
COMMENT ON COLUMN empresa_apelidos.apelido_norm IS
  'apelido passado por _gheNormStrong no frontend (trim + colapso de espaço + '
  'lowercase + NFD + strip de diacríticos). Coluna, e não expressão, porque o banco '
  'não tem unaccent/citext — lower() sozinho não colapsaria acento.';
COMMENT ON COLUMN empresa_apelidos.canonico IS
  'Grafia CRUA do catálogo da empresa (empresa_setores.nome ou empresa_funcoes.nome). '
  'É esta que é gravada em grupos_setor.pares.';

-- ── Verificação ──────────────────────────────────────────────────────────────
SELECT tablename, policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'empresa_apelidos'
ORDER BY policyname;

SELECT grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_name = 'empresa_apelidos'
ORDER BY grantee, privilege_type;
