import 'package:flutter/material.dart';
import 'blink_avatar.dart';
import 'game_card.dart';
import '../theme/game_tokens.dart';

/// Diálogo de Blink reutilizable — avatar + texto, en la misma card/borde/
/// glow del resto del sistema visual. Generaliza el patrón "Blink habla
/// arriba, opciones debajo" que ya funcionaba bien en Trabajos (Encargos).
///
/// Solo para diálogo DE BLINK (Encargos, Desafíos, Banco Estelar). Los
/// diálogos del Taller de crafting hablan otros NPCs (Capitán Astro, Robot
/// R2, etc.) y se quedan con su propio diseño — no usar este componente ahí.
class BlinkDialogueBox extends StatelessWidget {
  const BlinkDialogueBox({
    super.key,
    required this.text,
    this.accentColor = GameTokens.cyan,
    this.avatarSize = 44,
  });

  final String text;
  final Color accentColor;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    return GameCard(
      accentColor: accentColor,
      backgroundColor: accentColor.withOpacity(0.14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          BlinkAvatar(size: avatarSize, bounce: false),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GameText.body(size: 13.5, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
