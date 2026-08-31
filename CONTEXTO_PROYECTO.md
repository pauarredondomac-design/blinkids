# Blinkids — contexto técnico para futuras tareas

Última revisión: 2026-08-27

Este archivo es una guía interna basada en el código actual, no únicamente en el README histórico.

## Qué es

Blinkids es un videojuego educativo de finanzas personales para niñas y niños de aproximadamente 8–13 años. La app usa una metáfora de exploración espacial/biomas para enseñar ahorro, gasto, metas, recompensas y toma de decisiones mediante preguntas, trabajos, misiones y una cartera virtual.

Stack principal:

- Flutter/Dart; orientación landscape e interfaz inmersiva.
- Riverpod para estado y GoRouter para navegación.
- Supabase para autenticación, base de datos, RLS, realtime y Edge Functions.
- Flame está declarado como dependencia para experiencias 2D, aunque la navegación y la mayoría de pantallas actuales son widgets Flutter.
- OneSignal para push, `just_audio` para música/SFX y `video_player` para la animación del cohete.
- Fuentes visuales: Baloo2 y Nunito; idioma principal `es-MX`.

## Ubicación y ejecución

El proyecto de aplicación está en `blinkids/app`. La raíz funcional del producto es `blinkids/`; `Documentacion/` contiene entregables, APKs, documentos, hojas de cálculo y assets históricos.

Desde `blinkids/app`:

```bash
flutter pub get
flutter run --dart-define-from-file=dart_defines/local.json
flutter build apk --dart-define-from-file=dart_defines/local.json --debug
flutter build apk --dart-define-from-file=dart_defines/local.json --release
```

`dart_defines/local.json` debe contener `SUPABASE_URL` y `SUPABASE_ANON_KEY`; es local y no debe versionarse. El cliente de Flutter usa únicamente la clave anónima.

## Arranque y navegación

`lib/main.dart` inicializa errores, orientación, UI inmersiva, Supabase con `MonitoredHttpClient`, caché de imágenes, música, analytics y push. Si Supabase tarda o no hay red, la app intenta continuar para permitir el modo demo.

El router está en `lib/core/router/app_router.dart`. Rutas actuales relevantes:

| Ruta | Pantalla/flujo |
|---|---|
| `/` | Splash y decisión inicial |
| `/welcome` | Entrada/selección de rol |
| `/child-signup`, `/child-login` | Registro e inicio de sesión del niño |
| `/parent-auth`, `/parent` | Autenticación y panel de padres |
| `/redeem-code` | Vinculación por código |
| `/world` | Mapa principal del mundo Espacio |
| `/space/banco_estelar` | Banco Estelar |
| `/space/trabajos` | Trabajos; protegido por etapa demo |
| `/space/misiones` | Misiones; protegido por etapa demo |
| `/space/tienda` | Tienda; protegido por etapa demo |
| `/worlds`, `/world/forest` | Selector y mundo Bosque |
| `/mi-nave`, `/mi-nave/vestidor`, `/mi-nave/inventario` | Hub, cosméticos e inventario |
| `/wallet` | Actualmente pantalla de “próximamente” |

El router deja accesibles algunas rutas de juego incluso sin sesión porque el modo demo se mantiene en memoria. `currentRealUserProvider` devuelve `null` para usuarios anónimos, evitando consultas reales a Supabase desde providers de datos del jugador.

## Arquitectura de código

- `lib/core`: colores, tamaños, strings, tema, utilidades y router.
- `lib/data/models`: modelos serializables de perfil, cartera, personaje, mundos, preguntas, trabajos, misiones, ítems, cosméticos, combustible, metas, badges, notificaciones y salarios.
- `lib/data/repositories`: toda la interacción con Supabase; conviene modificar aquí la persistencia antes que hacer consultas directas desde widgets.
- `lib/data/services`: Supabase, analytics, crash reporting y push.
- `lib/shared/providers`: providers Riverpod que exponen repositorios y estado asíncrono/global.
- `lib/shared/widgets`: componentes reutilizables de HUD, Blink, diálogos, modales, cartera, combustible, badges y overlays.
- `lib/features`: pantallas agrupadas por auth, parent, wallet, cosmetics, hangar y mundos.

