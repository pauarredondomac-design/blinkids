-- ============================================================
-- Tabla blink_dialogues — Textos de diálogo de Blink
-- Ejecutar en Supabase SQL Editor
-- ============================================================

create table if not exists public.blink_dialogues (
  id       serial primary key,
  screen   text    not null,
  "order"  integer not null,
  title    text    not null default '',
  body     text    not null default '',
  active   boolean not null default true,
  created_at timestamptz default now()
);

-- Índice para búsquedas por pantalla
create index if not exists blink_dialogues_screen_idx
  on public.blink_dialogues (screen, "order")
  where active = true;

-- RLS: lectura pública (sin autenticación), solo admins pueden escribir
alter table public.blink_dialogues enable row level security;

create policy "Lectura pública de diálogos"
  on public.blink_dialogues for select
  using (true);

-- ============================================================
-- Seed: Textos iniciales
-- ============================================================

insert into public.blink_dialogues (screen, "order", title, body) values

-- Intro / Tutorial inicial
('intro', 1, '¡Hola!',    '¡Hola! Soy Blink, tu guía en Blinkids. ¡Estoy muy emocionado de conocerte!'),
('intro', 2, 'Finanzas',  'Aquí aprenderás a ahorrar, invertir y manejar tus monedas como todo un experto financiero.'),
('intro', 3, 'Misiones',  'Explora el Mundo Espacio, completa misiones y gana monedas. ¡Cada decisión cuenta!'),
('intro', 4, 'Tu bolsa',  'Tu bolsa tiene 5 categorías: Ahorro, Inversión, Emergencia, Gastos y Metas. ¡Aprende a distribuir!'),

-- Mapa Mundo Espacio
('world_map', 1, '🗺️ El Mapa Espacial', 'Este es tu mapa espacial. Cada edificio es una actividad diferente donde puedes ganar monedas y aprender.'),
('world_map', 2, '🚀 Las Estaciones',   'Toca cualquier edificio para entrar. ¡Explora el Banco, los Trabajos y las Misiones!'),

-- Bolsa / Wallet
('wallet', 1, '🏠 Mi Bolsa',         'Aquí ves todas tus monedas divididas en categorías. ¡Cada categoría tiene un propósito especial!'),
('wallet', 2, '🪙 ¿Cómo distribuir?', 'Ahorro para el futuro, Inversión para crecer, Emergencia para imprevistos, Gastos para el día a día y Metas para tus sueños.'),

-- Banco Estelar
('banco_estelar', 1, '¡Bienvenido al Banco Estelar!', 'Aquí puedes depositar tus monedas de Ahorro e Inversión para que trabajen por ti mientras duermes.'),
('banco_estelar', 2, 'Tu inversión trabaja por ti',    'Las monedas de Inversión generan intereses con el tiempo. ¡Cuanto más tiempo las dejes, más crecen!'),
('banco_estelar', 3, 'Misiones financieras',            'El banco también tiene misiones especiales de ahorro. ¡Complétalas para ganar recompensas extra!'),

-- Trabajos
('trabajos_v2', 1, '¡Trabajos Espaciales! 🔨', 'Aquí puedes tomar trabajos y completarlos para ganar monedas. ¡Cada trabajo requiere materiales!'),
('trabajos_v2', 2, '¿Cómo funciona? 🤔',        'Acepta un trabajo, consigue los materiales en la Tienda y luego reclama tu recompensa. ¡Así de fácil!'),

-- Misiones
('misiones_v2', 1, '¡Misiones del Espacio! ⚔️', 'Las misiones son retos especiales con grandes recompensas. ¡Son más difíciles que los trabajos normales!'),
('misiones_v2', 2, 'Cómo completar una misión 🗺️', 'Lee bien los requisitos de cada misión. Algunas necesitan materiales, otras necesitan tiempo o XP.'),
('misiones_v2', 3, '¡Reclamar la recompensa! 🎁',  'Cuando completes una misión, toca "Reclamar" para obtener tus monedas y XP. ¡No olvides reclamarlas!'),

-- Tienda
('tienda_v2', 1, '¡La Tienda Espacial! 🔮', 'Aquí puedes comprar materiales que necesitas para completar trabajos y misiones. ¡Elige bien lo que compras!'),
('tienda_v2', 2, 'Guarda los materiales 🎒',  'Los materiales que compras se guardan en tu mochila. Puedes verlos en la sección "Mi inventario".'),

-- Mercado Galáctico
('mercado_v2', 1, '¡Mercado Galáctico! 🛒',  'Aquí tienes 3 secciones: ver lo que tienes, poner cosas a la venta, y explorar lo que venden otros jugadores.'),
('mercado_v2', 2, 'Tu Tienda Personal 🏪',    'Puedes poner hasta 10 artículos a la venta. Otros jugadores pueden comprártelos. ¡Pon un precio justo!'),
('mercado_v2', 3, 'Explorar el Mercado 🔍',   'Aquí ves lo que venden otros jugadores. Si encuentras algo que necesitas para un trabajo, ¡cómpralo aquí!'),

-- Preguntas
('preguntas', 1, '¡Hora de Preguntas! ❓', 'Responde preguntas de finanzas para ganar monedas. Cada respuesta correcta te da monedas y experiencia.'),
('preguntas', 2, 'Lee con calma 📖',        'Lee bien la pregunta antes de elegir. Después de responder verás la explicación correcta con Juan.'),

-- Mapa Bosque
('forest_map', 1, '¡Bienvenido al Bosque! 🌲', 'El Bosque Mágico es un mundo diferente con actividades especiales. ¡Explora todos sus edificios!'),
('forest_map', 2, 'Explora los edificios 🏠',   'Cada edificio del bosque tiene actividades únicas. ¡El Mercado y las Preguntas te esperan!'),
('forest_map', 3, 'Tus monedas 🪙',             'Las monedas que ganas aquí se suman a tu bolsa principal. ¡Todo cuenta para tu progreso!');
