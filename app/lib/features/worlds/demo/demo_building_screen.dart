import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/demo_progress_provider.dart';
import '../space/banco_estelar_screen.dart';

/// Banco Estelar en modo demo — usa la pantalla real (con su propio tutorial),
/// y al salir desbloquea Trabajos si todavía no se había desbloqueado.
class DemoBancoWrapper extends ConsumerWidget {
  const DemoBancoWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        final store = ref.read(demoProgressProvider);
        if (store.stage == 0) {
          store.addXp(50);
          store.advanceStage();
          store.setPendingMessage('🔓 ¡Desbloqueaste Trabajos!');
        }
      },
      child: const BancoEstelarScreen(),
    );
  }
}

/// Envuelve una pantalla real del demo para avanzar automáticamente el stage
/// cuando el jugador la abandona (solo en modo demo).
///
/// [atStage] — el stage que se espera justo ANTES del avance (0=banco,1=trabajos…).
/// [unlockMessage] — mensaje de notificación que verá el jugador al volver al mapa.
class DemoStageGate extends ConsumerWidget {
  const DemoStageGate({
    super.key,
    required this.atStage,
    required this.unlockMessage,
    required this.child,
  });

  final int    atStage;
  final String unlockMessage;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!DemoStore.isActive) return child;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        final store = ref.read(demoProgressProvider);
        if (store.stage == atStage) {
          store.advanceStage();
          store.setPendingMessage(unlockMessage);
        }
      },
      child: child,
    );
  }
}
