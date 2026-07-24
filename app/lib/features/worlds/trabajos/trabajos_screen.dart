import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/crafting_job.dart';
import '../../../data/models/item.dart';
import '../../../data/repositories/crafting_job_repository.dart';
import '../../../data/repositories/mission_tracker.dart';
import '../../../data/repositories/wallet_repository.dart';
import '../../../shared/providers/character_provider.dart';
import '../../../shared/providers/demo_progress_provider.dart';
import '../../../shared/providers/fuel_provider.dart';
import '../../../shared/providers/item_provider.dart';
import '../../../shared/providers/wallet_provider.dart';
import '../../../shared/providers/world_provider.dart';
import '../../../shared/widgets/screen_tutorial.dart';
import '../../../shared/widgets/coin_display.dart';
import '../../../shared/widgets/rocket_launch_overlay.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TrabajosScreen
// ─────────────────────────────────────────────────────────────────────────────
void showTrabajosDialog(BuildContext context) {
  final size = MediaQuery.of(context).size;
  showGeneralDialog(
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
      insetPadding: const EdgeInsets.all(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: size.width * 0.94,
          height: size.height * 0.90,
          child: const TrabajosScreen(),
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
  Map<String, int>   _inventory  = {};
  List<CraftingJob>? _remoteJobs;   // null = usando hardcoded
  bool _loadingInv = true;

  @override
  void initState() {
    super.initState();
    _loadInventory();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    final worldId = ref.read(currentWorldProvider);
    final jobs = await CraftingJobRepository.getJobsForWorld(worldId);
    if (mounted) setState(() => _remoteJobs = jobs);
  }

  Future<void> _loadInventory() async {
    final repo = ref.read(itemRepositoryProvider);
    final map  = <String, int>{};
    for (final item in allItems) {
      final qty = await repo.countOf(item.id);
      if (qty > 0) map[item.id] = qty;
    }
    if (mounted) setState(() { _inventory = map; _loadingInv = false; });
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
      _snack('¡Te faltan materiales! Cómpralos en la Tienda. 🛒', Colors.orange.shade700);
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
          jobId:       job.id,
          coinsEarned: job.coinReward,
        );
      }

      await awardXp(ref, job.xpReward);
      ref.invalidate(currentCharacterProvider);

      if (job.itemReward != null) {
        await repo.addToInventory(job.itemReward!.itemId, job.itemReward!.qty);
      }
      var reachedFullFuel = false;
      if (job.fuelReward > 0) {
        reachedFullFuel = await ref.read(fuelNotifierProvider.notifier)
            .addFuel('space', job.fuelReward);
      }

      await MissionTracker().recordJob();
      ref.invalidate(inventoryProvider);
      await _loadInventory();

      if (mounted) {
        await _showRewardDialog(job);
        if (reachedFullFuel && mounted) showRocketLaunchOverlay(context);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red.shade700);
    }
  }

  void _snack(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _showRewardDialog(CraftingJob job) {
    return showDialog<void>(context: context, builder: (_) => _RewardDialog(job: job));
  }

  @override
  Widget build(BuildContext context) {
    final worldId = ref.watch(currentWorldProvider);
    final coins   = DemoStore.isActive
        ? ref.watch(demoProgressProvider).coins
        : (ref.watch(currentWalletProvider).valueOrNull?.totalCoins ?? 0);
    final jobs    = _remoteJobs ?? craftingJobsForWorld(worldId);

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
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A18),
        body: Row(
          children: [
            _JobsSidebar(
              coins: coins,
              worldId: worldId,
              jobCount: jobs.length,
              completable: completable,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: _loadingInv
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF4FC3F7)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      itemCount: jobs.length,
                      itemBuilder: (ctx, i) {
                        final job   = jobs[i];
                        final canDo = _hasAllMaterials(job);
                        return _JobCard(
                          job:       job,
                          inventory: _inventory,
                          canDo:     canDo,
                          onTap:     () => _doJob(job),
                        )
                            .animate(delay: (80 * i).ms)
                            .fadeIn(duration: 350.ms)
                            .slideY(
                              begin: 0.12, end: 0,
                              curve: Curves.easeOut,
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
// Sidebar oscura — mismo estilo que la tienda
// ─────────────────────────────────────────────────────────────────────────────
class _JobsSidebar extends StatelessWidget {
  const _JobsSidebar({
    required this.coins,
    required this.worldId,
    required this.jobCount,
    required this.completable,
    required this.onBack,
  });

  final int          coins;
  final String       worldId;
  final int          jobCount;
  final int          completable;
  final VoidCallback onBack;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),

            // Botón volver
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GestureDetector(
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
            ),

            const SizedBox(height: 16),

            // Título
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'TRABAJOS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Pill de monedas
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.amber.withOpacity(0.60),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AnimatedCoin(size: 15),
                    const SizedBox(width: 5),
                    Text(
                      '$coins',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Divider(
              color: const Color(0xFF2A1A5E).withOpacity(0.80),
              indent: 14,
              endIndent: 14,
            ),

            const SizedBox(height: 14),

            // Stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$jobCount trabajos\ndisponibles',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
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
  });

  final CraftingJob     job;
  final Map<String,int> inventory;
  final bool            canDo;
  final VoidCallback    onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B3E).withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: canDo
              ? const Color(0xFF4FC3F7).withOpacity(0.40)
              : Colors.white.withOpacity(0.10),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: canDo
                ? const Color(0xFF4FC3F7).withOpacity(0.10)
                : Colors.transparent,
            blurRadius: 14,
          ),
        ],
      ),
      child: Padding(
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
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.50),
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
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
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
                      _RewardChip('+${job.coinReward}', const Color(0xFFFFD600), showCoin: true),
                      _RewardChip('⭐ +${job.xpReward}', Colors.white54),
                      if (job.fuelReward > 0)
                        _RewardChip('🚀 +${job.fuelReward}%', const Color(0xFFFF9800)),
                      if (job.itemReward != null)
                        _RewardChip(
                          '${job.itemReward!.item?.emoji ?? '🎁'} ×${job.itemReward!.qty}',
                          const Color(0xFFCE93D8),
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
                  Text(
                    'Materiales necesarios:',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: job.requirements.map((req) {
                      final have = inventory[req.itemId] ?? 0;
                      final ok   = have >= req.qty;
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
                            Text(item?.emoji ?? '❓',
                                style: const TextStyle(fontSize: 13)),
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
                                color: ok
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
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
                                Icon(Icons.shopping_cart_rounded,
                                    color: Colors.white.withOpacity(0.50),
                                    size: 15),
                                const SizedBox(width: 6),
                                Text(
                                  'Ve a la Tienda',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.50),
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
  const _RewardChip(this.label, this.color, {this.showCoin = false});
  final String label;
  final Color  color;
  final bool   showCoin;

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
          Text(
            'Se consumirán estos materiales:',
            style: TextStyle(
              color: Colors.white.withOpacity(0.60),
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
                  Text(item?.emoji ?? '❓',
                      style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    '${item?.name ?? req.itemId} × ${req.qty}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
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
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
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
                Text(job.itemReward!.item?.emoji ?? '🎁',
                    style: const TextStyle(fontSize: 18)),
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
          child: Text(
            'Cancelar',
            style: TextStyle(color: Colors.white.withOpacity(0.50)),
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pop(context, true),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                begin: 1.0, end: 1.15,
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
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),

          // Badges de recompensa
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RewardBadge('+${job.coinReward}', const Color(0xFFFFD600), showCoin: true),
              const SizedBox(width: 8),
              _RewardBadge('⭐ +${job.xpReward}', Colors.white60),
              if (job.fuelReward > 0) ...[
                const SizedBox(width: 8),
                _RewardBadge('🚀 +${job.fuelReward}%', const Color(0xFFFF9800)),
              ],
              if (job.itemReward != null) ...[
                const SizedBox(width: 8),
                _RewardBadge(
                  '${job.itemReward!.item?.emoji ?? '🎁'} ×${job.itemReward!.qty}',
                  const Color(0xFFCE93D8),
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
  const _RewardBadge(this.label, this.color, {this.showCoin = false});
  final String label;
  final Color  color;
  final bool   showCoin;

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
