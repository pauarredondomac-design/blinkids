-- Backup de esquema (tablas + columnas + PK/FK) -- generado 2026-07-30
-- Reconstruido desde introspección de Supabase (no es un pg_dump exacto,
-- pero cubre tipos, defaults, nullability, PKs y FKs de cada tabla).

-- ── public.profiles (6 filas, RLS=on) ──
CREATE TABLE public.profiles (
  id uuid NOT NULL,
  role user_role NOT NULL,
  display_name text NOT NULL,
  avatar_url text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  last_active timestamptz DEFAULT now(),
  tutorials_seen jsonb NOT NULL DEFAULT '{}'::jsonb,
  world_name text,
  account_type text NOT NULL DEFAULT 'full'::text CHECK (account_type = ANY (ARRAY['demo'::text, 'limited'::text, 'full'::text])),
  pin_hash text
);
ALTER TABLE public.profiles ADD PRIMARY KEY (id);
-- FK: parent_missions_child_id_fkey  public.parent_missions.child_id -> public.profiles.id
-- FK: profiles_id_fkey  public.profiles.id -> auth.users.id
-- FK: parent_child_parent_id_fkey  public.parent_child.parent_id -> public.profiles.id
-- FK: parent_child_child_id_fkey  public.parent_child.child_id -> public.profiles.id
-- FK: wallets_user_id_fkey  public.wallets.user_id -> public.profiles.id
-- FK: transactions_from_user_id_fkey  public.transactions.from_user_id -> public.profiles.id
-- FK: transactions_to_user_id_fkey  public.transactions.to_user_id -> public.profiles.id
-- FK: world_progress_user_id_fkey  public.world_progress.user_id -> public.profiles.id
-- FK: characters_user_id_fkey  public.characters.user_id -> public.profiles.id
-- FK: inventory_user_id_fkey  public.inventory.user_id -> public.profiles.id
-- FK: player_answers_user_id_fkey  public.player_answers.user_id -> public.profiles.id
-- FK: job_completions_user_id_fkey  public.job_completions.user_id -> public.profiles.id
-- FK: mission_participants_user_id_fkey  public.mission_participants.user_id -> public.profiles.id
-- FK: market_listings_seller_id_fkey  public.market_listings.seller_id -> public.profiles.id
-- FK: market_listings_buyer_id_fkey  public.market_listings.buyer_id -> public.profiles.id
-- FK: tutorial_progress_user_id_fkey  public.tutorial_progress.user_id -> public.profiles.id
-- FK: real_purchases_user_id_fkey  public.real_purchases.user_id -> public.profiles.id
-- FK: link_requests_parent_id_fkey  public.link_requests.parent_id -> public.profiles.id
-- FK: link_requests_child_id_fkey  public.link_requests.child_id -> public.profiles.id
-- FK: notifications_user_id_fkey  public.notifications.user_id -> public.profiles.id
-- FK: invite_codes_parent_id_fkey  public.invite_codes.parent_id -> public.profiles.id
-- FK: invite_codes_child_id_fkey  public.invite_codes.child_id -> public.profiles.id
-- FK: mission_progress_user_id_fkey  public.mission_progress.user_id -> public.profiles.id
-- FK: mission_claims_user_id_fkey  public.mission_claims.user_id -> public.profiles.id
-- FK: player_items_user_id_fkey  public.player_items.user_id -> public.profiles.id
-- FK: player_market_listings_seller_id_fkey  public.player_market_listings.seller_id -> public.profiles.id
-- FK: parent_missions_parent_id_fkey  public.parent_missions.parent_id -> public.profiles.id

-- ── public.parent_child (2 filas, RLS=on) ──
CREATE TABLE public.parent_child (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  parent_id uuid NOT NULL,
  child_id uuid NOT NULL,
  created_at timestamptz DEFAULT now(),
  status text NOT NULL DEFAULT 'accepted'::text CHECK (status = ANY (ARRAY['pending'::text, 'accepted'::text, 'rejected'::text]))
);
ALTER TABLE public.parent_child ADD PRIMARY KEY (id);
-- FK: parent_child_child_id_fkey  public.parent_child.child_id -> public.profiles.id
-- FK: parent_child_parent_id_fkey  public.parent_child.parent_id -> public.profiles.id

