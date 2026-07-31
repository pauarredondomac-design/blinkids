# Backup de Supabase — 2026-07-30

Backup generado antes de continuar con más cambios, a petición del usuario.
Proyecto: `kids_game` (`mzwvazjofbdelsejxoqi`).

No se pudo usar `supabase db dump` (requiere Docker Desktop corriendo, no
disponible en esta máquina), así que el backup se armó por introspección
directa vía SQL:

- **`schema_2026-07-30.sql`** — las 43 tablas del esquema `public`: columnas,
  tipos, defaults, nullability, primary keys y foreign keys. No es un dump
  exacto tipo `pg_dump` (no incluye índices/triggers explícitos), pero cubre
  la estructura completa para reconstruir cualquier tabla si hiciera falta.
- **`policies_2026-07-30.sql`** — las 90 políticas RLS activas en `public`.
  Es solo referencia: ya existen en la base de datos actual, no ejecutar
  contra una base que ya las tiene.
- **`functions_2026-07-30.sql`** — las 58 funciones/RPCs (`CREATE OR REPLACE
  FUNCTION`) del esquema `public`, con su código completo.
- **`data_2026-07-30.json`** — los datos reales de las tablas con contenido
  (perfiles, wallets, ítems, preguntas, trabajos, insignias, etc.), incluyendo
  las cuentas de prueba existentes (Diego, Chencho, Diana, Superman).

## Qué NO se incluyó

- `crash_reports` (6845 filas) y `analytics_events` (352 filas): son solo
  logs técnicos/telemetría, no estado del juego. Se dejaron fuera por
  volumen — si algún día hace falta restaurarlos, siguen intactos en Supabase
  (este backup no los tocó ni los borró de la base real).
- Docker/`supabase db dump` no estaba disponible, así que no hay un dump
  binario tipo `pg_dump` — este backup es reconstruido por introspección.

## Cómo restaurar (si algo se rompe)

1. Ejecutar `schema_2026-07-30.sql` en un proyecto Supabase nuevo (o vacío).
2. Ejecutar `functions_2026-07-30.sql`.
3. Habilitar RLS en las tablas necesarias y ejecutar `policies_2026-07-30.sql`.
4. Insertar los datos de `data_2026-07-30.json` (por ejemplo con un script
   que recorra cada tabla y haga `insert into <tabla> select * from
   jsonb_populate_recordset(null::<tabla>, '<json>')`).

El código de la app en este mismo commit corresponde exactamente al estado
que usa este esquema (ver el resto del repo).
