-- ============================================================
-- Migración 021: Imágenes de ítems y cosméticos desde base de datos
-- + columna in_shop en cosmetic_definitions
-- ============================================================

-- ── 1. Tabla item_definitions (catálogo de ítems con soporte de imagen) ───────
create table if not exists public.item_definitions (
  item_id      text primary key,
  emoji        text    not null,
  name         text    not null,
  description  text    not null default '',
  world        text    not null default 'any',   -- 'forest' | 'space' | 'any'
  shop_price   integer not null default 0,        -- 0 = no se vende en tienda
  is_rare      boolean not null default false,
  image_name   text,                              -- nombre de archivo en assets/items/
  active       boolean not null default true,
  created_at   timestamptz default now()
);

alter table public.item_definitions enable row level security;

drop policy if exists "Lectura pública de definiciones de ítems" on public.item_definitions;
create policy "Lectura pública de definiciones de ítems"
  on public.item_definitions for select using (true);

-- Insertar/actualizar los 12 ítems del catálogo
insert into public.item_definitions
  (item_id, emoji, name, description, world, shop_price, is_rare, image_name)
values
  ('wood_plank',    '🪵', 'Tablón de Madera',       'Madera resistente del bosque. Sirve para reparar cabañas.',                  'forest', 50,  false, null),
  ('hammer',        '🔨', 'Martillo',                'Herramienta básica para todo tipo de construcción.',                         'forest', 80,  false, null),
  ('magic_herb',    '🌿', 'Hierba Mágica',           'Planta curativa que crece en lo profundo del bosque.',                      'forest', 100, false, null),
  ('health_potion', '🧪', 'Poción de Salud',         'Bebida mágica que sana a los animales enfermos del bosque.',                'forest', 150, false, null),
  ('acorn',         '🌰', 'Bellota',                 'La ardilla del bosque las colecciona para el invierno.',                    'forest', 30,  false, null),
  ('space_bolt',    '🔩', 'Perno Espacial',          'Pieza metálica reforzada para reparar naves espaciales.',                   'space',  60,  false, null),
  ('wrench',        '🔧', 'Llave Inglesa',           'Herramienta indispensable en cualquier taller galáctico.',                  'space',  90,  false, 'llave_inglesa.png'),
  ('battery',       '⚡', 'Batería Cuántica',        'Fuente de energía para dispositivos espaciales.',                           'space',  110, false, null),
  ('fuel_capsule',  '💊', 'Cápsula de Combustible',  'Combustible concentrado para naves espaciales y robots.',                   'space',  0,   false, null),
  ('lunar_circuit', '🖥️', 'Circuito Lunar',          'Componente electrónico fabricado en la Luna.',                             'space',  120, false, null)
on conflict (item_id) do update set
  emoji       = excluded.emoji,
  name        = excluded.name,
  description = excluded.description,
  world       = excluded.world,
  shop_price  = excluded.shop_price,
  is_rare     = excluded.is_rare,
  image_name  = excluded.image_name;

-- ── 2. Columnas nuevas en cosmetic_definitions ────────────────────────────────
alter table public.cosmetic_definitions
  add column if not exists in_shop    boolean not null default true,
  add column if not exists asset_path text;

-- Ampliar el check constraint de slot para incluir 'accesorios'
alter table public.cosmetic_definitions
  drop constraint if exists cosmetic_definitions_slot_check;

alter table public.cosmetic_definitions
  add constraint cosmetic_definitions_slot_check
  check (slot in ('top','bottom','helmet','suit','backpack','boots','flag','accesorios'));

-- ── 3. Insertar los 3 cosméticos (solo si no existen ya por nombre) ──────────
insert into public.cosmetic_definitions (id, slot, name, description, emoji, price, unlock_type, asset_path, in_shop)
select gen_random_uuid(), 'boots', 'Botas Veloces', 'Botas aerodinámicas que te hacen correr más rápido.', '👟', 200, 'buy', 'assets/cosmeticos/botas_veloces.png', true
where not exists (select 1 from public.cosmetic_definitions where name = 'Botas Veloces');

insert into public.cosmetic_definitions (id, slot, name, description, emoji, price, unlock_type, asset_path, in_shop)
select gen_random_uuid(), 'accesorios', 'Casco Veloz', 'Casco especial que protege y da velocidad extra.', '🪖', 200, 'buy', 'assets/cosmeticos/casco_veloces.png', true
where not exists (select 1 from public.cosmetic_definitions where name = 'Casco Veloz');

insert into public.cosmetic_definitions (id, slot, name, description, emoji, price, unlock_type, asset_path, in_shop)
select gen_random_uuid(), 'accesorios', 'Guantes Veloces', 'Guantes de alta tecnología para mayor destreza.', '🧤', 200, 'buy', 'assets/cosmeticos/guantes_veloces.png', true
where not exists (select 1 from public.cosmetic_definitions where name = 'Guantes Veloces');
