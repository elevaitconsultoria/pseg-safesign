-- ══════════════════════════════════════════════════════════
-- PSEG SafeSign — Schema v3 (definitivo)
-- Modelo: 1 questionário por empresa · questões globais reutilizáveis · setor livre
-- Execute no SQL Editor do Supabase
-- ══════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─────────────────────────────────────────
-- 1. EMPRESAS
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS empresas (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nome            TEXT NOT NULL,
  cnpj            TEXT,
  contato         TEXT,
  ativo           BOOLEAN DEFAULT true,
  criado_em       TIMESTAMPTZ DEFAULT now()
  -- questionario_id adicionado depois (FK circular resolvida abaixo)
);

-- ─────────────────────────────────────────
-- 2. BANCO GLOBAL DE QUESTÕES
--    Todas as questões disponíveis:
--    - is_oficial = true → 27 questões padrão PSEG
--    - is_oficial = false → extras criadas por empresa, visíveis para PSEG reutilizar
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS questoes (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  codigo        TEXT UNIQUE NOT NULL,   -- 'Q01'…'Q27' oficiais; 'QEXT_001' extras
  texto         TEXT NOT NULL,
  bloco         TEXT NOT NULL CHECK (bloco IN ('A','B','C','EXTRA')),
  fator_id      TEXT NOT NULL,          -- R01…R11 (extras também mapeiam para um fator)
  inversa       BOOLEAN DEFAULT false,
  is_ancora     BOOLEAN DEFAULT false,  -- questão mínima para o fator — não pode ser removida
  is_oficial    BOOLEAN DEFAULT true,   -- false = questão extra criada por empresa/PSEG
  criada_por_empresa_id UUID REFERENCES empresas(id) ON DELETE SET NULL,
  criado_em     TIMESTAMPTZ DEFAULT now()
);

-- ─────────────────────────────────────────
-- 3. QUESTIONÁRIOS (1 por empresa; existe 1 global padrão)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS questionarios (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nome          TEXT NOT NULL,
  empresa_id    UUID REFERENCES empresas(id) ON DELETE CASCADE, -- null = questionário global PSEG
  ativo         BOOLEAN DEFAULT true,
  criado_em     TIMESTAMPTZ DEFAULT now()
);

-- FK circular: empresa → questionário
ALTER TABLE empresas
  ADD COLUMN IF NOT EXISTS questionario_id UUID REFERENCES questionarios(id) ON DELETE SET NULL;

-- ─────────────────────────────────────────
-- 4. QUESTÕES ATIVAS EM CADA QUESTIONÁRIO
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS questionario_questoes (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  questionario_id  UUID NOT NULL REFERENCES questionarios(id) ON DELETE CASCADE,
  questao_id       UUID NOT NULL REFERENCES questoes(id) ON DELETE CASCADE,
  ordem            INT NOT NULL DEFAULT 0,
  ativa            BOOLEAN DEFAULT true,
  UNIQUE (questionario_id, questao_id)
);

-- ─────────────────────────────────────────
-- 5. CICLOS DE AVALIAÇÃO
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ciclos (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  empresa_id    UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  nome          TEXT NOT NULL,           -- ex: "Avaliação 2025-S1"
  data_inicio   DATE,
  data_fim      DATE,
  status        TEXT DEFAULT 'aberto' CHECK (status IN ('aberto','encerrado','laudo_gerado')),
  criado_em     TIMESTAMPTZ DEFAULT now()
);

-- ─────────────────────────────────────────
-- 6. LINKS DE COLETA
--    Cada link gerado para uma empresa tem:
--    - token único
--    - setor PRÉ-PREENCHIDO pelo admin (aparece no form, funcionário pode confirmar)
--    - ou setor em branco (funcionário digita livremente)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS links_coleta (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  empresa_id      UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  ciclo_id        UUID REFERENCES ciclos(id) ON DELETE SET NULL,
  token           TEXT UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(16), 'hex'),
  setor_sugerido  TEXT,   -- admin pode preencher para facilitar; funcionário confirma no form
  ativo           BOOLEAN DEFAULT true,
  expira_em       TIMESTAMPTZ,
  criado_em       TIMESTAMPTZ DEFAULT now()
);

