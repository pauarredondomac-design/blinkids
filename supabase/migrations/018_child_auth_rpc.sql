-- ─────────────────────────────────────────────────────────────────────────────
-- 018_child_auth_rpc.sql  (Bloque 2)
-- 1. Ampliar CHECK de account_type para admitir 'limited'
-- 2. RPC create_child_profile: crea perfil + cartera sin depender de RLS
--    (SECURITY DEFINER → corre como owner, bypasea policies)
-- ─────────────────────────────────────────────────────────────────────────────

-- ── 1. Actualizar constraint account_type ─────────────────────────────────────
ALTER TABLE profiles
  DROP CONSTRAINT IF EXISTS profiles_account_type_check;

ALTER TABLE profiles
  ADD CONSTRAINT profiles_account_type_check
  CHECK (account_type IN ('demo', 'limited', 'full'));

-- ── 2. RPC: create_child_profile ──────────────────────────────────────────────
-- Llamada por el niño justo después de signUp.
-- Recibe: display_name, pin_hash
-- Crea: profile (role='child', account_type='limited') + wallet vacía
-- No requiere que el email esté confirmado porque corre como SECURITY DEFINER.
CREATE OR REPLACE FUNCTION create_child_profile(
  p_display_name TEXT,
  p_pin_hash     TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Se requiere sesión activa';
  END IF;

  -- Verificar unicidad del nombre (ignorar mayúsculas)
  IF EXISTS (
    SELECT 1 FROM profiles
    WHERE lower(display_name) = lower(trim(p_display_name))
  ) THEN
    RAISE EXCEPTION 'El nombre ya está en uso';
  END IF;

  -- Crear perfil
  INSERT INTO profiles (id, role, display_name, account_type, pin_hash)
  VALUES (v_uid, 'child', trim(p_display_name), 'limited', p_pin_hash)
  ON CONFLICT (id) DO NOTHING;

  -- Crear cartera vacía
  INSERT INTO wallets (user_id, total_coins)
  VALUES (v_uid, 0)
  ON CONFLICT (user_id) DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION create_child_profile(TEXT, TEXT) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION create_child_profile(TEXT, TEXT) TO authenticated, anon;
