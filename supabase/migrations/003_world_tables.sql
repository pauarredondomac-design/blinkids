-- ============================================================
-- FinQuest — Migración 003: Mundos y progreso del jugador
-- ============================================================

-- 6. Mundos del juego
create table worlds (
  id           uuid default uuid_generate_v4() primary key,
  slug         text unique not null,        -- 'forest', 'space', 'city'
  name         text not null,
  description  text,
  unlock_cost  integer default 0,           -- monedas para desbloquear (0 = gratis)
  order_index  integer not null,
  is_active    boolean default true,
  created_at   timestamptz default now()
);

-- 7. Casitas / módulos dentro de cada mundo
create table world_houses (
  id          uuid default uuid_generate_v4() primary key,
  world_id    uuid references worlds(id) on delete cascade not null,
  type        house_type not null,
  name        text not null,
  position_x  float not null,              -- fracción relativa (0.0 – 1.0)
  position_y  float not null,
  is_active   boolean default true
);

-- 8. Progreso del jugador por mundo (qué mundos tiene desbloqueados)
create table world_progress (
  id           uuid default uuid_generate_v4() primary key,
  user_id      uuid references profiles(id) on delete cascade not null,
  world_id     uuid references worlds(id) on delete cascade not null,
  is_unlocked  boolean default false,
  unlocked_at  timestamptz,
  unique(user_id, world_id)
);

-- Índices
create index idx_world_progress_user on world_progress(user_id);