-- ─────────────────────────────────────────
-- 7. RESPOSTAS (1 por sessão de preenchimento)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS respostas (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  empresa_id      UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  ciclo_id        UUID REFERENCES ciclos(id) ON DELETE SET NULL,
  link_token      TEXT,                  -- token usado para chegar ao formulário
  questionario_id UUID REFERENCES questionarios(id), -- snapshot de qual questionário foi usado
  setor           TEXT NOT NULL,         -- digitado pelo funcionário (campo livre)
  funcao          TEXT,
  escolaridade    TEXT,
  fonte           TEXT DEFAULT 'formulario_web' CHECK (fonte IN ('formulario_web','import_csv')),
  respondido_em   TIMESTAMPTZ DEFAULT now()
);

-- ─────────────────────────────────────────
-- 8. ITENS DE RESPOSTA (1 linha por questão respondida)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS resposta_itens (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  resposta_id   UUID NOT NULL REFERENCES respostas(id) ON DELETE CASCADE,
  questao_id    UUID NOT NULL REFERENCES questoes(id),
  valor         SMALLINT NOT NULL CHECK (valor BETWEEN 1 AND 4),
  UNIQUE (resposta_id, questao_id)
);

-- ─────────────────────────────────────────
-- 9. LAUDOS (snapshot dos resultados calculados)
-- ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS laudos (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  empresa_id      UUID NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
  ciclo_id        UUID REFERENCES ciclos(id) ON DELETE SET NULL,
  gerado_por      TEXT,
  gerado_em       TIMESTAMPTZ DEFAULT now(),
  snapshot_json   JSONB NOT NULL,   -- resultados calculados no momento — imutável
  pdf_url         TEXT
);

-- ═══════════════════════════════
-- ÍNDICES
-- ═══════════════════════════════
CREATE INDEX IF NOT EXISTS idx_respostas_empresa    ON respostas(empresa_id);
CREATE INDEX IF NOT EXISTS idx_respostas_ciclo      ON respostas(ciclo_id);
CREATE INDEX IF NOT EXISTS idx_respostas_setor      ON respostas(setor);
CREATE INDEX IF NOT EXISTS idx_respostas_data       ON respostas(respondido_em DESC);
CREATE INDEX IF NOT EXISTS idx_ri_resposta          ON resposta_itens(resposta_id);
CREATE INDEX IF NOT EXISTS idx_ri_questao           ON resposta_itens(questao_id);
CREATE INDEX IF NOT EXISTS idx_qq_questionario      ON questionario_questoes(questionario_id);
CREATE INDEX IF NOT EXISTS idx_links_token          ON links_coleta(token);
CREATE INDEX IF NOT EXISTS idx_links_empresa        ON links_coleta(empresa_id);
CREATE INDEX IF NOT EXISTS idx_questoes_fator       ON questoes(fator_id);
CREATE INDEX IF NOT EXISTS idx_questoes_oficial     ON questoes(is_oficial);

-- ═══════════════════════════════
-- ROW LEVEL SECURITY
-- ═══════════════════════════════
ALTER TABLE empresas           ENABLE ROW LEVEL SECURITY;
ALTER TABLE questoes           ENABLE ROW LEVEL SECURITY;
ALTER TABLE questionarios      ENABLE ROW LEVEL SECURITY;
ALTER TABLE questionario_questoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE links_coleta       ENABLE ROW LEVEL SECURITY;
ALTER TABLE respostas          ENABLE ROW LEVEL SECURITY;
ALTER TABLE resposta_itens     ENABLE ROW LEVEL SECURITY;
ALTER TABLE ciclos             ENABLE ROW LEVEL SECURITY;
ALTER TABLE laudos             ENABLE ROW LEVEL SECURITY;

