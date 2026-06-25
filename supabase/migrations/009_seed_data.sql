-- ============================================================
-- FinQuest — Migración 009: Datos iniciales (mundos y casitas)
-- ============================================================

-- Mundos del juego
insert into worlds (slug, name, description, unlock_cost, order_index) values
  (
    'forest',
    'Bosque Mágico',
    'Un bosque lleno de vida donde aprenderás a ahorrar y a dar tus primeros pasos como aventurero financiero.',
    0,    -- gratis (Mundo 1)
    1
  ),
  (
    'space',
    'Galaxia FinQuest',
    'El espacio profundo donde las monedas vuelan entre estrellas y las inversiones alcanzan velocidades cósmicas.',
    500,  -- requiere 500 monedas (o compra premium)
    2
  ),
  (
    'city',
    'Ciudad del Futuro',
    'Una metrópolis futurista donde los negocios nunca duermen y los hologramas reemplazaron al efectivo.',
    1000, -- requiere 1000 monedas (o compra premium)
    3
  );

-- Casitas de cada mundo
-- Posiciones en coordenadas relativas (0.0 – 1.0) del mapa 2D
insert into world_houses (world_id, type, name, position_x, position_y)
select
  w.id,
  h.house_type::house_type,
  case w.slug
    when 'forest' then h.name_forest
    when 'space'  then h.name_space
    when 'city'   then h.name_city
  end,
  h.pos_x,
  h.pos_y
from worlds w
cross join (values
  -- (tipo,        nombre bosque,          nombre espacio,            nombre ciudad,          x,    y)
  ('wallet',    'Cabaña de Juan',       'Cápsula Espacial',        'Penthouse FinQuest',   0.15, 0.55),
  ('missions',  'Cueva de Misiones',    'Estación Espacial',       'Torre de Retos',       0.35, 0.30),
  ('jobs',      'Puesto de Frutas',     'Centro de Control',       'Oficina Corporativa',  0.55, 0.60),
  ('questions', 'Árbol del Saber',      'Computadora Alienígena',  'Sala de Hologramas',   0.75, 0.30),
  ('market',    'Tianguis del Bosque',  'Mercado Flotante',        'Bolsa de Valores',     0.45, 0.75),
  ('store',     'Tienda del Gnomo',     'Tienda Galáctica',        'MegaMall Futuro',      0.85, 0.55)
) as h(house_type, name_forest, name_space, name_city, pos_x, pos_y);

-- ============================================================
-- Preguntas de ejemplo (para pruebas iniciales)
-- ============================================================

insert into questions (world_id, type, difficulty, question_text, options, correct_answer, coin_reward, xp_reward, explanation)
select
  (select id from worlds where slug = 'forest'),
  'multiple_choice',
  'easy',
  '¿Qué es el ahorro?',
  '[
    {"id": "a", "text": "Gastar todo tu dinero en lo que quieras", "icon": "🛒"},
    {"id": "b", "text": "Guardar parte de tu dinero para el futuro", "icon": "🐷"},
    {"id": "c", "text": "Pedir dinero prestado a un amigo", "icon": "🤝"},
    {"id": "d", "text": "Perder dinero jugando", "icon": "🎲"}
  ]',
  '"b"',
  10,
  5,
  'El ahorro es guardar una parte de tu dinero para poder usarlo después, ya sea para una emergencia o para una meta importante.'
;

insert into questions (world_id, type, difficulty, question_text, options, correct_answer, coin_reward, xp_reward, explanation)
select
  (select id from worlds where slug = 'forest'),
  'true_false',
  'easy',
  '¿Es buena idea gastar todo tu dinero apenas lo recibes?',
  '[
    {"id": "true",  "text": "Verdadero"},
    {"id": "false", "text": "Falso"}
  ]',
  '"false"',
  8,
  4,
  'No es buena idea. Es mejor guardar una parte para el futuro y otra para emergencias antes de gastar.'
;

insert into questions (type, difficulty, question_text, options, correct_answer, coin_reward, xp_reward, explanation)
values (
  'multiple_choice',
  'easy',
  '¿Cuántas categorías tiene la bolsa de FinQuest?',
  '[
    {"id": "a", "text": "3", "icon": "3️⃣"},
    {"id": "b", "text": "4", "icon": "4️⃣"},
    {"id": "c", "text": "5", "icon": "5️⃣"},
    {"id": "d", "text": "10", "icon": "🔟"}
  ]',
  '"c"',
  10,
  5,
  'La bolsa tiene 5 categorías: Ahorro, Inversión, Emergencia, Gastos y Metas. ¡Cada una tiene un propósito diferente!'
);

-- ============================================================
-- Trabajos de ejemplo (Bosque)
-- ============================================================

insert into jobs (world_id, name, description, instructions, coin_reward, xp_reward, duration_seconds, cooldown_minutes)
select
  (select id from worlds where slug = 'forest'),
  'Vendedor de Frutas',
  'Atiende tu puesto de frutas y da el cambio correcto a los clientes.',
  '{
    "intro": "Los clientes llegan con billetes y monedas. Tu tarea es dar el cambio exacto.",
    "mechanics": "drag_coins",
    "levels": [
      {"price": 15, "paid": 20, "change": 5},
      {"price": 32, "paid": 50, "change": 18},
      {"price": 67, "paid": 100, "change": 33}
    ]
  }',
  25,
  15,
  60,
  60
;

insert into jobs (world_id, name, description, instructions, coin_reward, xp_reward, duration_seconds, cooldown_minutes)
select
  (select id from worlds where slug = 'forest'),
  'Tiendita del Bosque',
  'Anota los ingresos y gastos del día en tu tiendita.',
  '{
    "intro": "Registra cuánto ganaste y cuánto gastaste para saber si tuviste ganancia.",
    "mechanics": "income_expense_entry",
    "transactions": [
      {"type": "income",  "desc": "Ventas de mañana",  "amount": 120},
      {"type": "expense", "desc": "Compra de frutas",  "amount": 45},
      {"type": "income",  "desc": "Ventas de tarde",   "amount": 85},
      {"type": "expense", "desc": "Bolsas y empaques", "amount": 10}
    ]
  }',
  20,
  10,
  90,
  120
;
