# FinQuest — Guía de Setup

> Juego educativo de finanzas para niños de 8-13 años.
> Flutter + Flame + Supabase — mercado México 🇲🇽

---

## Requisitos previos

| Herramienta | Versión mínima | Link |
|---|---|---|
| Flutter SDK | 3.32+ | https://docs.flutter.dev/get-started/install/windows |
| Dart | 3.0+ | incluido con Flutter |
| Supabase CLI | cualquiera | https://supabase.com/docs/guides/cli |
| Android Studio | Ladybug+ | para Android |
| Xcode | 15+ | para iOS (solo macOS) |
| Git | cualquiera | https://git-scm.com |

---

## Pasos para correr el proyecto

### 1. Verificar Flutter

```bash
flutter doctor
```
Android toolchain y/o Xcode deben estar en verde.

### 2. Instalar dependencias

```bash
cd finquest/app
flutter pub get
```

### 3. Configurar Supabase

1. Crea un proyecto en https://supabase.com
2. Ve a **SQL Editor** y ejecuta los archivos en orden:

```
supabase/migrations/001_extensions_types.sql
supabase/migrations/002_core_tables.sql
supabase/migrations/003_world_tables.sql
supabase/migrations/004_character_items.sql
supabase/migrations/005_question_job_tables.sql
supabase/migrations/006_mission_market_tables.sql
supabase/migrations/007_tutorial_purchases.sql
supabase/migrations/008_rls_policies.sql
supabase/migrations/009_seed_data.sql
supabase/migrations/010_parent_notifications.sql   ← solicitudes de vinculación + notificaciones
```

3. Activa **Google Auth** en Supabase:
   - Authentication → Providers → Google
   - Agrega tu **Client ID** y **Client Secret** de Google Cloud Console
   - Agrega `finquest://callback` en "Redirect URLs"

4. Copia tus credenciales en `app/lib/core/constants/app_strings.dart`:

```dart
static const supabaseUrl    = 'https://TU_PROYECTO.supabase.co';
static const supabaseAnonKey = 'TU_ANON_KEY_AQUI';
```

> ⚠️ **Nunca uses la `service_role` key** en la app Flutter — bypasea RLS.

### 4. Configurar deep link OAuth

**Android** — `android/app/src/main/AndroidManifest.xml`:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="finquest" android:host="callback" />
</intent-filter>
```

**iOS** — `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array><string>finquest</string></array>
    </dict>
</array>
```

### 5. Agregar la fuente Nunito

Descarga desde [Google Fonts](https://fonts.google.com/specimen/Nunito) y agrégala en `app/assets/fonts/`:

```yaml
# pubspec.yaml → flutter → fonts:
fonts:
  - family: Nunito
    fonts:
      - asset: assets/fonts/Nunito-Regular.ttf
      - asset: assets/fonts/Nunito-Bold.ttf        weight: 700
      - asset: assets/fonts/Nunito-ExtraBold.ttf   weight: 800
      - asset: assets/fonts/Nunito-Black.ttf        weight: 900
```

### 6. Correr la app

```bash
flutter run                       # dispositivo conectado
flutter run -d chrome             # web (solo para debug)
```

---

## Estructura del proyecto

```
finquest/
├── CHANGELOG.md                  ← historial de cambios
├── README.md                     ← este archivo
│
├── app/                          ← proyecto Flutter
│   ├── pubspec.yaml
│   └── lib/
│       ├── main.dart
│       ├── core/
│       │   ├── constants/        ← app_colors, app_sizes, app_strings
│       │   ├── router/           ← app_router, go_router_refresh_stream
│       │   ├── theme/            ← app_theme
│       │   └── utils/            ← extensions
│       ├── data/
│       │   ├── models/           ← profile, wallet, character, mission,
│       │   │                        question, job, item, crafting_job,
│       │   │                        app_notification, world
│       │   ├── repositories/     ← auth, profile, wallet, character,
│       │   │                        mission, question, job, item,
│       │   │                        mission_tracker, parent, notification,
│       │   │                        world
│       │   └── services/         ← supabase_service
│       ├── features/
│       │   ├── auth/             ← splash, login, register_role, register_profile
│       │   ├── parent/           ← parent_home_screen, child_detail_screen
│       │   ├── tutorial/         ← tutorial_screen
│       │   ├── wallet/           ← wallet_screen
│       │   └── worlds/
│       │       ├── forest/       ← forest_world_map
│       │       ├── space/        ← space_world_map
│       │       ├── misiones/     ← misiones_screen
│       │       ├── preguntas/    ← preguntas_screen
│       │       ├── trabajos/     ← trabajos_screen + vendedor_frutas/
│       │       ├── mercado/      ← mercado_screen (inventario + tienda + explorar)
│       │       ├── tienda/       ← tienda_screen
│       │       └── widgets/      ← forest_buildings, space_buildings
│       └── shared/
│           ├── providers/        ← auth, profile, wallet, character, world,
│           │                        mission, question, job, item, parent
│           └── widgets/          ← screen_tutorial, fin_button, coin_display,
│                                    loading_overlay
│
├── supabase/
│   ├── migrations/               ← 10 archivos SQL numerados
│   └── functions/                ← Edge Functions (Fase 3)
│
└── admin/                        ← Next.js panel admin (Fase 5)
```

---

## Flujo de autenticación

```
App abre
  └── SplashScreen
        ├── No hay sesión  → /login
        ├── Sin perfil     → /register/role → /register/profile
        ├── Sin tutorial   → /tutorial
        ├── Rol padre      → /parent
        └── Rol hijo       → /world (ForestWorldMap)
