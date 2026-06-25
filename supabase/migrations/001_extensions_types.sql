-- ============================================================
-- FinQuest — Migración 001: Extensiones y tipos enumerados
-- ============================================================

-- UUID nativo de PostgreSQL
create extension if not exists "uuid-ossp";

-- Roles de usuario en el sistema
create type user_role as enum ('parent', 'child', 'admin');

-- Categorías de la bolsa del niño (5 categorías fijas)
create type wallet_category_type as enum (
  'ahorro',
  'inversion',
  'emergencia',
  'gastos',
  'metas'
);

-- Tipos de movimientos de monedas
create type transaction_type as enum (
  'deposit',          -- papá recarga dinero real
  'parent_to_child',  -- papá envía monedas al hijo
  'job_reward',       -- recompensa por trabajo completado
  'mission_reward',   -- recompensa por misión global
  'question_reward',  -- recompensa por respuesta correcta
  'store_purchase',   -- compra en tienda oficial
  'market_buy',       -- compra en mercado de jugadores
  'market_sell',      -- venta en mercado de jugadores
  'category_move'     -- mover entre categorías de la bolsa
);

-- Tipos de casitas en el mapa de cada mundo
create type house_type as enum (
  'wallet',     -- Mi Bolsa
  'missions',   -- Misiones globales
  'jobs',       -- Trabajos / mini-juegos
  'questions',  -- Banco de preguntas
  'market',     -- Mercado entre jugadores
  'store'       -- Tienda oficial
);

-- Tipos de preguntas del banco educativo
create type question_type as enum (
  'multiple_choice',  -- 4 opciones, elegir la correcta
  'drag_match',       -- arrastrar y relacionar
  'order_steps',      -- ordenar pasos en secuencia
  'true_false',       -- verdadero o falso
  'fill_blank'        -- completar el espacio en blanco
);

-- Niveles de dificultad
create type difficulty_level as enum ('easy', 'medium', 'hard');

-- Tipos de ítems en el catálogo de la tienda
create type item_type as enum ('avatar', 'tool', 'decoration', 'special');

-- Estados posibles de una misión global
create type mission_status as enum ('active', 'completed', 'expired');

-- Estados de un listado en el mercado de jugadores
create type listing_status as enum ('active', 'sold', 'cancelled');

-- Estados de una compra real (IAP)
create type purchase_status as enum ('pending', 'completed', 'failed', 'refunded');

-- Plataforma de la compra real
create type purchase_platform as enum ('ios', 'android');
