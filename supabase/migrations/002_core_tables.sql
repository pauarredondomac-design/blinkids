-- ============================================================
-- FinQuest — Migración 002: Tablas core (perfiles, carteras, transacciones)
-- ============================================================

-- 1. Perfiles de usuario (extiende auth.users de Supabase)
create table profiles (
  id            uuid references auth.users(id) on delete cascade primary key,
  role          user_role not null,
  display_name  text not null,
  avatar_url    text,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

-- Trigger para actualizar updated_at automáticamente
create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger profiles_updated_at
  before update on profiles
  for each row execute function update_updated_at();

-- 2. Relación padre-hijo
create table parent_child (
  id          uuid default uuid_generate_v4() primary key,
  parent_id   uuid references profiles(id) on delete cascade not null,
  child_id    uuid references profiles(id) on delete cascade not null,
  created_at  timestamptz default now(),
  unique(parent_id, child_id)
);

-- 3. Cartera principal de cada usuario
create table wallets (
  id                  uuid default uuid_generate_v4() primary key,
  user_id             uuid references profiles(id) on delete cascade unique not null,
  total_coins         integer default 0 check (total_coins >= 0),
  real_balance_cents  integer default 0 check (real_balance_cents >= 0),  -- solo para papás, MXN centavos
  created_at          timestamptz default now(),
  updated_at          timestamptz default now()
);

create trigger wallets_updated_at
  before update on wallets
  for each row execute function update_updated_at();

-- 4. Las 5 categorías de la bolsa del niño
create table wallet_categories (
  id          uuid default uuid_generate_v4() primary key,
  wallet_id   uuid references wallets(id) on delete cascade not null,
  category    wallet_category_type not null,
  balance     integer default 0 check (balance >= 0),
  updated_at  timestamptz default now(),
  unique(wallet_id, category)
);

create trigger wallet_categories_updated_at
  before update on wallet_categories
  for each row execute function update_updated_at();

-- 5. Historial de transacciones de monedas
create table transactions (
  id            uuid default uuid_generate_v4() primary key,
  from_user_id  uuid references profiles(id),
  to_user_id    uuid references profiles(id),
  amount        integer not null check (amount > 0),
  type          transaction_type not null,
  description   text,
  metadata      jsonb,
  created_at    timestamptz default now()
);

-- Índices para consultas frecuentes
create index idx_transactions_from_user on transactions(from_user_id);
create index idx_transactions_to_user   on transactions(to_user_id);
create index idx_transactions_type       on transactions(type);
create index idx_transactions_created   on transactions(created_at desc);
