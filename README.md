# Blinkids — Guía de Setup

> Juego educativo de finanzas personales para niños de 8–13 años.  
> Flutter 3.32 + Supabase · Orientación landscape · Mercado México 🇲🇽

---

## Requisitos previos

| Herramienta    | Versión mínima | Notas |
|----------------|---------------|-------|
| Flutter SDK    | 3.32+         | https://docs.flutter.dev/get-started/install/windows |
| Dart           | 3.0+          | incluido con Flutter |
| Android Studio | Ladybug+      | para compilar Android |
| Xcode          | 15+           | para compilar iOS (solo macOS) |
| Git            | cualquiera    | https://git-scm.com |

---

## Pasos para correr el proyecto

### 1. Verificar Flutter

```bash
flutter doctor
```
Android toolchain debe estar en verde.

### 2. Instalar dependencias

```bash
cd app
flutter pub get
```

### 3. Configurar credenciales de Supabase

Copia el archivo de ejemplo y rellena tus datos:

```bash
cp app/dart_defines/local.json.example app/dart_defines/local.json
```

Edita `app/dart_defines/local.json`:

```json
{
  "SUPABASE_URL": "https://TU_PROYECTO.supabase.co",
  "SUPABASE_ANON_KEY": "TU_ANON_KEY_AQUI"
}
```

> ⚠️ `local.json` está en `.gitignore` — nunca se sube al repositorio.

### 4. Configurar base de datos (Supabase)

En el **SQL Editor** de tu proyecto Supabase, ejecuta los archivos en orden:

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
supabase/migrations/010_parent_notifications.sql
supabase/migrations/011_unique_display_name.sql
supabase/migrations/012_tutorials_seen.sql
supabase/migrations/013_mark_tutorial_seen.sql
supabase/migrations/014_invite_codes.sql
supabase/migrations/015_child_sees_parent_profile.sql
supabase/migrations/016_demo_accounts.sql
```

### 5. Correr la app

```bash
cd app

# Debug en dispositivo conectado
flutter run --dart-define-from-file=dart_defines/local.json

# Compilar APK debug
flutter build apk --dart-define-from-file=dart_defines/local.json --debug

# Compilar APK release
flutter build apk --dart-define-from-file=dart_defines/local.json --release
```

---

## Estructura del proyecto

```
blinkids/
├── README.md
├── CHANGELOG.md
│
├── app/                              ← proyecto Flutter
│   ├── pubspec.yaml
│   ├── dart_defines/
│   │   └── local.json.example        ← plantilla de credenciales
│   └── lib/
│       ├── main.dart
│       ├── core/
│       │   ├── constants/            ← app_colors, app_sizes, app_strings
│       │   ├── router/               ← app_router, go_router_refresh_stream
│       │   ├── theme/                ← app_theme
│       │   └── utils/
│       ├── data/
│       │   ├── models/               ← profile, wallet, mission, question…
│       │   ├── repositories/         ← auth, profile, wallet, mission…
│       │   └── services/             ← supabase_service, analytics, push
│       ├── features/
│       │   ├── auth/
│       │   │   ├── splash_screen.dart
│       │   │   ├── adventurer_name_screen.dart
│       │   │   ├── demo_complete_screen.dart
│       │   │   ├── waiting_for_parent_screen.dart
│       │   │   ├── pin_setup_screen.dart
│       │   │   └── pin_entry_screen.dart
│       │   ├── tutorial/
│       │   │   └── tutorial_screen.dart
│       │   └── worlds/
│       │       ├── space/
│       │       │   ├── space_world_map.dart   ← mapa principal Bloque 1
│       │       │   └── banco_estelar_screen.dart
│       │       └── world_selector_screen.dart
│       └── shared/
│           ├── providers/
│           └── widgets/              ← blink_character, coin_display…
│
└── supabase/
    ├── migrations/                   ← 16 archivos SQL numerados
    └── functions/
        └── send-push/                ← Edge Function notificaciones push
```

---

## Flujo de la app (Bloque 1)

```
App abre
  └── SplashScreen (animación Blink + "Blinkids")
        ├── Sin sesión          → /adventurer-name
        ├── Demo, sin tutorial  → /tutorial
        ├── Demo, con tutorial  → /world  (SpaceWorldMap)
        └── Cuenta completa     → /enter-pin (o /setup-pin si no tiene)
```

### Registro de nuevo usuario (cuenta demo)

```
/adventurer-name  →  elige nombre de aventurero
                  →  crea sesión anónima Supabase
                  →  crea perfil con account_type='demo'
                  →  /tutorial
                  →  /world
```

---

## Rutas activas (Bloque 1)

| Ruta | Pantalla |
|------|----------|
| `/` | SplashScreen |
| `/adventurer-name` | AdventurerNameScreen |
| `/tutorial` | TutorialScreen |
| `/world` | SpaceWorldMap |
| `/space/banco_estelar` | BancoEstelarScreen |
| `/worlds` | WorldSelectorScreen |
| `/demo-end` | DemoCompleteScreen |
| `/waiting-parent` | WaitingForParentScreen |
| `/setup-pin` | PinSetupScreen |
| `/enter-pin` | PinEntryScreen |

Las rutas de Bloque 2+ (`/misiones`, `/trabajos`, `/mercado`, etc.) muestran una pantalla de "Próximamente".

---

## Estado del Bloque 1 — entregado

### ✅ Completado
- Splash nativo Android 12+ con Blink (sin círculo verde, sin recorte)
- Animación splash Flutter: Blink cae con rebote + letras "Blinkids" una a una
- Pantalla de nombre de aventurero con validación en tiempo real
- Autenticación anónima Supabase (sin login ni Google OAuth)
- Tutorial de 4 pasos con Blink grande + globo de texto animado
- **Mundo Espacio:** mapa con 6 edificios, HUD superior, panel de perfil
- Panel de perfil: avatar de Blink en círculo, nombre, nivel, estrellas XP, barra de progreso
- **Banco Estelar:** pantalla funcional dentro del Mundo Espacio
- Pantallas "Próximamente" para features de Bloque 2
- Demo completa → flujo de espera de vinculación con papá
- PIN de acceso para cuentas completas
- Base de datos: 16 migraciones SQL con RLS activado

### 🔲 Pendiente (Bloques siguientes)
- Módulo de Misiones
- Módulo de Trabajos / Crafting
- Módulo de Mercado (inventario + tienda + explorar)
- Panel de Padres
- Push notifications reales
- Biomas adicionales (Bosque, Océano, Desierto)

---

## Seguridad

- Nunca usar `service_role` key en Flutter — solo `anon` key
- `dart_defines/local.json` está en `.gitignore`
- RLS activado en todas las tablas de Supabase
- Cuentas anónimas no tienen acceso a datos de otros usuarios
