import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/mission.dart';
import '../../../data/repositories/mission_tracker.dart';
import '../../../data/repositories/wallet_repository.dart';
import '../../../shared/providers/demo_progress_provider.dart';
import '../../../shared/providers/fuel_provider.dart';
import '../../../shared/providers/item_provider.dart';
import '../../../shared/providers/mission_provider.dart';
import '../../../shared/providers/wallet_provider.dart';
import '../../../shared/providers/character_provider.dart';
import '../../../shared/providers/world_provider.dart';
import '../../../shared/providers/mission_return_provider.dart';
import '../../../shared/widgets/coin_display.dart';
import '../../../shared/widgets/item_icon.dart';
import '../../../shared/widgets/screen_tutorial.dart';
import '../../../shared/widgets/activity_player.dart';
import '../../../shared/widgets/rocket_launch_overlay.dart';
import '../../../shared/widgets/badge_unlock_celebration.dart';
import '../../../shared/widgets/game_popup.dart';
import '../../../shared/widgets/season_finale_celebration.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/theme/game_tokens.dart';
import '../../../shared/widgets/screen_background.dart';
import '../../../shared/widgets/game_card.dart';
import '../../../shared/widgets/tab_icon.dart';
import '../../../shared/widgets/modal_corners.dart';
import 'quizzes_screen.dart';
import '../trabajos/trabajos_screen.dart';
import '../tienda/tienda_screen.dart';
import '../space/banco_estelar_screen.dart';
import '../../wallet/screens/wallet_screen.dart';

// Misiones cuyo requisito faltante tiene UN destino único y claro (las demás
// —Engrane, Tornillos, Llave Maestra, combinaciones— se consiguen en más de
// un lugar, así que solo muestran el checklist de requisitos, sin botón).
const Map<String, (String, String)> _kMissingReqDestination = {
  'La nave no enciende': ('IR A TRABAJOS', 'trabajos'),
  'Cada moneda tiene una misión': ('IR A MI BOLSA', 'mi_bolsa'),
  'Energía para continuar': ('IR A TIENDA', 'tienda'),
  'Una decisión con empatía': ('IR A MI BOLSA', 'mi_bolsa'),
  'Haz crecer tus monedas': ('IR AL BANCO ESTELAR', 'banco_estelar'),
  'No alcanza para todo': ('IR A TRABAJOS', 'trabajos'),
};

