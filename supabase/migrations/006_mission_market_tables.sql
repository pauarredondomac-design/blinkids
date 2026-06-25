-- ============================================================
-- FinQuest — Migración 006: Misiones globales y mercado de jugadores
-- ============================================================

-- 16. Misiones globales (eventos colaborativos del mundo)
create table missions (
  id                           uuid default uuid_generate_v4() primary key,
  world_id                     uuid references worlds(id),
  name                         text not null,
  description                  text,
  story_text                   text,            -- narrativa inmersiva (ej. "llegó una nave destruida...")
  required_items               jsonb,           -- [{item_id, quantity}] necesarios para completar
  total_participants_needed    integer default 1 check (total_participants_needed > 0),
  current_participants         integer default 0 check (current_participants >= 0),
  coin_reward                  integer not null check (coin_reward > 0),
  xp_reward                    integer default 50 check (xp_reward >= 0),
  status                       mission_status default 'active',
  starts_at                    timestamptz default now(),
  ends_at                      timestamptz,
  repeat_interval_hours        integer,         -- null = no se repite automáticamente
  created_at                   timestamptz default now()
);

create index idx_missions_status   on missions(status);
create index idx_missions_world    on missions(world_id);

-- 17. Participación de jugadores en misiones
create table mission_participants (
  id           uuid default uuid_generate_v4() primary key,
  mission_id   uuid references missions(id) on delete cascade not null,
  user_id      uuid references profiles(id) on delete cascade not null,
  contribution jsonb,                           -- qué aportó el jugador a la misión
  joined_at    timestamptz default now(),
  unique(mission_id, user_id)
);

create index idx_mission_participants_mission on mission_participants(mission_id);
create index idx_mission_participants_user    on mission_participants(user_id);

-- 18. Mercado de jugadores (venta de ítems entre sí)
create table market_listings (
  id           uuid default uuid_generate_v4() primary key,
  seller_id    uuid references profiles(id) on delete cascade not null,
  item_id      uuid references item_catalog(id) not null,
  quantity     integer default 1 check (quantity > 0),
  price_coins  integer not null check (price_coins > 0),
  status       listing_status default 'active',
  buyer_id     uuid references profiles(id),
  listed_at    timestamptz default now(),
  sold_at      timestamptz
);

create index idx_market_listings_status   on market_listings(status);
create index idx_market_listings_seller   on market_listings(seller_id);
create index idx_market_listings_item     on market_listings(item_id);
