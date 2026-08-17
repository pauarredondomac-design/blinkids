import 'package:flutter/material.dart';
import '../theme/game_tokens.dart';

/// Reemplazo de los SnackBar de abajo de pantalla: un popup centrado, con el
/// mismo estilo que el resto de los diálogos del juego (panel oscuro +
/// borde/glow del color del mensaje), que se cierra al tocar en cualquier
/// parte de la pantalla (o solo, después de [autoDismiss], por si el niño
/// no toca nada).
Future<void> showGamePopup(
  BuildContext context,
  String message, {
  Color accentColor = const Color(0xFF2E7D32),
  Duration autoDismiss = const Duration(seconds: 3),
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar',
    barrierColor: Colors.black.withOpacity(0.45),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogCtx, _, __) {
      Future.delayed(autoDismiss, () {
        if (Navigator.of(dialogCtx).canPop()) Navigator.of(dialogCtx).pop();
      });
      return Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(dialogCtx).pop(),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 48),
              constraints: const BoxConstraints(maxWidth: 380),
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1230),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: accentColor, width: 1.5),
                boxShadow: [
                  ...GameTokens.glow(accentColor, blur: 26, opacity: 0.45),
                  const BoxShadow(
                    color: Colors.black54,
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Baloo2',
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Toca para cerrar',
                    style: TextStyle(
                      color: GameTokens.textMuted,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (dialogCtx, anim, __, child) => ScaleTransition(
      scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
      child: FadeTransition(opacity: anim, child: child),
    ),
  );
}
