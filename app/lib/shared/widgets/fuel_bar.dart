import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FuelBar
//
// Barra de combustible compacta para el HUD del mundo.
// Muestra: icono 🚀 + barra animada (naranja→verde al llenarse) + label XX%.
// ─────────────────────────────────────────────────────────────────────────────
class FuelBar extends StatelessWidget {
  const FuelBar({
    super.key,
    required this.fuel,
    this.width = 130,
    this.accentColor,
    this.showLabel = true,
  });

  /// Fuel del 0 al 100.
  final int fuel;
  final double width;

  /// Color de acento principal del mundo (por defecto naranja→verde según %).
  final Color? accentColor;
  final bool showLabel;

  Color _barColor() {
    if (accentColor != null) return accentColor!;
    if (fuel >= 100) return const Color(0xFF00E676);
    if (fuel >= 60) return const Color(0xFFFFD600);
    return const Color(0xFFFF6D00);
  }

  @override
  Widget build(BuildContext context) {
    final pct = (fuel / 100.0).clamp(0.0, 1.0);
    final color = _barColor();

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('🚀', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 4),
              const Text(
                'Combustible',
                style: TextStyle(
                  color: Colors.white54,
                  fontFamily: 'Nunito',
                  fontSize: 9,
                ),
              ),
              const Spacer(),
              if (showLabel)
                Text(
                  '$fuel%',
                  style: TextStyle(
                    color: color,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    ).animate(key: ValueKey(fuel)).fadeIn(duration: 200.ms);
  }
}
