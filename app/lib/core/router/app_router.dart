import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'go_router_refresh_stream.dart';

// ── Pantallas activas en Bloque 1 ────────────────────────────────────────────
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/adventurer_name_screen.dart';
import '../../features/auth/screens/demo_complete_screen.dart';
import '../../features/auth/screens/waiting_for_parent_screen.dart';
import '../../features/auth/screens/pin_setup_screen.dart';
import '../../features/auth/screens/pin_entry_screen.dart';
import '../../features/tutorial/screens/tutorial_screen.dart';
import '../../features/worlds/space/space_world_map.dart';
import '../../features/worlds/space/banco_estelar_screen.dart';
import '../../features/worlds/world_selector_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: false,
    refreshListenable: GoRouterRefreshStream(
      Supabase.instance.client.auth.onAuthStateChange,
    ),
    redirect: (context, state) {
      final user = Supabase.instance.client.auth.currentUser;
      final loc  = state.matchedLocation;

      // El splash maneja su propia navegación — nunca redirigir desde ahí
      if (loc == '/') return null;

      // Rutas siempre públicas (sin sesión)
      const publicRoutes = ['/adventurer-name'];
      if (publicRoutes.contains(loc)) {
        // Solo redirigir si hay sesión NO anónima (perfil ya creado)
        if (user != null && user.isAnonymous == false) return '/';
        return null;
      }

      // Sin sesión → pantalla de nombre de aventurero
      if (user == null) return '/adventurer-name';

      return null;
    },
    routes: [
      // ── Splash (decide a dónde ir según estado) ──────────────────────────
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (_, __) => const SplashScreen(),
      ),

      // ── Flujo nuevo: nombre → demo → esperar papá ────────────────────────
      GoRoute(
        path: '/adventurer-name',
        name: 'adventurer-name',
        builder: (_, __) => const AdventurerNameScreen(),
      ),
      GoRoute(
        path: '/demo-end',
        name: 'demo-end',
        builder: (_, __) => const DemoCompleteScreen(),
      ),
      GoRoute(
        path: '/waiting-parent',
        name: 'waiting-parent',
        builder: (_, __) => const WaitingForParentScreen(),
      ),

      // ── PIN (cuenta completa ligada por papá) ────────────────────────────
      GoRoute(
        path: '/setup-pin',
        name: 'setup-pin',
        builder: (_, __) => const PinSetupScreen(),
      ),
      GoRoute(
        path: '/enter-pin',
        name: 'enter-pin',
        builder: (_, __) => const PinEntryScreen(),
      ),

      // ── Tutorial ─────────────────────────────────────────────────────────
      GoRoute(
        path: '/tutorial',
        name: 'tutorial',
        builder: (_, __) => const TutorialScreen(),
      ),

      // ── Mundo Espacio (Bloque 1) ──────────────────────────────────────────
      GoRoute(
        path: '/world',
        name: 'world',
        builder: (_, __) => const SpaceWorldMap(),
      ),

      // ── Banco Estelar (Bloque 1) ──────────────────────────────────────────
      GoRoute(
        path: '/space/banco_estelar',
        name: 'space-banco-estelar',
        builder: (_, __) => const BancoEstelarScreen(),
      ),

      // ── Selector de mundos ────────────────────────────────────────────────
      GoRoute(
        path: '/worlds',
        name: 'worlds',
        builder: (_, state) => WorldSelectorScreen(
          currentWorldId: state.extra as String? ?? 'space',
        ),
      ),

      // ── Bloque 2 — Próximamente ───────────────────────────────────────────
      GoRoute(
        path: '/space/misiones',
        name: 'space-misiones',
        builder: (_, __) => const _ProximamenteScreen(titulo: 'Misiones', bloque: '2'),
      ),
      GoRoute(
        path: '/space/bolsa',
        name: 'space-bolsa',
        builder: (_, __) => const _ProximamenteScreen(titulo: 'Mi Bolsa', bloque: '2'),
      ),
      GoRoute(
        path: '/space/trabajos',
        name: 'space-trabajos',
        builder: (_, __) => const _ProximamenteScreen(titulo: 'Trabajos', bloque: '2'),
      ),
      GoRoute(
        path: '/space/mercado',
        name: 'space-mercado',
        builder: (_, __) => const _ProximamenteScreen(titulo: 'Mercado', bloque: '2'),
      ),
      GoRoute(
        path: '/space/tienda',
        name: 'space-tienda',
        builder: (_, __) => const _ProximamenteScreen(titulo: 'Tienda', bloque: '2'),
      ),
      GoRoute(
        path: '/world/misiones',
        name: 'misiones',
        builder: (_, __) => const _ProximamenteScreen(titulo: 'Misiones', bloque: '2'),
      ),
      GoRoute(
        path: '/world/trabajos',
        name: 'trabajos',
        builder: (_, __) => const _ProximamenteScreen(titulo: 'Trabajos', bloque: '2'),
      ),
      GoRoute(
        path: '/world/trabajos/vendedor-frutas',
        name: 'vendedor-frutas',
        builder: (_, __) => const _ProximamenteScreen(titulo: 'Trabajos', bloque: '2'),
      ),
      GoRoute(
        path: '/world/mercado',
        name: 'mercado',
        builder: (_, __) => const _ProximamenteScreen(titulo: 'Mercado', bloque: '2'),
      ),
      GoRoute(
        path: '/world/tienda',
        name: 'tienda',
        builder: (_, __) => const _ProximamenteScreen(titulo: 'Tienda', bloque: '2'),
      ),
      GoRoute(
        path: '/wallet',
        name: 'wallet',
        builder: (_, __) => const _ProximamenteScreen(titulo: 'Mi Bolsa', bloque: '2'),
      ),
      GoRoute(
        path: '/parent',
        name: 'parent',
        builder: (_, __) => const _ProximamenteScreen(titulo: 'Panel de Padres', bloque: '2'),
      ),
      GoRoute(
        path: '/parent/child',
        name: 'child-detail',
        builder: (_, __) => const _ProximamenteScreen(titulo: 'Panel de Padres', bloque: '2'),
      ),
      GoRoute(
        path: '/world-forest',
        name: 'world-forest',
        builder: (_, __) => const _ProximamenteScreen(titulo: 'Mundo Bosque', bloque: '2'),
      ),

      // ── Bloque 3 — Próximamente ───────────────────────────────────────────
      GoRoute(
        path: '/cosmetics',
        name: 'cosmetics',
        builder: (_, __) => const _ProximamenteScreen(titulo: 'Cosméticos', bloque: '3'),
      ),
      GoRoute(
        path: '/hangar',
        name: 'hangar',
        builder: (_, __) => const _ProximamenteScreen(titulo: 'Hangar', bloque: '3'),
      ),
    ],
    errorBuilder: (_, state) => _ErrorScreen(error: state.error.toString()),
  );
});

// ── Pantalla "Próximamente" ───────────────────────────────────────────────────
class _ProximamenteScreen extends StatelessWidget {
  const _ProximamenteScreen({required this.titulo, required this.bloque});
  final String titulo;
  final String bloque;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D2B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D2B),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(titulo),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🚀', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 24),
              Text(
                titulo,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C6AF7).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF7C6AF7)),
                ),
                child: Text(
                  'Disponible en Bloque $bloque',
                  style: const TextStyle(
                    color: Color(0xFF7C6AF7),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Esta función estará disponible\nen la siguiente etapa del proyecto.',
                style: TextStyle(color: Colors.white54, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back, color: Color(0xFF7C6AF7)),
                label: const Text(
                  'Volver',
                  style: TextStyle(color: Color(0xFF7C6AF7), fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Pantalla de error de ruta ─────────────────────────────────────────────────
class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Página no encontrada',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(error, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
