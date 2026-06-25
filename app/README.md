# FinQuest — App Flutter

Proyecto Flutter del juego educativo de finanzas para niños.

> Para la guía completa de setup y arquitectura, ver [`../README.md`](../README.md)

---

## Comandos rápidos

```bash
# Instalar dependencias
flutter pub get

# Correr en dispositivo conectado
flutter run

# Correr en Chrome (debug web)
flutter run -d chrome

# Analizar errores y warnings
flutter analyze

# Limpiar caché de build
flutter clean && flutter pub get

# Build APK para Android
flutter build apk --release

# Build para iOS
flutter build ios --release
```

---

## Credenciales (configurar antes de correr)

Edita `lib/core/constants/app_strings.dart`:

```dart
static const supabaseUrl     = 'https://TU_PROYECTO.supabase.co';
static const supabaseAnonKey = 'TU_ANON_KEY';
```

⚠️ **Nunca** uses la `service_role` key aquí.

---

## Estructura rápida

```
lib/
├── main.dart
├── core/            ← constantes, tema, router, utils
├── data/
│   ├── models/      ← profile, wallet, character, mission, question,
│   │                   job, item, crafting_job, app_notification, world
│   ├── repositories/← auth, profile, wallet, character, mission,
│   │                   question, job, item, mission_tracker,
│   │                   parent, notification, world
│   └── services/    ← supabase_service
├── features/
│   ├── auth/        ← splash, login, register_role, register_profile
│   ├── parent/      ← parent_home, child_detail
│   ├── tutorial/    ← tutorial_screen
│   ├── wallet/      ← wallet_screen
│   └── worlds/
│       ├── forest/  ← forest_world_map
│       ├── space/   ← space_world_map
│       ├── misiones/
│       ├── preguntas/
│       ├── trabajos/   ← crafting jobs
│       ├── mercado/    ← inventario + mi tienda + explorar
│       └── tienda/
└── shared/
    ├── providers/   ← auth, profile, wallet, character, world,
    │                   mission, question, job, item, parent
    └── widgets/     ← screen_tutorial, fin_button, coin_display,
                        loading_overlay
```

---

## Providers clave

| Provider | Tipo | Qué devuelve |
|---|---|---|
| `currentUserProvider` | `Provider<User?>` | Usuario Supabase actual |
| `currentProfileProvider` | `FutureProvider<Profile?>` | Perfil del usuario |
| `currentWalletProvider` | `FutureProvider<Wallet?>` | Cartera (monedas + saldo real) |
| `currentCharacterProvider` | `FutureProvider<Character?>` | Juan: XP, nivel, evolución |
| `currentWorldProvider` | `StateProvider<String>` | ID del mundo actual (`forest`/`space`) |
| `activeMissionsProvider` | `FutureProvider<List<Mission>>` | Misiones del mundo actual |
| `linkedChildrenProvider` | `FutureProvider<List<Profile>>` | Hijos vinculados (solo padres) |
| `childStatsProvider(Profile)` | `FutureProvider.family<ChildStats, Profile>` | Stats del hijo para panel padre |
| `unreadCountProvider` | `FutureProvider<int>` | Notificaciones no leídas |
| `inventoryProvider` | `FutureProvider<List<InventoryStack>>` | Inventario del jugador |

---

## Ciclo de juego (hijo)

```
/world (ForestWorldMap)
  ├── Tienda      → comprar ítems con 🪙 → recordPurchase()
  ├── Trabajos    → consumir ítems → ganar 🪙+XP → recordJob()
  ├── Preguntas   → responder → ganar 🪙+XP → recordQuiz()
  ├── Misiones    → objetivo auto-tracked → Reclamar → ganar 🪙+XP+ítem
  ├── Mercado     → vender inventario / explorar listings de otros
  └── 🌐 Mundos  → desbloquear Espacio (500🪙)
```

---

## Panel de padres

```
/parent (ParentHomeScreen)
  ├── 🔔 Campana  → panel de notificaciones lateral
  ├── + Agregar hijo → buscar por apodo o correo → enviar solicitud
  └── Tarjeta hijo → Ver actividad → /parent/child (ChildDetailScreen)
                                      └── Enviar monedas → notificación al niño
```
