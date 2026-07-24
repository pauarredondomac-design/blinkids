import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/mission.dart';
import '../../../data/models/parent_mission.dart';
import '../../../data/repositories/mission_tracker.dart';
import '../../../data/repositories/wallet_repository.dart';
import '../../../shared/providers/demo_progress_provider.dart';
import '../../../shared/providers/fuel_provider.dart';
import '../../../shared/providers/item_provider.dart';
import '../../../shared/providers/mission_provider.dart';
import '../../../shared/providers/parent_mission_provider.dart';
import '../../../shared/providers/wallet_provider.dart';
import '../../../shared/providers/character_provider.dart';
import '../../../shared/providers/world_provider.dart';
import '../../../shared/widgets/coin_display.dart';
import '../../../shared/widgets/screen_tutorial.dart';
import '../../../shared/widgets/rocket_launch_overlay.dart';
import '../../../core/constants/app_sizes.dart';
import '../preguntas/preguntas_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MisionesScreen
// ─────────────────────────────────────────────────────────────────────────────
void showMisionesDialog(BuildContext context) {
  final size = MediaQuery.of(context).size;
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Misiones',
    barrierColor: Colors.black.withOpacity(0.65),
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return ScaleTransition(
        scale: Tween<double>(begin: 0.90, end: 1.0).animate(curved),
        child: FadeTransition(opacity: anim, child: child),
      );
    },
    pageBuilder: (ctx, _, __) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: size.width * 0.94,
          height: size.height * 0.90,
          child: const MisionesScreen(),
        ),
      ),
    ),
  );
}

class MisionesScreen extends ConsumerStatefulWidget {
  const MisionesScreen({super.key});

  @override
  ConsumerState<MisionesScreen> createState() => _MisionesScreenState();
}

enum _MissionCategory { historia, diarias, papas }

class _MisionesScreenState extends ConsumerState<MisionesScreen> {
  Map<MissionObjectiveType, int> _progress = {};
  Set<String> _claimed  = {};
  Set<String> _claiming = {};
  bool _loadingProgress = true;
  _MissionCategory _category = _MissionCategory.historia;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final tracker  = MissionTracker();
    final progress = await tracker.allProgress();

    final missionsAsync = ref.read(activeMissionsProvider);
    final missions = missionsAsync.valueOrNull ?? [];
    final claimed  = <String>{};
    for (final m in missions) {
      if (await tracker.isClaimed(m.id)) claimed.add(m.id);
    }

