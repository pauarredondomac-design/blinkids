-- ─────────────────────────────────────────────────────────────────────────────
-- 017_child_pin_auth.sql  (Bloque 2)
-- Soporte para autenticación de niños con PIN de 6 dígitos.
-- El niño se registra con email interno child_{name}@blinkids.app + PIN.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── Columna pin_hash en profiles ─────────────────────────────────────────────
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS pin_hash TEXT;

-- ── account_type: 'limited' hasta que el padre vincule su cuenta ───────────────
-- El tipo account_type ya existe (TEXT). Valores posibles:
--   'demo'     → sin sesión real (Bloque 1 legacy)
--   'limited'  → niño registrado, no vinculado con padre aún
--   'full'     → niño vinculado con padre O cuenta de padre

-- ── RLS: el padre puede actualizar account_type del hijo vinculado ─────────────
CREATE POLICY "parent_update_child_account_type"
  ON profiles
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM parent_child
      WHERE parent_id = auth.uid()
        AND child_id  = profiles.id
        AND status    = 'accepted'
    )
  )
  WITH CHECK (true);

-- ── Función: upgrade_child_account()
-- Llamada automáticamente cuando se acepta un código de invitación.
-- Actualiza account_type del niño a 'full'.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION upgrade_child_account_on_link()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'accepted' THEN
    UPDATE profiles
    SET account_type = 'full'
    WHERE id = NEW.child_id;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_upgrade_child_on_link
  AFTER INSERT OR UPDATE OF status ON parent_child
  FOR EACH ROW
  EXECUTE FUNCTION upgrade_child_account_on_link();
