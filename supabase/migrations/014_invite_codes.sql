-- ─────────────────────────────────────────────────────────────────────────────
-- 014_invite_codes.sql
-- Sistema de códigos de invitación padre → hijo.
-- El padre genera un código de 6 letras; el hijo lo escribe en su app.
-- No se necesita búsqueda de perfiles ni aprobación extra.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── Tabla de códigos ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS invite_codes (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  code       TEXT        NOT NULL UNIQUE,
  parent_id  UUID        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  child_id   UUID        REFERENCES profiles(id),          -- se llena al canjear
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT now() + INTERVAL '24 hours',
  used_at    TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_invite_codes_parent ON invite_codes(parent_id);
CREATE INDEX IF NOT EXISTS idx_invite_codes_code   ON invite_codes(code);

ALTER TABLE invite_codes ENABLE ROW LEVEL SECURITY;

-- El padre solo ve sus propios códigos
CREATE POLICY "invite_codes — padre lee los suyos"
  ON invite_codes FOR SELECT
  USING (auth.uid() = parent_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- RPC: generate_invite_code()
-- Llamada por el padre. Invalida el código activo previo y devuelve uno nuevo.
-- Caracteres usados: A-Z sin I/O, dígitos 2-9 → fácil de leer y escribir.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION generate_invite_code()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code  TEXT;
  v_chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_taken BOOLEAN;
BEGIN
  -- Solo padres pueden generar códigos
  IF NOT EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'parent'
  ) THEN
    RAISE EXCEPTION 'Solo los padres pueden generar códigos de invitación';
  END IF;

  -- Invalidar códigos activos anteriores de este padre
  UPDATE invite_codes
  SET expires_at = now()
  WHERE parent_id = auth.uid()
    AND used_at IS NULL
    AND expires_at > now();

  -- Generar código único de 6 caracteres
  LOOP
    v_code := '';
    FOR i IN 1..6 LOOP
      v_code := v_code ||
        substr(v_chars, floor(random() * length(v_chars) + 1)::int, 1);
    END LOOP;

    SELECT EXISTS(
      SELECT 1 FROM invite_codes
      WHERE code = v_code AND expires_at > now()
    ) INTO v_taken;

    EXIT WHEN NOT v_taken;
  END LOOP;

  -- Insertar nuevo código (válido 24 horas)
  INSERT INTO invite_codes (code, parent_id, expires_at)
  VALUES (v_code, auth.uid(), now() + INTERVAL '24 hours');

  RETURN v_code;
END;
$$;

REVOKE ALL ON FUNCTION generate_invite_code() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION generate_invite_code() TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- RPC: redeem_invite_code(p_code TEXT)
-- Llamada por el hijo. Valida el código y crea el vínculo padre-hijo.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION redeem_invite_code(p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invite   RECORD;
  v_child_id UUID := auth.uid();
BEGIN
  -- Solo niños pueden canjear códigos
  IF NOT EXISTS (
    SELECT 1 FROM profiles WHERE id = v_child_id AND role = 'child'
  ) THEN
    RAISE EXCEPTION 'Solo los niños pueden canjear códigos de invitación';
  END IF;

  -- Buscar código válido (bloquear fila para evitar doble uso)
  SELECT * INTO v_invite
  FROM invite_codes
  WHERE code       = upper(trim(p_code))
    AND used_at   IS NULL
    AND expires_at > now()
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Código inválido o expirado. Pídele a tu papá o mamá uno nuevo.';
  END IF;

  -- Verificar que no estén ya vinculados
  IF EXISTS (
    SELECT 1 FROM parent_child
    WHERE parent_id = v_invite.parent_id AND child_id = v_child_id
  ) THEN
    RAISE EXCEPTION 'Ya estás vinculado con este papá o mamá';
  END IF;

  -- Crear vínculo (aceptado directamente, el código es la aprobación)
  INSERT INTO parent_child (parent_id, child_id, status)
  VALUES (v_invite.parent_id, v_child_id, 'accepted')
  ON CONFLICT (parent_id, child_id)
  DO UPDATE SET status = 'accepted';

  -- Marcar código como usado
  UPDATE invite_codes
  SET used_at  = now(),
      child_id = v_child_id
  WHERE id = v_invite.id;

  RETURN jsonb_build_object('success', true, 'parent_id', v_invite.parent_id);
END;
$$;

REVOKE ALL ON FUNCTION redeem_invite_code(TEXT) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION redeem_invite_code(TEXT) TO authenticated;
