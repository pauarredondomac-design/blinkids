-- ============================================================
-- Migración 028: Tablas base del sistema de cosméticos
--
-- Esta migración crea las tablas cosmetic_definitions,
-- player_cosmetics y character_equipped con CREATE TABLE IF NOT EXISTS
-- para que el esquema sea reproducible desde cero.
--
-- Las RPCs buy_cosmetic, equip_cosmetic y unequip_cosmetic
-- se crean aquí con OR REPLACE para que sean idempotentes.
-- ============================================================

-- ── Catálogo de cosméticos ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.cosmetic_definitions (
  id                  TEXT PRIMARY KEY,
  slot                TEXT NOT NULL CHECK (slot IN ('helmet','suit','backpack','boots','flag','top','bottom','accesorios')),
  name                TEXT NOT NULL,
  description         TEXT NOT NULL DEFAULT '',
  emoji               TEXT NOT NULL DEFAULT '🎭',
  price               INT  NOT NULL DEFAULT 0 CHECK (price >= 0),
  unlock_type         TEXT NOT NULL DEFAULT 'buy' CHECK (unlock_type IN ('buy','earn')),
  asset_path          TEXT,
  equipped_asset_path TEXT,
  in_shop             BOOLEAN NOT NULL DEFAULT true
);

-- ── Cosméticos que el jugador posee ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.player_cosmetics (
  user_id      UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  cosmetic_id  TEXT REFERENCES public.cosmetic_definitions(id) ON DELETE CASCADE,
  obtained_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, cosmetic_id)
);

-- ── Cosmético equipado por slot ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.character_equipped (
  user_id      UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  slot         TEXT NOT NULL CHECK (slot IN ('helmet','suit','backpack','boots','flag','top','bottom','accesorios')),
  cosmetic_id  TEXT REFERENCES public.cosmetic_definitions(id) ON DELETE SET NULL,
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, slot)
);

-- ── Índices ───────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_player_cosmetics_user   ON public.player_cosmetics (user_id);
CREATE INDEX IF NOT EXISTS idx_character_equipped_user ON public.character_equipped (user_id);

-- ── RLS ──────────────────────────────────────────────────────────────────────
ALTER TABLE public.cosmetic_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_cosmetics     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.character_equipped   ENABLE ROW LEVEL SECURITY;

-- Catálogo público
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'cosmetic_definitions' AND policyname = 'public read cosmetics catalog'
  ) THEN
    CREATE POLICY "public read cosmetics catalog"
      ON public.cosmetic_definitions FOR SELECT USING (true);
  END IF;
END $$;

-- Jugador lee sus propios cosméticos
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'player_cosmetics' AND policyname = 'player reads own cosmetics'
  ) THEN
    CREATE POLICY "player reads own cosmetics"
      ON public.player_cosmetics FOR SELECT USING (auth.uid() = user_id);
  END IF;
END $$;

-- Jugador lee su propio equipamiento
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'character_equipped' AND policyname = 'player reads own equipped'
  ) THEN
    CREATE POLICY "player reads own equipped"
      ON public.character_equipped FOR SELECT USING (auth.uid() = user_id);
  END IF;
END $$;

-- Padre lee cosméticos de sus hijos
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'player_cosmetics' AND policyname = 'parent reads child cosmetics'
  ) THEN
    CREATE POLICY "parent reads child cosmetics"
      ON public.player_cosmetics FOR SELECT USING (
        EXISTS (
          SELECT 1 FROM public.parent_child
          WHERE parent_id = auth.uid() AND child_id = player_cosmetics.user_id
        )
      );
  END IF;
END $$;

-- Padre lee equipamiento de sus hijos
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'character_equipped' AND policyname = 'parent reads child equipped'
  ) THEN
    CREATE POLICY "parent reads child equipped"
      ON public.character_equipped FOR SELECT USING (
        EXISTS (
          SELECT 1 FROM public.parent_child
          WHERE parent_id = auth.uid() AND child_id = character_equipped.user_id
        )
      );
  END IF;
END $$;

-- Sin INSERT/UPDATE directo — solo a través de RPCs SECURITY DEFINER
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'player_cosmetics' AND policyname = 'no direct insert cosmetics'
  ) THEN
    CREATE POLICY "no direct insert cosmetics"
      ON public.player_cosmetics FOR INSERT WITH CHECK (false);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'character_equipped' AND policyname = 'no direct insert equipped'
  ) THEN
    CREATE POLICY "no direct insert equipped"
      ON public.character_equipped FOR INSERT WITH CHECK (false);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'character_equipped' AND policyname = 'no direct update equipped'
  ) THEN
    CREATE POLICY "no direct update equipped"
      ON public.character_equipped FOR UPDATE USING (false);
  END IF;
END $$;

-- ── RPC: buy_cosmetic ────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.buy_cosmetic(p_cosmetic_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid     UUID := auth.uid();
  v_price   INT;
  v_new_bal INT;
BEGIN
  SELECT price INTO v_price
  FROM   public.cosmetic_definitions
  WHERE  id = p_cosmetic_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cosmético no encontrado: %', p_cosmetic_id;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.player_cosmetics
    WHERE user_id = v_uid AND cosmetic_id = p_cosmetic_id
  ) THEN
    RAISE EXCEPTION 'Ya tienes este cosmético';
  END IF;

  IF v_price > 0 THEN
    UPDATE public.wallets
    SET total_coins = total_coins - v_price
    WHERE user_id = v_uid AND total_coins >= v_price
    RETURNING total_coins INTO v_new_bal;

    IF v_new_bal IS NULL THEN
      RAISE EXCEPTION 'Monedas insuficientes';
    END IF;
  ELSE
    SELECT total_coins INTO v_new_bal FROM public.wallets WHERE user_id = v_uid;
  END IF;

  INSERT INTO public.player_cosmetics (user_id, cosmetic_id)
  VALUES (v_uid, p_cosmetic_id);

  RETURN jsonb_build_object('success', true, 'balance', COALESCE(v_new_bal, 0));
END;
$$;

REVOKE ALL ON FUNCTION public.buy_cosmetic(TEXT) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.buy_cosmetic(TEXT) TO authenticated;

-- ── RPC: equip_cosmetic ───────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.equip_cosmetic(p_cosmetic_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid  UUID := auth.uid();
  v_slot TEXT;
BEGIN
  SELECT slot INTO v_slot
  FROM   public.cosmetic_definitions
  WHERE  id = p_cosmetic_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cosmético no encontrado: %', p_cosmetic_id;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.player_cosmetics
    WHERE user_id = v_uid AND cosmetic_id = p_cosmetic_id
  ) THEN
    RAISE EXCEPTION 'No tienes este cosmético';
  END IF;

  INSERT INTO public.character_equipped (user_id, slot, cosmetic_id, updated_at)
  VALUES (v_uid, v_slot, p_cosmetic_id, now())
  ON CONFLICT (user_id, slot)
  DO UPDATE SET cosmetic_id = EXCLUDED.cosmetic_id, updated_at = now();

  RETURN jsonb_build_object('success', true, 'slot', v_slot);
END;
$$;

REVOKE ALL ON FUNCTION public.equip_cosmetic(TEXT) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.equip_cosmetic(TEXT) TO authenticated;

-- ── RPC: unequip_cosmetic ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.unequip_cosmetic(p_slot TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.character_equipped
  WHERE user_id = auth.uid() AND slot = p_slot;
END;
$$;

REVOKE ALL ON FUNCTION public.unequip_cosmetic(TEXT) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.unequip_cosmetic(TEXT) TO authenticated;
