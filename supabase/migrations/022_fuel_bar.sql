-- ─────────────────────────────────────────────────────────────────────────────
-- 022_fuel_bar.sql
--
-- Barra de combustible por mundo (independiente del XP).
-- Cuando fuel = 100 en el mundo espacio → el niño llega a Marte.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── Tabla principal ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS world_fuel (
  user_id    UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  world_slug TEXT        NOT NULL,
  fuel       INTEGER     NOT NULL DEFAULT 0 CHECK (fuel >= 0 AND fuel <= 100),
  cycle      INTEGER     NOT NULL DEFAULT 1,  -- se incrementa al completar 100%
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, world_slug)
);

-- Índice para padres consultando hijos
CREATE INDEX IF NOT EXISTS idx_world_fuel_user ON world_fuel(user_id);

-- ── RLS ───────────────────────────────────────────────────────────────────────
ALTER TABLE world_fuel ENABLE ROW LEVEL SECURITY;

-- El niño lee/escribe su propio fuel
CREATE POLICY "child_own_fuel"
  ON world_fuel FOR ALL
  USING  (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- El padre lee el fuel de sus hijos vinculados
CREATE POLICY "parent_reads_child_fuel"
  ON world_fuel FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM parent_child pc
      WHERE pc.parent_id = auth.uid()
        AND pc.child_id  = world_fuel.user_id
    )
  );

-- ── RPC: add_fuel ─────────────────────────────────────────────────────────────
-- Suma fuel al usuario actual.
-- Si alcanza 100 devuelve TRUE (evento Hangar de Despegue).
-- El fuel se queda en 100 hasta que se reinicie con reset_fuel().
CREATE OR REPLACE FUNCTION add_fuel(
  p_world_slug TEXT,
  p_amount     INTEGER
)
RETURNS BOOLEAN   -- TRUE si fuel llegó a 100 (o ya era 100 y sube más)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old_fuel INTEGER;
  v_new_fuel INTEGER;
  v_reached  BOOLEAN := FALSE;
BEGIN
  -- Upsert + lectura atómica
  INSERT INTO world_fuel(user_id, world_slug, fuel, updated_at)
  VALUES (auth.uid(), p_world_slug, LEAST(p_amount, 100), now())
  ON CONFLICT (user_id, world_slug) DO UPDATE
    SET fuel       = LEAST(world_fuel.fuel + p_amount, 100),
        updated_at = now()
  RETURNING fuel INTO v_new_fuel;

  -- Detectar primer arribo a 100
  SELECT fuel INTO v_old_fuel
  FROM world_fuel
  WHERE user_id = auth.uid() AND world_slug = p_world_slug;

  IF v_new_fuel = 100 THEN
    v_reached := TRUE;
  END IF;

  RETURN v_reached;
END;
$$;

GRANT EXECUTE ON FUNCTION add_fuel(TEXT, INTEGER) TO authenticated;

-- ── RPC: reset_fuel ───────────────────────────────────────────────────────────
-- Llama a esto después de que el niño completa el Hangar de Despegue.
-- Reinicia fuel a 0 e incrementa cycle.
CREATE OR REPLACE FUNCTION reset_fuel(p_world_slug TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE world_fuel
  SET fuel       = 0,
      cycle      = cycle + 1,
      updated_at = now()
  WHERE user_id    = auth.uid()
    AND world_slug = p_world_slug;
END;
$$;

GRANT EXECUTE ON FUNCTION reset_fuel(TEXT) TO authenticated;

-- ── RPC: get_fuel ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_fuel(p_world_slug TEXT)
RETURNS INTEGER
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT fuel FROM world_fuel
     WHERE user_id = auth.uid() AND world_slug = p_world_slug),
    0
  );
$$;

GRANT EXECUTE ON FUNCTION get_fuel(TEXT) TO authenticated;
