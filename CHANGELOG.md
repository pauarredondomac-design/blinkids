# FinQuest — Registro de cambios

> Formato: `[fecha] — Descripción corta`
> Cada entrada incluye archivos afectados, qué se hizo y por qué.

---

## [2026-05-23] — Panel de Padres: rediseño completo + notificaciones + búsqueda de hijos

### Archivos creados
* `supabase/migrations/010_parent_notifications.sql` — Tablas `link_requests` (solicitudes padre↔hijo con estado `pending/accepted/rejected`) y `notifications` (in-app, con `is_read`). RLS policies. Función RPC `search_child(p_query)` con SECURITY DEFINER que busca por `display_name` e `email` en `auth.users`
* `app/lib/data/models/app_notification.dart` — Modelo `AppNotification` con `typeIcon` (emoji por tipo) y `timeAgo` (relativo)
* `app/lib/data/repositories/parent_repository.dart` — `ChildSearchResult`, `ChildStats` (con `stageProgress`, `evolutionEmoji`, `evolutionLabel`); `ParentRepository`: `searchChild()` (RPC + fallback display_name), `sendLinkRequest()` (upsert + notificación al niño), `acceptLinkRequest()` (vinculación + notificación al padre), `getLinkedChildren()`, `getChildStats()` (character + wallet + missions en paralelo)
* `app/lib/data/repositories/notification_repository.dart` — `getNotifications()`, `getUnreadCount()`, `markAllRead()`, `markRead()`, `createNotification()`
* `app/lib/shared/providers/parent_provider.dart` — `parentRepositoryProvider`, `notificationRepositoryProvider`, `linkedChildrenProvider`, `childStatsProvider` (FutureProvider.family<ChildStats, Profile>), `unreadCountProvider`, `notificationsListProvider`
* `app/lib/features/parent/screens/child_detail_screen.dart` — Pantalla de actividad del hijo:
  - Layout 2 columnas: panel izquierdo (emoji evolución 72px, etapa, nombre+nivel, barra XP a siguiente etapa, stats chips 🪙⭐🏆) + panel derecho (historial de misiones con fecha relativa y recompensas)
  - AppBar: emoji+nombre hijo + botón "Enviar monedas"
  - `_SendCoinsDialog`: chips de cantidad (10/25/50/100/200/500 🪙), descuenta al padre en Supabase, acredita al hijo, crea notificación automática

### Archivos modificados
* `app/lib/features/parent/screens/parent_home_screen.dart` — **Rediseño completo:**
  - Fondo oscuro con gradiente navy→purple + estrellas decorativas + orbe brillante
  - Top bar: avatar 👨‍👩‍👧, saludo con nombre, 🔔 campana con badge rojo (count), botón salir
  - Panel izquierdo (240px): cartera (saldo real + monedas con chips de color), card "Enviar Monedas" informativa, consejo del día
  - Panel derecho: lista de hijos con `_ChildCardFull` (emoji evolución, barra XP, nivel badge, chips 🪙🏆⭐, botón "Ver actividad")
  - Estado vacío animado con call-to-action
  - `_NotifOverlay`: panel deslizante desde la derecha (SlideTransition + FadeTransition), lista de `_NotifTile` con punto rosa para no leídas, marca todas como leídas al abrirlo
  - `_AddChildDialog`: búsqueda por texto → `searchChild()` → resultados con `_RequestButton` (estados: botón activo / "⏳ Pendiente" / "✅ Vinculado")
* `app/lib/core/router/app_router.dart` — Nueva ruta `/parent/child` → `ChildDetailScreen(child: extra as Profile)`

### Qué se hizo
Rediseño visual completo del panel de padres con glassmorphism oscuro (tema navy/purple). Sistema completo de vinculación padre-hijo: el padre busca al niño por apodo o correo, envía solicitud → el niño recibe notificación in-app → acepta → el padre puede ver stats y actividad del hijo en tiempo real. Campana de notificaciones con badge contador y panel lateral animado.

### Por qué se hizo
El usuario pidió: UI más bonita, ver registros del hijo, buscar hijo por apodo/correo, enviar mensaje al niño para que acepte, y campana de notificaciones.

