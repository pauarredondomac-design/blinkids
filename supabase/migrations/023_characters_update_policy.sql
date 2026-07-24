-- Permite al niño actualizar su propio personaje (XP, nivel, equipamiento).
-- Faltaba esta política — sin ella addXp() falla silenciosamente con 406.
create policy "Personaje propio — actualizar"
  on characters for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
