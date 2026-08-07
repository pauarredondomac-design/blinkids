import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'blink_character.dart';
import 'blink_reaction.dart';
import '../../data/models/cosmetic.dart';

/// Presencia de Blink reutilizable en cualquier pantalla — envuelve
/// `BlinkCharacterWidget` (el personaje compuesto por capas, ya vestido con
/// el outfit real que el niño eligió en el Vestidor) en un tamaño chico
/// pensado para esquinas/acompañamiento, en vez del tamaño grande que usa
/// como protagonista del Mapa o el preview del Vestidor.
///
/// Si se le pasa un [reaction] controller, este mismo Blink reacciona en su
/// lugar cuando alguien llama `reaction.react(BlinkMood.x)` — no hace falta
/// agregar un segundo Blink para mostrar la reacción.
class BlinkAvatar extends StatefulWidget {
  const BlinkAvatar({
    super.key,
    this.size = 90,
    this.onTap,
    this.bounce = true,
    this.reaction,
    this.loadout,
  });

  final double size;
  final VoidCallback? onTap;
  final bool bounce;

  /// Controller opcional — si se provee, este BlinkAvatar reacciona cuando
  /// se llama a `reaction.react(mood)` en vez de solo mostrar el idle.
  final BlinkReactionController? reaction;

  /// Loadout externo (ej. preview en tiempo real del Vestidor). Si es null,
  /// BlinkCharacterWidget lee el loadout equipado real del jugador.
  final EquippedLoadout? loadout;

  @override
  State<BlinkAvatar> createState() => _BlinkAvatarState();
}

class _BlinkAvatarState extends State<BlinkAvatar> {
  @override
  void initState() {
    super.initState();
    widget.reaction?.addListener(_onReactionChanged);
  }

  @override
  void didUpdateWidget(covariant BlinkAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reaction != widget.reaction) {
      oldWidget.reaction?.removeListener(_onReactionChanged);
      widget.reaction?.addListener(_onReactionChanged);
    }
  }

  @override
  void dispose() {
    widget.reaction?.removeListener(_onReactionChanged);
    super.dispose();
  }

  void _onReactionChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final character = BlinkCharacterWidget(
      width: widget.size,
      onTap: widget.onTap,
      enableBounce: widget.bounce,
      loadout: widget.loadout,
    );

    final mood = widget.reaction?.mood;
    if (mood == null) return character;

    return Image.asset(
      blinkMoodPoseAsset[mood]!,
      width: widget.size,
      errorBuilder: (_, __, ___) => blinkReactionFallback(
        BlinkCharacterWidget(
          width: widget.size,
          onTap: widget.onTap,
          enableBounce: false,
          loadout: widget.loadout,
        ),
        mood,
      ),
    ).animate().scale(
          begin: const Offset(0.7, 0.7),
          end: const Offset(1, 1),
          duration: 280.ms,
          curve: Curves.elasticOut,
        );
  }
}