---

## [2026-05-23] — Orientación landscape forzada en las 5 sub-pantallas de mundos

### Archivos modificados
* `app/lib/features/worlds/tienda/tienda_screen.dart` — `import 'package:flutter/services.dart'` + `initState`/`dispose` con `SystemChrome.setPreferredOrientations`
* `app/lib/features/worlds/mercado/mercado_screen.dart` — Idem; se inyecta en el `initState`/`dispose` existente del `TabController`
* `app/lib/features/worlds/preguntas/preguntas_screen.dart` — Idem + `initState`/`dispose` nuevos

(Misiones y Trabajos ya tenían la corrección aplicada en la sesión anterior)

### Qué se hizo
Las 5 sub-pantallas de edificios ahora re-fuerzan la orientación landscape en `initState` y la liberan en `dispose`. Esto corrige el problema donde `context.go()` hacia un sub-screen destruía el WorldMap y su `dispose()` reseteaba la orientación a todos los ángulos.

### Por qué se hizo
El usuario reportó que algunas pantallas se veían desajustadas en landscape. El root cause era que `context.go()` reemplaza el stack de rutas, disparando `dispose()` del WorldMap que restauraba `DeviceOrientation.values`.

---

## [2026-05-23] — Sistema de economía: ítems, crafting jobs, marketplace, mission tracker

### Archivos creados
* `app/lib/data/models/item.dart` — 12 ítems (6 bosque + 6 espacio); modelos `Item`, `InventoryStack`, `ItemRequirement`, `ItemReward`, `PlayerListing`; helpers `itemById()`, `itemsForWorld()`, `shopItemsForWorld()`
* `app/lib/data/models/crafting_job.dart` — 6 trabajos de crafting (3 bosque + 3 espacio); modelo `CraftingJob` con requirements, rewards; helper `craftingJobsForWorld()`
* `app/lib/data/repositories/item_repository.dart` — Inventario en SharedPreferences (`inv_<itemId>`): `countOf()`, `getInventory()`, `addToInventory()`, `removeFromInventory()`, `hasRequirements()`, `consumeRequirements()`. Player shop (máx. 10): `getMyListings()`, `addListing()`, `removeListing()`. `getSampleMarketListings(worldId)` para el Explorar tab
* `app/lib/data/repositories/mission_tracker.dart` — Seguimiento local (SharedPreferences) de progreso de misiones: `recordQuiz()`, `recordJob()`, `recordPurchase()`, `progressFor()`, `allProgress()`, `isClaimed()`, `markClaimed()`
* `app/lib/shared/providers/item_provider.dart` — `itemRepositoryProvider`, `inventoryProvider`, `myListingsProvider`

### Archivos reescritos
* `app/lib/features/worlds/trabajos/trabajos_screen.dart` — Reemplaza "Vendedor de Frutas" con trabajos de crafting:
  - Layout de tarjeta 2 columnas landscape: IZQUIERDA (NPC emoji+nombre+historia+reward chips) / DERECHA (materiales requeridos con ✅/❌ + botón)
  - `_doJob()`: verifica inventario → diálogo confirmación → consume materiales → otorga monedas+XP+ítem → `recordJob()` → recarga inventario
  - `_ConfirmJobDialog` y `_RewardDialog` con animación de celebración
  - Landscape enforcement (initState/dispose)
* `app/lib/features/worlds/misiones/misiones_screen.dart` — Reemplaza joinMission con sistema de objetivos:
  - Layout tarjeta 2 columnas landscape: IZQUIERDA (icon objetivo+nombre+historia+reward pills) / DERECHA (contador progreso + LinearProgressIndicator + botón Reclamar)
  - `_loadProgress()` / `_handleClaim()`: markClaimed → awardCoins → awardXp → addToInventory (ítem reward) → invalidate providers
  - `_claiming` bool para estado de carga del botón
  - Landscape enforcement (initState/dispose)
