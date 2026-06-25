-- ─────────────────────────────────────────────────────────────────────────────
-- 012_tutorials_seen.sql
-- Agrega la columna tutorials_seen a profiles para registrar qué tutoriales
-- ya vio cada usuario, persistiendo el estado en la nube.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS tutorials_seen jsonb NOT NULL DEFAULT '{}'::jsonb;

-- Índice GIN para búsquedas rápidas por clave (opcional, útil si crece mucho)
CREATE INDEX IF NOT EXISTS idx_profiles_tutorials_seen
  ON profiles USING gin (tutorials_seen);

-- Comentario de columna
COMMENT ON COLUMN profiles.tutorials_seen IS
  'JSONB con claves de tutoriales vistos. Ej: {"forest_map": true, "space_map": true}';
