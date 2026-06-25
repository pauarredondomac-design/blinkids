-- ============================================================
-- FinQuest — Migración 008: Row Level Security (RLS) + políticas
-- ============================================================

-- Habilitar RLS en todas las tablas con datos de usuario
alter table profiles              enable row level security;
alter table parent_child          enable row level security;
alter table wallets               enable row level security;
alter table wallet_categories     enable row level security;
alter table transactions          enable row level security;
alter table world_progress        enable row level security;
alter table characters            enable row level security;
alter table inventory             enable row level security;
alter table player_answers        enable row level security;
alter table job_completions       enable row level security;
alter table mission_participants  enable row level security;
alter table market_listings       enable row level security;
alter table tutorial_progress     enable row level security;
alter table real_purchases        enable row level security;

-- Tablas de catálogo (lectura pública, escritura solo admin)
alter table worlds        enable row level security;
alter table world_houses  enable row level security;
alter table questions     enable row level security;
alter table jobs          enable row level security;
alter table missions      enable row level security;
alter table item_catalog  enable row level security;

-- ============================================================
-- POLÍTICAS: profiles
-- ============================================================

-- Cada usuario ve y edita solo su propio perfil
create policy "Perfil propio — leer"
  on profiles for select
  using (auth.uid() = id);

create policy "Perfil propio — actualizar"
  on profiles for update
  using (auth.uid() = id);

-- Papá puede ver el perfil de sus hijos
create policy "Papá ve perfil de hijos"
  on profiles for select
  using (
    exists (
      select 1 from parent_child
      where parent_id = auth.uid() and child_id = profiles.id
    )
  );

-- Insertar solo el perfil propio (durante el registro)
create policy "Crear perfil propio"
  on profiles for insert
  with check (auth.uid() = id);

-- ============================================================
-- POLÍTICAS: wallets
-- ============================================================

create policy "Cartera propia — leer"
  on wallets for select
  using (auth.uid() = user_id);

create policy "Cartera propia — actualizar"
  on wallets for update
  using (auth.uid() = user_id);

create policy "Crear cartera propia"
  on wallets for insert
  with check (auth.uid() = user_id);

-- Papá puede ver cartera de sus hijos
create policy "Papá ve cartera de hijos"
  on wallets for select
  using (
    exists (
      select 1 from parent_child
      where parent_id = auth.uid() and child_id = wallets.user_id
    )
  );

-- ============================================================
-- POLÍTICAS: wallet_categories
-- ============================================================

create policy "Categorías propias — leer"
  on wallet_categories for select
  using (
    exists (
      select 1 from wallets
      where wallets.id = wallet_categories.wallet_id
        and wallets.user_id = auth.uid()
    )
  );

create policy "Categorías propias — insertar"
  on wallet_categories for insert
  with check (
    exists (
      select 1 from wallets
      where wallets.id = wallet_categories.wallet_id
        and wallets.user_id = auth.uid()
    )
  );

create policy "Categorías propias — actualizar"
  on wallet_categories for update
  using (
    exists (
      select 1 from wallets
      where wallets.id = wallet_categories.wallet_id
        and wallets.user_id = auth.uid()
    )
  );

-- ============================================================
-- POLÍTICAS: transactions
-- ============================================================

create policy "Transacciones propias — leer"
  on transactions for select
  using (auth.uid() = from_user_id or auth.uid() = to_user_id);

-- Las inserciones solo se hacen desde Edge Functions (service role)

-- ============================================================
-- POLÍTICAS: characters
-- ============================================================

create policy "Personaje propio — leer"
  on characters for select
  using (auth.uid() = user_id);

create policy "Personaje propio — crear"
  on characters for insert
  with check (auth.uid() = user_id);

-- Papá puede ver el personaje de sus hijos
create policy "Papá ve personaje de hijos"
  on characters for select
  using (
    exists (
      select 1 from parent_child
      where parent_id = auth.uid() and child_id = characters.user_id
    )
  );

-- ============================================================
-- POLÍTICAS: tutorial_progress
-- ============================================================

create policy "Tutorial propio — leer/escribir"
  on tutorial_progress for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ============================================================
-- POLÍTICAS: inventory
-- ============================================================

create policy "Inventario propio — leer"
  on inventory for select
  using (auth.uid() = user_id);

create policy "Inventario propio — insertar"
  on inventory for insert
  with check (auth.uid() = user_id);

-- ============================================================
-- POLÍTICAS: player_answers / job_completions / mission_participants
-- ============================================================

create policy "Respuestas propias — leer/escribir"
  on player_answers for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Trabajos propios — leer/escribir"
  on job_completions for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Misiones propias — leer/escribir"
  on mission_participants for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ============================================================
-- POLÍTICAS: market_listings (lectura pública, escritura propia)
-- ============================================================

create policy "Mercado — leer todos los listados activos"
  on market_listings for select
  using (status = 'active' or seller_id = auth.uid() or buyer_id = auth.uid());

create policy "Mercado — publicar listado"
  on market_listings for insert
  with check (auth.uid() = seller_id);

-- ============================================================
-- POLÍTICAS: real_purchases
-- ============================================================

create policy "Compras propias — leer"
  on real_purchases for select
  using (auth.uid() = user_id);

-- Las inserciones y actualizaciones solo desde Edge Functions (service role)

-- ============================================================
-- POLÍTICAS: tablas de catálogo (solo lectura para usuarios)
-- ============================================================

create policy "Mundos activos — lectura pública"
  on worlds for select
  using (is_active = true);

create policy "Casitas activas — lectura pública"
  on world_houses for select
  using (is_active = true);

create policy "Preguntas activas — lectura pública"
  on questions for select
  using (is_active = true);

create policy "Trabajos activos — lectura pública"
  on jobs for select
  using (is_active = true);

create policy "Misiones activas — lectura pública"
  on missions for select
  using (status = 'active');

create policy "Catálogo activo — lectura pública"
  on item_catalog for select
  using (is_active = true);

create policy "parent_child — leer propias"
  on parent_child for select
  using (auth.uid() = parent_id or auth.uid() = child_id);

create policy "world_progress — lectura propia"
  on world_progress for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
