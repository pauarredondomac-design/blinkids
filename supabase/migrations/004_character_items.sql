-- ============================================================
-- FinQuest — Migración 004: Personajes, catálogo de ítems e inventario
-- ============================================================

-- 9. Catálogo de ítems (avatares, herramientas, decoraciones)
-- Se crea ANTES de characters porque characters referencia item_catalog.
create table item_catalog (
  id               uuid default uuid_generate_v4() primary key,
  name             text not null,
  description      text,
  type             item_type not null,
  price_coins      integer default 0 check (price_coins >= 0),
  price_real_cents integer default 0 check (price_real_cents >= 0),
  image_url        text,
  is_active        boolean default true,
  metadata         jsonb,                  -- datos extra según el tipo de ítem
  created_at       timestamptz default now()
);

-- 10. Personaje del jugador (Juan el zorro)
create table characters (
  id                 uuid default uuid_generate_v4() primary key,
  user_id            uuid references profiles(id) on delete cascade unique not null,
  xp                 integer default 0 check (xp >= 0),
  level              integer default 1 check (level >= 1),
  evolution_stage    integer default 1 check (evolution_stage between 1 and 4),
                     -- 1=Bebé (0-499 XP), 2=Joven (500-1999), 3=Adulto (2000-4999), 4=Legendario (5000+)
  equipped_avatar_id uuid references item_catalog(id),
  created_at         timestamptz default now(),
  updated_at         timestamptz default now()
);

create trigger characters_updated_at
  before update on characters
  for each row execute function update_updated_at();

-- 11. Inventario del jugador
create table inventory (
  id           uuid default uuid_generate_v4() primary key,
  user_id      uuid references profiles(id) on delete cascade not null,
  item_id      uuid references item_catalog(id) not null,
  quantity     integer default 1 check (quantity > 0),
  acquired_at  timestamptz default now(),
  unique(user_id, item_id)
);

-- Índices
create index idx_inventory_user on inventory(user_id);
create index idx_characters_user on characters(user_id);
