// ─────────────────────────────────────────────────────────────────────────────
// BlinkCharacterWidget
//
// Renderiza al personaje Blink en el mapa con animación de rebote.
//
// Arquitectura de capas (se activa cuando llegan los PNGs separados):
//
//   Stack [
//     blink_base.png      ← cuerpo desnudo (sin accesorios)
//     bottom/[id].png     ← accesorio de tronco inferior (OBLIGATORIO)
//     top/[id].png        ← accesorio de tronco superior (OBLIGATORIO)
//     head/[id].png       ← sombrero (opcional)
//   ]
//
// Modo actual: imagen única (blink_dressed.png) hasta que lleguen los
// PNGs de capas separadas. Cambiar [useLayeredMode] a true cuando estén.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/cosmetic_provider.dart';
import '../../data/models/cosmetic.dart';

// ─── Rutas de assets ─────────────────────────────────────────────────────────

/// Imagen de Blink sin accesorios (body desnudo).
/// Se activa en [useLayeredMode = true].
const String _kBlinkBase    = 'assets/characters/blink/blink_base.png';

/// Imagen temporal con ropa puesta (hasta que lleguen los PNGs de capas).
const String _kBlinkDressed = 'assets/characters/blink/blink_dressed.png';

/// Accesorios por defecto — OBLIGATORIOS (siempre equipados si no hay otro).
const String _kDefaultTop    = 'assets/characters/blink/top/hoodie_azul.png';
const String _kDefaultBottom = 'assets/characters/blink/bottom/pants_azul.png';

// ─── Bandera de modo ─────────────────────────────────────────────────────────
/// false → muestra blink_dressed.png (imagen completa, temporal).
/// true  → renderiza capas: base + bottom + top + head (cuando existan los PNGs).
const bool _kUseLayeredMode = false;

// ─────────────────────────────────────────────────────────────────────────────
// Widget principal
// ─────────────────────────────────────────────────────────────────────────────
class BlinkCharacterWidget extends ConsumerWidget {
  const BlinkCharacterWidget({
    super.key,
    this.width = 130,
    this.onTap,
    this.showSpeechBubble = false,
    this.speechText,
    this.enableBounce = true,
  });

  final double   width;
  final VoidCallback? onTap;
  final bool     showSpeechBubble;
  final String?  speechText;
  final bool     enableBounce;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadoutAsync = ref.watch(equippedLoadoutProvider);
    final loadout = loadoutAsync.valueOrNull ?? EquippedLoadout.empty;

    Widget character = _kUseLayeredMode
        ? _LayeredBlink(width: width, loadout: loadout)
        : _SingleImageBlink(width: width);

    if (enableBounce) {
      character = character
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(
            begin: 0,
            end: -10,
            duration: 1400.ms,
            curve: Curves.easeInOut,
          );
    }

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Burbuja de diálogo (opcional)
          if (showSpeechBubble && speechText != null)
            _SpeechBubble(text: speechText!)
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.2, end: 0),
          character,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modo imagen única (temporal)
// ─────────────────────────────────────────────────────────────────────────────
class _SingleImageBlink extends StatelessWidget {
  const _SingleImageBlink({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _kBlinkDressed,
      width: width,
      filterQuality: FilterQuality.high,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modo capas (activar cuando lleguen los PNGs separados)
// ─────────────────────────────────────────────────────────────────────────────
class _LayeredBlink extends StatelessWidget {
  const _LayeredBlink({required this.width, required this.loadout});
  final double        width;
  final EquippedLoadout loadout;

  @override
  Widget build(BuildContext context) {
    // Obtener rutas de los accesorios equipados
    final topCosmetic    = loadout[CosmeticSlot.top];
    final bottomCosmetic = loadout[CosmeticSlot.bottom];

    final topAsset    = topCosmetic?.assetPath    ?? _kDefaultTop;
    final bottomAsset = bottomCosmetic?.assetPath ?? _kDefaultBottom;

    return SizedBox(
      width: width,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Capa 0: cuerpo base
          Image.asset(_kBlinkBase,    width: width, filterQuality: FilterQuality.high),
          // Capa 1: tronco inferior (OBLIGATORIO)
          Image.asset(bottomAsset,    width: width, filterQuality: FilterQuality.high),
          // Capa 2: tronco superior (OBLIGATORIO)
          Image.asset(topAsset,       width: width, filterQuality: FilterQuality.high),
          // Capa 3: cabeza/sombrero (opcional, solo si está equipado)
          if (loadout[CosmeticSlot.helmet]?.assetPath != null)
            Image.asset(
              loadout[CosmeticSlot.helmet]!.assetPath!,
              width: width,
              filterQuality: FilterQuality.high,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Burbuja de diálogo
// ─────────────────────────────────────────────────────────────────────────────
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: Color(0xFF1A1A2E),
        ),
      ),
    );
  }
}
