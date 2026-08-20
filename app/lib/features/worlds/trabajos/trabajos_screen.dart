import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/crafting_job.dart';
import '../../../data/repositories/crafting_job_repository.dart';
import '../../../data/repositories/mission_tracker.dart';
import '../../../data/repositories/wallet_repository.dart';
import '../../../data/services/analytics_service.dart';
import '../../../shared/providers/character_provider.dart';
import '../../../shared/providers/demo_progress_provider.dart';
import '../../../shared/providers/fuel_provider.dart';
import '../../../shared/providers/item_provider.dart';
import '../../../shared/providers/mission_provider.dart';
import '../../../shared/providers/wallet_provider.dart';
import '../../../shared/providers/world_provider.dart';
import '../../../shared/widgets/item_icon.dart';
import '../../../shared/widgets/return_to_mission_banner.dart';
import '../../../shared/widgets/screen_tutorial.dart';
import '../misiones/misiones_screen.dart';
import '../../../shared/widgets/activity_player.dart';
import '../../../shared/widgets/coin_display.dart';
import '../../../shared/widgets/rocket_launch_overlay.dart';
import '../../../shared/widgets/badge_unlock_celebration.dart';
import '../../../shared/widgets/screen_background.dart';
import '../../../shared/widgets/game_card.dart';
import '../../../shared/widgets/game_popup.dart';
import '../../../shared/widgets/tab_icon.dart';
import '../../../shared/widgets/modal_corners.dart';
import '../../../shared/theme/game_tokens.dart';
import 'trabajos_en_casa_panel.dart';

enum _TrabajosSection { taller, enCasa }

// ─────────────────────────────────────────────────────────────────────────────
// TrabajosScreen
// ─────────────────────────────────────────────────────────────────────────────
Future<void> showTrabajosDialog(BuildContext context) {
  final size = MediaQuery.of(context).size;
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Trabajos',
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
        title: 'Trabajos',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: size.width * 0.94,
            height: size.height * 0.85,
            child: const TrabajosScreen(),
          ),
        ),
      ),
    ),
  );
}

class TrabajosScreen extends ConsumerStatefulWidget {
  const TrabajosScreen({super.key});

  @override
  ConsumerState<TrabajosScreen> createState() => _TrabajosScreenState();
}

class _TrabajosScreenState extends ConsumerState<TrabajosScreen> {
  Map<String, int> _inventory = {};
  List<CraftingJob>? _remoteJobs; // null = usando hardcoded
  bool _loadingInv = true;
  _TrabajosSection _section = _TrabajosSection.taller;
  int _unlockedChapter = 1;
  int? _expandedChapter;
  Set<String> _completedJobIds = {};

  @override
  void initState() {
    super.initState();
    _loadInventory();
    _loadJobs();
    _loadChapterUnlock();
    _loadCompletedJobs();
  }

  Future<void> _loadCompletedJobs() async {
    final ids = await CraftingJobRepository.completedJobIds();
    if (mounted) setState(() => _completedJobIds = ids);
  }

  Future<void> _loadJobs() async {
    final worldId = ref.read(currentWorldProvider);
    final jobs = await CraftingJobRepository.getJobsForWorld(worldId);
    if (mounted) setState(() => _remoteJobs = jobs);
  }

  Future<void> _loadChapterUnlock() async {
    final missions = await ref.read(activeMissionsProvider.future);
    final claimed = await MissionTracker().claimedMissionIds();
    final unlocked = MissionTracker().unlockedChapterFrom(missions, claimed);
    if (mounted) {
      setState(() {
        _unlockedChapter = unlocked;
        _expandedChapter ??= unlocked;
      });
    }
  }

  Future<void> _loadInventory() async {
    final repo = ref.read(itemRepositoryProvider);
    final stacks = await repo.getInventory();
    final map = {for (final s in stacks) s.item.id: s.qty};
    if (mounted) {
      setState(() {
        _inventory = map;
        _loadingInv = false;
      });
    }
  }

  bool _hasAllMaterials(CraftingJob job) {
    for (final req in job.requirements) {
      if ((_inventory[req.itemId] ?? 0) < req.qty) return false;
    }
    return true;
  }

