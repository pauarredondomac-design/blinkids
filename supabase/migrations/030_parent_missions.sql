-- ─────────────────────────────────────────────────────────────────────────────
-- 030_parent_missions.sql
-- 1. Recarga semanal de monedas virtuales para la billetera de cada padre.
-- 2. Tabla parent_missions: misiones que un papá/mamá crea para un hijo
--    vinculado, con recompensa en monedas pagada desde su propia billetera.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── 1. Recarga semanal en wallets ──────────────────────────────────────────
-- weekly_allowance: cuántas monedas recibe este usuario cada semana (0 = no aplica).
-- allowance_last_granted_at: última vez que se otorgó la recarga.
ALTER TABLE wallets
  ADD COLUMN IF NOT EXISTS weekly_allowance INTEGER NOT NULL DEFAULT 0 CHECK (weekly_allowance >= 0);

ALTER TABLE wallets
  ADD COLUMN IF NOT EXISTS allowance_last_granted_at TIMESTAMPTZ;

-- Todo padre existente arranca con 500 monedas/semana por defecto.
UPDATE wallets w
SET weekly_allowance = 500
FROM profiles p
WHERE p.id = w.user_id
  AND p.role = 'parent'
  AND w.weekly_allowance = 0;

-- RPC: otorga la recarga semanal al padre actual (auth.uid()) si ya toca.
-- Se llama desde el panel de padres al abrirlo. Devuelve cuánto se otorgó
-- (0 si aún no toca o si el usuario no es padre / no tiene wallet).
CREATE OR REPLACE FUNCTION grant_weekly_allowance_if_due()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid     UUID := auth.uid();
  v_wallet  wallets%ROWTYPE;
  v_granted INTEGER := 0;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Se requiere sesión activa';
  END IF;

  SELECT * INTO v_wallet FROM wallets WHERE user_id = v_uid FOR UPDATE;
  IF NOT FOUND OR v_wallet.weekly_allowance <= 0 THEN
    RETURN 0;
  END IF;

  IF v_wallet.allowance_last_granted_at IS NULL
     OR v_wallet.allowance_last_granted_at <= now() - INTERVAL '7 days' THEN
    UPDATE wallets
    SET total_coins = total_coins + v_wallet.weekly_allowance,
        allowance_last_granted_at = now(),
        updated_at = now()
    WHERE user_id = v_uid;
    v_granted := v_wallet.weekly_allowance;
  END IF;

  RETURN v_granted;
END;
$$;

REVOKE ALL ON FUNCTION grant_weekly_allowance_if_due() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION grant_weekly_allowance_if_due() TO authenticated;

-- ── 2. Tabla parent_missions ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS parent_missions (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id     UUID        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  child_id      UUID        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title         TEXT        NOT NULL,
  description   TEXT,
  coin_reward   INTEGER     NOT NULL CHECK (coin_reward > 0),
  status        TEXT        NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','completed','cancelled')),
  created_at    TIMESTAMPTZ DEFAULT now(),
  completed_at  TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_parent_missions_child  ON parent_missions(child_id);
CREATE INDEX IF NOT EXISTS idx_parent_missions_parent ON parent_missions(parent_id);

ALTER TABLE parent_missions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "parent_reads_own_missions"
  ON parent_missions FOR SELECT USING (auth.uid() = parent_id);

CREATE POLICY "child_reads_own_missions"
  ON parent_missions FOR SELECT USING (auth.uid() = child_id);

-- El padre puede cancelar mientras siga pendiente; el pago solo ocurre
-- a través del RPC complete_parent_mission (nunca por UPDATE directo).
CREATE POLICY "parent_updates_pending_missions"
  ON parent_missions FOR UPDATE
  USING (auth.uid() = parent_id AND status = 'pending');

-- ── RPC: crear misión de papá ────────────────────────────────────────────────
-- Solo el padre vinculado (parent_child, status='accepted') puede crear
-- misiones para ese hijo. Inserta también una notificación para el hijo.
CREATE OR REPLACE FUNCTION create_parent_mission(
  p_child_id    UUID,
  p_title       TEXT,
  p_description TEXT,
  p_coin_reward INTEGER
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid        UUID := auth.uid();
  v_mission_id UUID;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Se requiere sesión activa';
  END IF;

  IF p_coin_reward IS NULL OR p_coin_reward <= 0 THEN
    RAISE EXCEPTION 'La recompensa debe ser mayor a 0';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM parent_child
    WHERE parent_id = v_uid AND child_id = p_child_id AND status = 'accepted'
  ) THEN
    RAISE EXCEPTION 'No tienes un hijo vinculado con ese id';
  END IF;

  INSERT INTO parent_missions (parent_id, child_id, title, description, coin_reward)
  VALUES (v_uid, p_child_id, trim(p_title), NULLIF(trim(p_description), ''), p_coin_reward)
  RETURNING id INTO v_mission_id;

  INSERT INTO notifications (user_id, type, title, body, data)
  VALUES (
    p_child_id,
    'parent_mission_created',
    '¡Nueva misión de tu papá! 👨‍👩‍👧',
    trim(p_title),
    jsonb_build_object('mission_id', v_mission_id, 'coin_reward', p_coin_reward)
  );

  RETURN v_mission_id;
END;
$$;

REVOKE ALL ON FUNCTION create_parent_mission(UUID, TEXT, TEXT, INTEGER) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION create_parent_mission(UUID, TEXT, TEXT, INTEGER) TO authenticated;

-- ── RPC: completar misión de papá ────────────────────────────────────────────
-- La llama el hijo (auth.uid() = child_id de la misión). Paga la recompensa
-- desde la billetera del padre a la del hijo de forma atómica.
-- Lanza excepción si el padre no tiene saldo suficiente.
CREATE OR REPLACE FUNCTION complete_parent_mission(p_mission_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid     UUID := auth.uid();
  v_mission parent_missions%ROWTYPE;
  v_paid    INTEGER;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Se requiere sesión activa';
  END IF;

  SELECT * INTO v_mission
  FROM parent_missions
  WHERE id = p_mission_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Misión no encontrada';
  END IF;

  IF v_mission.child_id != v_uid THEN
    RAISE EXCEPTION 'Esta misión no te pertenece';
  END IF;

  IF v_mission.status != 'pending' THEN
    RAISE EXCEPTION 'Esta misión ya no está pendiente';
  END IF;

  -- Descontar del padre solo si tiene saldo suficiente (atómico, sin race condition).
  UPDATE wallets
  SET total_coins = total_coins - v_mission.coin_reward,
      updated_at  = now()
  WHERE user_id = v_mission.parent_id
    AND total_coins >= v_mission.coin_reward
  RETURNING total_coins INTO v_paid;

  IF v_paid IS NULL THEN
    RAISE EXCEPTION 'Tu papá no tiene monedas suficientes ahora mismo. Inténtalo más tarde.';
  END IF;

  UPDATE wallets
  SET total_coins = total_coins + v_mission.coin_reward,
      updated_at  = now()
  WHERE user_id = v_uid;

  UPDATE parent_missions
  SET status = 'completed', completed_at = now()
  WHERE id = p_mission_id;

  INSERT INTO notifications (user_id, type, title, body, data)
  VALUES (
    v_mission.parent_id,
    'parent_mission_completed',
    '¡Misión completada! 🎉',
    v_mission.title,
    jsonb_build_object('mission_id', p_mission_id, 'coin_reward', v_mission.coin_reward)
  );
END;
$$;

REVOKE ALL ON FUNCTION complete_parent_mission(UUID) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION complete_parent_mission(UUID) TO authenticated;
