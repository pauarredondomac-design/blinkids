import 'package:flutter/material.dart';
import '../theme/game_tokens.dart';

/// Card reutilizable del sistema visual "juego" — mismo radius/borde/glow
/// en todas las pantallas. Reemplaza los estilos de card duplicados por
/// módulo (Tienda, Trabajos, Vestidor...); cada pantalla sigue controlando
/// su propio contenido interno, solo la "cáscara" exterior es compartida.
class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = EdgeInsets.zero,
    this.accentColor = GameTokens.cyan,
    this.backgroundColor,
    this.borderRadius,
    this.locked = false,
    this.highlighted = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Color del borde/glow. Cada módulo puede pasar su propio acento
  /// (ej. dorado para recompensas, morado para Tienda) sin duplicar el
  /// resto del estilo de la card.
  final Color accentColor;
  final Color? backgroundColor;
  final double? borderRadius;

  /// Card bloqueada (candado): borde/glow apagados, sin tocar el contenido.
  final bool locked;

  /// Card resaltada (ej. seleccionada, hover): borde/glow más intensos.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? GameTokens.cardRadius;
    final content = Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? GameTokens.bgPanel.withOpacity(0.85),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: locked
              ? Colors.white.withOpacity(0.15)
              : accentColor.withOpacity(highlighted ? 0.90 : 0.40),
          width: highlighted
              ? GameTokens.borderWidthHighlight
              : GameTokens.borderWidth,
        ),
        boxShadow: locked
            ? null
            : GameTokens.glow(
                accentColor,
                blur: highlighted ? 16 : 10,
                opacity: highlighted ? 0.45 : 0.18,
              ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: Padding(padding: padding, child: child),
      ),
    );

    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}