* `app/lib/features/worlds/mercado/mercado_screen.dart` — 3 tabs completos:
  - 🎒 Mi Inventario: GridView del inventario actual con badge de cantidad
  - 🏪 Mi Tienda: listado de anuncios + `_AddListingDialog` (dropdown ítem + steppers qty/precio)
  - 🔍 Explorar: listings de otros jugadores, compra con `spendCoins` + `addToInventory`
  - Landscape enforcement (initState/dispose)
* `app/lib/features/worlds/tienda/tienda_screen.dart` — Filtrado por mundo `shopItemsForWorld(worldId)`, compra con `spendCoins` → `addToInventory` → `recordPurchase` → `_BuyDialog` con balance antes/después
* `app/lib/features/worlds/preguntas/preguntas_screen.dart` — `_handleAnswer()` incluye `MissionTracker().recordQuiz()` al responder correctamente
* `app/lib/data/models/mission.dart` — Nuevos campos: `objectiveType` (enum `MissionObjectiveType`), `objectiveTarget` (int), `itemReward` (ItemReward?); getter `hasObjective`; `fromJson()` parsea `objective_type`, `objective_target`, `item_reward_id`, `item_reward_qty`
* `app/lib/data/repositories/mission_repository.dart` — Fallback missions world-aware: `_forestMissions()` y `_spaceMissions()` con 3 misiones cada una (quiz/jobs/shop)
* `app/lib/shared/providers/mission_provider.dart` — `activeMissionsProvider` ahora observa `currentWorldProvider` para auto-refreshear al cambiar de mundo

### Qué se hizo
Sistema de economía completo. El ciclo de juego funciona de extremo a extremo: Tienda (comprar ítems) → Inventario → Trabajos (consumir ítems, ganar monedas) → Misiones (objetivos automáticos con seguimiento local) → Mercado (vender y explorar). Todos los intercambios registran eventos de seguimiento para las misiones.

### Por qué se hizo
El usuario tenía stubs sin funcionalidad real. Se implementó el sistema económico completo con ítems, crafting, marketplace y mission tracking.

---

## [2026-05-22] — Sistema de mundos: selector, desbloqueo y progresión

### Archivos creados / modificados
* `app/lib/data/models/world.dart` — Modelo `World` (id, name, emoji, route, unlockCost, description, accentColor, comingSoon); constante global `allWorlds` con 4 biomas: Bosque (gratis), Espacio (500🪙), Océano (1500🪙, próximamente), Desierto (3000🪙, próximamente)
* `app/lib/data/repositories/world_repository.dart` — Persiste mundos desbloqueados en SharedPreferences; 'forest' siempre incluido; métodos: `getUnlockedWorldIds()`, `unlockWorld(id)`, `isUnlocked(id, list)`
* `app/lib/data/repositories/wallet_repository.dart` — Nuevo método `spendCoins(userId, amount) → bool`: lee saldo actual, verifica suficiencia, descuenta; retorna false si no alcanza
* `app/lib/shared/providers/world_provider.dart` — `worldRepositoryProvider` + `unlockedWorldsProvider (FutureProvider<List<String>>)`
* `app/lib/features/worlds/world_selector_screen.dart` — Pantalla de selección con fondo galáctico:
  - 4 tarjetas en fila (landscape): emoji, nombre, descripción, estado y botón de acción
  - Bosque: siempre desbloqueado → botón "✅ Estás aquí" o "🚀 Entrar"
  - Espacio: bloqueado → botón "🔓 500 🪙" (ámbar si puede pagar) o "🔒 500 🪙" (gris si no)
  - Océano/Desierto: "🔒 Próximamente"
  - Flujo de compra: dialog confirmación → `spendCoins` → `unlockWorld` → invalidate providers → snackbar
  - Tarjeta del mundo actual con borde blanco, glow y badge "📍 AQUÍ"
* `app/lib/features/worlds/forest/forest_world_map.dart` — Botón "🌐 Mundos" en HUD; navega a `/worlds` con `extra: 'forest'` (push, permite volver)
* `app/lib/features/worlds/space/space_world_map.dart` — Botón "🌐 Mundos" con `extra: 'space'`
* `app/lib/core/router/app_router.dart` — Nueva ruta `/worlds` → `WorldSelectorScreen(currentWorldId: extra ?? 'forest')`

