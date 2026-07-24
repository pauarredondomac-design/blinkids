import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'go_router_refresh_stream.dart';

import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_selector_screen.dart';
import '../../features/auth/screens/child_signup_screen.dart';
import '../../features/auth/screens/child_login_screen.dart';
import '../../features/auth/screens/parent_auth_screen.dart';
import '../../features/auth/screens/redeem_code_screen.dart';
import '../../features/tutorial/screens/tutorial_screen.dart';
import '../../features/worlds/space/space_world_map.dart';
import '../../features/worlds/space/banco_estelar_screen.dart';
import '../../features/worlds/world_selector_screen.dart';
import '../../features/parent/screens/parent_home_screen.dart';
import '../../features/wallet/screens/wallet_screen.dart';
import '../../features/worlds/demo/demo_building_screen.dart';
import '../../features/worlds/trabajos/trabajos_screen.dart';
import '../../features/worlds/misiones/misiones_screen.dart';
import '../../features/worlds/mercado/mercado_screen.dart';
import '../../features/worlds/tienda/tienda_screen.dart';

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

      // Splash maneja su propia navegación
      if (loc == '/') return null;

      // Rutas de auth y demo — siempre accesibles
      const openRoutes = [
        '/login-selector', '/child-signup', '/child-login', '/parent-auth',
        '/world', '/tutorial',
      ];
      if (openRoutes.contains(loc)) return null;
      if (loc.startsWith('/space/') || loc.startsWith('/world/')) return null;

      // Panel de padres → requiere sesión
      if (loc.startsWith('/parent')) {
        if (user == null) return '/login-selector';
        return null;
      }

      // Canjear código → requiere sesión de niño
      if (loc == '/redeem-code') {
        if (user == null) return '/login-selector';
        return null;
      }

      return null;
    },
    routes: [
      // ── Splash ───────────────────────────────────────────────────────────────
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (_, __) => const SplashScreen(),
      ),

      // ── Auth ─────────────────────────────────────────────────────────────────
      GoRoute(
        path: '/login-selector',
        name: 'login-selector',
        builder: (_, __) => const LoginSelectorScreen(),
      ),
      GoRoute(
        path: '/child-signup',
        name: 'child-signup',
        builder: (_, __) => const ChildSignupScreen(),
      ),
      GoRoute(
        path: '/child-login',
        name: 'child-login',
        builder: (_, __) => const ChildLoginScreen(),
      ),
      GoRoute(
        path: '/parent-auth',
        name: 'parent-auth',
        builder: (_, __) => const ParentAuthScreen(),
      ),
      GoRoute(
        path: '/redeem-code',
        name: 'redeem-code',
        builder: (_, __) => const RedeemCodeScreen(),
      ),

      // ── Tutorial ──────────────────────────────────────────────────────────────
      GoRoute(
        path: '/tutorial',
        name: 'tutorial',
        builder: (_, __) => const TutorialScreen(),
      ),

      // ── Mundo Espacio ─────────────────────────────────────────────────────────
      GoRoute(
        path: '/world',
        name: 'world',
        builder: (_, __) => const SpaceWorldMap(),
      ),
      GoRoute(
        path: '/space/banco_estelar',
        name: 'space-banco-estelar',
        builder: (_, __) => const BancoEstelarScreen(),
      ),
      GoRoute(
        path: '/space/bolsa',
        name: 'space-bolsa',
        builder: (_, __) => const DemoStageGate(
          atStage: 3,
          unlockMessage: '🔓 ¡Desbloqueaste la Tienda!',
          child: WalletScreen(),
        ),
      ),

      // ── Demo guiada (en memoria, no toca Supabase) ──────────────────────────
      GoRoute(
        path: '/demo/banco',
        name: 'demo-banco',
        builder: (_, __) => const DemoBancoWrapper(),
      ),

      // ── Selector de mundos ───────────────────────────────────────────────────
      GoRoute(
        path: '/worlds',
        name: 'worlds',
        builder: (_, state) => WorldSelectorScreen(
          currentWorldId: state.extra as String? ?? 'space',
        ),
      ),

      // ── Panel de Padres ──────────────────────────────────────────────────────
      GoRoute(
        path: '/parent',
        name: 'parent',
        builder: (_, __) => const ParentHomeScreen(),
      ),

      // ── Pantallas del mundo espacio (demo y real comparten la misma ruta) ─────
      GoRoute(
        path: '/space/trabajos',
        name: 'space-trabajos',
        builder: (_, __) => const DemoStageGate(
          atStage: 1,
          unlockMessage: '🔓 ¡Desbloqueaste Misiones!',
          child: TrabajosScreen(),
        ),
      ),
      GoRoute(
        path: '/space/misiones',
        name: 'space-misiones',
        builder: (_, __) => const DemoStageGate(
          atStage: 2,
          unlockMessage: '🔓 ¡Desbloqueaste Mi Bolsa!',
          child: MisionesScreen(),
        ),
      ),
      // Mercado eliminado visualmente — ruta preservada para uso futuro
      // GoRoute(path: '/space/mercado', name: 'space-mercado',
      //   builder: (_, __) => const DemoStageGate(atStage: 3,
      //     unlockMessage: '🔓 ¡Desbloqueaste la Tienda!', child: MercadoScreen())),
      GoRoute(
        path: '/space/tienda',
        name: 'space-tienda',
        builder: (_, __) => const DemoStageGate(
          atStage: 4,
          unlockMessage: '🎉 ¡Has completado la demo!',
          child: TiendaScreen(),
        ),
      ),
      GoRoute(
        path: '/wallet',
        name: 'wallet',
        builder: (_, __) => const _ProximamenteScreen(titulo: 'Mi Bolsa', bloque: '3'),
      ),
      GoRoute(
        path: '/world-forest',
        name: 'world-forest',
        builder: (_, __) => const _ProximamenteScreen(titulo: 'Mundo Bosque', bloque: '3'),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🚀', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 24),
            Text(titulo,
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
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
              child: Text('Disponible en Bloque $bloque',
                style: const TextStyle(color: Color(0xFF7C6AF7), fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const SizedBox(height: 40),
            TextButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back, color: Color(0xFF7C6AF7)),
              label: const Text('Volver', style: TextStyle(color: Color(0xFF7C6AF7), fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

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
            Text('Página no encontrada', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(error, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
