-- ============================================================
-- Migración 027: Actualizar rutas de assets de cosméticos
-- Reorganización de carpeta assets/
-- cosmeticos/ → cosmetics/shop/
-- vestidor/   → cosmetics/equipped/  (capas equipables)
-- ============================================================

-- Imágenes de tienda (asset_path)
update public.cosmetic_definitions
  set asset_path = replace(asset_path, 'assets/cosmeticos/', 'assets/cosmetics/shop/')
  where asset_path like 'assets/cosmeticos/%';

-- Capas equipables (equipped_asset_path)
update public.cosmetic_definitions
  set equipped_asset_path = replace(equipped_asset_path, 'assets/vestidor/', 'assets/cosmetics/equipped/')
  where equipped_asset_path like 'assets/vestidor/%';
