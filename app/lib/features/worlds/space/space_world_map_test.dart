// Pantalla de prueba rápida para visualizar SpaceWorldMap.
// Ejecutar con:
//   flutter run -t lib/features/worlds/space/space_world_map_test.dart
// No necesita Supabase — los providers fallan silenciosamente
// y el HUD muestra valores por defecto (0 monedas, "Aventurero").

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'space_world_map.dart';

void main() {
  runApp(const ProviderScope(child: _SpaceTestApp()));
}

class _SpaceTestApp extends StatelessWidget {
  const _SpaceTestApp();

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const SpaceWorldMap(),
        ),
        // Stubs para que los taps no rompan el test
        GoRoute(
          path: '/world/misiones',
          builder: (_, __) => const _StubScreen('⚔️ Misiones'),
        ),
        GoRoute(
          path: '/world/preguntas',
          builder: (_, __) => const _StubScreen('❓ Preguntas'),
        ),
        GoRoute(
          path: '/world/tienda',
          builder: (_, __) => const _StubScreen('🔮 Tienda'),
        ),
        GoRoute(
          path: '/wallet',
          builder: (_, __) => const _StubScreen('🎒 Mi Bolsa'),
        ),
        GoRoute(
          path: '/world/mercado',
          builder: (_, __) => const _StubScreen('🛒 Mercado'),
        ),
        GoRoute(
          path: '/world/trabajos',
          builder: (_, __) => const _StubScreen('🔨 Trabajos'),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Space Map — Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00BCD4)),
        fontFamily: 'Nunito',
      ),
      routerConfig: router,
    );
  }
}

class _StubScreen extends StatelessWidget {
  const _StubScreen(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.cyanAccent,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
              ),
              child: const Text('← Volver al mapa espacial'),
            ),
          ],
        ),
      ),
    );
  }
}
