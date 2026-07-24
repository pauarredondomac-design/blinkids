-- ============================================================
-- Migración 020: Trabajos de crafting en tabla jobs
-- Agrega columnas para crafting y registra los 6 trabajos.
-- ============================================================

-- Columna para distinguir tipo de trabajo
alter table public.jobs
  add column if not exists type        text not null default 'minigame',
  add column if not exists emoji       text,
  add column if not exists npc_name    text,
  add column if not exists npc_emoji   text,
  add column if not exists story       text,
  add column if not exists requirements jsonb,
  add column if not exists item_reward  jsonb;

-- Índice para filtrar por tipo y mundo
create index if not exists jobs_type_world_idx
  on public.jobs (type, world_id)
  where is_active = true;

-- ── Insertar los 6 trabajos de crafting ───────────────────────────────────────

-- BOSQUE: Reparar la Cabaña
insert into public.jobs (type, world_id, emoji, name, npc_name, npc_emoji, story, requirements, coin_reward, xp_reward, item_reward, is_active)
select
  'crafting',
  (select id from worlds where slug = 'forest'),
  '🏚️',
  'Reparar la Cabaña',
  'Osito Bruno',
  '🐻',
  '¡Hola aventurero! Un árbol cayó sobre mi cabaña durante la tormenta. Necesito 3 tablones de madera y un martillo para repararla. ¿Me puedes ayudar? ¡Te lo agradeceré con muchas monedas!',
  '[{"item_id": "wood_plank", "qty": 3}, {"item_id": "hammer", "qty": 1}]',
  250,
  40,
  '{"item_id": "forest_gem", "qty": 1}',
  true;

-- BOSQUE: Curar al Zorro
insert into public.jobs (type, world_id, emoji, name, npc_name, npc_emoji, story, requirements, coin_reward, xp_reward, item_reward, is_active)
select
  'crafting',
  (select id from worlds where slug = 'forest'),
  '🦊',
  'Curar al Zorro',
  'Doctora Búho',
  '🦉',
  'El zorro del bosque está muy enfermo y necesita ayuda urgente. Prepara 2 hierbas mágicas mezcladas con 1 poción de salud para hacer la medicina. ¡Date prisa, por favor!',
  '[{"item_id": "magic_herb", "qty": 2}, {"item_id": "health_potion", "qty": 1}]',
  200,
  30,
  null,
  true;

-- BOSQUE: El Festín de la Ardilla
insert into public.jobs (type, world_id, emoji, name, npc_name, npc_emoji, story, requirements, coin_reward, xp_reward, item_reward, is_active)
select
  'crafting',
  (select id from worlds where slug = 'forest'),
  '🐿️',
  'El Festín de la Ardilla',
  'Ardilla Chispa',
  '🐿️',
  '¡El invierno se acerca y no tengo suficiente comida! Necesito juntar 5 bellotas para llenar mi despensa. Si me las consigues, te doy unas hierbas especiales que encontré.',
  '[{"item_id": "acorn", "qty": 5}]',
  150,
  20,
  '{"item_id": "magic_herb", "qty": 2}',
  true;

-- ESPACIO: Reparar la Nave
insert into public.jobs (type, world_id, emoji, name, npc_name, npc_emoji, story, requirements, coin_reward, xp_reward, item_reward, is_active)
select
  'crafting',
  (select id from worlds where slug = 'space'),
  '🚀',
  'Reparar la Nave',
  'Capitán Astro',
  '👨‍🚀',
  '¡Socorro, astronauta! Mi nave espacial chocó con un asteroide. Necesito 3 pernos espaciales y 1 llave inglesa para repararla. Si me ayudas, te doy una recompensa galáctica muy especial.',
  '[{"item_id": "space_bolt", "qty": 3}, {"item_id": "wrench", "qty": 1}]',
  300,
  50,
  '{"item_id": "star_crystal", "qty": 1}',
  true;

-- ESPACIO: Activar la Estación
insert into public.jobs (type, world_id, emoji, name, npc_name, npc_emoji, story, requirements, coin_reward, xp_reward, item_reward, is_active)
select
  'crafting',
  (select id from worlds where slug = 'space'),
  '⚡',
  'Activar la Estación',
  'Robot R2',
  '🤖',
  'BEEP BOOP - Estación de energía sin poder. Necesito 2 baterías cuánticas y 1 cápsula de combustible para reactivar los sistemas. ¡Muchas gracias, humano amigo!',
  '[{"item_id": "battery", "qty": 2}, {"item_id": "fuel_capsule", "qty": 1}]',
  250,
  35,
  null,
  true;

-- ESPACIO: Arreglar al Robot
insert into public.jobs (type, world_id, emoji, name, npc_name, npc_emoji, story, requirements, coin_reward, xp_reward, item_reward, is_active)
select
  'crafting',
  (select id from worlds where slug = 'space'),
  '🦾',
  'Arreglar al Robot',
  'Ingeniera Luna',
  '👩‍🔬',
  'El robot de mantenimiento de la estación espacial se descompuso. Para repararlo necesito 1 llave inglesa, 2 circuitos lunares y 1 perno espacial. ¡Es urgente para la misión!',
  '[{"item_id": "wrench", "qty": 1}, {"item_id": "lunar_circuit", "qty": 2}, {"item_id": "space_bolt", "qty": 1}]',
  350,
  60,
  '{"item_id": "star_crystal", "qty": 1}',
  true;
