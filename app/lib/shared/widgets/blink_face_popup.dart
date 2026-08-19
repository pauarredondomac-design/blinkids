import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'blink_reaction.dart';
import '../theme/game_tokens.dart';

const _kDefaultHead = 'assets/blink/layers/cabeza_principal.png';

const _kFaceCaption = <BlinkMood, String>{
  BlinkMood.contento: '¡Se ve genial este look! 😍',
  BlinkMood.celebrando: '¡Nuevo look listo! 🎉',
  BlinkMood.sorprendido: '¡Wow, qué cambio! 😲',
};

/// Popup con la CARA de Blink (no de cuerpo completo) reaccionando a un
/// cambio de look — se muestra al guardar un cambio en el Vestidor.
/// [helmetAssetPath] es el casco equipado (si hay), o null para la cabeza
/// base sin nada encima.
Future<void> showBlinkFacePopup(
  BuildContext context, {
  String? helmetAssetPath,
  BlinkMood mood = BlinkMood.contento,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(32),
      child: GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1B1F3B), Color(0xFF0D1B3E)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFB300).withOpacity(0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Recuadro con la cara de Blink ─────────────────────────────
              Container(
                width: 150,
                height: 150,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFB300).withOpacity(0.55),
                    width: 3,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    helmetAssetPath ?? _kDefaultHead,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text('🦊', style: TextStyle(fontSize: 64)),
                    ),
                  ),
                ),
              )
                  .animate()
                  .scale(
                      begin: const Offset(0.6, 0.6),
                      end: const Offset(1, 1),
                      duration: 350.ms,
                      curve: Curves.easeOutBack)
                  .then()
                  .shake(hz: 2, rotation: 0.03),
              const SizedBox(height: 16),
              Text(
                _kFaceCaption[mood] ?? '¡Se ve genial! 😍',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  fontFamily: 'Nunito',
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Toca para continuar',
                style: TextStyle(
                  color: GameTokens.textSecondary,
                  fontSize: 11,
                  fontFamily: 'Nunito',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
