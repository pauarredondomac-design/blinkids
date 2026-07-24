-- Migración 029: columna status en parent_child
-- Necesaria para que la app pueda filtrar relaciones pendientes/aceptadas/rechazadas.
ALTER TABLE public.parent_child
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'accepted'
    CHECK (status IN ('pending','accepted','rejected'));

-- Índice para queries de hijos de un padre filtrados por estado
CREATE INDEX IF NOT EXISTS idx_parent_child_child_id ON public.parent_child (child_id);
