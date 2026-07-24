-- Agrega columna equipped_asset_path a cosmetic_definitions.
-- Esta columna apunta al PNG de capa que se superpone sobre Blink en el vestidor,
-- diferente del asset_path que se muestra en la tienda.
alter table public.cosmetic_definitions
  add column if not exists equipped_asset_path text;

-- Actualizar los 3 cosméticos existentes con sus rutas de capa (carpeta vestidor/)
update public.cosmetic_definitions
  set equipped_asset_path = 'assets/vestidor/casco_veloz.png'
  where id = 'casco_veloces';

update public.cosmetic_definitions
  set equipped_asset_path = 'assets/vestidor/botas_veloz.png'
  where id = 'botas_veloces';

update public.cosmetic_definitions
  set equipped_asset_path = 'assets/vestidor/guantes_veloz.png'
  where id = 'guantes_veloces';