### Qué se hizo
El jugador puede cambiar de mundo desde cualquier mapa. Empieza con el Bosque desbloqueado; puede desbloquear el Espacio con 500🪙 de forma permanente.

### Por qué se hizo
El usuario preguntó cómo cambiar entre mapas y quería progresión donde el segundo mundo se compra con monedas del juego.

---

## [2026-05-22] — SpaceWorldMap: mapa del mundo Espacio con HUD cian

### Archivos creados / modificados
* `app/lib/features/worlds/space/space_world_map.dart` — Mapa interactivo bioma Espacio:
  - Fondo: `space_background.png` (2816 × 1536 px) con BoxFit.cover
  - 6 estaciones espaciales posicionadas sobre el fondo
  - HUD idéntico al bosque con acento cian
  - `ScreenTutorial` de 2 pasos al primer ingreso
* `app/lib/core/router/app_router.dart` — Ruta `/world-space` → `SpaceWorldMap()` (antes: WorldMapScreen CustomPainter)

### Qué se hizo
El bioma Espacio tiene su propio mapa visual con estética galáctica (fondo negro, acentos cian, estaciones espaciales).

---

## [2026-05-22] — Fase 2D: HUD completo + sistema XP conectado a todas las pantallas

### Archivos modificados
* `app/lib/shared/providers/character_provider.dart` — Helper global `awardXp(ref, amount)`
* `app/lib/features/worlds/forest/forest_world_map.dart` — HUD rediseñado: emoji evolutivo de Juan + nombre + badge nivel + barra XP + label XP actual/siguiente umbral
* `app/lib/features/worlds/misiones/misiones_screen.dart` — `_handleJoin()` otorga monedas y XP en paralelo
* `app/lib/features/worlds/preguntas/preguntas_screen.dart` — `_handleAnswer()` otorga monedas y XP en paralelo
* `app/lib/features/worlds/trabajos/vendedor_frutas/vendedor_frutas_screen.dart` — `_finish()` otorga monedas + XP + recordCompletion en paralelo

### Qué se hizo
El mapa Bosque muestra el HUD completo con avatar de Juan evolucionado, nivel y barra de XP en tiempo real. Cada acción de juego otorga XP.

---

## [2026-05-22] — Fase 2C: Trabajos + Vendedor de Frutas + Mercado + Tienda

### Archivos creados / modificados
* `app/lib/data/models/job.dart` — Modelos Job y JobLevel
* `app/lib/data/repositories/job_repository.dart` — getActiveJobs, recordCompletion; fallback local
* `app/lib/shared/providers/job_provider.dart` — activeJobsProvider
* `app/lib/features/worlds/trabajos/trabajos_screen.dart` — Lista de trabajos con ScreenTutorial
* `app/lib/features/worlds/trabajos/vendedor_frutas/vendedor_frutas_screen.dart` — Mini-juego completo: 3 columnas (cliente/contador/denominaciones), 6 denominaciones tocables, timer countdown, 3 niveles de dificultad, victoria/derrota con recompensas
* `app/lib/features/worlds/mercado/mercado_screen.dart` — Mercado con 8 artículos en 3 categorías, grid 2 columnas, compra con deducción de monedas
* `app/lib/features/worlds/tienda/tienda_screen.dart` — Tienda cosméticos: 10 artículos, items raros con borde dorado, vista previa de Juan, inventario en SharedPreferences
* `app/lib/core/router/app_router.dart` — Rutas: /world/trabajos, /world/trabajos/vendedor-frutas, /world/mercado, /world/tienda

### Qué se hizo
Ciclo económico completo del bioma Bosque. El jugador puede ganar monedas (Trabajos/Misiones/Preguntas) → gastarlas (Mercado/Tienda).

---

## [2026-05-22] — Fase 2B: HUD del mapa + Misiones + Preguntas (quiz)