-- Formulário público: pode ler empresa pelo token e inserir resposta
CREATE POLICY "pub_read_empresa"   ON empresas    FOR SELECT USING (ativo = true);
CREATE POLICY "pub_read_link"      ON links_coleta FOR SELECT USING (ativo = true);
CREATE POLICY "pub_read_questoes"  ON questoes    FOR SELECT USING (true);
CREATE POLICY "pub_read_qq"        ON questionario_questoes FOR SELECT USING (true);
CREATE POLICY "pub_read_questionarios" ON questionarios FOR SELECT USING (true);
CREATE POLICY "pub_insert_resposta" ON respostas  FOR INSERT WITH CHECK (true);
CREATE POLICY "pub_insert_item"    ON resposta_itens FOR INSERT WITH CHECK (true);
-- Admin usa service_role → ignora RLS por padrão

-- ═══════════════════════════════
-- TRIGGER: protege questões âncora
-- ═══════════════════════════════
CREATE OR REPLACE FUNCTION fn_proteger_ancora()
RETURNS TRIGGER AS $$
BEGIN
  IF (SELECT is_ancora FROM questoes WHERE id = NEW.questao_id) = true
     AND NEW.ativa = false THEN
    RAISE EXCEPTION 'Questão âncora não pode ser desativada — ela garante cobertura mínima do fator de risco.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tg_proteger_ancora
  BEFORE UPDATE ON questionario_questoes
  FOR EACH ROW
  WHEN (OLD.ativa = true AND NEW.ativa = false)
  EXECUTE FUNCTION fn_proteger_ancora();

-- ═══════════════════════════════
-- VIEWS ÚTEIS
-- ═══════════════════════════════

-- Questões ativas do questionário de uma empresa
CREATE OR REPLACE VIEW v_questoes_empresa AS
SELECT
  e.id                AS empresa_id,
  e.nome              AS empresa_nome,
  COALESCE(e.questionario_id, '00000000-0000-0000-0000-000000000001'::uuid) AS questionario_id,
  q.id                AS questao_id,
  q.codigo,
  q.texto,
  q.bloco,
  q.fator_id,
  q.inversa,
  q.is_ancora,
  q.is_oficial,
  qq.ordem
FROM empresas e
JOIN questionario_questoes qq
  ON qq.questionario_id = COALESCE(e.questionario_id, '00000000-0000-0000-0000-000000000001'::uuid)
  AND qq.ativa = true
JOIN questoes q ON q.id = qq.questao_id
ORDER BY e.id, qq.ordem;

-- Respostas completas com contexto (para o admin)
CREATE OR REPLACE VIEW v_respostas_admin AS
SELECT
  r.id,
  e.nome        AS empresa,
  c.nome        AS ciclo,
  r.setor,
  r.funcao,
  r.escolaridade,
  r.fonte,
  r.respondido_em,
  r.questionario_id
FROM respostas r
JOIN empresas e ON r.empresa_id = e.id
LEFT JOIN ciclos c ON r.ciclo_id = c.id;

-- Cobertura de fatores por questionário
CREATE OR REPLACE VIEW v_cobertura_questionario AS
SELECT
  qq.questionario_id,
  q.fator_id,
  COUNT(*)                                          AS total_questoes,
  SUM(CASE WHEN qq.ativa THEN 1 ELSE 0 END)::INT   AS ativas,
  BOOL_OR(q.is_ancora AND qq.ativa)                 AS tem_ancora,
  CASE
    WHEN SUM(CASE WHEN qq.ativa THEN 1 ELSE 0 END) = 0 THEN 'zero'
    WHEN SUM(CASE WHEN qq.ativa THEN 1 ELSE 0 END) = 1 THEN 'parcial'
    ELSE 'suficiente'
  END AS cobertura
FROM questionario_questoes qq
JOIN questoes q ON q.id = qq.questao_id
GROUP BY qq.questionario_id, q.fator_id;

-- ═══════════════════════════════
-- DADOS INICIAIS
-- ═══════════════════════════════

-- Questionário padrão PSEG (ID fixo conhecido)
INSERT INTO questionarios (id, nome, empresa_id)
VALUES ('00000000-0000-0000-0000-000000000001', 'Padrão PSEG — 27 questões oficiais', null)
ON CONFLICT (id) DO NOTHING;

