import 'package:flutter/material.dart';

/// Ícono del sistema visual "juego" — lee un PNG propio de
/// `assets/icons/icon_<name>.png` y, mientras ese archivo no exista
/// todavía, cae automáticamente al ícono Material actual (`fallback`).
/// Mismo patrón que `Item.imagePath` con fallback a emoji: no bloquea
/// nada mientras las ilustraciones van llegando una por una.
///
/// Ejemplo: `GameIcon(name: 'back', fallback: Icons.arrow_back_rounded)`
/// busca `assets/icons/icon_back.png`.
class GameIcon extends StatelessWidget {
  const GameIcon({
    super.key,
    required this.name,
    required this.fallback,
    this.size = 20,
    this.color,
  });

  final String name;
  final IconData fallback;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/icon_$name.png',
      width: size,
      height: size,
      // `color` solo tiñe el ícono Material de respaldo (fallback) —
      // el PNG ilustrado se muestra a color completo, sin aplanar.
      errorBuilder: (_, __, ___) => Icon(fallback, size: size, color: color),
    );
  }
}
