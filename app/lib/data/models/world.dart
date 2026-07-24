import 'package:flutter/material.dart';

/// Representa un bioma/mundo del juego.
class World {
  const World({
    required this.id,
    required this.name,
    required this.shortName,
    required this.emoji,
    required this.route,
    required this.unlockCost,
    required this.description,
    required this.accentColor,
    this.unlockedImagePath,
    this.lockedImagePath,
    this.backgroundImagePath,
    this.comingSoon = false,
  });

  final String id;
  final String name;
  /// Nombre corto para mostrar bajo la imagen en el selector.
  final String shortName;
  final String emoji;
  final String route;
  final int    unlockCost;
  final String description;
  final Color  accentColor;

  /// Imagen que se muestra en la tarjeta cuando el mundo está desbloqueado.
  final String? unlockedImagePath;

  /// Imagen que se muestra en la tarjeta cuando el mundo está bloqueado.
  final String? lockedImagePath;

  /// Fondo del mapa de este mundo, usado como fondo de la tarjeta en el selector.
  final String? backgroundImagePath;

  final bool comingSoon;

  bool get isFree => unlockCost == 0;
}

// ─────────────────────────────────────────────────────────────
// Catálogo completo. Para agregar un nuevo mundo, añade aquí
// y crea la ruta correspondiente en app_router.dart.
// ─────────────────────────────────────────────────────────────
const allWorlds = [
  World(
    id:                'space',
    name:              'La Galaxia',
    shortName:         'Galaxia',
    emoji:             '🚀',
    route:             '/world',
    unlockCost:        0,
    description:       'Tu mundo de inicio.\nExplora las finanzas galácticas.',
    accentColor:       Color(0xFF00BCD4),
    unlockedImagePath: 'assets/worlds/space/unlocked.png',
    backgroundImagePath: 'assets/worlds/space/space_background.png',
  ),
  World(
    id:               'forest',
    name:             'Bosque Encantado',
    shortName:        'Bosque',
    emoji:            '🌲',
    route:            '/world/forest',
    unlockCost:       500,
    description:      'Un bosque lleno de misterios\ny riquezas naturales.',
    accentColor:      Color(0xFF4CAF50),
    lockedImagePath:  'assets/worlds/forest/locked.png',
    backgroundImagePath: 'assets/worlds/forest/forest_background.png',
  ),
  World(
    id:               'sea',
    name:             'Fondo del Mar',
    shortName:        'Mar',
    emoji:            '🌊',
    route:            '/world/sea',
    unlockCost:       1000,
    description:      'Las profundidades guardan\nlos tesoros más valiosos.',
    accentColor:      Color(0xFF1565C0),
    lockedImagePath:  'assets/worlds/sea/locked.png',
    backgroundImagePath: 'assets/worlds/sea/ocean_background.png',
  ),
];
