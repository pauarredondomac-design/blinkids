-- ============================================================
-- Migración 026: Ampliar constraint de slot en character_equipped
-- para incluir los slots usados por Binkids: top, bottom, accesorios
-- + corregir slot de Casco Veloz a 'helmet' (reemplaza cabeza)
-- ============================================================

alter table public.character_equipped
  drop constraint if exists character_equipped_slot_check;

alter table public.character_equipped
  add constraint character_equipped_slot_check
  check (slot in ('helmet','suit','backpack','boots','flag','top','bottom','accesorios'));

-- El casco reemplaza la cabeza → debe ir en slot 'helmet', no 'accesorios'
update public.cosmetic_definitions
  set slot = 'helmet'
  where name = 'Casco Veloz';
