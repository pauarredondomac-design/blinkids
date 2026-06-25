-- ─────────────────────────────────────────────────────────────────────────────
-- 010_parent_notifications.sql
-- Solicitudes de vinculación padre-hijo + notificaciones in-app
-- ─────────────────────────────────────────────────────────────────────────────

-- ── Solicitudes de vinculación ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS link_requests (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id   UUID        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  child_id    UUID        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  status      TEXT        NOT NULL DEFAULT 'pending'
                          CHECK (status IN ('pending','accepted','rejected')),
  created_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE(parent_id, child_id)
);

CREATE INDEX IF NOT EXISTS idx_link_requests_parent ON link_requests(parent_id);
CREATE INDEX IF NOT EXISTS idx_link_requests_child  ON link_requests(child_id);

-- ── Notificaciones in-app ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type        TEXT        NOT NULL,   -- link_request | link_accepted | coins_received
  title       TEXT        NOT NULL,
  body        TEXT        NOT NULL,
  data        JSONB       DEFAULT '{}'::jsonb,
  is_read     BOOLEAN     DEFAULT false,
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user   ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, is_read)
  WHERE NOT is_read;

-- ── RLS ─────────────────────────────────────────────────────────────────────
ALTER TABLE link_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications  ENABLE ROW LEVEL SECURITY;

-- link_requests: padre lee y crea; hijo lee y actualiza estado
CREATE POLICY "parent_reads_own_requests"
  ON link_requests FOR SELECT USING (auth.uid() = parent_id);

CREATE POLICY "child_reads_own_requests"
  ON link_requests FOR SELECT USING (auth.uid() = child_id);

CREATE POLICY "parent_inserts_requests"
  ON link_requests FOR INSERT WITH CHECK (auth.uid() = parent_id);

CREATE POLICY "child_updates_status"
  ON link_requests FOR UPDATE USING (auth.uid() = child_id);

-- notifications: cada usuario lee/actualiza las suyas; cualquier user puede crear
CREATE POLICY "user_reads_own_notifications"
  ON notifications FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "user_updates_own_notifications"
  ON notifications FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "anyone_inserts_notifications"
  ON notifications FOR INSERT WITH CHECK (true);

-- ── Función de búsqueda (apodo o correo) ─────────────────────────────────────
-- Requiere acceso a auth.users → usar SECURITY DEFINER
CREATE OR REPLACE FUNCTION search_child(p_query TEXT)
RETURNS TABLE(
  id           UUID,
  display_name TEXT,
  avatar_url   TEXT,
  email        TEXT
)
LANGUAGE sql
SECURITY DEFINER
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
      p.display_name ILIKE '%' || p_query || '%'
      OR u.email     ILIKE '%' || p_query || '%'
    )
  LIMIT 10;
$$;
