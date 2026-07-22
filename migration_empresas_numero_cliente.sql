-- ══════════════════════════════════════════════════════════════════════
-- migration_empresas_numero_cliente.sql
-- Codigo curto sequencial por tenant para referencia de clientes
-- (ex.: CLI-007), gerado por contador dedicado — nunca reutilizado mesmo
-- apos exclusao de empresa (hard delete). Aplicar em DEV, validar, PROD.
-- ══════════════════════════════════════════════════════════════════════

-- Contador atomico por tenant
CREATE TABLE IF NOT EXISTS tenant_contadores (
  tenant_id uuid PRIMARY KEY REFERENCES tenants(id) ON DELETE CASCADE,
  contador_empresas integer NOT NULL DEFAULT 0
);

ALTER TABLE empresas ADD COLUMN IF NOT EXISTS numero_cliente integer;

CREATE OR REPLACE FUNCTION fn_atribuir_numero_cliente()
RETURNS trigger AS $$
DECLARE
  novo_numero integer;
BEGIN
  -- Linhas legadas sem tenant_id nao recebem numero (evita violar a PK do contador)
  IF NEW.tenant_id IS NULL THEN
    RETURN NEW;
  END IF;

  INSERT INTO tenant_contadores (tenant_id, contador_empresas)
  VALUES (NEW.tenant_id, 1)
  ON CONFLICT (tenant_id) DO UPDATE SET contador_empresas = tenant_contadores.contador_empresas + 1
  RETURNING contador_empresas INTO novo_numero;

  NEW.numero_cliente := novo_numero;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_numero_cliente ON empresas;
CREATE TRIGGER trg_numero_cliente
  BEFORE INSERT ON empresas
  FOR EACH ROW
  WHEN (NEW.numero_cliente IS NULL)
  EXECUTE FUNCTION fn_atribuir_numero_cliente();

-- Funcao de trigger nao deve ficar exposta como RPC publico (Postgres concede
-- EXECUTE a PUBLIC por padrao em toda funcao nova)
REVOKE EXECUTE ON FUNCTION fn_atribuir_numero_cliente() FROM PUBLIC, anon, authenticated;

-- Backfill: numera os clientes ja existentes, por tenant, na ordem de criacao
-- (linhas com tenant_id NULL ficam sem numero — mesmo criterio do trigger)
WITH numerados AS (
  SELECT id, tenant_id,
         row_number() OVER (PARTITION BY tenant_id ORDER BY criado_em) AS rn
  FROM empresas
  WHERE numero_cliente IS NULL AND tenant_id IS NOT NULL
)
UPDATE empresas e SET numero_cliente = n.rn
FROM numerados n WHERE e.id = n.id;

-- Sincroniza o contador de cada tenant com o maior numero ja usado (evita colisao pos-backfill)
INSERT INTO tenant_contadores (tenant_id, contador_empresas)
SELECT tenant_id, MAX(numero_cliente)
FROM empresas
WHERE tenant_id IS NOT NULL AND numero_cliente IS NOT NULL
GROUP BY tenant_id
ON CONFLICT (tenant_id) DO UPDATE SET contador_empresas = GREATEST(tenant_contadores.contador_empresas, EXCLUDED.contador_empresas);
