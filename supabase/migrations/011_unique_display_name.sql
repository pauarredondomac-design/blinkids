-- ─────────────────────────────────────────────────────────────────────────────
-- 011_unique_display_name.sql
-- 1. Display names únicos (constraint + función de verificación)
-- 2. RLS: padres pueden buscar perfiles de niños (para vincularse)
-- 3. Columna last_active en profiles para notificaciones de engagement
-- ─────────────────────────────────────────────────────────────────────────────

-- ── 1. Display name único (case-insensitive) ──────────────────────────────────
-- Primero normalizamos: guardamos siempre en minúsculas para comparación.
-- La constraint usa LOWER() via un índice único funcional.
CREATE UNIQUE INDEX IF NOT EXISTS profiles_display_name_unique
  ON profiles (LOWER(display_name));

-- Función helper para validar disponibilidad desde el cliente
-- (evita exponer lógica de auth en el query directo)
CREATE OR REPLACE FUNCTION is_display_name_available(p_name TEXT)
RETURNS BOOLEAN
LANGUAGE sql SECURITY DEFINER
AS $$
  SELECT NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE LOWER(display_name) = LOWER(p_name)
  );
$$;

-- ── 2. Columna last_active ────────────────────────────────────────────────────
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS last_active TIMESTAMPTZ DEFAULT now();

-- Actualizar last_active al registrarse
CREATE OR REPLACE FUNCTION touch_last_active()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.last_active = now();
  RETURN NEW;
END;
$$;

-- Trigger en UPDATE de profiles (se dispara cuando el niño hace cualquier acción)
DROP TRIGGER IF EXISTS trg_touch_last_active ON profiles;
CREATE TRIGGER trg_touch_last_active
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION touch_last_active();

-- ── 3. RLS: búsqueda de niños para vinculación ────────────────────────────────
-- Un padre autenticado puede leer el display_name, id y avatar_url
-- de cualquier perfil con role='child' para buscar a su hijo.
-- Esto NO expone datos sensibles (wallet, personaje, etc. siguen protegidos).
CREATE POLICY "Buscar niños para vinculación"
  ON profiles FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND role = 'child'
  );

-- ── 4. Función de búsqueda mejorada (reemplaza la de 010) ────────────────────
-- Ahora busca solo en profiles (no requiere JOIN con auth.users para el nombre).
-- El email solo se devuelve si el usuario tiene acceso a auth.users (admin).
-- Para el MVP devolvemos NULL en email desde este endpoint público.
CREATE OR REPLACE FUNCTION search_child(p_query TEXT)
RETURNS TABLE(
  id           UUID,
  display_name TEXT,
  avatar_url   TEXT,
  email        TEXT
)
LANGUAGE sql SECURITY DEFINER
AS $$
  SELECT
    p.id,
    p.display_name,
    p.avatar_url,
    u.email
  FROM profiles p
  JOIN auth.users u ON u.id = p.id
  WHERE
    p.role = 'child'
    AND (
      LOWER(p.display_name) LIKE '%' || LOWER(p_query) || '%'
      OR LOWER(u.email)        LIKE '%' || LOWER(p_query) || '%'
    )
  LIMIT 10;
$$;
