import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/parent_mission.dart';
import '../../../shared/providers/parent_mission_provider.dart';
import '../../../shared/widgets/coin_display.dart';
import '../../../shared/widgets/game_popup.dart';
import '../../../core/constants/app_sizes.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TrabajosEnCasaPanel — tareas reales que el papá asigna y confirma.
// Vive en Trabajos (no en Misiones): Regla 2 del documento de diseño —
// cada función existe en un solo lugar.
// ─────────────────────────────────────────────────────────────────────────────
class TrabajosEnCasaPanel extends ConsumerStatefulWidget {
  const TrabajosEnCasaPanel({super.key});

  @override
  ConsumerState<TrabajosEnCasaPanel> createState() =>
      _TrabajosEnCasaPanelState();
}

class _TrabajosEnCasaPanelState extends ConsumerState<TrabajosEnCasaPanel> {
  final Set<String> _completing = {};

  Future<void> _handleMarkDone(ParentMission mission) async {
    if (_completing.contains(mission.id)) return;
    setState(() => _completing.add(mission.id));
    try {
      await ref
          .read(parentMissionRepositoryProvider)
          .markMissionDone(mission.id);
      ref.invalidate(childParentMissionsProvider);
      if (mounted) {
        showGamePopup(
          context,
          '¡Avisado! Espera a que tu papá o mamá lo confirme. ✅',
          accentColor: const Color(0xFF2E7D32),
        );
      }
    } catch (e) {
      if (mounted) {
        showGamePopup(
          context,
          '$e'.replaceFirst('Exception: ', ''),
          accentColor: Colors.red.shade700,
        );
      }
    } finally {
      if (mounted) setState(() => _completing.remove(mission.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final missionsAsync = ref.watch(childParentMissionsProvider);

    return missionsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF4FC3F7)),
      ),
      error: (_, __) => _SimpleErrorView(
        onRetry: () => ref.invalidate(childParentMissionsProvider),
      ),
      data: (missions) {
        if (missions.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('👨‍👩‍👧', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                Text(
                  'Aún no tienes tareas de casa',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.65), fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  'Cuando tu papá o mamá te asigne una,\naparecerá aquí.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.35), fontSize: 13),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSizes.md),
          itemCount: missions.length,
          itemBuilder: (ctx, i) {
            final m = missions[i];
            return _ParentMissionCard(
              mission: m,
              completing: _completing.contains(m.id),
              onMarkDone: () => _handleMarkDone(m),
            )
                .animate(delay: (80 * i).ms)
                .fadeIn(duration: 350.ms)
                .slideY(begin: 0.12, end: 0, curve: Curves.easeOut);
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta de tarea de casa
// ─────────────────────────────────────────────────────────────────────────────
class _ParentMissionCard extends StatelessWidget {
  const _ParentMissionCard({
    required this.mission,
    required this.completing,
    required this.onMarkDone,
  });
  final ParentMission mission;
  final bool completing;
  final VoidCallback onMarkDone;

  @override
  Widget build(BuildContext context) {
    final done = mission.isCompleted;
    final waiting = mission.isAwaitingApproval;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12122A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: done
              ? Colors.greenAccent.withOpacity(0.35)
              : waiting
                  ? const Color(0xFFFFB300).withOpacity(0.35)
                  : const Color(0xFF7C4DFF).withOpacity(0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF7C4DFF).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(
                child: Text('👨‍👩‍👧', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mission.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                if (mission.description != null &&
                    mission.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    mission.description!,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.55), fontSize: 12),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AnimatedCoin(size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '+${mission.coinReward}',
                          style: const TextStyle(
                            color: Color(0xFFFFD600),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (done)
                      const _StatusChip(
                          label: '✓ Completada', color: Colors.greenAccent)
                    else if (waiting)
                      const _StatusChip(
                          label: '⏳ Esperando confirmación',
                          color: Color(0xFFFFB300))
                    else
                      GestureDetector(
                        onTap: completing ? null : onMarkDone,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: completing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Marcar como hecho',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

class _SimpleErrorView extends StatelessWidget {
  const _SimpleErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('😕', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            'No se pudieron cargar las tareas',
            style: TextStyle(color: Colors.white.withOpacity(0.65)),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4FC3F7), Color(0xFF1976D2)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Reintentar',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