-- ── public.wallets (4 filas, RLS=on) ──
CREATE TABLE public.wallets (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  user_id uuid NOT NULL,
  total_coins int4 DEFAULT 0 CHECK (total_coins >= 0),
  real_balance_cents int4 DEFAULT 0 CHECK (real_balance_cents >= 0),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  weekly_allowance int4 NOT NULL DEFAULT 0 CHECK (weekly_allowance >= 0),
  allowance_last_granted_at timestamptz
);
ALTER TABLE public.wallets ADD PRIMARY KEY (id);
-- FK: wallet_categories_wallet_id_fkey  public.wallet_categories.wallet_id -> public.wallets.id
-- FK: wallets_user_id_fkey  public.wallets.user_id -> public.profiles.id

-- ── public.wallet_categories (20 filas, RLS=on) ──
CREATE TABLE public.wallet_categories (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  wallet_id uuid NOT NULL,
  category wallet_category_type NOT NULL,
  balance int4 DEFAULT 0 CHECK (balance >= 0),
  updated_at timestamptz DEFAULT now()
);
ALTER TABLE public.wallet_categories ADD PRIMARY KEY (id);
-- FK: wallet_categories_wallet_id_fkey  public.wallet_categories.wallet_id -> public.wallets.id

-- ── public.transactions (0 filas, RLS=on) ──
CREATE TABLE public.transactions (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  from_user_id uuid,
  to_user_id uuid,
  amount int4 NOT NULL CHECK (amount > 0),
  type transaction_type NOT NULL,
  description text,
  metadata jsonb,
  created_at timestamptz DEFAULT now()
);
ALTER TABLE public.transactions ADD PRIMARY KEY (id);
-- FK: transactions_from_user_id_fkey  public.transactions.from_user_id -> public.profiles.id
-- FK: transactions_to_user_id_fkey  public.transactions.to_user_id -> public.profiles.id

-- ── public.worlds (0 filas, RLS=on) ──
CREATE TABLE public.worlds (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  slug text NOT NULL,
  name text NOT NULL,
  description text,
  unlock_cost int4 DEFAULT 0,
  order_index int4 NOT NULL,
  is_active bool DEFAULT true,
  created_at timestamptz DEFAULT now()
);
ALTER TABLE public.worlds ADD PRIMARY KEY (id);
-- FK: world_progress_world_id_fkey  public.world_progress.world_id -> public.worlds.id
-- FK: questions_world_id_fkey  public.questions.world_id -> public.worlds.id
-- FK: world_houses_world_id_fkey  public.world_houses.world_id -> public.worlds.id
-- FK: missions_world_id_fkey  public.missions.world_id -> public.worlds.id
-- FK: jobs_world_id_fkey  public.jobs.world_id -> public.worlds.id

-- ── public.world_houses (0 filas, RLS=on) ──
CREATE TABLE public.world_houses (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  world_id uuid NOT NULL,
  type house_type NOT NULL,
  name text NOT NULL,
  position_x float8 NOT NULL,
  position_y float8 NOT NULL,
  is_active bool DEFAULT true
);
ALTER TABLE public.world_houses ADD PRIMARY KEY (id);
-- FK: world_houses_world_id_fkey  public.world_houses.world_id -> public.worlds.id

-- ── public.world_progress (1 filas, RLS=on) ──
CREATE TABLE public.world_progress (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  user_id uuid NOT NULL,
  world_id uuid NOT NULL,
  is_unlocked bool DEFAULT false,
  unlocked_at timestamptz
);
ALTER TABLE public.world_progress ADD PRIMARY KEY (id);
-- FK: world_progress_user_id_fkey  public.world_progress.user_id -> public.profiles.id
-- FK: world_progress_world_id_fkey  public.world_progress.world_id -> public.worlds.id

-- ── public.item_catalog (1 filas, RLS=on) ──
CREATE TABLE public.item_catalog (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  name text NOT NULL,
  description text,
  type item_type NOT NULL,
  price_coins int4 DEFAULT 0 CHECK (price_coins >= 0),
  price_real_cents int4 DEFAULT 0 CHECK (price_real_cents >= 0),
  image_url text,
  is_active bool DEFAULT true,
  metadata jsonb,
  created_at timestamptz DEFAULT now()
);
ALTER TABLE public.item_catalog ADD PRIMARY KEY (id);
-- FK: characters_equipped_avatar_id_fkey  public.characters.equipped_avatar_id -> public.item_catalog.id
-- FK: market_listings_item_id_fkey  public.market_listings.item_id -> public.item_catalog.id
-- FK: inventory_item_id_fkey  public.inventory.item_id -> public.item_catalog.id

