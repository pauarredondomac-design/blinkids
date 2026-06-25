-- ============================================================
-- FinQuest — Migración 007: Tutorial y compras reales (IAP)
-- ============================================================

-- 19. Progreso del tutorial por jugador
create table tutorial_progress (
  id            uuid default uuid_generate_v4() primary key,
  user_id       uuid references profiles(id) on delete cascade unique not null,
  current_step  integer default 0 check (current_step >= 0),
  is_completed  boolean default false,
  completed_at  timestamptz
);

-- 20. Compras reales de papás (Google Play / App Store)
create table real_purchases (
  id                   uuid default uuid_generate_v4() primary key,
  user_id              uuid references profiles(id) on delete cascade not null,
  platform             purchase_platform not null,
  product_id           text not null,             -- ID del producto en tienda (ej. 'finquest_coins_1000')
  amount_cents         integer not null check (amount_cents > 0),  -- MXN centavos
  coins_granted        integer not null check (coins_granted > 0),
  status               purchase_status default 'pending',
  store_transaction_id text unique,               -- ID único de Google/Apple
  created_at           timestamptz default now(),
  updated_at           timestamptz default now()
);

create trigger real_purchases_updated_at
  before update on real_purchases
  for each row execute function update_updated_at();

create index idx_real_purchases_user   on real_purchases(user_id);
create index idx_real_purchases_status on real_purchases(status);
