// ─────────────────────────────────────────────────────────────────────────────
// BlinkCharacterWidget
//
// Ensambla a Blink a partir de recortes PNG individuales.
//
// Orden de pintura (de abajo a arriba):
//   1. cuerpo_principal   — cuerpo en calzones (referencia de ancho)
//   2. pants / bottom     — pantalón, sobre cintura y piernas
//   3. top / sudadera     — sudadera, cubre torso y brazos
//   4. boots              — botas, en los pies
//   5. accesorios         — guantes, a la altura de los puños
//   6. cabeza / helmet    — cabeza que encaja en el stub gris del cuerpo
//
// Todos los offsets son fracciones de W (ancho del cuerpo) y pueden
// ajustarse en _BlinkLayout si el ilustrador entrega nuevas proporciones.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/cosmetic_provider.dart';
import '../../data/models/cosmetic.dart';

// ─── Paths base (vestidor) ────────────────────────────────────────────────────
const _kBody = 'assets/blink/layers/cuerpo_principal.png';
const _kHead = 'assets/blink/layers/cabeza_principal.png';
const _kDefTop = 'assets/blink/layers/sudadera_azul.png';
const _kDefBot = 'assets/blink/layers/pants_azul.png';

// ─── Proporciones naturales de cada recorte ───────────────────────────────────
// (medidas en píxeles del PNG original; usamos ratios, no px absolutos)
const _kBodyW = 1357.0;
const _kBodyH = 1472.0; // referencia
const _kHeadW = 1204.0;
const _kHeadH = 1278.0;
const _kTopW = 1106.0;
const _kTopH = 729.0;

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
    this.loadout,
  });

  final double width;
  final VoidCallback? onTap;
  final bool showSpeechBubble;
  final String? speechText;
  final bool enableBounce;

  /// Loadout externo (vestidor preview). Si null lee equippedLoadoutProvider.
  final EquippedLoadout? loadout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveLo = loadout ??
        (ref.watch(equippedLoadoutProvider).valueOrNull ??
            EquippedLoadout.empty);

    Widget character = _AssembledBlink(width: width, loadout: liveLo);

    if (enableBounce) {
      character = character
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(
              begin: 0, end: -10, duration: 1400.ms, curve: Curves.easeInOut);
    }

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
// Ensamblado de capas con posicionamiento relativo
// ─────────────────────────────────────────────────────────────────────────────
class _AssembledBlink extends StatelessWidget {
  const _AssembledBlink({required this.width, required this.loadout});
  final double width;
  final EquippedLoadout loadout;

  @override
  Widget build(BuildContext context) {
    final W = width; // ancho de referencia = ancho del cuerpo

    // ── Tamaños de cada pieza (proporcionales a W) ─────────────────────────
    final bodyH = W * _kBodyH / _kBodyW; // 1.085W

    final headW = W * _kHeadW / _kBodyW; // 0.887W
    final headH = headW * _kHeadH / _kHeadW; // 0.941W

    // El cuello de la cabeza (≈28% inferior) encaja sobre el stub gris del cuerpo
    final neckOverlap = headH * 0.21;
    final bodyY = headH - neckOverlap; // dónde empieza el cuerpo
    final totalH = bodyY + bodyH;

    // Sudadera: cuello del hoodie alineado con stub del cuerpo
    final topW = W * _kTopW / _kBodyW; // 0.815W
    final topX = (W - topW) / 1.35;
    final topY = bodyY -
        topW * (_kTopH / _kTopW) * -0.20; // 8% por encima del inicio del cuerpo

    // Pantalón: cintura a 48% de la altura del cuerpo
    final botRenderW = W * 0.50;
    final botX = (W - botRenderW) / 2.2;
    final botY = bodyY + bodyH * 0.48;

    // Botas: en los pies (78% de la altura del cuerpo)
    final bootRenderW = W * 0.82;
    final bootX = (W - bootRenderW) / 2;
    final bootY = bodyY + bodyH * 0.78;

    // Guantes: a la altura de los puños (28% del cuerpo, al ancho completo)
    final gloveRenderW = W * 0.82;
    final gloveX = (W - gloveRenderW) / .85;
    final gloveY = bodyY + bodyH * 0.15;

    // ── Selectores de asset ────────────────────────────────────────────────
    final topAsset = loadout[CosmeticSlot.top]?.equippedAssetPath ?? _kDefTop;
    final bottomAsset =
        loadout[CosmeticSlot.bottom]?.equippedAssetPath ?? _kDefBot;
    final helmetAsset = loadout[CosmeticSlot.helmet]?.equippedAssetPath;
    final bootsAsset = loadout[CosmeticSlot.boots]?.equippedAssetPath;
    final accAsset = loadout[CosmeticSlot.accesorios]?.equippedAssetPath;

    return SizedBox(
      width: W,
      height: totalH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Cuerpo base
          _img(_kBody, left: 0, top: bodyY, width: W),
          // 2. Cabeza (debajo de la ropa — el cuello queda tapado por la sudadera)
          _img(helmetAsset ?? _kHead,
              left: (W - headW) / 2 - W * 0.05,
              top: helmetAsset != null ? -headH * 0.08 : 0,
              width: headW),
          // 3. Pantalón (sobre cuerpo y cabeza)
          _img(bottomAsset, left: botX, top: botY, width: botRenderW),
          // 4. Sudadera (cubre torso, brazos y cuello de la cabeza)
          _img(topAsset, left: topX, top: topY, width: topW),
          // 5. Botas (pies, sobre pantalón)
          if (bootsAsset != null)
            _img(bootsAsset, left: bootX, top: bootY, width: bootRenderW),
          // 6. Guantes (puños, encima de todo)
          if (accAsset != null)
            _img(accAsset, left: gloveX, top: gloveY, width: gloveRenderW),
        ],
      ),
    );
  }

  Widget _img(String path,
          {required double left, required double top, required double width}) =>
      Positioned(
        left: left,
        top: top,
        child: Image.asset(
          path,
          width: width,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
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
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))
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
