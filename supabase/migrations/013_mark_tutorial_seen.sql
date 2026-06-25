-- ─────────────────────────────────────────────────────────────────────────────
-- 013_mark_tutorial_seen.sql
-- Función RPC para marcar un tutorial como visto.
-- SECURITY DEFINER: corre como el dueño de la tabla → bypassa RLS sin riesgo
-- porque la función solo actualiza el propio row (WHERE id = auth.uid()).
-- Usa el operador || para merge atómico de JSONB (no sobreescribe otras claves).
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION mark_tutorial_seen(p_key TEXT)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE profiles
  SET tutorials_seen = tutorials_seen || jsonb_build_object(p_key, true)
  WHERE id = auth.uid();
$$;

-- Revocar acceso público y conceder solo a usuarios autenticados
REVOKE ALL ON FUNCTION mark_tutorial_seen(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION mark_tutorial_seen(TEXT) TO authenticated;