-- ── public.characters (1 filas, RLS=on) ──
CREATE TABLE public.characters (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  user_id uuid NOT NULL,
  xp int4 DEFAULT 0 CHECK (xp >= 0),
  level int4 DEFAULT 1 CHECK (level >= 1),
  evolution_stage int4 DEFAULT 1 CHECK (evolution_stage >= 1 AND evolution_stage <= 4),
  equipped_avatar_id uuid,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
ALTER TABLE public.characters ADD PRIMARY KEY (id);
-- FK: characters_equipped_avatar_id_fkey  public.characters.equipped_avatar_id -> public.item_catalog.id
-- FK: characters_user_id_fkey  public.characters.user_id -> public.profiles.id

-- ── public.inventory (0 filas, RLS=on) ──
CREATE TABLE public.inventory (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  user_id uuid NOT NULL,
  item_id uuid NOT NULL,
  quantity int4 DEFAULT 1 CHECK (quantity > 0),
  acquired_at timestamptz DEFAULT now()
);
ALTER TABLE public.inventory ADD PRIMARY KEY (id);
-- FK: inventory_user_id_fkey  public.inventory.user_id -> public.profiles.id
-- FK: inventory_item_id_fkey  public.inventory.item_id -> public.item_catalog.id

-- ── public.questions (63 filas, RLS=on) ──
CREATE TABLE public.questions (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  world_id uuid,
  type question_type NOT NULL,
  difficulty difficulty_level NOT NULL,
  question_text text NOT NULL,
  options jsonb NOT NULL,
  correct_answer jsonb NOT NULL,
  coin_reward int4 DEFAULT 10 CHECK (coin_reward >= 0),
  xp_reward int4 DEFAULT 5 CHECK (xp_reward >= 0),
  explanation text,
  is_active bool DEFAULT true,
  created_at timestamptz DEFAULT now(),
  catalog_id text,
  module_slug text,
  group_name text,
  gancho text,
  retro_wrong text,
  fuel_reward int4 NOT NULL DEFAULT 0,
  is_hito bool NOT NULL DEFAULT false,
  badge_name text,
  sort_order int4 NOT NULL DEFAULT 0
);
ALTER TABLE public.questions ADD PRIMARY KEY (id);
-- FK: player_answers_question_id_fkey  public.player_answers.question_id -> public.questions.id
-- FK: questions_world_id_fkey  public.questions.world_id -> public.worlds.id

-- ── public.player_answers (11 filas, RLS=on) ──
CREATE TABLE public.player_answers (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  user_id uuid NOT NULL,
  question_id uuid NOT NULL,
  is_correct bool NOT NULL,
  answered_at timestamptz DEFAULT now()
);
ALTER TABLE public.player_answers ADD PRIMARY KEY (id);
-- FK: player_answers_user_id_fkey  public.player_answers.user_id -> public.profiles.id
-- FK: player_answers_question_id_fkey  public.player_answers.question_id -> public.questions.id

-- ── public.jobs (7 filas, RLS=on) ──
CREATE TABLE public.jobs (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  world_id uuid,
  name text NOT NULL,
  description text,
  instructions jsonb,
  coin_reward int4 NOT NULL CHECK (coin_reward > 0),
  xp_reward int4 DEFAULT 10 CHECK (xp_reward >= 0),
  duration_seconds int4 DEFAULT 60 CHECK (duration_seconds > 0),
  cooldown_minutes int4 DEFAULT 60 CHECK (cooldown_minutes >= 0),
  image_url text,
  is_active bool DEFAULT true,
  created_at timestamptz DEFAULT now(),
  type text NOT NULL DEFAULT 'minigame'::text,
  emoji text,
  npc_name text,
  npc_emoji text,
  story text,
  requirements jsonb,
  item_reward jsonb,
  fuel_reward int4 NOT NULL DEFAULT 0
);
ALTER TABLE public.jobs ADD PRIMARY KEY (id);
-- FK: jobs_world_id_fkey  public.jobs.world_id -> public.worlds.id
-- FK: job_completions_job_id_fkey  public.job_completions.job_id -> public.jobs.id

-- ── public.job_completions (29 filas, RLS=on) ──
CREATE TABLE public.job_completions (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  user_id uuid NOT NULL,
  job_id uuid NOT NULL,
  coins_earned int4 NOT NULL CHECK (coins_earned >= 0),
  completed_at timestamptz DEFAULT now()
);
ALTER TABLE public.job_completions ADD PRIMARY KEY (id);
-- FK: job_completions_user_id_fkey  public.job_completions.user_id -> public.profiles.id
-- FK: job_completions_job_id_fkey  public.job_completions.job_id -> public.jobs.id

-- ── public.missions (0 filas, RLS=on) ──
CREATE TABLE public.missions (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  world_id uuid,
  name text NOT NULL,
  description text,
  story_text text,
  required_items jsonb,
  total_participants_needed int4 DEFAULT 1 CHECK (total_participants_needed > 0),
  current_participants int4 DEFAULT 0 CHECK (current_participants >= 0),
  coin_reward int4 NOT NULL CHECK (coin_reward > 0),
  xp_reward int4 DEFAULT 50 CHECK (xp_reward >= 0),
  status mission_status DEFAULT 'active'::mission_status,
  starts_at timestamptz DEFAULT now(),
  ends_at timestamptz,
  repeat_interval_hours int4,
  created_at timestamptz DEFAULT now()
);
ALTER TABLE public.missions ADD PRIMARY KEY (id);
-- FK: mission_participants_mission_id_fkey  public.mission_participants.mission_id -> public.missions.id
-- FK: missions_world_id_fkey  public.missions.world_id -> public.worlds.id

-- ── public.mission_participants (0 filas, RLS=on) ──
CREATE TABLE public.mission_participants (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  mission_id uuid NOT NULL,
  user_id uuid NOT NULL,
  contribution jsonb,
  joined_at timestamptz DEFAULT now()
);
ALTER TABLE public.mission_participants ADD PRIMARY KEY (id);
-- FK: mission_participants_mission_id_fkey  public.mission_participants.mission_id -> public.missions.id
-- FK: mission_participants_user_id_fkey  public.mission_participants.user_id -> public.profiles.id

-- ── public.market_listings (0 filas, RLS=on) ──
CREATE TABLE public.market_listings (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  seller_id uuid NOT NULL,
  item_id uuid NOT NULL,
  quantity int4 DEFAULT 1 CHECK (quantity > 0),
  price_coins int4 NOT NULL CHECK (price_coins > 0),
  status listing_status DEFAULT 'active'::listing_status,
  buyer_id uuid,
  listed_at timestamptz DEFAULT now(),
  sold_at timestamptz
);
ALTER TABLE public.market_listings ADD PRIMARY KEY (id);
-- FK: market_listings_buyer_id_fkey  public.market_listings.buyer_id -> public.profiles.id
-- FK: market_listings_item_id_fkey  public.market_listings.item_id -> public.item_catalog.id
-- FK: market_listings_seller_id_fkey  public.market_listings.seller_id -> public.profiles.id

-- ── public.tutorial_progress (4 filas, RLS=on) ──
CREATE TABLE public.tutorial_progress (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  user_id uuid NOT NULL,
  current_step int4 DEFAULT 0 CHECK (current_step >= 0),
  is_completed bool DEFAULT false,
  completed_at timestamptz
);
ALTER TABLE public.tutorial_progress ADD PRIMARY KEY (id);
-- FK: tutorial_progress_user_id_fkey  public.tutorial_progress.user_id -> public.profiles.id

-- ── public.real_purchases (0 filas, RLS=on) ──
CREATE TABLE public.real_purchases (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  user_id uuid NOT NULL,
  platform purchase_platform NOT NULL,
  product_id text NOT NULL,
  amount_cents int4 NOT NULL CHECK (amount_cents > 0),
  coins_granted int4 NOT NULL CHECK (coins_granted > 0),
  status purchase_status DEFAULT 'pending'::purchase_status,
  store_transaction_id text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
ALTER TABLE public.real_purchases ADD PRIMARY KEY (id);
-- FK: real_purchases_user_id_fkey  public.real_purchases.user_id -> public.profiles.id

-- ── public.link_requests (0 filas, RLS=on) ──
CREATE TABLE public.link_requests (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  parent_id uuid NOT NULL,
  child_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'accepted'::text, 'rejected'::text])),
  created_at timestamptz DEFAULT now()
);
ALTER TABLE public.link_requests ADD PRIMARY KEY (id);
-- FK: link_requests_parent_id_fkey  public.link_requests.parent_id -> public.profiles.id
-- FK: link_requests_child_id_fkey  public.link_requests.child_id -> public.profiles.id

