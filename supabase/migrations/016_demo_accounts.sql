-- ─────────────────────────────────────────────────────────────────────────────
-- 016_demo_accounts.sql
-- Agrega soporte para cuentas demo (usuarios anónimos que prueban el juego
-- antes de que un padre los ligue y compre el acceso completo).
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Tipo de cuenta: 'demo' = anónimo jugando la muestra
--                   'full' = padre ligó y compró
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS account_type TEXT NOT NULL DEFAULT 'full'
    CHECK (account_type IN ('demo', 'full'));

-- 2. PIN hash (6 dígitos, se llena cuando el niño configura su clave de acceso)
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS pin_hash TEXT;

-- 3. Índice para búsquedas rápidas por tipo de cuenta
CREATE INDEX IF NOT EXISTS idx_profiles_account_type
  ON profiles (account_type);

-- 4. RLS: el propio usuario puede actualizar su pin_hash y account_type
--    (cuando el padre lo ligue, un RPC con SECURITY DEFINER actualizará el tipo)
CREATE POLICY "Usuario actualiza su propio pin"
  ON profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- 5. Función para verificar si un display_name está disponible
--    (ya existe en 011, pero la re-declaramos aquí para asegurarnos que incluye
--     usuarios demo, ya que los nombres deben ser únicos entre todos)
--    No se hace nada extra: el índice único de 011 ya cubre este caso.

COMMENT ON COLUMN profiles.account_type IS
  'demo = usuario anónimo en prueba | full = cuenta activa ligada a un padre';
COMMENT ON COLUMN profiles.pin_hash IS
  'PIN de 6 dígitos (hash) que el niño usa para entrar al juego después de ligar su cuenta';
