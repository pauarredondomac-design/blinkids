import 'package:flutter/material.dart';

/// Representa un bioma/mundo del juego.
class World {
  const World({
    required this.id,
    required this.name,
    required this.emoji,
    required this.route,
    required this.unlockCost,
    required this.description,
    required this.accentColor,
    this.comingSoon = false,
  });

  /// Identificador único (ej. 'forest', 'space').
  final String id;

  /// Nombre visible (ej. 'El Bosque').
  final String name;

  /// Emoji representativo.
  final String emoji;

  /// Ruta GoRouter a la que navega al entrar.
  final String route;

  /// Costo en monedas para desbloquear (0 = gratis).
  final int unlockCost;

  /// Descripción corta de dos líneas.
  final String description;

  /// Color de acento para la UI de este mundo.
  final Color accentColor;

  /// Si es true, el mundo no está disponible aún.
  final bool comingSoon;

  bool get isFree => unlockCost == 0;
}

// ─────────────────────────────────────────────────────────────
// Catálogo completo. Para agregar un nuevo mundo, añade aquí
// y crea la ruta correspondiente en app_router.dart.
// ─────────────────────────────────────────────────────────────
const allWorlds = [
  World(
    id:          'space',
    name:        'La Galaxia',
    emoji:       '🚀',
    route:       '/world',
    unlockCost:  0,
    description: 'Tu mundo de inicio.\nExplora las finanzas galácticas.',
    accentColor: Color(0xFF00BCD4),
  ),
];
