import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/wallet.dart';
import '../../data/models/child_goal.dart';
import '../providers/wallet_provider.dart';
import '../providers/child_goal_provider.dart';
import 'screen_tutorial.dart';
import 'coin_display.dart';
import 'screen_background.dart';
import 'game_icon.dart';
import 'modal_corners.dart';
import '../theme/game_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mis Sueños — el niño elige un sueño de un catálogo visual y lo va cumpliendo
// con las monedas que reparte en "Disfrutar" dentro de Mi Bolsa. Antes vivía
// en Banco Estelar; ahora vive dentro de Mi Bolsa porque la categoría
// "Disfrutar" es la que está relacionada con la meta.
// ─────────────────────────────────────────────────────────────────────────────
Future<void> showGoalDreamDialog(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Mis sueños',
    barrierColor: Colors.black.withOpacity(0.65),
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return ScaleTransition(
        scale: Tween<double>(begin: 0.90, end: 1.0).animate(curved),
        child: FadeTransition(opacity: anim, child: child),
      );
    },
    pageBuilder: (ctx, _, __) => const _GoalDreamShell(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
class _GoalDreamShell extends ConsumerWidget {
  const _GoalDreamShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final goalAsync = ref.watch(currentGoalProvider);
    final catsAsync = ref.watch(walletCategoriesProvider);

    // La meta se financia con lo que el niño puso en "Disfrutar" en Mi Bolsa.
    int fundedCoins = 0;
    if (catsAsync is AsyncData<List<WalletCategory>>) {
      try {
        fundedCoins = catsAsync.value
            .firstWhere((c) => c.category == WalletCategoryType.gastar)
            .balance;
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
      child: Material(
        color: Colors.transparent,
        child: ScreenTutorial(
          tutorialKey: 'mis_suenos_v1',
          steps: const [
            TutorialStep(
              title: '✨ ¡Mis Sueños!',
              body:
                  'Elige algo que de verdad quieras. Cada moneda que pones en '
                  '"Disfrutar" en Mi Bolsa te acerca a conseguirlo.',
            ),
          ],
          child: SizedBox(
            width: size.width * 0.90,
            height: size.height * 0.83,
            child: goalAsync.when(
              loading: () => const _DreamFrame(
                  child: Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFFFB300)))),
              error: (_, __) => _DreamFrame(
                  child: _GoalPickerView(fundedCoins: fundedCoins)),
              data: (goal) => goal == null || goal.isCompleted
                  ? _DreamFrame(
                      child: _GoalPickerView(
                          fundedCoins: fundedCoins, previousGoal: goal))
                  : _DreamFrame(
                      child:
                          _DreamVaultView(goal: goal, fundedCoins: fundedCoins)),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Marco visual — mismo patrón que el resto de pantallas, acento dorado
// (el sueño/meta ya usaba dorado internamente para íconos y barra).
// ─────────────────────────────────────────────────────────────────────────────
class _DreamFrame extends StatelessWidget {
  const _DreamFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ModalCorners(
      onClose: () => Navigator.of(context).pop(),
      title: 'Mis Sueños',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: const Color(0xFFFFB300).withOpacity(0.45), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFFFB300).withOpacity(0.16),
                blurRadius: 30,
                spreadRadius: 3),
            BoxShadow(color: Colors.black.withOpacity(0.70), blurRadius: 20),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: ScreenBackground(child: child),
        ),
      ),
    );
  }
}

const _goalIcons = <String, IconData>{
  'bici': Icons.directions_bike,
  'consola': Icons.sports_esports,
  'balon': Icons.sports_soccer,
  'audifonos': Icons.headphones,
  'patin': Icons.roller_skating,
  'mascota': Icons.pets,
  'libros': Icons.menu_book,
  'mochila': Icons.backpack,
};

// ─────────────────────────────────────────────────────────────────────────────
// Selector de sueño — primera vez o tras cumplir una meta
// ─────────────────────────────────────────────────────────────────────────────
class _GoalPickerView extends ConsumerWidget {
  const _GoalPickerView({required this.fundedCoins, this.previousGoal});
  final int fundedCoins;
  final ChildGoal? previousGoal;