-- 27 questões oficiais — textos e mapeamentos atualizados (sessão 2025)
-- fator_id mantido como R-code para compatibilidade; cd_risco real no RISCOS_DETALHES do front
INSERT INTO questoes (codigo, texto, bloco, fator_id, inversa, is_ancora, is_oficial) VALUES
-- Bloco A: Demandas de Trabalho
('Q01','Tenho prazos impossíveis de serem cumpridos?',                                                        'A','R03',false,false,true),
('Q02','Carga de trabalho intensa e excessiva?',                                                              'A','R01',false,true ,true),
('Q03','Excesso de horas extras e falta de pausas?',                                                          'A','R01',false,false,true),
('Q04','Tarefas com prazos inatingíveis?',                                                                    'A','R03',false,false,true),
('Q05','Na equipe que participo, cada colaborador tem suas tarefas e responsabilidades bem definidas?',       'A','R03',true ,false,true),
('Q06','Meu Trabalho e minhas atividades são repetitivas?',                                                   'A','R08',false,false,true),
('Q07','Sou pressionado para trabalhar por longos períodos?',                                                 'A','R01',false,false,true),
-- Bloco B: Relações Interpessoais
('Q08','Sinto que sou tratado(a) de forma justa e respeitosa?',                                               'B','R07',true ,false,true),
('Q09','Existem canais seguros para denúncias de constrangimentos ou comportamentos inadequados?',             'B','R04',true ,false,true),
('Q10','Falta de reconhecimento e desenvolvimento profissional?',                                             'B','R08',false,false,true),
('Q11','O trabalho e as atividades são reconhecidas?',                                                        'B','R08',true ,false,true),
('Q12','Recebo retorno / feedback sobre os trabalhos que realizo?',                                           'B','R08',true ,false,true),
('Q13','Constrangimento e situações expostas publicamente que deveriam ser privadas?',                        'B','R04',false,true ,true),
('Q14','Tenho oportunidades suficientes para questionar as chefias sobre mudanças no trabalho?',              'B','R06',true ,false,true),
('Q15','Estou ciente quais são os meus deveres e responsabilidades?',                                         'B','R06',true ,false,true),
('Q16','Recebo a ajuda e o apoio necessário dos meus colegas?',                                               'B','R07',true ,false,true),
('Q17','Já presenciei conflitos nos locais de trabalho?',                                                     'B','R07',false,true ,true),
('Q18','Tenho conflitos frequentes com meu líder, chefia?',                                                   'B','R06',false,true ,true),
-- Bloco C: Fatores Organizacionais
('Q19','Estou satisfeito com o meu salário (remuneração)?',                                                   'C','R08',true ,false,true),
('Q20','Mudanças frequentes não planejadas?',                                                                 'C','R09',false,false,true),
('Q21','Trabalho em ambiente inadequado, desconfortos físicos e emocionais?',                                 'C','R11',false,true ,true),
('Q22','Quando ocorrem mudanças no trabalho, sou esclarecido de como elas funcionarão na prática?',           'C','R09',true ,false,true),
('Q23','No meu setor acontecem mudanças repentinas sem aviso prévio?',                                        'C','R09',false,false,true),
('Q24','As informações de que preciso para executar minhas tarefas são claras?',                              'C','R06',true ,false,true),
('Q25','Já presenciei/vivenciei situações de desigualdade no local de trabalho?',                             'C','R05',false,false,true),
('Q26','Já presenciei/vivenciei situações de discriminação no local de trabalho?',                            'C','R05',false,true ,true),
('Q27','Tenho medo de perder meu emprego?',                                                                   'C','R10',false,true ,true)
ON CONFLICT (codigo) DO NOTHING;

-- Vincular todas as 27 ao questionário padrão
INSERT INTO questionario_questoes (questionario_id, questao_id, ordem, ativa)
SELECT
  '00000000-0000-0000-0000-000000000001',
  id,
  CAST(SUBSTRING(codigo FROM 2) AS INT),
  true
FROM questoes
WHERE is_oficial = true
ON CONFLICT (questionario_id, questao_id) DO NOTHING;
