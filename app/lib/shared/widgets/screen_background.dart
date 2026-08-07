import 'package:flutter/material.dart';
import '../theme/game_tokens.dart';

/// Fondo espacial compartido — mismo fondo que usa el Mapa principal
/// (assets/worlds/space/space_background.png) con un overlay oscuro para
/// que el contenido encima siga siendo legible.
///
/// Reemplaza los fondos sólidos/gradiente que tenía cada pantalla
/// (Tienda, Vestidor, Trabajos) por uno solo, consistente en todo el juego.
class ScreenBackground extends StatelessWidget {
  const ScreenBackground(
      {super.key, required this.child, this.overlayOpacity = 0.55});

  final Widget child;

  /// Opacidad del overlay negro sobre la imagen. Las pantallas con mucho
  /// texto/UI encima (Tienda, Vestidor, Trabajos) necesitan más overlay que
  /// el Mapa (que ya tiene poco contenido superpuesto).
  final double overlayOpacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: GameTokens.bgDeep),
        Image.asset(
          'assets/worlds/space/space_background.png',
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
        ColoredBox(color: Colors.black.withOpacity(overlayOpacity)),
        child,
      ],
    );
  }
}