    if (mounted) {
      setState(() {
        _progress        = progress;
        _claimed         = claimed;
        _loadingProgress = false;
      });
    }
  }

  int _progressFor(MissionObjectiveType? type) =>
      type == null ? 0 : (_progress[type] ?? 0);

  bool _isComplete(Mission m) {
    if (!m.hasObjective) return false;
    return _progressFor(m.objectiveType) >= m.objectiveTarget;
  }

  Future<void> _handleClaim(Mission mission) async {
    if (_claiming.contains(mission.id)) return;
    setState(() => _claiming.add(mission.id));
    var reachedFullFuel = false;

    try {
      await MissionTracker().markClaimed(mission.id);

      if (DemoStore.isActive) {
        ref.read(demoProgressProvider).addCoins(mission.coinReward);
      } else {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          await WalletRepository().awardStarterCoins(userId, mission.coinReward);
          ref.invalidate(currentWalletProvider);
        }
      }

      await awardXp(ref, mission.xpReward);
      ref.invalidate(currentCharacterProvider);

      if (mission.itemReward != null) {
        await ref.read(itemRepositoryProvider).addToInventory(
          mission.itemReward!.itemId,
          mission.itemReward!.qty,
        );
        ref.invalidate(inventoryProvider);
        if (mission.itemReward!.itemId == 'fuel_capsule') {
          reachedFullFuel = await ref.read(fuelNotifierProvider.notifier)
              .addFuel('space', mission.itemReward!.qty * 10);
        }
      }

      if (mounted) {
        setState(() {
          _claiming.remove(mission.id);
          _claimed.add(mission.id);
        });
        await _showClaimDialog(mission);
        if (reachedFullFuel && mounted) showRocketLaunchOverlay(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _claiming.remove(mission.id));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  Future<void> _showClaimDialog(Mission mission) {
    return showDialog<void>(
      context: context,
      builder: (_) => _ClaimDialog(mission: mission),
    );
  }

  @override
  Widget build(BuildContext context) {
    final worldId       = ref.watch(currentWorldProvider);
    final missionsAsync = ref.watch(activeMissionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A18),
      body: ScreenTutorial(
        tutorialKey: 'misiones_v2',
        steps: const [
          TutorialStep(
            title: '¡Misiones del Espacio! ⚔️',
            body: 'Las misiones te dan retos especiales que debes completar '
                'jugando en el mundo. ¡Gana monedas y objetos raros al terminarlas!',
          ),
          TutorialStep(
            title: 'Cómo completar una misión 🗺️',
            body: 'Cada misión tiene un objetivo: responder preguntas, '
                'completar trabajos o comprar en la tienda. La barra te muestra cuánto llevas.',
          ),
          TutorialStep(
            title: '¡Reclamar la recompensa! 🎁',
            body: 'Cuando la barra llegue al 100% aparece el botón "¡Reclamar!". '
                '¡Tócalo para recibir tus monedas y objetos!',
          ),
        ],
        child: Row(
          children: [
            _MisionesSidebar(
              category: _category,
              onSelectCategory: (c) => setState(() => _category = c),
              onOpenPreguntas: () => showPreguntasDialog(context),
              onBack: () => context.pop(),
            ),
            Expanded(
              child: _category == _MissionCategory.papas
                  ? const _ParentMissionsPanel()
                  : _loadingProgress
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF4FC3F7)),
                    )
                  : missionsAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF4FC3F7)),
                      ),
                      error: (_, __) => _ErrorView(
                        onRetry: () {
                          ref.invalidate(activeMissionsProvider);
                          _loadProgress();
                        },
                      ),
                      data: (allMissions) {
                        final missions = allMissions.where((m) {
                          return _category == _MissionCategory.diarias
                              ? m.endsAt != null
                              : m.endsAt == null;
                        }).toList();
                        if (missions.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('🌌',
                                    style:
                                        TextStyle(fontSize: 64)),
                                const SizedBox(height: 16),
                                Text(
                                  'No hay misiones activas\npor ahora. ¡Vuelve pronto!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color:
                                        Colors.white.withOpacity(0.65),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.builder(
                          padding:
                              const EdgeInsets.all(AppSizes.md),
                          itemCount: missions.length,
                          itemBuilder: (ctx, i) {
                            final m        = missions[i];
                            final progress = _progressFor(m.objectiveType);
                            final complete = _isComplete(m);
                            final claimed  = _claimed.contains(m.id);
                            final claiming = _claiming.contains(m.id);

                            return _MissionCard(
                              mission:  m,
                              progress: progress,
                              complete: complete,
                              claimed:  claimed,
                              claiming: claiming,
                              onClaim:  () => _handleClaim(m),
                            )
                                .animate(delay: (80 * i).ms)
                                .fadeIn(duration: 350.ms)
                                .slideY(
                                  begin: 0.12,
                                  end: 0,
                                  curve: Curves.easeOut,
                                );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar oscura — estilo consistente con la tienda
// ─────────────────────────────────────────────────────────────────────────────
class _MisionesSidebar extends StatelessWidget {
  const _MisionesSidebar({
    required this.category,
    required this.onSelectCategory,
    required this.onOpenPreguntas,
    required this.onBack,
  });
  final _MissionCategory                 category;
  final ValueChanged<_MissionCategory>   onSelectCategory;
  final VoidCallback                     onOpenPreguntas;
  final VoidCallback                     onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D0A2A), Color(0xFF08061A)],
        ),
        border: Border(
          right: BorderSide(color: Color(0xFF2A1A5E), width: 1.5),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Botón volver
              GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.20),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Título
              const Text(
                'MISIONES',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
                ),
              ),

              const SizedBox(height: 22),

              // Divider con label
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      color: const Color(0xFF2A1A5E),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      'CATEGORÍAS',
                      style: TextStyle(
                        color: Color(0xFF6B5B9E),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: const Color(0xFF2A1A5E),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              _CategoryItem(
                emoji:    '📖',
                label:    'MISIONES HISTORIA',
                active:   category == _MissionCategory.historia,
                onTap:    () => onSelectCategory(_MissionCategory.historia),
              ),
              const SizedBox(height: 6),
              _CategoryItem(
                emoji:    '🔁',
                label:    'MISIONES DIARIAS',
                active:   category == _MissionCategory.diarias,
                onTap:    () => onSelectCategory(_MissionCategory.diarias),
              ),
              const SizedBox(height: 6),
              _CategoryItem(
                emoji:    '👨‍👩‍👧',
                label:    'MISIONES DE PAPÁS',
                active:   category == _MissionCategory.papas,
                onTap:    () => onSelectCategory(_MissionCategory.papas),
              ),
              const SizedBox(height: 6),
              _CategoryItem(
                emoji:    '❓',
                label:    'PREGUNTAS',
                active:   false,
                onTap:    onOpenPreguntas,
                trailing: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Item de categoría en el sidebar
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryItem extends StatelessWidget {
  const _CategoryItem({
    required this.emoji,
    required this.label,
    required this.active,
    required this.onTap,
    this.trailing = false,
  });
  final String       emoji;
  final String       label;
  final bool         active;
  final VoidCallback onTap;
  final bool         trailing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF3D1E8F).withOpacity(0.35) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? const Color(0xFF7C4DFF).withOpacity(0.55) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white.withOpacity(0.55),
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            if (trailing)
              Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.45), size: 16),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Estado vacío: aún no hay misiones de papás
// ─────────────────────────────────────────────────────────────────────────────
class _ParentMissionsPanel extends ConsumerStatefulWidget {
  const _ParentMissionsPanel();

  @override
  ConsumerState<_ParentMissionsPanel> createState() => _ParentMissionsPanelState();
}

class _ParentMissionsPanelState extends ConsumerState<_ParentMissionsPanel> {
  final Set<String> _completing = {};

  Future<void> _handleComplete(ParentMission mission) async {
    if (_completing.contains(mission.id)) return;
    setState(() => _completing.add(mission.id));
    try {
      await ref.read(parentMissionRepositoryProvider).completeMission(mission.id);
      ref.invalidate(childParentMissionsProvider);
      ref.invalidate(currentWalletProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('¡Ganaste ${mission.coinReward} monedas! 🎉'),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
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
      error: (_, __) => _ErrorView(
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
                  'Aún no tienes misiones de papás',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  'Cuando tu papá o mamá te asigne una,\naparecerá aquí.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13),
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
              onComplete: () => _handleComplete(m),
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
// Tarjeta de misión de papá
// ─────────────────────────────────────────────────────────────────────────────
class _ParentMissionCard extends StatelessWidget {
  const _ParentMissionCard({
    required this.mission,
    required this.completing,
    required this.onComplete,
  });
  final ParentMission mission;
  final bool          completing;
  final VoidCallback  onComplete;

  @override
  Widget build(BuildContext context) {
    final done = mission.isCompleted;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12122A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: done
              ? Colors.greenAccent.withOpacity(0.35)
              : const Color(0xFF7C4DFF).withOpacity(0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF7C4DFF).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('👨‍👩‍👧', style: TextStyle(fontSize: 18))),
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
                if (mission.description != null && mission.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    mission.description!,
                    style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12),
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
                      const _StatusChip(label: '✓ Completada', color: Colors.greenAccent)
                    else
                      GestureDetector(
                        onTap: completing ? null : onComplete,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: completing
                              ? const SizedBox(
                                  width: 14, height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Completar',
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
  final Color  color;

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
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta de misión — layout 2 columnas para landscape
// ─────────────────────────────────────────────────────────────────────────────
class _MissionCard extends StatelessWidget {
  const _MissionCard({
    required this.mission,
    required this.progress,
    required this.complete,
    required this.claimed,
    required this.claiming,
    required this.onClaim,
  });

  final Mission      mission;
  final int          progress;
  final bool         complete;
  final bool         claimed;
  final bool         claiming;
  final VoidCallback onClaim;

  String get _objectiveLabel {
    if (mission.objectiveType == null) return '';
    switch (mission.objectiveType!) {
      case MissionObjectiveType.completeQuizzes: return '❓ Preguntas respondidas';
      case MissionObjectiveType.completeJobs:    return '🔨 Trabajos completados';
      case MissionObjectiveType.buyFromShop:     return '🛒 Compras en la Tienda';
    }
  }

  String get _objectiveIcon {
    if (mission.objectiveType == null) return '⚔️';
    switch (mission.objectiveType!) {
      case MissionObjectiveType.completeQuizzes: return '🧠';
      case MissionObjectiveType.completeJobs:    return '🔨';
      case MissionObjectiveType.buyFromShop:     return '🛒';
    }
  }

  // Color del borde según estado
  Color get _borderColor {
    if (claimed)  return Colors.greenAccent.withOpacity(0.35);
    if (complete) return Colors.greenAccent.withOpacity(0.55);
    return const Color(0xFF4FC3F7).withOpacity(0.25);
  }

  Color get _progressColor {
    if (claimed || complete) return Colors.greenAccent;
    return const Color(0xFF4FC3F7);
  }

  @override
  Widget build(BuildContext context) {
    final clampedProgress = claimed
        ? mission.objectiveTarget
        : progress.clamp(0, mission.objectiveTarget);
    final ratio = mission.objectiveTarget == 0
        ? 1.0
        : (clampedProgress / mission.objectiveTarget).clamp(0.0, 1.0);

    return Opacity(
      opacity: claimed ? 0.65 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1B3E).withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: complete && !claimed
                  ? Colors.greenAccent.withOpacity(0.10)
                  : Colors.transparent,
              blurRadius: 14,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── IZQUIERDA: icono + nombre + historia + recompensas ────────
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Título
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.07),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.12),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _objectiveIcon,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            mission.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // Historia
                    if (mission.storyText != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        '"${mission.storyText}"',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.52),
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          height: 1.35,
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Chips de recompensa
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        _Pill('+${mission.coinReward}',
                            const Color(0xFFFFD600), showCoin: true),
                        _Pill('⭐ +${mission.xpReward}', Colors.white54),
                        if (mission.itemReward != null)
                          _Pill(
                            '${mission.itemReward!.item?.emoji ?? '🎁'} ×${mission.itemReward!.qty}',
                            const Color(0xFFCE93D8),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),
              Container(
                  width: 1,
                  color: Colors.white.withOpacity(0.10)),
              const SizedBox(width: 12),

              // ── DERECHA: progreso + botón ─────────────────────────────────
              Expanded(
                flex: 4,
                child: mission.hasObjective
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Etiqueta del objetivo
                          Text(
                            _objectiveLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Contador numérico
                          Text(
                            '$clampedProgress / ${mission.objectiveTarget}',
                            style: TextStyle(
                              color: _progressColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Barra de progreso
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: ratio,
                              backgroundColor: Colors.white.withOpacity(0.10),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  _progressColor),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Estado / botón
                          if (claimed)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.greenAccent.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color:
                                      Colors.greenAccent.withOpacity(0.30),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('✅', style: TextStyle(fontSize: 14)),
                                  SizedBox(width: 5),
                                  Text(
                                    'Completada',
                                    style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (complete)
                            // Botón reclamar — gradiente verde
                            GestureDetector(
                              onTap: claiming ? null : onClaim,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: claiming
                                      ? null
                                      : const LinearGradient(
                                          colors: [
                                            Color(0xFF2E7D32),
                                            Color(0xFF43A047),
                                          ],
                                        ),
                                  color: claiming
                                      ? Colors.white.withOpacity(0.08)
                                      : null,
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  boxShadow: claiming
                                      ? null
                                      : [
                                          BoxShadow(
                                            color: Colors.greenAccent
                                                .withOpacity(0.30),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          )
                                        ],
                                ),
                                child: claiming
                                    ? const Center(
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white60,
                                          ),
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text('🎁',
                                              style: TextStyle(fontSize: 14)),
                                          SizedBox(width: 6),
                                          Text(
                                            '¡Reclamar!',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            )
                          else
                            // En progreso
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.10),
                                ),
                              ),
                              child: Text(
                                'En progreso…',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.60),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chip de recompensa
// ─────────────────────────────────────────────────────────────────────────────
class _Pill extends StatelessWidget {
  const _Pill(this.label, this.color, {this.showCoin = false});
  final String label;
  final Color  color;
  final bool   showCoin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showCoin) ...[
            const AnimatedCoin(size: 12),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Diálogo de recompensa reclamada — estilo espacial
// ─────────────────────────────────────────────────────────────────────────────
class _ClaimDialog extends StatelessWidget {
  const _ClaimDialog({required this.mission});
  final Mission mission;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF07101F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: Colors.greenAccent.withOpacity(0.55),
          width: 1.5,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Celebración animada
          const Text('🎉', style: TextStyle(fontSize: 56))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(
                begin: 1.0, end: 1.18,
                duration: 600.ms,
                curve: Curves.easeInOut,
              ),
          const SizedBox(height: 10),

          // Título
          Text(
            '¡Misión completada!',
            style: TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              shadows: [
                Shadow(
                  color: Colors.greenAccent.withOpacity(0.60),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            mission.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),

          // Badges de recompensa
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _ClaimBadge(
                  '+${mission.coinReward} monedas',
                  const Color(0xFFFFD600), showCoin: true),
              _ClaimBadge(
                  '⭐ +${mission.xpReward} XP', Colors.white70),
              if (mission.itemReward != null)
                _ClaimBadge(
                  '${mission.itemReward!.item?.emoji ?? '🎁'} '
                  '${mission.itemReward!.item?.name ?? ''} '
                  '×${mission.itemReward!.qty}',
                  const Color(0xFFCE93D8),
                ),
            ],
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.greenAccent.withOpacity(0.30),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Text(
              '¡Increíble! 🚀',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ClaimBadge extends StatelessWidget {
  const _ClaimBadge(this.label, this.color, {this.showCoin = false});
  final String label;
  final Color  color;
  final bool   showCoin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showCoin) ...[
            const AnimatedCoin(size: 14),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vista de error
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
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
            'No se pudieron cargar las misiones',
            style: TextStyle(color: Colors.white.withOpacity(0.65)),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4FC3F7), Color(0xFF1976D2)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded,
                      color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Reintentar',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