Patrón habitual: pantalla → provider Riverpod → repository → Supabase. Para cambios que deban funcionar en demo y cuenta real, revisar siempre `demoProgressProvider` y `currentRealUserProvider`.

## Flujos de usuario

### Demo

La entrada lleva a una sesión anónima o estado demo, crea/usa el progreso local en `demo_progress_provider.dart` y guía por etapas. Monedas, progreso, desbloqueos y algunos rewards pueden vivir en memoria; no asumir que el estado demo es persistente.

### Niño con cuenta

Puede registrarse/iniciar sesión con email/contraseña, Google o mecanismos de PIN según el flujo. El perfil, cartera, personaje, inventario, preguntas contestadas, trabajos, misiones, cosméticos, metas, combustible y badges se almacenan en Supabase.

### Padre

El panel permite consultar hijos vinculados, estadísticas, resumen semanal, actividad, notificaciones, salarios/allowance, solicitudes de vinculación y misiones asignadas al niño. La vinculación usa solicitudes, códigos de invitación y relaciones `parent_child`.

## Dominio persistido en Supabase

Las migraciones están en `supabase/migrations` y deben aplicarse en orden numérico. La base cubre:

- perfiles, relación padre-hijo, carteras, categorías y transacciones;
- mundos, edificios y progreso/desbloqueos;
- personajes, catálogo de ítems, inventario y equipamiento;
- preguntas, respuestas, trabajos, completions y crafting;
- misiones, participantes, misiones padre-hijo y mercado/listados;
- tutoriales, compras reales, diálogos de Blink, badges y notificaciones;
- PIN/autenticación infantil, códigos de invitación, combustible, salario y cosméticos.

Las migraciones más nuevas llegan hasta `030_parent_missions.sql`. Las políticas RLS comenzaron en `008_rls_policies.sql` y luego se ampliaron; cualquier tabla nueva debe recibir RLS y políticas explícitas. La Edge Function `supabase/functions/send-push/index.ts` lee plantillas/cooldowns y llama la API REST de OneSignal; requiere los secrets `ONESIGNAL_APP_ID` y `ONESIGNAL_REST_API_KEY`.

## Estado observado

El README principal describe un estado de Bloque 1 más antiguo que el código actual. En el código ya existen pantallas y repositories para padre, misiones, trabajos, crafting, preguntas, tienda, cosméticos, inventario, combustible, metas y Bosque. Sin embargo, algunas rutas siguen mostrando “próximamente” o están deliberadamente restringidas por etapas de demo; verificar la ruta concreta antes de considerar una funcionalidad completamente habilitada.

En la revisión había cambios locales sin commit, que deben tratarse como trabajo del usuario:

- modificación de `app/lib/core/router/app_router.dart`;
- modificación de `app/lib/shared/widgets/world_side_panels.dart`;
- assets y código nuevos para `mi-nave`, vestidor e inventario;
- carpeta local `app/.claude/`.

No sobrescribir esos cambios sin inspeccionarlos primero.

## Puntos de atención para futuras modificaciones

1. Mantener el doble comportamiento demo/real. No convertir accidentalmente una pantalla demo en una consulta Supabase ni mezclar monedas locales con cartera real.
2. Tras cambiar modelos o repositories, revisar el nombre exacto de columnas y la migración correspondiente; la base ha evolucionado mediante muchas migraciones incrementales.
3. Mantener RLS: las operaciones padre-hijo dependen de políticas y de la relación aceptada, no solo de filtros en Flutter.
4. Los rewards (monedas, XP, ítems, combustible y badges) suelen invalidar/refrescar varios providers; revisar providers relacionados después de completar una acción.
5. La UI está diseñada para landscape y usa muchos assets; verificar overflow, caché, escalado y navegación de regreso.
6. `main.dart` fija analytics en `1.0.0+7`, mientras `pubspec.yaml` indica `1.0.0+11`; sincronizarlo si se trabaja en versionado/telemetría.
7. Hay referencias históricas en README y documentación que pueden no representar las rutas actuales; tomar el router y el árbol de `lib/` como fuente primaria.

## Verificaciones útiles

```bash
cd blinkids/app
flutter pub get
flutter analyze
flutter test
```

En esta revisión `flutter analyze --no-pub` no entregó salida dentro del tiempo disponible; no se debe interpretar como una ejecución exitosa.