// ─────────────────────────────────────────────────────────────────────────────
// MisionesScreen
// ─────────────────────────────────────────────────────────────────────────────
Future<void> showMisionesDialog(BuildContext context) {
  final size = MediaQuery.of(context).size;
  return showGeneralDialog(
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
      insetPadding: const EdgeInsets.fromLTRB(12, 60, 12, 12),
      child: ModalCorners(
        onClose: () => Navigator.of(ctx).pop(),
        title: 'Misiones',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: size.width * 0.94,
            height: size.height * 0.85,
            child: const MisionesScreen(),
          ),
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

enum _MissionCategory { historia, diarias }

class _MisionesScreenState extends ConsumerState<MisionesScreen> {
  Map<MissionObjectiveType, int> _progress = {};
  Set<String> _claimed = {};
  final Set<String> _claiming = {};
  bool _loadingProgress = true;
  _MissionCategory _category = _MissionCategory.historia;
  int _unlockedChapter = 1;
  int? _expandedChapter;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final tracker = MissionTracker();
    final missionsAsync = ref.read(activeMissionsProvider);
    final missions = missionsAsync.valueOrNull ?? [];

    // Una sola consulta cada una, en paralelo — antes esto hacía una
    // consulta de red POR misión (isClaimed en loop), lo que hacía que
    // la pantalla tardara mucho en cargar con muchas misiones.
    final results = await Future.wait([
      tracker.allProgress(),
      tracker.claimedMissionIds(),
    ]);
    final progress = results[0] as Map<MissionObjectiveType, int>;
    final claimed = results[1] as Set<String>;
    final unlockedChapter = tracker.unlockedChapterFrom(missions, claimed);

    if (mounted) {
      setState(() {
        _progress = progress;
        _claimed = claimed;
        _unlockedChapter = unlockedChapter;
        _expandedChapter ??= unlockedChapter;
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

    // Misiones de capítulo: hay que tener los ítems/monedas requeridos.
    if (mission.hasClaimRequirements) {
      final itemRepo = ref.read(itemRepositoryProvider);
      final hasItems = await itemRepo.hasRequirements(mission.requiredItems);
      final coins = DemoStore.isActive
          ? ref.read(demoProgressProvider).coins
          : (ref.read(currentWalletProvider).valueOrNull?.totalCoins ?? 0);
      if (!hasItems || coins < mission.requiredCoins) {
        if (mounted) {
          showGamePopup(
            context,
            '¡Te falta lo necesario para completar esta misión! 🔍',
            accentColor: Colors.orange.shade700,
          );
        }
        return;
      }
    }

    setState(() => _claiming.add(mission.id));
    var reachedFullFuel = false;
    List<String> newBadges = [];

    try {
      if (mission.hasClaimRequirements) {
        final itemRepo = ref.read(itemRepositoryProvider);
        await itemRepo.consumeRequirements(mission.requiredItems);
        if (mission.requiredCoins > 0) {
          if (DemoStore.isActive) {
            ref.read(demoProgressProvider).spendCoins(mission.requiredCoins);
          } else {
            final userId = Supabase.instance.client.auth.currentUser?.id;
            if (userId != null) {
              await WalletRepository()
                  .spendCoins(userId, mission.requiredCoins);
            }
          }
          ref.invalidate(currentWalletProvider);
        }
        ref.invalidate(inventoryProvider);
      }

      await MissionTracker().markClaimed(mission.id);

      if (mission.fuelReward > 0) {
        reachedFullFuel = await ref
            .read(fuelNotifierProvider.notifier)
            .addFuel('space', mission.fuelReward);
      }

      if (DemoStore.isActive) {
        ref.read(demoProgressProvider).addCoins(mission.coinReward);
      } else {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          await WalletRepository()
              .awardStarterCoins(userId, mission.coinReward);
          ref.invalidate(currentWalletProvider);
        }
      }

      newBadges = await awardXp(ref, mission.xpReward);
      ref.invalidate(currentCharacterProvider);

      if (mission.itemReward != null) {
        await ref.read(itemRepositoryProvider).addToInventory(
              mission.itemReward!.itemId,
              mission.itemReward!.qty,
            );
        ref.invalidate(inventoryProvider);
        if (mission.itemReward!.itemId == 'fuel_capsule') {
          reachedFullFuel = reachedFullFuel ||
              await ref
                  .read(fuelNotifierProvider.notifier)
                  .addFuel('space', mission.itemReward!.qty * 10);
        }
      }

      if (mounted) {
        setState(() {
          _claiming.remove(mission.id);
          _claimed.add(mission.id);
          if (mission.isChapterMission) {
            final missions = ref.read(activeMissionsProvider).valueOrNull ?? [];
            final unlockedChapter =
                MissionTracker().unlockedChapterFrom(missions, _claimed);
            _unlockedChapter = unlockedChapter;
            if (unlockedChapter > (_expandedChapter ?? 1)) {
              _expandedChapter = unlockedChapter;
            }
          }
        });
        if (mission.isSeasonFinale) {
          await showSeasonFinaleCelebration(context);
        } else {
          await _showClaimDialog(mission);
        }
        if (mounted) showBadgeUnlockCelebrations(context, ref, newBadges);
        if (reachedFullFuel && mounted) {
          await handleFuelReachedFull(context, ref);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _claiming.remove(mission.id));
        showGamePopup(context, 'Error: $e', accentColor: Colors.red.shade700);
      }
    }
  }

  // ── Agrupación por capítulo ───────────────────────────────────────────────
  List<Widget> _buildChapterSections(List<Mission> missions) {
    final byChapter = <int, List<Mission>>{};
    for (final m in missions) {
      if (m.chapterNumber == null) continue;
      byChapter.putIfAbsent(m.chapterNumber!, () => []).add(m);
    }
    if (byChapter.isEmpty) return [];

    final chapterNumbers = byChapter.keys.toList()..sort();
    final widgets = <Widget>[];
    for (final chNum in chapterNumbers) {
      final chMissions = byChapter[chNum]!
        ..sort((a, b) =>
            (a.orderInChapter ?? 0).compareTo(b.orderInChapter ?? 0));
      final chapterTitle = chMissions.first.chapter ?? 'Capítulo $chNum';
      final chapterLocked = chNum > _unlockedChapter;
      final expanded = _expandedChapter == chNum && !chapterLocked;
      final claimedCount =
          chMissions.where((m) => _claimed.contains(m.id)).length;

      widgets.add(
        _ChapterHeader(
          title: chapterTitle,
          locked: chapterLocked,
          expanded: expanded,
          progressLabel: '$claimedCount/${chMissions.length}',
          onTap: chapterLocked
              ? null
              : () => setState(
                  () => _expandedChapter = expanded ? null : chNum),
        ),
      );

      if (expanded) {
        for (var i = 0; i < chMissions.length; i++) {
          final m = chMissions[i];
          final prevClaimed =
              i == 0 || _claimed.contains(chMissions[i - 1].id);
          widgets.add(
            _MissionCard(
              mission: m,
              progress: _progressFor(m.objectiveType),
              complete: _isComplete(m),
              claimed: _claimed.contains(m.id),
              claiming: _claiming.contains(m.id),
              locked: !prevClaimed,
              onClaim: () => _handleClaim(m),
            ).animate().fadeIn(duration: 250.ms),
          );
        }
      }
      widgets.add(const SizedBox(height: 6));
    }
    widgets.add(const SizedBox(height: 4));
    return widgets;
  }

  List<Widget> _buildFlatMissions(List<Mission> missions) {
    return [
      for (final m in missions.where((m) => m.chapterNumber == null))
        _MissionCard(
          mission: m,
          progress: _progressFor(m.objectiveType),
          complete: _isComplete(m),
          claimed: _claimed.contains(m.id),
          claiming: _claiming.contains(m.id),
          locked: false,
          onClaim: () => _handleClaim(m),
        ).animate().fadeIn(duration: 250.ms),
    ];
  }

  Future<void> _showClaimDialog(Mission mission) {
    return showDialog<void>(
      context: context,
      builder: (_) => _ClaimDialog(mission: mission),
    );
  }

  @override
  Widget build(BuildContext context) {
    final worldId = ref.watch(currentWorldProvider);
    final missionsAsync = ref.watch(activeMissionsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
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
            body:
                'Cuando la barra llegue al 100% aparece el botón "¡Reclamar!". '
                '¡Tócalo para recibir tus monedas y objetos!',
          ),
        ],
        onReady: () {
          if (mounted) {
            maybeShowDailyBuildingQuestion(
              context,
              ref,
              buildingSlug: 'misiones',
              accentColor: const Color(0xFF4FC3F7),
              dailyGroupName: '🌞 Diaria',
            );
          }
        },
        child: ScreenBackground(
            child: Row(
          children: [
            _MisionesSidebar(
              category: _category,
              onSelectCategory: (c) => setState(() => _category = c),
              onOpenQuizzes: () => showQuizzesDialog(context),
            ),
            Expanded(
              child: _loadingProgress
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF4FC3F7)),
                    )
                  : missionsAsync.when(
                      loading: () => const Center(
                        child:
                            CircularProgressIndicator(color: Color(0xFF4FC3F7)),
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
                          return const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('🌌', style: TextStyle(fontSize: 64)),
                                SizedBox(height: 16),
                                Text(
                                  'No hay misiones activas\npor ahora. ¡Vuelve pronto!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: GameTokens.textSecondary,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView(
                          padding: const EdgeInsets.all(AppSizes.md),
                          children: [
                            ..._buildChapterSections(missions),
                            ..._buildFlatMissions(missions),
                          ],
                        );
                      },
                    ),
            ),
          ],
        )),
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
    required this.onOpenQuizzes,
  });
  final _MissionCategory category;
  final ValueChanged<_MissionCategory> onSelectCategory;
  final VoidCallback onOpenQuizzes;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: GameTokens.spaceLg),

          // Label de sección — mismo tratamiento plano que Tienda, sin líneas divisoras
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: GameTokens.spaceMd),
            child: Text(
              'Categorías'.toUpperCase(),
              style: const TextStyle(
                color: GameTokens.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),

          const SizedBox(height: GameTokens.spaceSm),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: GameTokens.spaceSm),
            child: Column(
              children: [
                _CategoryItem(
                  emoji: '📖',
                  iconName: 'historia',
                  label: 'Misiones historia',
                  active: category == _MissionCategory.historia,
                  onTap: () => onSelectCategory(_MissionCategory.historia),
                ),
                const SizedBox(height: GameTokens.spaceSm),
                _CategoryItem(
                  emoji: '🔁',
                  iconName: 'diarias',
                  label: 'Misiones diarias',
                  active: category == _MissionCategory.diarias,
                  onTap: () => onSelectCategory(_MissionCategory.diarias),
                ),
                const SizedBox(height: GameTokens.spaceSm),
                _CategoryItem(
                  emoji: '🧠',
                  iconName: 'quizzes_tab',
                  label: 'Quizzes',
                  active: false,
                  onTap: onOpenQuizzes,
                  trailing: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Item de categoría en el sidebar
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryItem extends StatelessWidget {
  const _CategoryItem({
    required this.emoji,
    required this.iconName,
    required this.label,
    required this.active,
    required this.onTap,
    this.trailing = false,
  });
  final String emoji;
  final String iconName;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool trailing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: GameTokens.spaceSm, vertical: GameTokens.spaceSm),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF3D1E8F).withOpacity(0.35)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? const Color(0xFF7C4DFF).withOpacity(0.55)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            TabIcon(name: iconName, emoji: emoji, size: 32),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: active ? Colors.white : GameTokens.textSecondary,
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            if (trailing)
              Icon(Icons.chevron_right_rounded,
                  color: Colors.white.withOpacity(0.45), size: 16),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Estado vacío: aún no hay misiones de papás
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Encabezado desplegable de capítulo — agrupa las misiones de historia
// ─────────────────────────────────────────────────────────────────────────────
class _ChapterHeader extends StatelessWidget {
  const _ChapterHeader({
    required this.title,
    required this.locked,
    required this.expanded,
    required this.progressLabel,
    required this.onTap,
  });

  final String title;
  final bool locked;
  final bool expanded;
  final String progressLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: locked
                ? Colors.white.withOpacity(0.03)
                : const Color(0xFF3D1E8F).withOpacity(0.22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: locked
                  ? Colors.white.withOpacity(0.08)
                  : const Color(0xFF7C4DFF).withOpacity(0.45),
            ),
          ),
          child: Row(
            children: [
              Text(locked ? '🔒' : '🪐', style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: locked ? GameTokens.textSecondary : Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              if (!locked) ...[
                Text(
                  progressLabel,
                  style: const TextStyle(
                    color: GameTokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: Colors.white.withOpacity(0.60),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta de misión — layout 2 columnas para landscape
// ─────────────────────────────────────────────────────────────────────────────
class _MissionCard extends ConsumerWidget {
  const _MissionCard({
    required this.mission,
    required this.progress,
    required this.complete,
    required this.claimed,
    required this.claiming,
    required this.onClaim,
    this.locked = false,
  });

  final Mission mission;
  final int progress;
  final bool complete;
  final bool claimed;
  final bool claiming;
  final VoidCallback onClaim;
  final bool locked;

  String get _objectiveLabel {
    if (mission.objectiveType == null) return '';
    switch (mission.objectiveType!) {
      case MissionObjectiveType.completeQuizzes:
        return '❓ Preguntas respondidas';
      case MissionObjectiveType.completeJobs:
        return '🔨 Trabajos completados';
      case MissionObjectiveType.buyFromShop:
        return '🛒 Compras en la Tienda';
    }
  }

  String get _objectiveIcon {
    if (mission.objectiveType == null) return '⚔️';
    switch (mission.objectiveType!) {
      case MissionObjectiveType.completeQuizzes:
        return '🧠';
      case MissionObjectiveType.completeJobs:
        return '🔨';
      case MissionObjectiveType.buyFromShop:
        return '🛒';
    }
  }

  // Acento de color según estado — celeste mientras está en curso, verde
  // una vez completada/reclamada. Se usa tanto para el borde/glow de
  // GameCard como para la barra y el contador de progreso.
  Color get _progressColor {
    if (claimed || complete) return Colors.greenAccent;
    return const Color(0xFF4FC3F7);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clampedProgress = claimed
        ? mission.objectiveTarget
        : progress.clamp(0, mission.objectiveTarget);
    final ratio = mission.objectiveTarget == 0
        ? 1.0
        : (clampedProgress / mission.objectiveTarget).clamp(0.0, 1.0);

    return Opacity(
      opacity: claimed ? 0.65 : (locked ? 0.55 : 1.0),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GameCard(
          accentColor: _progressColor,
          highlighted: complete && !claimed,
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
                        style: const TextStyle(
                          color: GameTokens.textSecondary,
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
                        _Pill('+${mission.coinReward}', const Color(0xFFFFD600),
                            showCoin: true),
                        _Pill('⭐ +${mission.xpReward}', Colors.white54),
                        if (mission.fuelReward > 0)
                          _Pill('🚀 +${mission.fuelReward}%',
                              const Color(0xFFFF9800)),
                        if (mission.itemReward != null)
                          _Pill(
                            '×${mission.itemReward!.qty}',
                            const Color(0xFFCE93D8),
                            icon:
                                ItemIcon(item: mission.itemReward!.item, size: 14),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),
              Container(width: 1, color: Colors.white.withOpacity(0.10)),
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
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(_progressColor),
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
                                  color: Colors.greenAccent.withOpacity(0.30),
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
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
                                  borderRadius: BorderRadius.circular(12),
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
                              child: const Text(
                                'En progreso…',
                                style: TextStyle(
                                  color: GameTokens.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      )
                    : (mission.isChapterMission
                        ? _buildChapterClaimPanel(ref)
                        : const SizedBox.shrink()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Panel derecho para misiones de capítulo (sin objectiveType): requisitos
  // de ítems/monedas + botón de reclamar, o estado bloqueado/completado.
  Widget _buildChapterClaimPanel(WidgetRef ref) {
    if (locked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🔒', style: TextStyle(fontSize: 14)),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Completa la misión anterior',
                style: TextStyle(
                  color: GameTokens.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (claimed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.greenAccent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.greenAccent.withOpacity(0.30)),
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
      );
    }

    final inventory = ref.watch(inventoryProvider).valueOrNull ?? [];
    final have = {for (final s in inventory) s.item.id: s.qty};
    final coins = DemoStore.isActive
        ? ref.watch(demoProgressProvider).coins
        : (ref.watch(currentWalletProvider).valueOrNull?.totalCoins ?? 0);

    final itemsOk =
        mission.requiredItems.every((r) => (have[r.itemId] ?? 0) >= r.qty);
    final coinsOk = coins >= mission.requiredCoins;
    final canClaim = itemsOk && coinsOk;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mission.hasClaimRequirements) ...[
          const Text(
            'Necesitas:',
            style: TextStyle(
              color: GameTokens.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 5,
            runSpacing: 4,
            children: [
              if (mission.requiredCoins > 0)
                _ReqChip('🪙 ${mission.requiredCoins}', coinsOk),
              for (final r in mission.requiredItems)
                _ReqChip(
                  '${r.item?.name ?? r.itemId} ×${r.qty}',
                  (have[r.itemId] ?? 0) >= r.qty,
                  icon: ItemIcon(item: r.item, size: 15),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (!canClaim && _kMissingReqDestination.containsKey(mission.name))
          _GoToDestinationButton(
            mission: mission,
            label: _kMissingReqDestination[mission.name]!.$1,
            destination: _kMissingReqDestination[mission.name]!.$2,
          )
        else
          GestureDetector(
            onTap: (canClaim && !claiming) ? onClaim : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: canClaim && !claiming
                    ? const LinearGradient(
                        colors: [Color(0xFF2E7D32), Color(0xFF43A047)])
                    : null,
                color: canClaim && !claiming
                    ? null
                    : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
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
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(canClaim ? '🎁' : '🛒',
                            style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          canClaim ? '¡Reclamar!' : 'Te falta lo necesario',
                          style: TextStyle(
                            color: canClaim
                                ? Colors.white
                                : GameTokens.textSecondary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Botón "IR A X" — solo para misiones con un único destino claro para
// conseguir lo que falta. Marca la misión como "activa" (para el banner
// "Volver a la misión" en la pantalla destino) y navega para allá.
// ─────────────────────────────────────────────────────────────────────────────
class _GoToDestinationButton extends ConsumerWidget {
  const _GoToDestinationButton({
    required this.mission,
    required this.label,
    required this.destination,
  });
  final Mission mission;
  final String label;
  final String destination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(activeMissionReturnProvider.notifier).state = mission.id;
        Navigator.of(context).pop();
        switch (destination) {
          case 'trabajos':
            showTrabajosDialog(context);
          case 'tienda':
            showTiendaDialog(context);
          case 'mi_bolsa':
            showWalletDialog(context);
          case 'banco_estelar':
            showBancoEstelarDialog(context);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF4FC3F7), Color(0xFF1976D2)]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chip de requisito (verde si se cumple, rojo si falta)
// ─────────────────────────────────────────────────────────────────────────────
class _ReqChip extends StatelessWidget {
  const _ReqChip(this.label, this.ok, {this.icon});
  final String label;
  final bool ok;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (ok ? Colors.greenAccent : Colors.redAccent).withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (ok ? Colors.greenAccent : Colors.redAccent).withOpacity(0.38),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            icon!,
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: ok ? Colors.greenAccent : Colors.redAccent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chip de recompensa
// ─────────────────────────────────────────────────────────────────────────────
class _Pill extends StatelessWidget {
  const _Pill(this.label, this.color, {this.showCoin = false, this.icon});
  final String label;
  final Color color;
  final bool showCoin;
  final Widget? icon;

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
          if (icon != null) ...[
            icon!,
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
                begin: 1.0,
                end: 1.18,
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
            style: const TextStyle(
              color: GameTokens.textSecondary,
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
                  '+${mission.coinReward} monedas', const Color(0xFFFFD600),
                  showCoin: true),
              _ClaimBadge('⭐ +${mission.xpReward} XP', Colors.white70),
              if (mission.fuelReward > 0)
                _ClaimBadge(
                    '🚀 +${mission.fuelReward}%', const Color(0xFFFF9800)),
              if (mission.itemReward != null)
                _ClaimBadge(
                  '${mission.itemReward!.item?.name ?? ''} '
                  '×${mission.itemReward!.qty}',
                  const Color(0xFFCE93D8),
                  icon: ItemIcon(item: mission.itemReward!.item, size: 18),
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
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
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
  const _ClaimBadge(this.label, this.color, {this.showCoin = false, this.icon});
  final String label;
  final Color color;
  final bool showCoin;
  final Widget? icon;

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
          if (icon != null) ...[
            icon!,
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
          const Text(
            'No se pudieron cargar las misiones',
            style: TextStyle(color: GameTokens.textSecondary),
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
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
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