  Future<void> _doJob(CraftingJob job) async {
    final repo = ref.read(itemRepositoryProvider);

    final ok = await repo.hasRequirements(job.requirements);
    if (!mounted) return;
    if (!ok) {
      _snack('¡Te faltan materiales! Cómpralos en la Tienda. 🛒',
          Colors.orange.shade700);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmJobDialog(job: job),
    );
    if (confirmed != true || !mounted) return;

    try {
      await repo.consumeRequirements(job.requirements);

      if (DemoStore.isActive) {
        ref.read(demoProgressProvider).addCoins(job.coinReward);
      } else {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          await WalletRepository().awardStarterCoins(userId, job.coinReward);
          ref.invalidate(currentWalletProvider);
        }
        // Registrar completion en Supabase
        await CraftingJobRepository.recordCompletion(
          jobId: job.id,
          coinsEarned: job.coinReward,
        );
      }

      final newBadges = await awardXp(ref, job.xpReward);
      ref.invalidate(currentCharacterProvider);

      if (job.itemReward != null) {
        await repo.addToInventory(job.itemReward!.itemId, job.itemReward!.qty);
      }
      var reachedFullFuel = false;
      if (job.fuelReward > 0) {
        reachedFullFuel = await ref
            .read(fuelNotifierProvider.notifier)
            .addFuel('space', job.fuelReward);
      }

      await MissionTracker().recordJob();
      ref.invalidate(inventoryProvider);
      await _loadInventory();
      await _loadCompletedJobs();
      AnalyticsService.instance.jobCompleted(job.id, job.coinReward);

      if (mounted) {
        await _showRewardDialog(job);
        if (mounted) showBadgeUnlockCelebrations(context, ref, newBadges);
        if (reachedFullFuel && mounted) {
          await handleFuelReachedFull(context, ref);
        }
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red.shade700);
    }
  }

  void _snack(String msg, Color bg) =>
      showGamePopup(context, msg, accentColor: bg);

  Future<void> _showRewardDialog(CraftingJob job) {
    return showDialog<void>(
        context: context, builder: (_) => _RewardDialog(job: job));
  }

  // ── Agrupación por capítulo (mismo criterio que Misiones) ────────────────
  List<Widget> _buildChapterSections(List<CraftingJob> jobs) {
    final byChapter = <int, List<CraftingJob>>{};
    for (final j in jobs) {
      if (j.chapterNumber == null) continue;
      byChapter.putIfAbsent(j.chapterNumber!, () => []).add(j);
    }
    if (byChapter.isEmpty) return [];

    final chapterNumbers = byChapter.keys.toList()..sort();
    final widgets = <Widget>[];
    for (final chNum in chapterNumbers) {
      final chJobs = byChapter[chNum]!
        ..sort((a, b) =>
            (a.orderInChapter ?? 0).compareTo(b.orderInChapter ?? 0));
      final chapterTitle = chJobs.first.chapter ?? 'Capítulo $chNum';
      final chapterLocked = chNum > _unlockedChapter;
      final expanded = _expandedChapter == chNum && !chapterLocked;

      widgets.add(
        _ChapterHeader(
          title: chapterTitle,
          locked: chapterLocked,
          expanded: expanded,
          onTap: chapterLocked
              ? null
              : () => setState(
                  () => _expandedChapter = expanded ? null : chNum),
        ),
      );

      if (expanded) {
        for (var i = 0; i < chJobs.length; i++) {
          final job = chJobs[i];
          final prevCompleted =
              i == 0 || _completedJobIds.contains(chJobs[i - 1].id);
          widgets.add(
            _JobCard(
              job: job,
              inventory: _inventory,
              canDo: _hasAllMaterials(job),
              locked: !prevCompleted,
              completed: _completedJobIds.contains(job.id),
              onTap: () => _doJob(job),
            ).animate().fadeIn(duration: 250.ms),
          );
        }
      }
      widgets.add(const SizedBox(height: 6));
    }
    widgets.add(const SizedBox(height: 4));
    return widgets;
  }

  List<Widget> _buildFlatJobs(List<CraftingJob> jobs) {
    return [
      for (final job in jobs.where((j) => j.chapterNumber == null))
        _JobCard(
          job: job,
          inventory: _inventory,
          canDo: _hasAllMaterials(job),
          completed: _completedJobIds.contains(job.id),
          onTap: () => _doJob(job),
        ).animate().fadeIn(duration: 250.ms),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final worldId = ref.watch(currentWorldProvider);
    final coins = DemoStore.isActive
        ? ref.watch(demoProgressProvider).coins
        : (ref.watch(currentWalletProvider).valueOrNull?.totalCoins ?? 0);
    final jobs = _remoteJobs ?? craftingJobsForWorld(worldId);

    final completable = jobs.where((j) => _hasAllMaterials(j)).length;

    return ScreenTutorial(
      tutorialKey: 'trabajos_v2',
      steps: const [
        TutorialStep(
          title: '¡Trabajos Espaciales! 🔨',
          body: 'Los personajes necesitan tu ayuda. Junta materiales '
              'que compras en la Tienda y úsalos aquí para ganar monedas y objetos especiales.',
        ),
        TutorialStep(
          title: '¿Cómo funciona? 🤔',
          body: 'Cada trabajo muestra qué materiales necesitas. '
              'Los que ya tienes aparecen en verde ✅ y los que te faltan en rojo ❌. '
              '¡Cómpralos en la Tienda y vuelve aquí!',
        ),
      ],
      onReady: () {
        if (mounted) {
          maybeShowDailyBuildingQuestion(
            context,
            ref,
            buildingSlug: 'trabajos',
            accentColor: const Color(0xFF4FC3F7),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(children: [
          ScreenBackground(
              child: Row(
          children: [
            _JobsSidebar(
              coins: coins,
              worldId: worldId,
              jobCount: jobs.length,
              completable: completable,
              section: _section,
              onSelectSection: (s) => setState(() => _section = s),
            ),
            Expanded(
              child: switch (_section) {
                _TrabajosSection.taller => _loadingInv
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: Color(0xFF4FC3F7)),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        children: [
                          ..._buildChapterSections(jobs),
                          ..._buildFlatJobs(jobs),
                        ],
                      ),
                _TrabajosSection.enCasa => const TrabajosEnCasaPanel(),
              },
            ),
          ],
        )),
          ReturnToMissionBanner(
            onReturn: () {
              Navigator.of(context).pop();
              showMisionesDialog(context);
            },
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar oscura — mismo estilo que la tienda
// ─────────────────────────────────────────────────────────────────────────────
class _JobsSidebar extends StatelessWidget {
  const _JobsSidebar({
    required this.coins,
    required this.worldId,
    required this.jobCount,
    required this.completable,
    required this.section,
    required this.onSelectSection,
  });

  final int coins;
  final String worldId;
  final int jobCount;
  final int completable;
  final _TrabajosSection section;
  final ValueChanged<_TrabajosSection> onSelectSection;

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
          const SizedBox(height: 20),

          // Pill de monedas
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: CoinChip(coins: coins, size: CoinChipSize.sm),
          ),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'Secciones'.toUpperCase(),
              style: const TextStyle(
                color: GameTokens.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          _TrabajosSidebarItem(
            icon: '🔨',
            iconName: 'taller',
            label: 'Taller',
            active: section == _TrabajosSection.taller,
            onTap: () => onSelectSection(_TrabajosSection.taller),
          ),
          _TrabajosSidebarItem(
            icon: '🏠',
            iconName: 'en_casa',
            label: 'En Casa',
            active: section == _TrabajosSection.enCasa,
            onTap: () => onSelectSection(_TrabajosSection.enCasa),
          ),

          const SizedBox(height: 16),

          Divider(
            color: const Color(0xFF2A1A5E).withOpacity(0.80),
            indent: 14,
            endIndent: 14,
          ),

          const SizedBox(height: 14),

          // Stats — solo aplican al Taller
          if (section == _TrabajosSection.taller)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$jobCount trabajos\ndisponibles',
                    style: const TextStyle(
                      color: GameTokens.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$completable listos\npara hacer',
                    style: const TextStyle(
                      color: Color(0xFF69F0AE),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
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
// Ítem de sección en el sidebar — mismo estilo que la Tienda
// ─────────────────────────────────────────────────────────────────────────────
class _TrabajosSidebarItem extends StatelessWidget {
  const _TrabajosSidebarItem({
    required this.icon,
    required this.iconName,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String icon;
  final String iconName;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF4FC3F7).withOpacity(0.20)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: active ? const Color(0xFF4FC3F7) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            TabIcon(name: iconName, emoji: icon, size: 32),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : GameTokens.textSecondary,
                fontSize: 12,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Encabezado desplegable de capítulo — agrupa los trabajos del Taller
// ─────────────────────────────────────────────────────────────────────────────
class _ChapterHeader extends StatelessWidget {
  const _ChapterHeader({
    required this.title,
    required this.locked,
    required this.expanded,
    required this.onTap,
  });

  final String title;
  final bool locked;
  final bool expanded;
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
              if (!locked)
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: Colors.white.withOpacity(0.60),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta de trabajo — layout 2 columnas optimizado para landscape
// ─────────────────────────────────────────────────────────────────────────────
class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.job,
    required this.inventory,
    required this.canDo,
    required this.onTap,
    this.locked = false,
    this.completed = false,
  });

  final CraftingJob job;
  final Map<String, int> inventory;
  final bool canDo;
  final VoidCallback onTap;
  final bool locked;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    if (completed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Opacity(
          opacity: 0.70,
          child: GameCard(
            accentColor: Colors.greenAccent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Text('✅', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${job.emoji} ${job.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Completado — ya recibiste tu recompensa.',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (locked) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Opacity(
          opacity: 0.55,
          child: GameCard(
            accentColor: const Color(0xFF4FC3F7),
            locked: true,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Text('🔒', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${job.emoji} ${job.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Completa el trabajo anterior para abrir este.',
                        style: TextStyle(
                          color: GameTokens.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          _RewardChip('+${job.coinReward}',
                              const Color(0xFFFFD600), showCoin: true),
                          _RewardChip('⭐ +${job.xpReward}', Colors.white54),
                          if (job.fuelReward > 0)
                            _RewardChip('🚀 +${job.fuelReward}%',
                                const Color(0xFFFF9800)),
                          if (job.itemReward != null)
                            _RewardChip(
                              '×${job.itemReward!.qty}',
                              const Color(0xFFCE93D8),
                              icon: ItemIcon(
                                  item: job.itemReward!.item, size: 14),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GameCard(
        accentColor: const Color(0xFF4FC3F7),
        locked: !canDo,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── IZQUIERDA: NPC + historia + recompensas ──────────────────
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // NPC + nombre
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            job.npcEmoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job.npcName,
                              style: const TextStyle(
                                color: GameTokens.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              '${job.emoji} ${job.name}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),

                  // Historia
                  Text(
                    '"${job.story}"',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: GameTokens.textSecondary,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Chips de recompensa
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      _RewardChip('+${job.coinReward}', const Color(0xFFFFD600),
                          showCoin: true),
                      _RewardChip('⭐ +${job.xpReward}', Colors.white54),
                      if (job.fuelReward > 0)
                        _RewardChip(
                            '🚀 +${job.fuelReward}%', const Color(0xFFFF9800)),
                      if (job.itemReward != null)
                        _RewardChip(
                          '×${job.itemReward!.qty}',
                          const Color(0xFFCE93D8),
                          icon:
                              ItemIcon(item: job.itemReward!.item, size: 14),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),
            Container(width: 1, color: Colors.white.withOpacity(0.10)),
            const SizedBox(width: 12),

            // ── DERECHA: materiales + botón ──────────────────────────────
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (job.requirements.isNotEmpty) ...[
                    const Text(
                      'Materiales necesarios:',
                      style: TextStyle(
                        color: GameTokens.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: job.requirements.map((req) {
                      final have = inventory[req.itemId] ?? 0;
                      final ok = have >= req.qty;
                      final item = req.item;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: ok
                              ? Colors.greenAccent.withOpacity(0.08)
                              : Colors.redAccent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: ok
                                ? Colors.greenAccent.withOpacity(0.38)
                                : Colors.redAccent.withOpacity(0.38),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ItemIcon(item: item, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${item?.name ?? req.itemId} ×${req.qty}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              ok ? '✅$have' : '❌$have',
                              style: TextStyle(
                                color:
                                    ok ? Colors.greenAccent : Colors.redAccent,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),

                  // Botón de acción
                  SizedBox(
                    width: double.infinity,
                    child: canDo
                        ? GestureDetector(
                            onTap: onTap,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF8C00),
                                    Color(0xFFFFB300),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.40),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.rocket_launch_rounded,
                                      color: Colors.white, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    '¡Realizar!',
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
                        : Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.15),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock_clock_rounded,
                                    color: Colors.white.withOpacity(0.50),
                                    size: 15),
                                const SizedBox(width: 6),
                                const Text(
                                  'Te faltan materiales',
                                  style: TextStyle(
                                    color: GameTokens.textSecondary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chip de recompensa
// ─────────────────────────────────────────────────────────────────────────────
class _RewardChip extends StatelessWidget {
  const _RewardChip(this.label, this.color,
      {this.showCoin = false, this.icon});
  final String label;
  final Color color;
  final bool showCoin;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
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
// Diálogo de confirmación — estilo espacial
// ─────────────────────────────────────────────────────────────────────────────
class _ConfirmJobDialog extends StatelessWidget {
  const _ConfirmJobDialog({required this.job});
  final CraftingJob job;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF07101F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: const Color(0xFF4FC3F7).withOpacity(0.45),
          width: 1.5,
        ),
      ),
      title: Row(
        children: [
          Text(job.npcEmoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${job.emoji} ${job.name}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vas a usar:',
            style: TextStyle(
              color: GameTokens.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          ...job.requirements.map((req) {
            final item = req.item;
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  ItemIcon(item: item, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    '${item?.name ?? req.itemId} × ${req.qty}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '(se gasta)',
                    style: TextStyle(
                      color: GameTokens.textSecondary,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            );
          }),
          Divider(color: Colors.white.withOpacity(0.12), height: 20),
          // Recompensas
          Row(
            children: [
              const AnimatedCoin(size: 18),
              const SizedBox(width: 6),
              Text(
                '+${job.coinReward} monedas',
                style: const TextStyle(
                  color: Color(0xFFFFD600),
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '⭐ +${job.xpReward} XP',
                style: const TextStyle(
                  color: GameTokens.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (job.fuelReward > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('🚀', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(
                  '+${job.fuelReward}% combustible',
                  style: const TextStyle(
                    color: Color(0xFFFF9800),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
          if (job.itemReward != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                ItemIcon(item: job.itemReward!.item, size: 22),
                const SizedBox(width: 6),
                Text(
                  '+${job.itemReward!.qty} ${job.itemReward!.item?.name ?? ''}',
                  style: const TextStyle(
                    color: Color(0xFFCE93D8),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: GameTokens.textSecondary),
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pop(context, true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF8C00), Color(0xFFFFB300)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '¡Hacer! 🚀',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Diálogo de recompensa — celebración espacial
// ─────────────────────────────────────────────────────────────────────────────
class _RewardDialog extends StatelessWidget {
  const _RewardDialog({required this.job});
  final CraftingJob job;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF07101F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF4FC3F7), width: 1.5),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Emoji del trabajo animado
          Text(job.emoji, style: const TextStyle(fontSize: 56))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(
                begin: 1.0,
                end: 1.15,
                duration: 600.ms,
                curve: Curves.easeInOut,
              ),
          const SizedBox(height: 10),

          // Título
          Text(
            '¡Trabajo completado! 🎉',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF4FC3F7),
              fontWeight: FontWeight.w900,
              fontSize: 17,
              shadows: [
                Shadow(
                  color: const Color(0xFF4FC3F7).withOpacity(0.70),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Agradecimiento del NPC
          Text(
            '${job.npcEmoji} ${job.npcName} te agradece mucho.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: GameTokens.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),

          // Badges de recompensa
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RewardBadge('+${job.coinReward}', const Color(0xFFFFD600),
                  showCoin: true),
              const SizedBox(width: 8),
              _RewardBadge('⭐ +${job.xpReward}', Colors.white60),
              if (job.fuelReward > 0) ...[
                const SizedBox(width: 8),
                _RewardBadge('🚀 +${job.fuelReward}%', const Color(0xFFFF9800)),
              ],
              if (job.itemReward != null) ...[
                const SizedBox(width: 8),
                _RewardBadge(
                  '×${job.itemReward!.qty}',
                  const Color(0xFFCE93D8),
                  icon: ItemIcon(item: job.itemReward!.item, size: 18),
                ),
              ],
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
                colors: [Color(0xFF4FC3F7), Color(0xFF1976D2)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4FC3F7).withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Text(
              '¡Genial! 🚀',
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

// ─────────────────────────────────────────────────────────────────────────────
// Badge de recompensa en diálogo
// ─────────────────────────────────────────────────────────────────────────────
class _RewardBadge extends StatelessWidget {
  const _RewardBadge(this.label, this.color,
      {this.showCoin = false, this.icon});
  final String label;
  final Color color;
  final bool showCoin;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.40)),
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