### Archivos creados / modificados
* `app/lib/data/models/mission.dart` — Modelo Mission con MissionStatus, progressRatio, fromJson
* `app/lib/data/models/question.dart` — Modelos Question, QuestionOption, QuestionType
* `app/lib/data/repositories/mission_repository.dart` — getActiveMissions, joinMission, hasJoined; 3 misiones locales de fallback
* `app/lib/data/repositories/question_repository.dart` — getQuestionsForWorld, recordAnswer; 5 preguntas locales de fallback
* `app/lib/shared/providers/mission_provider.dart` — activeMissionsProvider
* `app/lib/shared/providers/question_provider.dart` — forestQuestionsProvider
* `app/lib/features/worlds/forest/forest_world_map.dart` — Convertido a ConsumerStatefulWidget; HUD con chip nombre+monedas; ScreenTutorial 3 pasos; rutas Misiones+Preguntas conectadas
* `app/lib/features/worlds/misiones/misiones_screen.dart` — Lista animada de misiones, botón unirme, dialog recompensa, ScreenTutorial
* `app/lib/features/worlds/preguntas/preguntas_screen.dart` — Quiz completo: Juan animado con burbuja de diálogo, opciones con colores post-respuesta, explicación, resumen final con medalla

### Qué se hizo
Implementación completa de Misiones y Preguntas. El mapa muestra nombre y monedas en tiempo real.

---

## [2026-05-22] — Mapa del Bosque 2D con assets PNG + animaciones flotantes

### Archivos modificados
* `app/pubspec.yaml` — Registrado `assets/images/worlds/forest/`
* `app/lib/features/worlds/forest/forest_world_map.dart` — Fondo PNG, 6 edificios con posicionamiento relativo, animación flotante por AnimationController, entrada escalonada con flutter_animate, landscape forzado

### Qué se hizo
El mapa Bosque usa sprites 2D reales con edificios flotantes.

---

## [2026-05-22] — Fixes de compilación + setup de Flutter + configuración nativa

### Archivos modificados
* `app/lib/core/router/app_router.dart` — Import `flutter/material.dart` faltante
* `app/lib/core/theme/app_theme.dart` — `CardTheme` → `CardThemeData` (breaking change Flutter 3.32)
* `app/lib/main.dart` — Agregado `flutter_localizations` para es_MX
* `app/pubspec.yaml` — Agregado `flutter_localizations` SDK package
* `app/android/app/src/main/AndroidManifest.xml` — Restaurado intent-filter LAUNCHER, `screenOrientation="sensorLandscape"`
* `app/ios/Runner/Info.plist` — Orientaciones restringidas a landscape
* `app/lib/core/constants/app_strings.dart` — URL de Supabase corregida, anon key configurada

### Qué se hizo
Setup completo del entorno. La app corre en Chrome mostrando el login screen.

---

## [2026-05-22] — Fase 1: Estructura base del proyecto Flutter + Supabase

### Archivos creados
* `app/pubspec.yaml` — Flame 1.18, Riverpod 2.5, GoRouter 14, Supabase 2.5, flutter_animate
* `app/lib/main.dart` — Inicializa Supabase, bloquea landscape, arranca ProviderScope
* `app/lib/core/constants/` — app_colors, app_sizes, app_strings
* `app/lib/core/theme/app_theme.dart` — Tema Material 3 con Nunito
* `app/lib/core/router/app_router.dart` — GoRouter con redirect auth + refreshListenable
* `app/lib/data/models/` — profile, wallet, character
* `app/lib/data/repositories/` — auth, profile, wallet, character
* `app/lib/shared/providers/` — auth, profile, wallet, character
* `app/lib/shared/widgets/` — fin_button, coin_display, loading_overlay
* `app/lib/features/auth/` — splash, login, register_role, register_profile
* `app/lib/features/tutorial/` — tutorial_screen (4 pasos, no saltable)
* `app/lib/features/parent/` — parent_home_screen (placeholder)
* `supabase/migrations/001-009` — 22 tablas, RLS, seed data

### Qué se hizo
Fase 1 completa: estructura Flutter, BD con RLS, autenticación Google OAuth + email, flujo de registro completo (rol → perfil → cartera → personaje → tutorial), rutas protegidas.
