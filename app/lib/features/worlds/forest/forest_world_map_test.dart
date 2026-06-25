// Pantalla de prueba rápida para visualizar ForestWorldMap.
// Ejecutar con:
//   flutter run -t lib/features/worlds/forest/forest_world_map_test.dart
// No necesita Supabase — los providers fallan silenciosamente
// y el HUD muestra valores por defecto (0 monedas, "Aventurero").

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'forest_world_map.dart';

void main() {
  runApp(const ProviderScope(child: _ForestTestApp()));
}

class _ForestTestApp extends StatelessWidget {
  const _ForestTestApp();

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const ForestWorldMap(),
        ),
        // Stub de /wallet para que el tap de Mi Bolsa no rompa
        GoRoute(
          path: '/wallet',
          builder: (_, __) => const _StubScreen('💼 Mi Bolsa'),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Forest Map — Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
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
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('← Volver al mapa'),
            ),
          ],
        ),
      ),
    );
  }
}