-- ── public.notifications (10 filas, RLS=on) ──
CREATE TABLE public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  type text NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  data jsonb DEFAULT '{}'::jsonb,
  is_read bool DEFAULT false,
  created_at timestamptz DEFAULT now()
);
ALTER TABLE public.notifications ADD PRIMARY KEY (id);
-- FK: notifications_user_id_fkey  public.notifications.user_id -> public.profiles.id

-- ── public.invite_codes (2 filas, RLS=on) ──
CREATE TABLE public.invite_codes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  code text NOT NULL,
  parent_id uuid NOT NULL,
  child_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + '24:00:00'::interval),
  used_at timestamptz
);
ALTER TABLE public.invite_codes ADD PRIMARY KEY (id);
-- FK: invite_codes_parent_id_fkey  public.invite_codes.parent_id -> public.profiles.id
-- FK: invite_codes_child_id_fkey  public.invite_codes.child_id -> public.profiles.id

-- ── public.mission_progress (2 filas, RLS=on) ──
CREATE TABLE public.mission_progress (
  user_id uuid NOT NULL,
  quizzes int4 NOT NULL DEFAULT 0 CHECK (quizzes >= 0),
  jobs int4 NOT NULL DEFAULT 0 CHECK (jobs >= 0),
  purchases int4 NOT NULL DEFAULT 0 CHECK (purchases >= 0),
  updated_at timestamptz DEFAULT now()
);
ALTER TABLE public.mission_progress ADD PRIMARY KEY (user_id);
-- FK: mission_progress_user_id_fkey  public.mission_progress.user_id -> public.profiles.id

