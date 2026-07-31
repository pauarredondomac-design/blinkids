-- Backup de funciones/RPCs de Supabase (kids_game) -- generado 2026-07-30

CREATE OR REPLACE FUNCTION public.add_fuel(p_world_slug text, p_amount integer)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_old_fuel INTEGER;
  v_new_fuel INTEGER;
  v_reached  BOOLEAN := FALSE;
BEGIN
  INSERT INTO world_fuel(user_id, world_slug, fuel, updated_at)
  VALUES (auth.uid(), p_world_slug, LEAST(p_amount, 100), now())
  ON CONFLICT (user_id, world_slug) DO UPDATE
    SET fuel       = LEAST(world_fuel.fuel + p_amount, 100),
        updated_at = now()
  RETURNING fuel INTO v_new_fuel;

  IF v_new_fuel = 100 THEN
    v_reached := TRUE;
  END IF;

  RETURN v_reached;
END;
$function$;

CREATE OR REPLACE FUNCTION public.add_player_item(p_item_id text, p_qty integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF p_qty <= 0 THEN
    RAISE EXCEPTION 'La cantidad debe ser positiva';
  END IF;

  INSERT INTO player_items (user_id, item_id, qty)
  VALUES (auth.uid(), p_item_id, p_qty)
  ON CONFLICT (user_id, item_id)
  DO UPDATE SET qty = player_items.qty + p_qty;
END;
$function$;

CREATE OR REPLACE FUNCTION public.analytics_breakdown(p_event text, p_field text, p_days integer DEFAULT 7)
 RETURNS TABLE(value text, cnt bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF p_field = 'platform' THEN
    RETURN QUERY
    SELECT COALESCE(platform, 'unknown'), COUNT(*)
    FROM analytics_events
    WHERE event_name = p_event
      AND created_at >= now() - (p_days || ' days')::INTERVAL
    GROUP BY 1 ORDER BY 2 DESC;
  ELSE
    RETURN QUERY
    SELECT COALESCE(properties ->> p_field, 'unknown'), COUNT(*)
    FROM analytics_events
    WHERE event_name = p_event
      AND created_at >= now() - (p_days || ' days')::INTERVAL
    GROUP BY 1 ORDER BY 2 DESC;
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.analytics_daily(p_days integer DEFAULT 7)
 RETURNS TABLE(day date, sessions bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    created_at::DATE AS day,
    COUNT(*)         AS sessions
  FROM analytics_events
  WHERE event_name = 'app_open'
    AND created_at >= now() - (p_days || ' days')::INTERVAL
  GROUP BY 1
  ORDER BY 1 ASC;
END;
$function$;

CREATE OR REPLACE FUNCTION public.analytics_dau(p_days integer DEFAULT 30)
 RETURNS TABLE(day date, dau bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN QUERY
  SELECT created_at::DATE, COUNT(DISTINCT user_id)
  FROM analytics_events
  WHERE created_at >= now() - (p_days||' days')::INTERVAL
    AND user_id IS NOT NULL
  GROUP BY 1 ORDER BY 1 ASC;
END;$function$;

CREATE OR REPLACE FUNCTION public.analytics_economy(p_days integer DEFAULT 7)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_since TIMESTAMPTZ := now() - (p_days||' days')::INTERVAL;
BEGIN
  RETURN jsonb_build_object(
    'coins_received_total',   (SELECT COALESCE(SUM((properties->>'amount')::int),0) FROM analytics_events WHERE event_name='coins_received'        AND created_at>=v_since),
    'coins_from_jobs',        (SELECT COALESCE(SUM((properties->>'coins_earned')::int),0) FROM analytics_events WHERE event_name='job_completed'   AND created_at>=v_since),
    'items_purchased',        (SELECT COUNT(*) FROM analytics_events WHERE event_name='item_purchased'      AND created_at>=v_since),
    'cosmetics_purchased',    (SELECT COUNT(*) FROM analytics_events WHERE event_name='cosmetic_purchased'  AND created_at>=v_since),
    'cosmetics_equipped',     (SELECT COUNT(*) FROM analytics_events WHERE event_name='cosmetic_equipped'   AND created_at>=v_since),
    'coins_spent_items',      (SELECT COALESCE(SUM((properties->>'price')::int),0) FROM analytics_events WHERE event_name='item_purchased'         AND created_at>=v_since),
    'coins_spent_cosmetics',  (SELECT COALESCE(SUM((properties->>'price')::int),0) FROM analytics_events WHERE event_name='cosmetic_purchased'     AND created_at>=v_since)
  );
END;$function$;

CREATE OR REPLACE FUNCTION public.analytics_education(p_days integer DEFAULT 7)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_since TIMESTAMPTZ := now() - (p_days||' days')::INTERVAL;
BEGIN
  RETURN jsonb_build_object(
    'quizzes_total',    (SELECT COUNT(*) FROM analytics_events WHERE event_name='quiz_completed' AND created_at>=v_since),
    'quizzes_correct',  (SELECT COUNT(*) FROM analytics_events WHERE event_name='quiz_completed' AND created_at>=v_since AND (properties->>'correct')::boolean = true),
    'quizzes_wrong',    (SELECT COUNT(*) FROM analytics_events WHERE event_name='quiz_completed' AND created_at>=v_since AND (properties->>'correct')::boolean = false),
    'xp_total',         (SELECT COALESCE(SUM((properties->>'xp_gained')::int),0) FROM analytics_events WHERE event_name IN ('quiz_completed','mission_completed') AND created_at>=v_since),
    'missions_total',   (SELECT COUNT(*) FROM analytics_events WHERE event_name='mission_completed' AND created_at>=v_since),
    'jobs_total',       (SELECT COUNT(*) FROM analytics_events WHERE event_name='job_completed'     AND created_at>=v_since),
    'worlds_entered',   (SELECT COUNT(*) FROM analytics_events WHERE event_name='world_entered'     AND created_at>=v_since),
    'worlds_unlocked',  (SELECT COUNT(*) FROM analytics_events WHERE event_name='world_unlocked'    AND created_at>=v_since),
    'badges_earned',    (SELECT COUNT(*) FROM analytics_events WHERE event_name='badge_earned'      AND created_at>=v_since)
  );
END;$function$;

CREATE OR REPLACE FUNCTION public.analytics_events_summary(p_days integer DEFAULT 7)
 RETURNS TABLE(event_name text, total bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN QUERY
  SELECT ae.event_name, COUNT(*) AS total
  FROM analytics_events ae
  WHERE ae.created_at >= now() - (p_days || ' days')::INTERVAL
  GROUP BY ae.event_name
  ORDER BY total DESC;
END;
$function$;

CREATE OR REPLACE FUNCTION public.analytics_funnel(p_days integer DEFAULT 7)
 RETURNS TABLE(stage text, unique_users bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_since TIMESTAMPTZ := now() - (p_days || ' days')::INTERVAL;
BEGIN
  RETURN QUERY VALUES
    ('app_open',           (SELECT COUNT(DISTINCT user_id) FROM analytics_events WHERE event_name = 'app_open'           AND created_at >= v_since AND user_id IS NOT NULL)),
    ('register',           (SELECT COUNT(DISTINCT user_id) FROM analytics_events WHERE event_name = 'register'           AND created_at >= v_since AND user_id IS NOT NULL)),
    ('tutorial_completed', (SELECT COUNT(DISTINCT user_id) FROM analytics_events WHERE event_name = 'tutorial_completed' AND created_at >= v_since AND user_id IS NOT NULL)),
    ('mission_completed',  (SELECT COUNT(DISTINCT user_id) FROM analytics_events WHERE event_name = 'mission_completed'  AND created_at >= v_since AND user_id IS NOT NULL)),
    ('quiz_completed',     (SELECT COUNT(DISTINCT user_id) FROM analytics_events WHERE event_name = 'quiz_completed'     AND created_at >= v_since AND user_id IS NOT NULL)),
    ('job_completed',      (SELECT COUNT(DISTINCT user_id) FROM analytics_events WHERE event_name = 'job_completed'      AND created_at >= v_since AND user_id IS NOT NULL));
END;
$function$;

CREATE OR REPLACE FUNCTION public.analytics_kpis(p_days integer DEFAULT 7)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_since TIMESTAMPTZ := now() - (p_days || ' days')::INTERVAL;
  v_result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'unique_users',       (SELECT COUNT(DISTINCT user_id) FROM analytics_events WHERE created_at >= v_since AND user_id IS NOT NULL),
    'app_opens',          (SELECT COUNT(*) FROM analytics_events WHERE event_name = 'app_open'          AND created_at >= v_since),
    'missions',           (SELECT COUNT(*) FROM analytics_events WHERE event_name = 'mission_completed' AND created_at >= v_since),
    'quizzes',            (SELECT COUNT(*) FROM analytics_events WHERE event_name = 'quiz_completed'    AND created_at >= v_since),
    'jobs',               (SELECT COUNT(*) FROM analytics_events WHERE event_name = 'job_completed'     AND created_at >= v_since),
    'items_purchased',    (SELECT COUNT(*) FROM analytics_events WHERE event_name = 'item_purchased'    AND created_at >= v_since),
    'cosmetics_purchased',(SELECT COUNT(*) FROM analytics_events WHERE event_name = 'cosmetic_purchased'AND created_at >= v_since),
    'tutorial_completed', (SELECT COUNT(*) FROM analytics_events WHERE event_name = 'tutorial_completed'AND created_at >= v_since),
    'registrations',      (SELECT COUNT(*) FROM analytics_events WHERE event_name = 'register'          AND created_at >= v_since)
  ) INTO v_result;
  RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.analytics_new_vs_returning(p_days integer DEFAULT 30)
 RETURNS TABLE(day date, new_users bigint, returning_users bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN QUERY
  WITH first_seen AS (
    SELECT user_id, MIN(created_at)::DATE AS first_day
    FROM analytics_events WHERE user_id IS NOT NULL
    GROUP BY user_id
  ),
  daily AS (
    SELECT created_at::DATE AS day, user_id
    FROM analytics_events
    WHERE created_at >= now() - (p_days||' days')::INTERVAL
      AND user_id IS NOT NULL
    GROUP BY 1, 2
  )
  SELECT
    d.day,
    COUNT(*) FILTER (WHERE d.day = fs.first_day) AS new_users,
    COUNT(*) FILTER (WHERE d.day > fs.first_day)  AS returning_users
  FROM daily d
  JOIN first_seen fs ON fs.user_id = d.user_id
  GROUP BY d.day ORDER BY d.day ASC;
END;$function$;

CREATE OR REPLACE FUNCTION public.analytics_top_items(p_days integer DEFAULT 30, p_limit integer DEFAULT 8)
 RETURNS TABLE(item_id text, purchases bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN QUERY
  SELECT properties->>'item_id', COUNT(*)
  FROM analytics_events
  WHERE event_name = 'item_purchased'
    AND created_at >= now() - (p_days||' days')::INTERVAL
  GROUP BY 1 ORDER BY 2 DESC LIMIT p_limit;
END;$function$;

CREATE OR REPLACE FUNCTION public.analytics_users(p_days integer DEFAULT 7)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_since TIMESTAMPTZ := now() - (p_days||' days')::INTERVAL;
BEGIN
  RETURN jsonb_build_object(
    'total_auth_users',    (SELECT COUNT(*) FROM auth.users),
    'total_profiles',      (SELECT COUNT(*) FROM profiles),
    'parents',             (SELECT COUNT(*) FROM profiles WHERE role='parent'),
    'children',            (SELECT COUNT(*) FROM profiles WHERE role='child'),
    'linked_pairs',        (SELECT COUNT(*) FROM parent_child WHERE status='accepted'),
    'new_registrations',   (SELECT COUNT(*) FROM analytics_events WHERE event_name='register' AND created_at>=v_since),
    'tutorial_completions',(SELECT COUNT(*) FROM analytics_events WHERE event_name='tutorial_completed' AND created_at>=v_since),
    'avg_sessions_per_user',(
      SELECT ROUND(
        COUNT(*)::numeric / NULLIF(COUNT(DISTINCT user_id),0), 1
      )
      FROM analytics_events
      WHERE event_name='app_open' AND created_at>=v_since AND user_id IS NOT NULL
    )
  );
END;$function$;

CREATE OR REPLACE FUNCTION public.analytics_versions(p_days integer DEFAULT 30)
 RETURNS TABLE(app_version text, cnt bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN QUERY
  SELECT COALESCE(app_version,'unknown'), COUNT(DISTINCT user_id)
  FROM analytics_events
  WHERE created_at >= now() - (p_days||' days')::INTERVAL
    AND user_id IS NOT NULL
  GROUP BY 1 ORDER BY 2 DESC;
END;$function$;

CREATE OR REPLACE FUNCTION public.analytics_worlds(p_days integer DEFAULT 7)
 RETURNS TABLE(world_id text, entries bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN QUERY
  SELECT COALESCE(properties->>'world_id','desconocido'), COUNT(*)
  FROM analytics_events
  WHERE event_name = 'world_entered'
    AND created_at >= now() - (p_days||' days')::INTERVAL
  GROUP BY 1 ORDER BY 2 DESC;
END;$function$;

CREATE OR REPLACE FUNCTION public.apply_banco_estelar_interest()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_count INTEGER := 0;
BEGIN
  -- Por cada wallet_category banco_estelar con balance > 0:
  --   1. Suma +5 al total_coins del wallet
  --   2. Suma +3 fuel al mundo espacio del niño
  WITH beneficiados AS (
    UPDATE wallets w
    SET total_coins = w.total_coins + 5,
        updated_at  = now()
    FROM wallet_categories wc
    WHERE wc.wallet_id = w.id
      AND wc.category  = 'banco_estelar'
      AND wc.balance   > 0
    RETURNING w.user_id
  )
  SELECT COUNT(*) INTO v_count FROM beneficiados;

  -- Insertar notificación in-app para cada niño beneficiado
  INSERT INTO notifications(user_id, type, title, body)
  SELECT
    user_id,
    'banco_estelar_interest',
    '¡Banco Estelar! 🏦✨',
    '¡Recibiste +5 monedas de interés esta semana. ¡Sigue ahorrando!'
  FROM (
    SELECT DISTINCT w.user_id
    FROM wallets w
    JOIN wallet_categories wc ON wc.wallet_id = w.id
    WHERE wc.category = 'banco_estelar' AND wc.balance > 0
  ) sub;

  RETURN v_count;
END;
$function$;

CREATE OR REPLACE FUNCTION public.award_coins(p_amount integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_new_balance INT;
BEGIN
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'El monto debe ser positivo';
  END IF;

  UPDATE wallets
  SET total_coins = total_coins + p_amount
  WHERE user_id = auth.uid()
  RETURNING total_coins INTO v_new_balance;

  RETURN COALESCE(v_new_balance, -1);
END;
$function$;

CREATE OR REPLACE FUNCTION public.buy_cosmetic(p_cosmetic_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid     UUID := auth.uid();
  v_price   INT;
  v_new_bal INT;
BEGIN
  -- Obtener precio
  SELECT price INTO v_price
  FROM   cosmetic_definitions
  WHERE  id = p_cosmetic_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cosmético no encontrado: %', p_cosmetic_id;
  END IF;

  -- Verificar si ya lo tiene
  IF EXISTS (
    SELECT 1 FROM player_cosmetics
    WHERE user_id = v_uid AND cosmetic_id = p_cosmetic_id
  ) THEN
    RAISE EXCEPTION 'Ya tienes este cosmético';
  END IF;

  -- Cobrar (si tiene precio)
  IF v_price > 0 THEN
    UPDATE wallets
    SET total_coins = total_coins - v_price
    WHERE user_id = v_uid AND total_coins >= v_price
    RETURNING total_coins INTO v_new_bal;

    IF v_new_bal IS NULL THEN
      RAISE EXCEPTION 'Monedas insuficientes';
    END IF;
  ELSE
    SELECT total_coins INTO v_new_bal FROM wallets WHERE user_id = v_uid;
  END IF;

  -- Registrar propiedad
  INSERT INTO player_cosmetics (user_id, cosmetic_id)
  VALUES (v_uid, p_cosmetic_id);

  RETURN jsonb_build_object('success', true, 'balance', COALESCE(v_new_bal, 0));
END;
$function$;

CREATE OR REPLACE FUNCTION public.can_send_push(p_type text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_cooldown INTEGER;
BEGIN
  -- Obtener cooldown del tipo (default 24h si no existe la plantilla)
  SELECT COALESCE(cooldown_hours, 24)
    INTO v_cooldown
    FROM push_notification_templates
   WHERE type = p_type;

  RETURN NOT EXISTS (
    SELECT 1 FROM push_notification_log
    WHERE user_id           = auth.uid()
      AND notification_type = p_type
      AND sent_at           > now() - (v_cooldown || ' hours')::INTERVAL
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.check_and_award_badges()
 RETURNS SETOF text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid       UUID := auth.uid();
  v_level     INT;
  v_coins     INT;
  v_missions  INT;
  v_xp        INT;
  v_badge     TEXT;
  v_new       TEXT[];
BEGIN
  -- ── Leer datos actuales del jugador ──────────────────────────────────────
  SELECT COALESCE(level, 1), COALESCE(xp, 0)
  INTO   v_level, v_xp
  FROM   characters
  WHERE  user_id = v_uid;

  SELECT COALESCE(total_coins, 0)
  INTO   v_coins
  FROM   wallets
  WHERE  user_id = v_uid;

  SELECT COALESCE(quizzes + jobs + purchases, 0)
  INTO   v_missions
  FROM   mission_progress
  WHERE  user_id = v_uid;

  -- ── Evaluar cada medalla ──────────────────────────────────────────────────

  -- Niveles
  IF v_level >= 5  THEN v_new := array_append(v_new, 'level_5');  END IF;
  IF v_level >= 10 THEN v_new := array_append(v_new, 'level_10'); END IF;
  IF v_level >= 20 THEN v_new := array_append(v_new, 'level_20'); END IF;

  -- Misiones completadas
  IF v_missions >= 10 THEN v_new := array_append(v_new, 'missions_10'); END IF;
  IF v_missions >= 30 THEN v_new := array_append(v_new, 'missions_30'); END IF;

  -- Monedas acumuladas
  IF v_coins >= 100 THEN v_new := array_append(v_new, 'savings_100'); END IF;
  IF v_coins >= 500 THEN v_new := array_append(v_new, 'savings_500'); END IF;

  -- Primer mundo extra desbloqueado
  IF EXISTS (
    SELECT 1 FROM world_progress
    WHERE user_id    = v_uid
      AND is_unlocked = true
  ) THEN
    v_new := array_append(v_new, 'first_world');
  END IF;

  -- ── Insertar solo las que aún no tiene ───────────────────────────────────
  FOREACH v_badge IN ARRAY COALESCE(v_new, '{}')
  LOOP
    INSERT INTO player_badges (user_id, badge_id)
    VALUES (v_uid, v_badge)
    ON CONFLICT DO NOTHING;

    -- Devolver solo si fue una inserción nueva
    IF FOUND THEN
      RETURN NEXT v_badge;
    END IF;
  END LOOP;

  RETURN;
END;
$function$;

CREATE OR REPLACE FUNCTION public.claim_weekly_salary()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid       UUID    := auth.uid();
  v_salary    weekly_salaries%ROWTYPE;
  v_week_start TIMESTAMPTZ := date_trunc('week', now());
  v_fuel       INTEGER     := 8;  -- el salario da 8 puntos de combustible
BEGIN
  SELECT * INTO v_salary
  FROM weekly_salaries
  WHERE child_id  = v_uid
    AND is_active = TRUE
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'No tienes salario asignado');
  END IF;

  -- Verificar que no se cobró ya esta semana
  IF v_salary.last_paid_at IS NOT NULL AND v_salary.last_paid_at >= v_week_start THEN
    RETURN jsonb_build_object('already_claimed', TRUE, 'amount', 0);
  END IF;

  -- Pagar
  UPDATE wallets
  SET total_coins = total_coins + v_salary.amount,
      updated_at  = now()
  WHERE user_id = v_uid;

  UPDATE weekly_salaries
  SET last_paid_at = now(),
      updated_at   = now()
  WHERE child_id = v_uid AND parent_id = v_salary.parent_id;

  -- Combustible
  PERFORM add_fuel('space', v_fuel);

  -- Notificación
  INSERT INTO notifications(user_id, type, title, body)
  VALUES (
    v_uid,
    'salary_received',
    '💰 ¡Salario recibido!',
    '¡Recibiste ' || v_salary.amount || ' monedas de tu papá/mamá esta semana!'
  );

  -- Registrar misión semanal completada → racha semanal
  PERFORM record_weekly_mission();

  RETURN jsonb_build_object(
    'amount',      v_salary.amount,
    'fuel_added',  v_fuel,
    'already_claimed', FALSE
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.complete_parent_mission(p_mission_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid     UUID := auth.uid();
  v_mission parent_missions%ROWTYPE;
  v_paid    INTEGER;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Se requiere sesión activa';
  END IF;

  SELECT * INTO v_mission
  FROM parent_missions
  WHERE id = p_mission_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Misión no encontrada';
  END IF;

  IF v_mission.child_id != v_uid THEN
    RAISE EXCEPTION 'Esta misión no te pertenece';
  END IF;

  IF v_mission.status != 'pending' THEN
    RAISE EXCEPTION 'Esta misión ya no está pendiente';
  END IF;

  -- Descontar del padre solo si tiene saldo suficiente (atómico, sin race condition).
  UPDATE wallets
  SET total_coins = total_coins - v_mission.coin_reward,
      updated_at  = now()
  WHERE user_id = v_mission.parent_id
    AND total_coins >= v_mission.coin_reward
  RETURNING total_coins INTO v_paid;

  IF v_paid IS NULL THEN
    RAISE EXCEPTION 'Tu papá no tiene monedas suficientes ahora mismo. Inténtalo más tarde.';
  END IF;

  UPDATE wallets
  SET total_coins = total_coins + v_mission.coin_reward,
      updated_at  = now()
  WHERE user_id = v_uid;

  UPDATE parent_missions
  SET status = 'completed', completed_at = now()
  WHERE id = p_mission_id;

  INSERT INTO notifications (user_id, type, title, body, data)
  VALUES (
    v_mission.parent_id,
    'parent_mission_completed',
    '¡Misión completada! 🎉',
    v_mission.title,
    jsonb_build_object('mission_id', p_mission_id, 'coin_reward', v_mission.coin_reward)
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.create_child_profile(p_display_name text, p_pin_hash text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Se requiere sesión activa'; END IF;
  IF EXISTS (SELECT 1 FROM profiles WHERE lower(display_name) = lower(trim(p_display_name))) THEN
    RAISE EXCEPTION 'El nombre ya está en uso';
  END IF;
  INSERT INTO profiles (id, role, display_name, account_type, pin_hash)
  VALUES (v_uid, 'child', trim(p_display_name), 'limited', p_pin_hash)
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO wallets (user_id, total_coins) VALUES (v_uid, 0)
  ON CONFLICT (user_id) DO NOTHING;
END; $function$;

CREATE OR REPLACE FUNCTION public.create_parent_mission(p_child_id uuid, p_title text, p_description text, p_coin_reward integer)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid        UUID := auth.uid();
  v_mission_id UUID;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Se requiere sesión activa';
  END IF;

  IF p_coin_reward IS NULL OR p_coin_reward <= 0 THEN
    RAISE EXCEPTION 'La recompensa debe ser mayor a 0';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM parent_child
    WHERE parent_id = v_uid AND child_id = p_child_id AND status = 'accepted'
  ) THEN
    RAISE EXCEPTION 'No tienes un hijo vinculado con ese id';
  END IF;

  INSERT INTO parent_missions (parent_id, child_id, title, description, coin_reward)
  VALUES (v_uid, p_child_id, trim(p_title), NULLIF(trim(p_description), ''), p_coin_reward)
  RETURNING id INTO v_mission_id;

  INSERT INTO notifications (user_id, type, title, body, data)
  VALUES (
    p_child_id,
    'parent_mission_created',
    '¡Nueva misión de tu papá! 👨‍👩‍👧',
    trim(p_title),
    jsonb_build_object('mission_id', v_mission_id, 'coin_reward', p_coin_reward)
  );

  RETURN v_mission_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.equip_cosmetic(p_cosmetic_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid  UUID := auth.uid();
  v_slot TEXT;
BEGIN
  -- Obtener slot del cosmético
  SELECT slot INTO v_slot
  FROM   cosmetic_definitions
  WHERE  id = p_cosmetic_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cosmético no encontrado: %', p_cosmetic_id;
  END IF;

  -- Verificar que el jugador lo posee
  IF NOT EXISTS (
    SELECT 1 FROM player_cosmetics
    WHERE user_id = v_uid AND cosmetic_id = p_cosmetic_id
  ) THEN
    RAISE EXCEPTION 'No tienes este cosmético';
  END IF;

  -- Equipar (upsert)
  INSERT INTO character_equipped (user_id, slot, cosmetic_id, updated_at)
  VALUES (v_uid, v_slot, p_cosmetic_id, now())
  ON CONFLICT (user_id, slot)
  DO UPDATE SET cosmetic_id = EXCLUDED.cosmetic_id, updated_at = now();

  RETURN jsonb_build_object('success', true, 'slot', v_slot);
END;
$function$;

CREATE OR REPLACE FUNCTION public.game_economy()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'total_wallets',          (SELECT COUNT(*) FROM wallets),
    'total_coins_circulation',(SELECT COALESCE(SUM(balance), 0) FROM wallets),
    'avg_balance',            (SELECT COALESCE(ROUND(AVG(balance), 0), 0) FROM wallets),
    'max_balance',            (SELECT COALESCE(MAX(balance), 0) FROM wallets),
    'total_transactions',     (SELECT COUNT(*) FROM transactions),
    'total_items_owned',      (SELECT COUNT(*) FROM player_items),
    'total_cosmetics_owned',  (SELECT COUNT(*) FROM player_cosmetics),
    'total_inventory_slots',  (SELECT COUNT(*) FROM inventory),
    'weekly_salaries_paid',   (SELECT COUNT(*) FROM weekly_salaries),
    'real_purchases',         (SELECT COUNT(*) FROM real_purchases)
  );
END;$function$;

CREATE OR REPLACE FUNCTION public.game_education()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN jsonb_build_object(
    -- Misiones
    'missions_total',         (SELECT COUNT(*) FROM missions),
    'missions_completed',     (SELECT COUNT(*) FROM mission_claims),
    'mission_participants',   (SELECT COUNT(DISTINCT user_id) FROM mission_claims),
    -- Quizzes / preguntas
    'total_answers',          (SELECT COUNT(*) FROM player_answers),
    'correct_answers',        (SELECT COUNT(*) FROM player_answers WHERE is_correct = true),
    'wrong_answers',          (SELECT COUNT(*) FROM player_answers WHERE is_correct = false),
    'unique_quiz_users',      (SELECT COUNT(DISTINCT user_id) FROM player_answers),
    -- Badges
    'badges_earned_total',    (SELECT COUNT(*) FROM player_badges),
    'unique_badge_earners',   (SELECT COUNT(DISTINCT user_id) FROM player_badges),
    'badge_types_available',  (SELECT COUNT(*) FROM badge_definitions),
    -- Trabajos/Jobs
    'jobs_available',         (SELECT COUNT(*) FROM jobs),
    'jobs_completed',         (SELECT COUNT(*) FROM job_completions),
    'unique_job_workers',     (SELECT COUNT(DISTINCT user_id) FROM job_completions),
    -- Mundos
    'world_progress_entries', (SELECT COUNT(*) FROM world_progress),
    'unique_world_players',   (SELECT COUNT(DISTINCT user_id) FROM world_progress)
  );
END;$function$;

CREATE OR REPLACE FUNCTION public.game_missions_status()
 RETURNS TABLE(status text, cnt bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN QUERY
  SELECT COALESCE(mp.status, 'sin_progreso'), COUNT(*)
  FROM mission_progress mp
  GROUP BY mp.status
  ORDER BY cnt DESC;
END;$function$;

CREATE OR REPLACE FUNCTION public.game_quiz_accuracy()
 RETURNS TABLE(user_id uuid, total bigint, correct bigint, accuracy numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    pa.user_id,
    COUNT(*)                                                     AS total,
    COUNT(*) FILTER (WHERE pa.is_correct = true)                 AS correct,
    ROUND(
      COUNT(*) FILTER (WHERE pa.is_correct = true)::numeric
      / NULLIF(COUNT(*), 0) * 100, 1
    )                                                            AS accuracy
  FROM player_answers pa
  GROUP BY pa.user_id
  ORDER BY accuracy DESC;
END;$function$;

CREATE OR REPLACE FUNCTION public.game_top_badges(p_limit integer DEFAULT 8)
 RETURNS TABLE(badge_id text, badge_name text, earned_count bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    pb.badge_id::TEXT,
    COALESCE(bd.name, pb.badge_id::TEXT),
    COUNT(*)
  FROM player_badges pb
  LEFT JOIN badge_definitions bd ON bd.id::TEXT = pb.badge_id::TEXT
  GROUP BY pb.badge_id, bd.name
  ORDER BY earned_count DESC
  LIMIT p_limit;
END;$function$;

CREATE OR REPLACE FUNCTION public.game_top_jobs(p_limit integer DEFAULT 8)
 RETURNS TABLE(job_id text, job_name text, completions bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    jc.job_id::TEXT,
    COALESCE(j.name, jc.job_id::TEXT),
    COUNT(*)
  FROM job_completions jc
  LEFT JOIN jobs j ON j.id = jc.job_id
  GROUP BY jc.job_id, j.name
  ORDER BY completions DESC
  LIMIT p_limit;
END;$function$;

CREATE OR REPLACE FUNCTION public.game_transactions_breakdown()
 RETURNS TABLE(tx_type text, total_count bigint, total_amount numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(type, 'desconocido'),
    COUNT(*),
    COALESCE(SUM(amount), 0)
  FROM transactions
  GROUP BY type
  ORDER BY total_count DESC;
END;$function$;

CREATE OR REPLACE FUNCTION public.game_users()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN jsonb_build_object(
    'total_auth_users',   (SELECT COUNT(*) FROM auth.users),
    'total_profiles',     (SELECT COUNT(*) FROM profiles),
    'parents',            (SELECT COUNT(*) FROM profiles WHERE role = 'parent'),
    'children',           (SELECT COUNT(*) FROM profiles WHERE role = 'child'),
    'linked_pairs',       (SELECT COUNT(*) FROM parent_child WHERE status = 'accepted'),
    'pending_links',      (SELECT COUNT(*) FROM parent_child WHERE status = 'pending'),
    'tutorials_completed',(SELECT COUNT(DISTINCT user_id) FROM tutorial_progress WHERE is_completed = true),
    'active_streaks',     (SELECT COUNT(*) FROM user_streaks WHERE current_streak > 0),
    'max_streak',         (SELECT COALESCE(MAX(longest_streak), 0) FROM user_streaks),
    'avg_streak',         (SELECT COALESCE(ROUND(AVG(current_streak), 1), 0) FROM user_streaks WHERE current_streak > 0)
  );
END;$function$;

CREATE OR REPLACE FUNCTION public.game_wallet_distribution(p_limit integer DEFAULT 10)
 RETURNS TABLE(balance_range text, user_count bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    CASE
      WHEN balance = 0          THEN '0 monedas'
      WHEN balance BETWEEN 1   AND 100  THEN '1–100'
      WHEN balance BETWEEN 101 AND 500  THEN '101–500'
      WHEN balance BETWEEN 501 AND 1000 THEN '501–1,000'
      WHEN balance BETWEEN 1001 AND 5000 THEN '1,001–5,000'
      ELSE '5,000+'
    END,
    COUNT(*)
  FROM wallets
  GROUP BY 1
  ORDER BY MIN(balance) ASC;
END;$function$;

CREATE OR REPLACE FUNCTION public.game_worlds_progress()
 RETURNS TABLE(world_id text, users_entered bigint, avg_level numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(world_id, 'desconocido'),
    COUNT(DISTINCT user_id),
    COALESCE(ROUND(AVG(level), 1), 0)
  FROM world_progress
  GROUP BY world_id
  ORDER BY users_entered DESC;
END;$function$;

CREATE OR REPLACE FUNCTION public.generate_invite_code()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_code  TEXT;
  v_chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_taken BOOLEAN;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'parent') THEN
    RAISE EXCEPTION 'Solo los padres pueden generar códigos';
  END IF;

  UPDATE invite_codes SET expires_at = now()
  WHERE parent_id = auth.uid() AND used_at IS NULL AND expires_at > now();

  LOOP
    v_code := '';
    FOR i IN 1..6 LOOP
      v_code := v_code || substr(v_chars, floor(random() * length(v_chars) + 1)::int, 1);
    END LOOP;
    SELECT EXISTS(SELECT 1 FROM invite_codes WHERE code = v_code AND expires_at > now()) INTO v_taken;
    EXIT WHEN NOT v_taken;
  END LOOP;

  INSERT INTO invite_codes (code, parent_id, expires_at)
  VALUES (v_code, auth.uid(), now() + INTERVAL '24 hours');

  RETURN v_code;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_fuel(p_world_slug text)
 RETURNS integer
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT COALESCE(
    (SELECT fuel FROM world_fuel
     WHERE user_id = auth.uid() AND world_slug = p_world_slug),
    0
  );
$function$;

CREATE OR REPLACE FUNCTION public.get_my_salary_status()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid        UUID  := auth.uid();
  v_salary     weekly_salaries%ROWTYPE;
  v_week_start TIMESTAMPTZ := date_trunc('week', now());
BEGIN
  SELECT * INTO v_salary
  FROM weekly_salaries
  WHERE child_id = v_uid AND is_active = TRUE
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('has_salary', FALSE);
  END IF;

  RETURN jsonb_build_object(
    'has_salary',              TRUE,
    'amount',                  v_salary.amount,
    'already_claimed',
      v_salary.last_paid_at IS NOT NULL
        AND v_salary.last_paid_at >= v_week_start
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.grant_weekly_allowance_if_due()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid     UUID := auth.uid();
  v_wallet  wallets%ROWTYPE;
  v_granted INTEGER := 0;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Se requiere sesión activa';
  END IF;

  SELECT * INTO v_wallet FROM wallets WHERE user_id = v_uid FOR UPDATE;
  IF NOT FOUND OR v_wallet.weekly_allowance <= 0 THEN
    RETURN 0;
  END IF;

  IF v_wallet.allowance_last_granted_at IS NULL
     OR v_wallet.allowance_last_granted_at <= now() - INTERVAL '7 days' THEN
    UPDATE wallets
    SET total_coins = total_coins + v_wallet.weekly_allowance,
        allowance_last_granted_at = now(),
        updated_at = now()
    WHERE user_id = v_uid;
    v_granted := v_wallet.weekly_allowance;
  END IF;

  RETURN v_granted;
END;
$function$;

CREATE OR REPLACE FUNCTION public.increment_mission_action(p_type text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF p_type NOT IN ('quiz', 'job', 'purchase') THEN
    RAISE EXCEPTION 'Tipo de acción inválido: %', p_type;
  END IF;

  INSERT INTO mission_progress (user_id, quizzes, jobs, purchases)
  VALUES (
    auth.uid(),
    CASE WHEN p_type = 'quiz'     THEN 1 ELSE 0 END,
    CASE WHEN p_type = 'job'      THEN 1 ELSE 0 END,
    CASE WHEN p_type = 'purchase' THEN 1 ELSE 0 END
  )
  ON CONFLICT (user_id) DO UPDATE SET
    quizzes    = mission_progress.quizzes    + CASE WHEN p_type = 'quiz'     THEN 1 ELSE 0 END,
    jobs       = mission_progress.jobs       + CASE WHEN p_type = 'job'      THEN 1 ELSE 0 END,
    purchases  = mission_progress.purchases  + CASE WHEN p_type = 'purchase' THEN 1 ELSE 0 END,
    updated_at = now();
END;
$function$;

CREATE OR REPLACE FUNCTION public.is_display_name_available(p_name text)
 RETURNS boolean
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
  SELECT NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE LOWER(display_name) = LOWER(p_name)
  );
$function$;

CREATE OR REPLACE FUNCTION public.log_push_sent(p_type text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO push_notification_log (user_id, notification_type)
  VALUES (auth.uid(), p_type);
END;
$function$;

CREATE OR REPLACE FUNCTION public.mark_tutorial_seen(p_key text)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  UPDATE profiles
  SET tutorials_seen = tutorials_seen || jsonb_build_object(p_key, true)
  WHERE id = auth.uid();
$function$;

CREATE OR REPLACE FUNCTION public.purchase_world(p_world_slug text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_world_id    UUID;
  v_cost        INT;
  v_new_balance INT;
BEGIN
  -- Obtener UUID y costo del mundo
  SELECT id, unlock_cost
  INTO   v_world_id, v_cost
  FROM   worlds
  WHERE  slug = p_world_slug AND is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Mundo no encontrado: %', p_world_slug;
  END IF;

  -- Verificar que no está ya desbloqueado
  IF EXISTS (
    SELECT 1 FROM world_progress
    WHERE user_id   = auth.uid()
      AND world_id  = v_world_id
      AND is_unlocked = true
  ) THEN
    RAISE EXCEPTION 'Este mundo ya está desbloqueado';
  END IF;

  -- Para mundos gratuitos (unlock_cost = 0) saltar el UPDATE de monedas
  IF v_cost > 0 THEN
    UPDATE wallets
    SET total_coins = total_coins - v_cost
    WHERE user_id = auth.uid()
      AND total_coins >= v_cost
    RETURNING total_coins INTO v_new_balance;

    IF v_new_balance IS NULL THEN
      RAISE EXCEPTION 'Monedas insuficientes';
    END IF;
  ELSE
    -- Leer el saldo actual solo para devolverlo en la respuesta
    SELECT total_coins INTO v_new_balance
    FROM wallets WHERE user_id = auth.uid();
  END IF;

  -- Registrar desbloqueo (INSERT o UPDATE si ya existía el registro)
  INSERT INTO world_progress (user_id, world_id, is_unlocked, unlocked_at)
  VALUES (auth.uid(), v_world_id, true, now())
  ON CONFLICT (user_id, world_id)
  DO UPDATE SET is_unlocked = true, unlocked_at = now();

  RETURN jsonb_build_object('success', true, 'balance', COALESCE(v_new_balance, 0));
END;
$function$;

CREATE OR REPLACE FUNCTION public.record_daily_activity()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid         UUID    := auth.uid();
  v_today       DATE    := CURRENT_DATE;
  v_last        DATE;
  v_streak      INTEGER := 0;
  v_longest     INTEGER := 0;
  v_is_new_day  BOOLEAN := FALSE;
  v_coins       INTEGER := 0;
  v_fuel        INTEGER := 2;   -- cada día activo da 2 puntos de combustible
BEGIN
  -- Leer estado actual
  SELECT current_streak, longest_streak, last_activity_at
  INTO   v_streak, v_longest, v_last
  FROM   user_streaks
  WHERE  user_id = v_uid AND streak_type = 'daily';

  IF NOT FOUND THEN
    -- Primera vez
    v_streak     := 1;
    v_longest    := 1;
    v_is_new_day := TRUE;
    INSERT INTO user_streaks(user_id, streak_type, current_streak, longest_streak, last_activity_at)
    VALUES (v_uid, 'daily', 1, 1, v_today);
  ELSIF v_last < v_today THEN
    v_is_new_day := TRUE;
    IF v_last = v_today - 1 THEN
      -- Día consecutivo
      v_streak := v_streak + 1;
    ELSE
      -- Racha rota
      v_streak := 1;
    END IF;
    v_longest := GREATEST(v_longest, v_streak);
    UPDATE user_streaks
    SET current_streak   = v_streak,
        longest_streak   = v_longest,
        last_activity_at = v_today,
        updated_at       = now()
    WHERE user_id = v_uid AND streak_type = 'daily';
  END IF;

  -- Recompensas por hito de días
  IF v_is_new_day THEN
    IF v_streak = 3  THEN v_coins := 5;  END IF;
    IF v_streak = 28 THEN v_coins := 15; END IF;
    IF v_streak = 56 THEN v_coins := 25; END IF;
    IF v_streak = 84 THEN v_coins := 35; END IF;

    IF v_coins > 0 THEN
      UPDATE wallets SET total_coins = total_coins + v_coins,
                         updated_at  = now()
      WHERE user_id = v_uid;
    END IF;

    -- Combustible diario
    PERFORM add_fuel('space', v_fuel);
  END IF;

  RETURN jsonb_build_object(
    'streak',        v_streak,
    'is_new_day',    v_is_new_day,
    'milestone_coins', v_coins,
    'fuel_added',    CASE WHEN v_is_new_day THEN v_fuel ELSE 0 END
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.record_weekly_mission()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_uid        UUID    := auth.uid();
  v_week       DATE    := date_trunc('week', CURRENT_DATE)::DATE;
  v_last_week  DATE;
  v_streak     INTEGER := 0;
  v_longest    INTEGER := 0;
  v_is_new_wk  BOOLEAN := FALSE;
  v_coins      INTEGER := 0;
BEGIN
  SELECT current_streak, longest_streak, last_activity_at
  INTO   v_streak, v_longest, v_last_week
  FROM   user_streaks
  WHERE  user_id = v_uid AND streak_type = 'weekly';

  IF NOT FOUND THEN
    v_streak    := 1;
    v_longest   := 1;
    v_is_new_wk := TRUE;
    INSERT INTO user_streaks(user_id, streak_type, current_streak, longest_streak, last_activity_at)
    VALUES (v_uid, 'weekly', 1, 1, v_week);
  ELSIF v_last_week < v_week THEN
    v_is_new_wk := TRUE;
    IF v_last_week = v_week - INTERVAL '7 days' THEN
      v_streak := v_streak + 1;
    ELSE
      v_streak := 1;
    END IF;
    v_longest := GREATEST(v_longest, v_streak);
    UPDATE user_streaks
    SET current_streak   = v_streak,
        longest_streak   = v_longest,
        last_activity_at = v_week,
        updated_at       = now()
    WHERE user_id = v_uid AND streak_type = 'weekly';
  END IF;

  -- Recompensas por hito de semanas
  IF v_is_new_wk THEN
    -- Hitos: 4, 8, 12 semanas
    IF v_streak = 4  THEN v_coins := 15; END IF;
    IF v_streak = 8  THEN v_coins := 25; END IF;
    IF v_streak = 12 THEN v_coins := 35; END IF;

    IF v_coins > 0 THEN
      UPDATE wallets SET total_coins = total_coins + v_coins,
                         updated_at  = now()
      WHERE user_id = v_uid;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'streak',          v_streak,
    'is_new_week',     v_is_new_wk,
    'milestone_coins', v_coins
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.redeem_invite_code(p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_invite   RECORD;
  v_child_id UUID := auth.uid();
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM profiles WHERE id = v_child_id AND role = 'child'
  ) THEN
    RAISE EXCEPTION 'Solo los niños pueden canjear códigos de invitación';
  END IF;

  SELECT * INTO v_invite
  FROM invite_codes
  WHERE code       = upper(trim(p_code))
    AND used_at   IS NULL
    AND expires_at > now()
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Código inválido o expirado. Pídele a tu papá o mamá uno nuevo.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM parent_child
    WHERE parent_id = v_invite.parent_id AND child_id = v_child_id
  ) THEN
    RAISE EXCEPTION 'Ya estás vinculado con este papá o mamá';
  END IF;

  INSERT INTO parent_child (parent_id, child_id, status)
  VALUES (v_invite.parent_id, v_child_id, 'accepted')
  ON CONFLICT (parent_id, child_id)
  DO UPDATE SET status = 'accepted';

  UPDATE invite_codes
  SET used_at  = now(),
      child_id = v_child_id
  WHERE id = v_invite.id;

  -- Promover cuenta del niño a 'full' al vincularse
  UPDATE profiles SET account_type = 'full' WHERE id = v_child_id;

  RETURN jsonb_build_object('success', true, 'parent_id', v_invite.parent_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.remove_player_item(p_item_id text, p_qty integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_remaining INT;
BEGIN
  IF p_qty <= 0 THEN
    RAISE EXCEPTION 'La cantidad debe ser positiva';
  END IF;

  UPDATE player_items
  SET qty = qty - p_qty
  WHERE user_id = auth.uid()
    AND item_id = p_item_id
    AND qty >= p_qty
  RETURNING qty INTO v_remaining;

  IF v_remaining IS NULL THEN
    RAISE EXCEPTION 'No tienes suficiente: % (necesitas %)', p_item_id, p_qty;
  END IF;

  RETURN v_remaining;
END;
$function$;

CREATE OR REPLACE FUNCTION public.reset_fuel(p_world_slug text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  UPDATE world_fuel
  SET fuel       = 0,
      cycle      = cycle + 1,
      updated_at = now()
  WHERE user_id    = auth.uid()
    AND world_slug = p_world_slug;
END;
$function$;

CREATE OR REPLACE FUNCTION public.search_child(p_query text)
 RETURNS TABLE(id uuid, display_name text, avatar_url text, email text)
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
  SELECT
    p.id,
    p.display_name,
    p.avatar_url,
    u.email
  FROM profiles p
  JOIN auth.users u ON u.id = p.id
  WHERE
    p.role = 'child'
    AND (
      LOWER(p.display_name) LIKE '%' || LOWER(p_query) || '%'
      OR LOWER(u.email)        LIKE '%' || LOWER(p_query) || '%'
    )
  LIMIT 10;
$function$;

CREATE OR REPLACE FUNCTION public.set_world_name(p_name text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  UPDATE profiles
     SET world_name = trim(p_name)
   WHERE id = auth.uid();
END;
$function$;

CREATE OR REPLACE FUNCTION public.spend_coins(p_amount integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_new_balance INT;
BEGIN
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'El monto debe ser positivo';
  END IF;

  -- Actualización atómica: solo se ejecuta si hay fondos suficientes
  UPDATE wallets
  SET total_coins = total_coins - p_amount
  WHERE user_id = auth.uid()
    AND total_coins >= p_amount
  RETURNING total_coins INTO v_new_balance;

  -- COALESCE: si no se actualizó ninguna fila → saldo insuficiente
  RETURN COALESCE(v_new_balance, -1);
END;
$function$;

CREATE OR REPLACE FUNCTION public.touch_last_active()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.last_active = now();
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.transfer_coins_to_child(p_child_id uuid, p_amount integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_parent_id   UUID := auth.uid();
  v_new_balance INT;
BEGIN
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'El monto debe ser mayor a cero';
  END IF;

  -- Verificar que el caller es padre
  IF NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = v_parent_id AND role = 'parent'
  ) THEN
    RAISE EXCEPTION 'Solo los padres pueden enviar monedas';
  END IF;

  -- Verificar vínculo padre-hijo activo
  IF NOT EXISTS (
    SELECT 1 FROM parent_child
    WHERE parent_id = v_parent_id
      AND child_id  = p_child_id
      AND status    = 'accepted'
  ) THEN
    RAISE EXCEPTION 'No estás vinculado con este hijo';
  END IF;

  -- Deducir del padre de forma atómica
  UPDATE wallets
  SET total_coins = total_coins - p_amount
  WHERE user_id = v_parent_id
    AND total_coins >= p_amount
  RETURNING total_coins INTO v_new_balance;

  IF v_new_balance IS NULL THEN
    RAISE EXCEPTION 'Saldo insuficiente';
  END IF;

  -- Sumar al hijo
  UPDATE wallets
  SET total_coins = total_coins + p_amount
  WHERE user_id = p_child_id;

  IF NOT FOUND THEN
    -- Revertir: devolver las monedas al padre antes de lanzar error
    UPDATE wallets
    SET total_coins = total_coins + p_amount
    WHERE user_id = v_parent_id;
    RAISE EXCEPTION 'El hijo no tiene cartera registrada';
  END IF;

  -- Notificación al hijo
  INSERT INTO notifications (user_id, type, title, body, data)
  VALUES (
    p_child_id,
    'coins_received',
    '¡Recibiste monedas! 🪙',
    'Tu papá/mamá te envió ' || p_amount || ' monedas. ¡Úsalas bien!',
    jsonb_build_object('amount', p_amount)
  );

  RETURN jsonb_build_object('success', true, 'parent_balance', v_new_balance);
END;
$function$;

CREATE OR REPLACE FUNCTION public.unequip_cosmetic(p_slot text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  DELETE FROM character_equipped
  WHERE user_id = auth.uid() AND slot = p_slot;
END;
$function$;

CREATE OR REPLACE FUNCTION public.unlock_hangar_suit()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO player_cosmetics (user_id, cosmetic_id)
  VALUES (auth.uid(), 'hangar_suit')
  ON CONFLICT (user_id, cosmetic_id) DO NOTHING;

  INSERT INTO character_equipped (user_id, slot, cosmetic_id)
  VALUES (auth.uid(), 'suit', 'hangar_suit')
  ON CONFLICT (user_id, slot) DO UPDATE
    SET cosmetic_id = 'hangar_suit';

  INSERT INTO notifications (user_id, type, title, body)
  VALUES (
    auth.uid(),
    'hangar_suit_unlocked',
    '🥇 ¡Traje Dorado desbloqueado!',
    '¡Completaste el Hangar de Despegue! El Traje Dorado es tuyo para siempre.'
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.upsert_weekly_salary(p_child_id uuid, p_amount integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- Verificar vínculo padre-hijo
  IF NOT EXISTS (
    SELECT 1 FROM parent_child
    WHERE parent_id = auth.uid() AND child_id = p_child_id
  ) THEN
    RAISE EXCEPTION 'No vinculado con este niño';
  END IF;

  INSERT INTO weekly_salaries(parent_id, child_id, amount, is_active, updated_at)
  VALUES (auth.uid(), p_child_id, p_amount, TRUE, now())
  ON CONFLICT (parent_id, child_id) DO UPDATE
    SET amount     = EXCLUDED.amount,
        is_active  = TRUE,
        updated_at = now();
END;
$function$;

