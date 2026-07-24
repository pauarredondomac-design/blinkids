-- Agrega fuel_reward como columna directa en jobs.
-- Reemplaza el workaround de guardar fuel_capsule en item_reward JSON.
alter table public.jobs
  add column if not exists fuel_reward integer not null default 0;

-- Migrar los trabajos espaciales que tenían fuel_capsule en item_reward
update public.jobs set
  fuel_reward  = 10,
  item_reward  = null
where item_reward->>'item_id' = 'fuel_capsule';