-- ── public.mission_claims (0 filas, RLS=on) ──
CREATE TABLE public.mission_claims (
  user_id uuid NOT NULL,
  mission_id text NOT NULL,
  claimed_at timestamptz DEFAULT now()
);
ALTER TABLE public.mission_claims ADD PRIMARY KEY (user_id, mission_id);
-- FK: mission_claims_user_id_fkey  public.mission_claims.user_id -> public.profiles.id

-- ── public.player_items (6 filas, RLS=on) ──
CREATE TABLE public.player_items (
  user_id uuid NOT NULL,
  item_id text NOT NULL,
  qty int4 NOT NULL DEFAULT 0 CHECK (qty >= 0)
);
ALTER TABLE public.player_items ADD PRIMARY KEY (user_id, item_id);
-- FK: player_items_user_id_fkey  public.player_items.user_id -> public.profiles.id

-- ── public.player_market_listings (0 filas, RLS=on) ──
CREATE TABLE public.player_market_listings (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  seller_id uuid NOT NULL,
  seller_name text NOT NULL,
  item_id text NOT NULL,
  qty int4 NOT NULL CHECK (qty > 0),
  price_per_unit int4 NOT NULL CHECK (price_per_unit > 0),
  created_at timestamptz DEFAULT now()
);
ALTER TABLE public.player_market_listings ADD PRIMARY KEY (id);
-- FK: player_market_listings_seller_id_fkey  public.player_market_listings.seller_id -> public.profiles.id

-- ── public.badge_definitions (0 filas, RLS=on) ──
CREATE TABLE public.badge_definitions (
  id text NOT NULL,
  name text NOT NULL,
  description text NOT NULL,
  emoji text NOT NULL DEFAULT '🏆'::text,
  sort_order int4 NOT NULL DEFAULT 0
);
ALTER TABLE public.badge_definitions ADD PRIMARY KEY (id);
-- FK: player_badges_badge_id_fkey  public.player_badges.badge_id -> public.badge_definitions.id