  Future<void> _choose(
      BuildContext context, WidgetRef ref, SavingsGoalOption goal) async {
    await ref.read(childGoalRepositoryProvider).chooseGoal(goal);
    ref.invalidate(currentGoalProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const SizedBox(height: 22),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              children: [
                if (previousGoal != null) ...[
                  Text('${previousGoal!.goalEmoji} ¡Cumpliste tu sueño!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFFFFB300),
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          fontFamily: 'Nunito')),
                  const SizedBox(height: 6),
                  const Text('Elige tu próximo sueño',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: GameTokens.textSecondary,
                          fontFamily: 'Nunito',
                          fontSize: 13)),
                ] else ...[
                  const Text('🎁', style: TextStyle(fontSize: 44))
                      .animate()
                      .scale(
                          begin: const Offset(0.6, 0.6),
                          duration: 500.ms,
                          curve: Curves.elasticOut),
                  const SizedBox(height: 10),
                  const Text('Bienvenido a Mis Sueños',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: GameTokens.textMuted,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 1)),
                  const SizedBox(height: 8),
                  const Text(
                      'Elige algo que de verdad quieras. Cada moneda que pones '
                      'en "Disfrutar" en Mi Bolsa te acerca a conseguirlo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: GameTokens.textSecondary,
                          fontFamily: 'Nunito',
                          fontSize: 13,
                          height: 1.4)),
                  const SizedBox(height: 4),
                  const Text('Elige tu sueño:',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Nunito',
                          fontSize: 15)),
                ],
                const SizedBox(height: 16),
                // 2 filas de 4 (Row+Expanded, no GridView): cada ícono llena
                // TODA su celda vía FittedBox, en vez de quedar chico y fijo
                // (92px) dentro de una celda mucho más grande.
                Column(
                  children: [
                    Row(
                      children: [
                        for (final g in savingsGoalCatalog.take(4))
                          Expanded(
                            child: _GoalTile(
                                goal: g, onTap: () => _choose(context, ref, g)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (final g in savingsGoalCatalog.skip(4).take(4))
                          Expanded(
                            child: _GoalTile(
                                goal: g, onTap: () => _choose(context, ref, g)),
                          ),
                      ],
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
// Celda de un sueño — el ícono se estira con FittedBox para llenar TODA la
// celda disponible (no un tamaño fijo perdido dentro de una celda grande).
// ─────────────────────────────────────────────────────────────────────────────
class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.goal, required this.onTap});
  final SavingsGoalOption goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: AspectRatio(
        aspectRatio: 1,
        child: GestureDetector(
          onTap: onTap,
          child: FittedBox(
            fit: BoxFit.contain,
            child: GameIcon(
              name: goal.key,
              fallback: _goalIcons[goal.key] ?? Icons.star_rounded,
              size: 100,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sueño activo — progreso + actividad del día
// ─────────────────────────────────────────────────────────────────────────────
class _DreamVaultView extends ConsumerStatefulWidget {
  const _DreamVaultView({required this.goal, required this.fundedCoins});
  final ChildGoal goal;
  final int fundedCoins;

  @override
  ConsumerState<_DreamVaultView> createState() => _DreamVaultViewState();
}

class _DreamVaultViewState extends ConsumerState<_DreamVaultView> {
  bool _claiming = false;

  Future<void> _claim() async {
    if (_claiming) return;
    setState(() => _claiming = true);
    await ref.read(childGoalRepositoryProvider).markCompleted();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _GoalCompletedDialog(goal: widget.goal),
    );
    if (mounted) ref.invalidate(currentGoalProvider);
  }

  @override
  Widget build(BuildContext context) {
    final pct = (widget.fundedCoins / widget.goal.goalCost).clamp(0.0, 1.0);
    final canClaim = widget.fundedCoins >= widget.goal.goalCost;

    return Column(
      children: [
        const SizedBox(height: 22),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              children: [
                GameIcon(
                  name: widget.goal.goalKey,
                  fallback:
                      _goalIcons[widget.goal.goalKey] ?? Icons.star_rounded,
                  size: 64,
                  color: const Color(0xFFFFB300),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(
                    begin: 1.0,
                    end: 1.08,
                    duration: 2000.ms,
                    curve: Curves.easeInOut),
                const SizedBox(height: 4),
                Text(widget.goal.goalName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        fontFamily: 'Nunito')),
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
                    Text('${widget.fundedCoins} de ${widget.goal.goalCost}',
                        style: const TextStyle(
                            color: GameTokens.textSecondary,
                            fontFamily: 'Nunito',
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 5),
                    const AnimatedCoin(size: 14),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                    'Cada moneda que pones en "Disfrutar" en Mi Bolsa te acerca aquí.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: GameTokens.textMuted,
                        fontFamily: 'Nunito',
                        fontSize: 11)),
                const SizedBox(height: 20),
                if (canClaim)
                  GestureDetector(
                    onTap: _claiming ? null : _claim,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFFFFB300), Color(0xFFFF8C00)]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFFFFB300).withOpacity(0.40),
                              blurRadius: 14,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: _claiming
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('🎉', style: TextStyle(fontSize: 18)),
                                SizedBox(width: 8),
                                Text('¡Cumplir!',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Nunito',
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15)),
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
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: const Color(0xFFFFB300).withOpacity(0.5))),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GameIcon(
              name: goal.goalKey,
              fallback: _goalIcons[goal.goalKey] ?? Icons.star_rounded,
              size: 56,
              color: const Color(0xFFFFB300),
            ).animate().scale(
                begin: const Offset(0.5, 0.5),
                duration: 400.ms,
                curve: Curves.elasticOut),
            const SizedBox(height: 12),
            const Text('🎉 ¡Sueño cumplido!',
                style: TextStyle(
                    color: Color(0xFFFFB300),
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w900,
                    fontSize: 22)),
            const SizedBox(height: 8),
            Text('Juntaste lo suficiente para ${goal.goalName}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: GameTokens.textSecondary,
                    fontFamily: 'Nunito',
                    fontSize: 14)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('¡Elegir nuevo sueño!',
                  style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}
