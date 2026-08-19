import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/mission_return_provider.dart';

/// Banner flotante "Volver a la misión" — aparece en Trabajos, Tienda,
/// Mi Bolsa y Banco Estelar cuando el niño llegó ahí desde una misión.
/// Al tocarlo: cierra esta pantalla, limpia el estado y reabre Misiones,
/// que ya revisa el progreso en vivo (sin lógica extra aquí).
class ReturnToMissionBanner extends ConsumerWidget {
  const ReturnToMissionBanner({super.key, required this.onReturn});

  /// Callback del caller: debe cerrar la pantalla actual y reabrir Misiones
  /// (cada pantalla ya sabe cómo hacer su propio Navigator.pop + showMisionesDialog).
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missionId = ref.watch(activeMissionReturnProvider);
    if (missionId == null) return const SizedBox.shrink();

    return Positioned(
      top: 10,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: () {
            ref.read(activeMissionReturnProvider.notifier).state = null;
            onReturn();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4FC3F7), Color(0xFF1976D2)],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4FC3F7).withOpacity(0.45),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_rounded, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  'VOLVER A LA MISIÓN',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.4,
                    fontFamily: 'Nunito',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.3, end: 0);
  }
}
