-- ─────────────────────────────────────────────────────────────────────────────
-- 015_child_sees_parent_profile.sql
-- Permite que un hijo vea el perfil (display_name, role) de su padre/madre.
-- Política simétrica a "Papá ve perfil de hijos" que ya existe en 008.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE POLICY "Hijo ve perfil de su padre"
  ON profiles FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM parent_child
      WHERE parent_child.child_id  = auth.uid()
        AND parent_child.parent_id = profiles.id
    )
  );