-- ── public.player_badges (7 filas, RLS=on) ──
CREATE TABLE public.player_badges (
  user_id uuid NOT NULL,
  badge_id text NOT NULL,
  earned_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.player_badges ADD PRIMARY KEY (user_id, badge_id);
-- FK: player_badges_user_id_fkey  public.player_badges.user_id -> auth.users.id
-- FK: player_badges_badge_id_fkey  public.player_badges.badge_id -> public.badge_definitions.id

-- ── public.cosmetic_definitions (0 filas, RLS=on) ──
CREATE TABLE public.cosmetic_definitions (
  id text NOT NULL,
  slot text NOT NULL CHECK (slot = ANY (ARRAY['top'::text, 'bottom'::text, 'helmet'::text, 'suit'::text, 'backpack'::text, 'boots'::text, 'flag'::text, 'accesorios'::text])),
  name text NOT NULL,
  description text NOT NULL DEFAULT ''::text,
  emoji text NOT NULL DEFAULT '🎭'::text,
  price int4 NOT NULL DEFAULT 0 CHECK (price >= 0),
  unlock_type text NOT NULL DEFAULT 'buy'::text CHECK (unlock_type = ANY (ARRAY['buy'::text, 'earn'::text, 'event'::text])),
  in_shop bool NOT NULL DEFAULT true,
  asset_path text,
  equipped_asset_path text
);
ALTER TABLE public.cosmetic_definitions ADD PRIMARY KEY (id);
-- FK: player_cosmetics_cosmetic_id_fkey  public.player_cosmetics.cosmetic_id -> public.cosmetic_definitions.id
-- FK: character_equipped_cosmetic_id_fkey  public.character_equipped.cosmetic_id -> public.cosmetic_definitions.id

-- ── public.player_cosmetics (3 filas, RLS=on) ──
CREATE TABLE public.player_cosmetics (
  user_id uuid NOT NULL,
  cosmetic_id text NOT NULL,
  obtained_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.player_cosmetics ADD PRIMARY KEY (user_id, cosmetic_id);
-- FK: player_cosmetics_cosmetic_id_fkey  public.player_cosmetics.cosmetic_id -> public.cosmetic_definitions.id
-- FK: player_cosmetics_user_id_fkey  public.player_cosmetics.user_id -> auth.users.id

-- ── public.character_equipped (2 filas, RLS=on) ──
CREATE TABLE public.character_equipped (
  user_id uuid NOT NULL,
  slot text NOT NULL CHECK (slot = ANY (ARRAY['helmet'::text, 'suit'::text, 'backpack'::text, 'boots'::text, 'flag'::text, 'top'::text, 'bottom'::text, 'accesorios'::text])),
  cosmetic_id text,
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.character_equipped ADD PRIMARY KEY (user_id, slot);
-- FK: character_equipped_cosmetic_id_fkey  public.character_equipped.cosmetic_id -> public.cosmetic_definitions.id
-- FK: character_equipped_user_id_fkey  public.character_equipped.user_id -> auth.users.id

-- ── public.analytics_events (352 filas, RLS=on) ──
CREATE TABLE public.analytics_events (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  event_name text NOT NULL,
  properties jsonb NOT NULL DEFAULT '{}'::jsonb,
  app_version text,
  platform text,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.analytics_events ADD PRIMARY KEY (id);
-- FK: analytics_events_user_id_fkey  public.analytics_events.user_id -> auth.users.id

-- ── public.crash_reports (6845 filas, RLS=on) ──
CREATE TABLE public.crash_reports (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  error text NOT NULL,
  stack_trace text,
  context text,
  app_version text,
  platform text,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.crash_reports ADD PRIMARY KEY (id);
-- FK: crash_reports_user_id_fkey  public.crash_reports.user_id -> auth.users.id

-- ── public.push_notification_log (0 filas, RLS=on) ──
CREATE TABLE public.push_notification_log (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  notification_type text NOT NULL,
  sent_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.push_notification_log ADD PRIMARY KEY (id);
-- FK: push_notification_log_user_id_fkey  public.push_notification_log.user_id -> auth.users.id

-- ── public.world_fuel (1 filas, RLS=on) ──
CREATE TABLE public.world_fuel (
  user_id uuid NOT NULL,
  world_slug text NOT NULL,
  fuel int4 NOT NULL DEFAULT 0 CHECK (fuel >= 0 AND fuel <= 100),
  cycle int4 NOT NULL DEFAULT 1,
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.world_fuel ADD PRIMARY KEY (user_id, world_slug);
-- FK: world_fuel_user_id_fkey  public.world_fuel.user_id -> auth.users.id

-- ── public.user_streaks (1 filas, RLS=on) ──
CREATE TABLE public.user_streaks (
  user_id uuid NOT NULL,
  streak_type text NOT NULL CHECK (streak_type = ANY (ARRAY['daily'::text, 'weekly'::text])),
  current_streak int4 NOT NULL DEFAULT 0,
  longest_streak int4 NOT NULL DEFAULT 0,
  last_activity_at date NOT NULL DEFAULT CURRENT_DATE,
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.user_streaks ADD PRIMARY KEY (user_id, streak_type);
-- FK: user_streaks_user_id_fkey  public.user_streaks.user_id -> auth.users.id

-- ── public.weekly_salaries (0 filas, RLS=on) ──
CREATE TABLE public.weekly_salaries (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  parent_id uuid NOT NULL,
  child_id uuid NOT NULL,
  amount int4 NOT NULL DEFAULT 25 CHECK (amount >= 20 AND amount <= 35),
  is_active bool NOT NULL DEFAULT true,
  last_paid_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.weekly_salaries ADD PRIMARY KEY (id);
-- FK: weekly_salaries_parent_id_fkey  public.weekly_salaries.parent_id -> auth.users.id
-- FK: weekly_salaries_child_id_fkey  public.weekly_salaries.child_id -> auth.users.id

-- ── public.push_notification_templates (0 filas, RLS=on) ──
CREATE TABLE public.push_notification_templates (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  type text NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  target_role text CHECK (target_role = ANY (ARRAY['child'::text, 'parent'::text])),
  cooldown_hours int4 NOT NULL DEFAULT 24,
  is_active bool NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.push_notification_templates ADD PRIMARY KEY (id);

-- ── public.blink_dialogues (26 filas, RLS=on) ──
CREATE TABLE public.blink_dialogues (
  id int4 NOT NULL DEFAULT nextval('blink_dialogues_id_seq'::regclass),
  screen text NOT NULL,
  order int4 NOT NULL,
  title text NOT NULL DEFAULT ''::text,
  body text NOT NULL DEFAULT ''::text,
  active bool NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now()
);
ALTER TABLE public.blink_dialogues ADD PRIMARY KEY (id);

-- ── public.item_definitions (11 filas, RLS=on) ──
CREATE TABLE public.item_definitions (
  item_id text NOT NULL,
  emoji text NOT NULL,
  name text NOT NULL,
  description text NOT NULL DEFAULT ''::text,
  world text NOT NULL DEFAULT 'any'::text,
  shop_price int4 NOT NULL DEFAULT 0,
  is_rare bool NOT NULL DEFAULT false,
  image_name text,
  active bool NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now()
);
ALTER TABLE public.item_definitions ADD PRIMARY KEY (item_id);

-- ── public.parent_missions (0 filas, RLS=on) ──
CREATE TABLE public.parent_missions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  parent_id uuid NOT NULL,
  child_id uuid NOT NULL,
  title text NOT NULL,
  description text,
  coin_reward int4 NOT NULL CHECK (coin_reward > 0),
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'completed'::text, 'cancelled'::text])),
  created_at timestamptz DEFAULT now(),
  completed_at timestamptz
);
ALTER TABLE public.parent_missions ADD PRIMARY KEY (id);
-- FK: parent_missions_child_id_fkey  public.parent_missions.child_id -> public.profiles.id
-- FK: parent_missions_parent_id_fkey  public.parent_missions.parent_id -> public.profiles.id

-- ── public.child_goals (1 filas, RLS=on) ──
CREATE TABLE public.child_goals (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  user_id uuid NOT NULL,
  goal_key text NOT NULL,
  goal_name text NOT NULL,
  goal_emoji text NOT NULL,
  goal_cost int4 NOT NULL CHECK (goal_cost > 0),
  chosen_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz
);
ALTER TABLE public.child_goals ADD PRIMARY KEY (id);
-- FK: child_goals_user_id_fkey  public.child_goals.user_id -> auth.users.id
