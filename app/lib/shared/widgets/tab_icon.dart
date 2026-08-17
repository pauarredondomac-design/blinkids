import 'package:flutter/material.dart';

/// Ícono de pestaña/categoría — intenta cargar `assets/icons/icon_<name>.png`
/// y, mientras esa ilustración no exista, muestra el emoji de respaldo.
/// Mismo patrón que `GameIcon`, pero con fallback a emoji en vez de
/// `IconData` (para sidebars que hoy ya usan un emoji como ícono).
class TabIcon extends StatelessWidget {
  const TabIcon({
    super.key,
    required this.name,
    required this.emoji,
    this.size = 16,
  });

  final String name;
  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/icon_$name.png',
      width: size,
      height: size,
      errorBuilder: (_, __, ___) =>
          Text(emoji, style: TextStyle(fontSize: size)),
    );
  }
}