```

---

## Rutas principales

| Ruta | Pantalla |
|---|---|
| `/` | SplashScreen |
| `/login` | LoginScreen |
| `/register/role` | RegisterRoleScreen |
| `/register/profile` | RegisterProfileScreen |
| `/tutorial` | TutorialScreen |
| `/world` | ForestWorldMap |
| `/world-space` | SpaceWorldMap |
| `/worlds` | WorldSelectorScreen |
| `/world/misiones` | MisionesScreen |
| `/world/preguntas` | PreguntasScreen |
| `/world/trabajos` | TrabajosScreen (crafting jobs) |
| `/world/mercado` | MercadoScreen (inventario + mi tienda + explorar) |
| `/world/tienda` | TiendaScreen |
| `/wallet` | WalletScreen |
| `/parent` | ParentHomeScreen |
| `/parent/child` | ChildDetailScreen |

---

## Sistema de economía del juego

### Ítems (12 total)
- **Bosque (6):** Tablón de Madera 🪵, Martillo 🔨, Hierba Mágica 🌿, Poción de Vida 🧪, Bellota 🌰, Gema del Bosque 💎 (solo misión)
- **Espacio (6):** Tornillo Espacial 🔩, Llave Inglesa 🔧, Batería ⚡, Cápsula de Combustible 💊, Circuito Lunar 🖥️, Cristal Estelar 🔮 (solo misión)

### Trabajos de Crafting (6 total)
- **Bosque:** Reparar Cabaña 🏚️, Curar al Zorro 🦊, Festín de la Ardilla 🐿️
- **Espacio:** Reparar Nave 🚀, Activar Estación ⚡, Arreglar Robot 🦾

### Mercado (3 tabs)
- 🎒 **Mi Inventario** — ítems comprados en la Tienda
- 🏪 **Mi Tienda** — vender ítems a otros jugadores (máx. 10 anuncios)
- 🔍 **Explorar** — comprar a otros jugadores

### Misiones con seguimiento automático
- Tipo `completeQuizzes` → se registra al responder preguntas correctas
- Tipo `completeJobs` → se registra al completar trabajos de crafting
- Tipo `buyFromShop` → se registra al comprar en la Tienda
- Botón **Reclamar** aparece cuando se alcanza el objetivo

---

## Panel de Padres

### Funcionalidades
- **Campana 🔔** — badge de notificaciones no leídas, panel deslizante lateral
- **Tarjetas de hijos** — nivel, XP, monedas, misiones con emoji de evolución (🐣→🦊→🦁→🐉)
- **Buscar hijo** — por apodo (display_name) o correo (vía RPC `search_child`)
- **Solicitud de vinculación** — padre envía → notificación al niño → niño acepta
- **Ver actividad** → `ChildDetailScreen`: historial de misiones, stats, barra XP
- **Enviar monedas** — el padre deduce de su wallet y acredita al hijo + notificación automática

### Tablas Supabase (migration 010)
- `link_requests` — solicitudes padre→hijo con estado `pending/accepted/rejected`
- `notifications` — notificaciones in-app por usuario
- Función RPC `search_child(p_query)` — búsqueda por apodo O correo con SECURITY DEFINER

---

## Reglas de seguridad (obligatorias)

- 🔒 Nunca usar `service_role` key en Flutter — solo `anon` key
- 🔒 Niños no pueden hacer compras reales — solo el padre
- 🔒 Todas las transacciones reales van por Edge Functions
- 🔒 La UI del niño solo muestra monedas virtuales, nunca dinero real
- 🔒 RLS activado en todas las tablas

---

## Estado actual del proyecto

### ✅ Completado
- Estructura Flutter completa (Flame, Riverpod, GoRouter, Supabase)
- Base de datos: 22+ tablas, RLS, seed data, 10 migraciones SQL
- Autenticación: Google OAuth + email/password
- Flujo de registro completo: rol → perfil → cartera → personaje → tutorial
- **Bioma Bosque:** mapa 2D, 6 edificios funcionales, HUD completo
- **Bioma Espacio:** mapa 2D, 6 estaciones, HUD cian
- **Sistema de mundos:** selector con compra de mundos (Espacio: 500 🪙)
- **Misiones** con seguimiento automático y recompensas
- **Preguntas** (quiz) con explicaciones y registro en Supabase
- **Trabajos de Crafting** con verificación de inventario y recompensas
- **Mercado** (inventario + mi tienda + explorar marketplace)
- **Tienda** filtrada por mundo con sistema de compra
- **Sistema de economía:** 12 ítems, 6 crafting jobs, mission tracker
- **Orientación landscape** forzada en todas las sub-pantallas de mundos
- **Panel de Padres** rediseñado: notificaciones, búsqueda de hijos, actividad, envío de monedas
- **Sistema XP:** barra de progreso, 4 etapas evolutivas de Juan

### 🔲 Pendiente (Fases futuras)
- Sincronizar mundos desbloqueados con Supabase (ahora solo en SharedPreferences)
- Push notifications reales (Firebase Cloud Messaging)
- Panel admin Next.js (Fase 5)
- Edge Functions para transacciones atómicas de dinero real (Fase 3)
- Biomas Océano y Desierto (bloqueados como "próximamente")
- Animación de subida de nivel para Juan
