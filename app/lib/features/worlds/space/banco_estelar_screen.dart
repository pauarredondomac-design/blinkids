import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/wallet.dart';
import '../../../data/models/child_goal.dart';
import '../../../shared/providers/wallet_provider.dart';
import '../../../shared/providers/child_goal_provider.dart';
import '../../../shared/providers/question_provider.dart';
import '../../../shared/widgets/screen_tutorial.dart';
import '../../../shared/widgets/coin_display.dart';
import '../../../shared/widgets/activity_player.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC API
// ─────────────────────────────────────────────────────────────────────────────

/// Muestra el Banco Estelar como panel flotante sobre el mapa espacial.
void showBancoEstelarDialog(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Banco Estelar',
    barrierColor: Colors.black.withOpacity(0.65),
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return ScaleTransition(
        scale: Tween<double>(begin: 0.90, end: 1.0).animate(curved),
        child: FadeTransition(opacity: anim, child: child),
      );
    },
    pageBuilder: (ctx, _, __) => const _BEDialogShell(isFullScreen: false),
  );
}

/// Pantalla completa — mantiene la ruta GoRouter /space/banco_estelar activa.
class BancoEstelarScreen extends StatelessWidget {
  const BancoEstelarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/worlds/space/space_background.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.60)),
          ),
          const Center(child: _BEDialogShell(isFullScreen: true)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shell — obtiene datos Supabase y decide qué vista mostrar
// ─────────────────────────────────────────────────────────────────────────────
class _BEDialogShell extends ConsumerWidget {
  const _BEDialogShell({required this.isFullScreen});
  final bool isFullScreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final goalAsync = ref.watch(currentGoalProvider);
    final catsAsync = ref.watch(walletCategoriesProvider);

    void onClose() {
      if (isFullScreen) {
        context.pop();
      } else {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    int savedCoins = 0;
    if (catsAsync is AsyncData<List<WalletCategory>>) {
      try {
        savedCoins = catsAsync.value
            .firstWhere((c) => c.category == WalletCategoryType.guardar)
            .balance;
      } catch (_) {}
    }

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ScreenTutorial(
          tutorialKey: 'banco_estelar_v2',
          steps: const [
            TutorialStep(
              title: '¡Bienvenido al Banco Estelar!',
              body: 'Aquí guardamos las monedas que tienen una misión importante: cumplir tu meta.',
            ),
            TutorialStep(
              title: 'Elige tu meta',
              body: 'Elige un sueño del catálogo. Cada moneda que pongas en "Guardar" en Mi Bolsa te acerca a cumplirlo.',
            ),
            TutorialStep(
              title: 'No es un banco de verdad',
              body: 'Aquí no hay saldo ni intereses — solo tu sueño acercándose, poquito a poco.',
            ),
          ],
          child: SizedBox(
            width: size.width * (isFullScreen ? 0.85 : 0.90),
            height: size.height * (isFullScreen ? 0.85 : 0.88),
            child: goalAsync.when(
              loading: () => const _BEFrame(child: Center(child: CircularProgressIndicator(color: Color(0xFFFFB300)))),
              error: (_, __) => _BEFrame(child: _GoalPicker(savedCoins: savedCoins, onClose: onClose)),
              data: (goal) => goal == null || goal.isCompleted
                  ? _BEFrame(child: _GoalPicker(savedCoins: savedCoins, onClose: onClose, previousGoal: goal))
                  : _BEFrame(child: _VaultView(goal: goal, savedCoins: savedCoins, onClose: onClose)),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Marco visual compartido
// ─────────────────────────────────────────────────────────────────────────────
class _BEFrame extends StatelessWidget {
  const _BEFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF07101F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3A7BD5).withOpacity(0.45), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF4FC3F7).withOpacity(0.18), blurRadius: 30, spreadRadius: 3),
          BoxShadow(color: Colors.black.withOpacity(0.70), blurRadius: 20),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header reutilizable con placa "BANCO ESTELAR"
// ─────────────────────────────────────────────────────────────────────────────
class _BEHeaderBar extends StatelessWidget {
  const _BEHeaderBar({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0A1835), Color(0xFF152B5E), Color(0xFF0A1835)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF4FC3F7).withOpacity(0.55), width: 1.5),
              boxShadow: [BoxShadow(color: const Color(0xFF4FC3F7).withOpacity(0.28), blurRadius: 18, spreadRadius: 1)],
            ),
            child: const Text(
              'BANCO ESTELAR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: 3.5,
                shadows: [Shadow(color: Color(0xB84FC3F7), blurRadius: 12)],
              ),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 3.seconds, color: const Color(0xFF81D4FA).withOpacity(0.35)),
          Positioned(
            right: 0,
            child: GestureDetector(
              onTap: onClose,
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.09),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white70, size: 17),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Selector de meta — primera vez o tras cumplir una meta
// ─────────────────────────────────────────────────────────────────────────────
class _GoalPicker extends ConsumerWidget {
  const _GoalPicker({required this.savedCoins, required this.onClose, this.previousGoal});
  final int savedCoins;
  final VoidCallback onClose;
  final ChildGoal? previousGoal;

  Future<void> _choose(BuildContext context, WidgetRef ref, SavingsGoalOption goal) async {
    await ref.read(childGoalRepositoryProvider).chooseGoal(goal);
    ref.invalidate(currentGoalProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _BEHeaderBar(onClose: onClose),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              children: [
                if (previousGoal != null) ...[
                  Text('${previousGoal!.goalEmoji} ¡Cumpliste tu meta!', textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFFFB300), fontWeight: FontWeight.w900, fontSize: 20, fontFamily: 'Nunito')),
                  const SizedBox(height: 6),
                  const Text('Elige tu próximo sueño', textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontFamily: 'Nunito', fontSize: 13)),
                ] else ...[
                  const Text('🔒', style: TextStyle(fontSize: 44)).animate().scale(begin: const Offset(0.6, 0.6), duration: 500.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 10),
                  const Text('CLONK...', textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  const Text('Bienvenido al Banco Estelar.\nAquí guardamos las monedas que tienen una misión importante.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontFamily: 'Nunito', fontSize: 13, height: 1.4)),
                  const SizedBox(height: 4),
                  const Text('Elige tu sueño:', textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontFamily: 'Nunito', fontSize: 15)),
                ],
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.85,
                  children: [
                    for (final g in savingsGoalCatalog)
                      GestureDetector(
                        onTap: () => _choose(context, ref, g),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D1B3E).withOpacity(0.75),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF4FC3F7).withOpacity(0.35)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(g.emoji, style: const TextStyle(fontSize: 30)),
                              const SizedBox(height: 4),
                              Text(g.name, textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white, fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bóveda — meta activa + progreso + actividad del día
// ─────────────────────────────────────────────────────────────────────────────
class _VaultView extends ConsumerStatefulWidget {
  const _VaultView({required this.goal, required this.savedCoins, required this.onClose});
  final ChildGoal goal;
  final int savedCoins;
  final VoidCallback onClose;

  @override
  ConsumerState<_VaultView> createState() => _VaultViewState();
}

class _VaultViewState extends ConsumerState<_VaultView> {
  bool _showActivities = false;
  bool _celebrated = false;

  @override
  void didUpdateWidget(covariant _VaultView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeCelebrate();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeCelebrate());
  }

  void _maybeCelebrate() {
    if (_celebrated) return;
    if (widget.savedCoins >= widget.goal.goalCost) {
      _celebrated = true;
      ref.read(childGoalRepositoryProvider).markCompleted();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          showDialog<void>(
            context: context,
            builder: (_) => _GoalCompletedDialog(goal: widget.goal),
          ).then((_) => ref.invalidate(currentGoalProvider));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showActivities) {
      return Column(
        children: [
          _BEHeaderBar(onClose: () => setState(() => _showActivities = false)),
          Expanded(
            child: Consumer(builder: (context, ref, __) {
              final activitiesAsync = ref.watch(questionsForModuleProvider('banco_estelar'));
              return activitiesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFFB300))),
                error: (_, __) => const Center(child: Text('No se pudieron cargar las actividades.', style: TextStyle(color: Colors.white70, fontFamily: 'Nunito'))),
                data: (activities) => ActivityPlayer(
                  activities: activities,
                  accentColor: const Color(0xFF4FC3F7),
                ),
              );
            }),
          ),
        ],
      );
    }

    final pct = (widget.savedCoins / widget.goal.goalCost).clamp(0.0, 1.0);

    return Column(
      children: [
        _BEHeaderBar(onClose: widget.onClose),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              children: [
                Text(widget.goal.goalEmoji, style: const TextStyle(fontSize: 64))
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scaleXY(begin: 1.0, end: 1.08, duration: 2000.ms, curve: Curves.easeInOut),
                const SizedBox(height: 4),
                Text(widget.goal.goalName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, fontFamily: 'Nunito')),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 18,
                    backgroundColor: Colors.white.withOpacity(0.10),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFFFB300)),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${widget.savedCoins} de ${widget.goal.goalCost}',
                        style: const TextStyle(color: Colors.white70, fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 5),
                    const AnimatedCoin(size: 14),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Cada moneda que pones en "Guardar" en Mi Bolsa te acerca aquí.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.45), fontFamily: 'Nunito', fontSize: 11)),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => setState(() => _showActivities = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF4FC3F7), Color(0xFF1976D2)]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('⭐', style: TextStyle(fontSize: 18)),
                        SizedBox(width: 8),
                        Text('Actividad del día', style: TextStyle(color: Colors.white, fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GoalCompletedDialog extends StatelessWidget {
  const _GoalCompletedDialog({required this.goal});
  final ChildGoal goal;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF07101F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: const Color(0xFFFFB300).withOpacity(0.5))),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(goal.goalEmoji, style: const TextStyle(fontSize: 56))
                .animate().scale(begin: const Offset(0.5, 0.5), duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: 12),
            const Text('🎉 ¡Meta cumplida!',
                style: TextStyle(color: Color(0xFFFFB300), fontFamily: 'Nunito', fontWeight: FontWeight.w900, fontSize: 22)),
            const SizedBox(height: 8),
            Text('Guardaste lo suficiente para ${goal.goalName}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontFamily: 'Nunito', fontSize: 14)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('¡Elegir nueva meta!', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}
