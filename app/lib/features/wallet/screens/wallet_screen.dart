import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../data/models/wallet.dart';
import '../../../shared/providers/fuel_provider.dart';
import '../../../shared/providers/wallet_provider.dart';
import '../../../shared/widgets/screen_tutorial.dart';
import '../../../shared/widgets/coin_display.dart';
import '../../../shared/widgets/rocket_launch_overlay.dart';

void showWalletDialog(BuildContext context) {
  final size = MediaQuery.of(context).size;
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Mi Bolsa',
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
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          width: size.width * 0.92,
          height: size.height * 0.88,
          child: const WalletScreen(),
        ),
      ),
    ),
  );
}

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(currentWalletProvider);
    final categoriesAsync = ref.watch(walletCategoriesProvider);

    final wallet = walletAsync.valueOrNull;
    final available = wallet?.totalCoins ?? 0;

    return ScreenTutorial(
      tutorialKey: 'wallet_v2',
      steps: const [
        TutorialStep(
          title: '🎯 Mi Bolsa',
          body:
              'Cada moneda que ganas pasa por aquí primero. Repártela entre 4 misiones: Guardar 🛡, Invertir 🚀, Donar ❤️ y Disfrutar 🎉.',
        ),
        TutorialStep(
          title: '🪙 ¿Cómo reparto?',
          body:
              'Arrastra la pila de monedas hasta la misión que elijas. Una moneda cae a la vez, con su "cling".',
        ),
        TutorialStep(
          title: '✅ Es una decisión',
          body:
              'Una vez que una moneda tiene su misión, se queda ahí — así aprendemos que decidir tiene consecuencia.',
        ),
      ],
      child: Scaffold(
        backgroundColor: const Color(0xFF060B1F),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 4),
              _OrnateHeader(onClose: () => Navigator.of(context).pop()),
              const SizedBox(height: 6),
              _CoinStackSource(available: available, enabled: true),
              const SizedBox(height: 6),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSizes.md, 0, AppSizes.md, AppSizes.sm),
                  child: categoriesAsync.when(
                    data: (cats) {
                      final totalEver = available +
                          cats.fold<int>(0, (s, c) => s + c.balance);
                      return _CategoriesRow(
                        categories: cats,
                        wallet: wallet,
                        totalEver: totalEver,
                        ref: ref,
                      );
                    },
                    loading: () => const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF4FC3F7)),
                    ),
                    error: (_, __) => const Center(
                      child: Text(
                        'No se pudo cargar la bolsa',
                        style: TextStyle(
                            color: Colors.white, fontFamily: 'Nunito'),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.sm),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Cabecera ornamentada — placa dorada con cierre
// ─────────────────────────────────────────────
class _OrnateHeader extends StatelessWidget {
  const _OrnateHeader({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF13203F),
                  Color(0xFF1F3A63),
                  Color(0xFF13203F)
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFFFFD54F).withOpacity(0.75), width: 1.4),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFFFFD54F).withOpacity(0.18),
                    blurRadius: 12,
                    spreadRadius: 1),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('◆',
                    style: TextStyle(color: Color(0xFFFFD54F), fontSize: 10)),
                SizedBox(width: 10),
                Text(
                  'MI BOLSA',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 3,
                    fontFamily: 'Nunito',
                    shadows: [Shadow(color: Color(0xFFFFD54F), blurRadius: 10)],
                  ),
                ),
                SizedBox(width: 10),
                Text('◆',
                    style: TextStyle(color: Color(0xFFFFD54F), fontSize: 10)),
              ],
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(
                duration: 3.seconds,
                color: const Color(0xFFFFD54F).withOpacity(0.25),
              ),
          Positioned(
            right: 0,
            child: GestureDetector(
              onTap: onClose,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF13203F),
                  border: Border.all(
                      color: const Color(0xFFFFD54F).withOpacity(0.7),
                      width: 1.4),
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white70, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Categories row
// ─────────────────────────────────────────────
class _CategoriesRow extends StatefulWidget {
  const _CategoriesRow({
    required this.categories,
    required this.wallet,
    required this.totalEver,
    required this.ref,
  });

  final List<WalletCategory> categories;
  final Wallet? wallet;
  final int totalEver;
  final WidgetRef ref;

  @override
  State<_CategoriesRow> createState() => _CategoriesRowState();
}

class _CategoriesRowState extends State<_CategoriesRow> {
  bool _assigning = false;

  Future<void> _assignOneCoin(WalletCategory category) =>
      _assignCoins(category, 1);

  /// Asigna [amount] monedas del pool libre a [category]. Solo suma —
  /// nunca se puede quitar de una categoría ya asignada.
  Future<void> _assignCoins(WalletCategory category, int amount) async {
    if (_assigning || amount <= 0) return;
    final available = widget.wallet?.totalCoins ?? 0;
    if (available <= 0 || widget.wallet == null) return;
    final toAssign = amount.clamp(1, available);
    setState(() => _assigning = true);
    try {
      await widget.ref.read(walletRepositoryProvider).distributeCoins(
            categoryId: category.id,
            newCategoryBalance: category.balance + toAssign,
            walletId: widget.wallet!.id,
            newWalletTotal: available - toAssign,
          );
      widget.ref.invalidate(walletCategoriesProvider);
      widget.ref.invalidate(currentWalletProvider);

      // Guardar recompensa más combustible (ahorro es la misión más valiosa).
      // Una sola vez por acción, sin importar cuántas monedas se repartieron.
      final fuelAmount =
          category.category == WalletCategoryType.guardar ? 5 : 3;
      final reachedFullFuel = await widget.ref
          .read(fuelNotifierProvider.notifier)
          .addFuel('space', fuelAmount);
      if (reachedFullFuel && mounted) {
        await handleFuelReachedFull(context, widget.ref);
      }
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  Future<void> _openAddDialog(WalletCategory category) async {
    final available = widget.wallet?.totalCoins ?? 0;
    if (available <= 0) return;
    final amount = await showDialog<int>(
      context: context,
      builder: (_) => _AddCoinsDialog(category: category, available: available),
    );
    if (amount != null) await _assignCoins(category, amount);
  }

  Widget _cardFor(WalletCategory cat, int i) {
    return _CategoryDropZone(
      category: cat,
      totalEver: widget.totalEver,
      onCoinDropped: () => _assignOneCoin(cat),
      onTap: () => _openAddDialog(cat),
    )
        .animate()
        .fadeIn(delay: (i * 80).ms, duration: 350.ms)
        .slideY(begin: 0.25, end: 0, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final byType = {for (final c in widget.categories) c.category: c};
    final ordered = assignableWalletCategories
        .map((t) => byType[t])
        .whereType<WalletCategory>()
        .toList();
    if (ordered.length < 4) return const SizedBox.shrink();

    // Cuadrícula 2x2 manual (no GridView): siempre llena exactamente el
    // espacio disponible, sin scroll y sin que las tarjetas queden gigantes.
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _cardFor(ordered[0], 0)),
              const SizedBox(width: AppSizes.sm),
              Expanded(child: _cardFor(ordered[1], 1)),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _cardFor(ordered[2], 2)),
              const SizedBox(width: AppSizes.sm),
              Expanded(child: _cardFor(ordered[3], 3)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Fuente arrastrable — pila de monedas sin repartir
// ─────────────────────────────────────────────
class _CoinStackSource extends StatelessWidget {
  const _CoinStackSource({required this.available, required this.enabled});
  final int available;
  final bool enabled;

  Widget _visual({required bool dragging}) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: available > 0
                ? [const Color(0xFF4A3208), const Color(0xFF241804)]
                : [
                    Colors.white.withOpacity(0.05),
                    Colors.white.withOpacity(0.02)
                  ],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: available > 0
                ? const Color(0xFFFFD54F).withOpacity(dragging ? 1 : 0.85)
                : Colors.white24,
            width: dragging ? 2.2 : 1.6,
          ),
          boxShadow: available > 0
              ? [
                  BoxShadow(
                      color: const Color(0xFFFFD54F)
                          .withOpacity(dragging ? 0.45 : 0.22),
                      blurRadius: dragging ? 16 : 8,
                      spreadRadius: 1)
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AnimatedCoin(size: 18),
            const SizedBox(width: 6),
            Text(
              available > 0
                  ? '$available monedas por repartir'
                  : '¡Ya repartiste todo! 🎉',
              style: TextStyle(
                color: available > 0 ? const Color(0xFFFFD54F) : Colors.white70,
                fontWeight: FontWeight.w800,
                fontFamily: 'Nunito',
                fontSize: AppSizes.fontSm,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (available <= 0 || !enabled) return _visual(dragging: false);
    return Draggable<int>(
      data: 1,
      feedback:
          Material(color: Colors.transparent, child: _visual(dragging: true)),
      childWhenDragging:
          Opacity(opacity: 0.35, child: _visual(dragging: false)),
      child: _visual(dragging: false),
    );
  }
}

// ─────────────────────────────────────────────
// Category drop zone — recibe monedas una por una
// ─────────────────────────────────────────────
class _CategoryDropZone extends StatelessWidget {
  const _CategoryDropZone({
    required this.category,
    required this.totalEver,
    required this.onCoinDropped,
    required this.onTap,
  });

  final WalletCategory category;
  final int totalEver;
  final VoidCallback onCoinDropped;
  final VoidCallback onTap;

  static const _cut = 16.0;

  /// Gradiente tipo gema por categoría — mismo espíritu visual en todas
  /// las "casas" del juego, pero cada misión con su propia piedra preciosa.
  static List<Color> _gemColors(WalletCategoryType cat) {
    switch (cat) {
      case WalletCategoryType.guardar:
        return const [Color(0xFF3B82F6), Color(0xFF0F2A63)];
      case WalletCategoryType.invertir:
        return const [Color(0xFF34D399), Color(0xFF0B4A32)];
      case WalletCategoryType.donar:
        return const [Color(0xFFF59E0B), Color(0xFF5C3A05)];
      case WalletCategoryType.gastar:
        return const [Color(0xFF2DD4BF), Color(0xFF0A4A45)];
      case WalletCategoryType.banco_estelar:
        return const [Color(0xFFCE93D8), Color(0xFF4A148C)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _gemColors(category.category);
    final pct =
        totalEver > 0 ? (category.balance / totalEver).clamp(0.0, 1.0) : 0.0;
    final pctLabel = '${(pct * 100).toStringAsFixed(0)}%';

    return DragTarget<int>(
      onAcceptWithDetails: (_) => onCoinDropped(),
      builder: (context, candidate, __) {
        final hovering = candidate.isNotEmpty;
        return GestureDetector(
          onTap: onTap,
          child: ClipPath(
            clipper: const _GemClipper(_cut),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GemPainter(
                      colors: colors,
                      borderColor: hovering
                          ? Colors.white
                          : const Color(0xFFFFD54F).withOpacity(0.75),
                      borderWidth: hovering ? 3 : 2,
                      cut: _cut,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                    child: Center(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Icono con halo
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [
                                Colors.white.withOpacity(0.30),
                                Colors.white.withOpacity(0.02)
                              ]),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.55),
                                  width: 1.3),
                            ),
                            child: Center(
                              child: Text(category.category.emoji,
                                  style: const TextStyle(fontSize: 21)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  category.category.displayName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    fontFamily: 'Nunito',
                                    shadows: [
                                      Shadow(
                                          blurRadius: 3, color: Colors.black45)
                                    ],
                                  ),
                                ),
                                Text(
                                  category.category.description,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white.withOpacity(0.80),
                                    fontFamily: 'Nunito',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: pct,
                                          backgroundColor:
                                              Colors.black.withOpacity(0.30),
                                          valueColor:
                                              const AlwaysStoppedAnimation<
                                                  Color>(Colors.white),
                                          minHeight: 5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      pctLabel,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: 'Nunito'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                _GoldCoinPill(balance: category.balance),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Recorte "gema" con esquinas cortadas
// ─────────────────────────────────────────────
Path _gemPath(Size size, double cut) {
  final w = size.width, h = size.height;
  return Path()
    ..moveTo(cut, 0)
    ..lineTo(w - cut, 0)
    ..lineTo(w, cut)
    ..lineTo(w, h - cut)
    ..lineTo(w - cut, h)
    ..lineTo(cut, h)
    ..lineTo(0, h - cut)
    ..lineTo(0, cut)
    ..close();
}

class _GemClipper extends CustomClipper<Path> {
  const _GemClipper(this.cut);
  final double cut;
  @override
  Path getClip(Size size) => _gemPath(size, cut);
  @override
  bool shouldReclip(covariant _GemClipper oldClipper) => oldClipper.cut != cut;
}

class _GemPainter extends CustomPainter {
  _GemPainter(
      {required this.colors,
      required this.borderColor,
      required this.borderWidth,
      required this.cut});
  final List<Color> colors;
  final Color borderColor;
  final double borderWidth;
  final double cut;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _gemPath(size, cut);
    final rect = Offset.zero & size;

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors)
            .createShader(rect),
    );
    // brillo diagonal para dar sensación de piedra pulida
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withOpacity(0.22), Colors.transparent],
          stops: const [0.0, 0.55],
        ).createShader(rect),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _GemPainter oldDelegate) =>
      oldDelegate.colors != colors ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.borderWidth != borderWidth;
}

// ─────────────────────────────────────────────
// Píldora dorada con el saldo — como una moneda de recompensa
// ─────────────────────────────────────────────
class _GoldCoinPill extends StatelessWidget {
  const _GoldCoinPill({required this.balance});
  final int balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFFFE082), Color(0xFFB8860B)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6B4A00), width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.30),
              blurRadius: 3,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AnimatedCoin(size: 15),
          const SizedBox(width: 5),
          Text(
            '$balance',
            style: const TextStyle(
                color: Color(0xFF3E2400),
                fontWeight: FontWeight.w900,
                fontSize: 13,
                fontFamily: 'Nunito'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Diálogo — agregar la cantidad que el niño quiera (solo suma)
// ─────────────────────────────────────────────
class _AddCoinsDialog extends StatefulWidget {
  const _AddCoinsDialog({required this.category, required this.available});
  final WalletCategory category;
  final int available;

  @override
  State<_AddCoinsDialog> createState() => _AddCoinsDialogState();
}

class _AddCoinsDialogState extends State<_AddCoinsDialog> {
  late double _amount;

  @override
  void initState() {
    super.initState();
    _amount = widget.available.clamp(1, widget.available).toDouble();
  }

  Color get _accent => Color(widget.category.category.colorLightHex);

  @override
  Widget build(BuildContext context) {
    final amount = _amount.round();
    return Dialog(
      backgroundColor: const Color(0xFF0D1B3E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        side: BorderSide(color: _accent.withOpacity(0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg, vertical: AppSizes.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.category.category.emoji,
                style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 6),
            Text(
              widget.category.category.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
                fontSize: AppSizes.fontLg,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tienes ${widget.available} monedas por repartir',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontFamily: 'Nunito',
                  fontSize: AppSizes.fontSm),
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AnimatedCoin(size: 26),
                const SizedBox(width: 8),
                Text(
                  '$amount',
                  style: TextStyle(
                      color: _accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 40,
                      fontFamily: 'Nunito'),
                ),
              ],
            ),
            Slider(
              value: _amount,
              min: 1,
              max: widget.available.toDouble(),
              divisions: widget.available > 1 ? widget.available - 1 : 1,
              activeColor: _accent,
              onChanged: (v) => setState(() => _amount = v),
            ),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final q in [1, 5, 10, 25])
                  if (q <= widget.available)
                    _QuickPickChip(
                        label: '$q',
                        accent: _accent,
                        onTap: () => setState(() => _amount = q.toDouble())),
                _QuickPickChip(
                    label: 'Todo',
                    accent: _accent,
                    onTap: () =>
                        setState(() => _amount = widget.available.toDouble())),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(amount),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.black87),
                    child: const Text('¡Agregar!'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.xs),
          ],
        ),
      ),
    );
  }
}

class _QuickPickChip extends StatelessWidget {
  const _QuickPickChip(
      {required this.label, required this.accent, required this.onTap});
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withOpacity(0.5)),
        ),
        child: Text(label,
            style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w700,
                fontFamily: 'Nunito',
                fontSize: 12)),
      ),
    );
  }
}
