import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../data/models/wallet.dart';
import '../../../shared/providers/fuel_provider.dart';
import '../../../shared/providers/wallet_provider.dart';
import '../../../shared/widgets/screen_tutorial.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(currentWalletProvider);
    final categoriesAsync = ref.watch(walletCategoriesProvider);

    return ScreenTutorial(
      tutorialKey: 'wallet',
      steps: const [
        TutorialStep(
          title: '🏠 Mi Bolsa',
          body: 'Aquí guardas tus monedas en 3 categorías: Guardar 🐷, Banco Estelar 🏦 y Gastar 🛒. ¡Ser ordenado es un súper poder!',
        ),
        TutorialStep(
          title: '🪙 ¿Cómo distribuir?',
          body: 'Toca cualquier categoría, mueve el slider y pulsa ¡Guardar! Las monedas se mueven al instante.',
        ),
        TutorialStep(
          title: '↩️ ¿Y si me equivoco?',
          body: 'Sin problema — puedes retirar monedas de una categoría en cualquier momento y redistribuirlas.',
        ),
      ],
      child: Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1565C0), Color(0xFF283593), Color(0xFF1A237E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _Header(walletAsync: walletAsync, categoriesAsync: categoriesAsync),
              const _Subtitle(),
              Expanded(
                child: categoriesAsync.when(
                  data: (cats) {
                    final wallet = walletAsync.valueOrNull;
                    final available = wallet?.totalCoins ?? 0;
                    final totalEver = available + cats.fold<int>(0, (s, c) => s + c.balance);
                    return _CategoriesRow(
                      categories: cats,
                      wallet: wallet,
                      totalEver: totalEver,
                      ref: ref,
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  error: (_, __) => const Center(
                    child: Text(
                      'No se pudo cargar la bolsa',
                      style: TextStyle(color: Colors.white, fontFamily: 'Nunito'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.sm),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({required this.walletAsync, required this.categoriesAsync});
  final AsyncValue<Wallet?> walletAsync;
  final AsyncValue<List<WalletCategory>> categoriesAsync;

  @override
  Widget build(BuildContext context) {
    final available = walletAsync.valueOrNull?.totalCoins ?? 0;
    final allocated = categoriesAsync.valueOrNull
            ?.fold<int>(0, (s, c) => s + c.balance) ??
        0;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.go('/world'),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: AppSizes.xs),
          const Text(
            '🏠 Mi Bolsa',
            style: TextStyle(
              fontSize: AppSizes.fontXl,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontFamily: 'Nunito',
              shadows: [Shadow(blurRadius: 4, color: Colors.black38)],
            ),
          ),
          const Spacer(),
          // Monedas en categorías (secundario)
          if (allocated > 0)
            Container(
              margin: const EdgeInsets.only(right: AppSizes.sm),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
                vertical: AppSizes.xs,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(AppSizes.radiusRound),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('📊', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    '$allocated en categorías',
                    style: const TextStyle(
                      fontSize: AppSizes.fontXs,
                      fontWeight: FontWeight.w600,
                      color: Colors.white60,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ],
              ),
            ),
          // Monedas disponibles (principal)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md,
              vertical: AppSizes.xs,
            ),
            decoration: BoxDecoration(
              color: available > 0
                  ? const Color(0xFFFFC107).withOpacity(0.25)
                  : Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(AppSizes.radiusRound),
              border: Border.all(
                color: available > 0 ? const Color(0xFFFFC107) : Colors.white30,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🪙', style: TextStyle(fontSize: 18)),
                const SizedBox(width: AppSizes.xs),
                Text(
                  '$available disponibles',
                  style: TextStyle(
                    fontSize: AppSizes.fontMd,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontFamily: 'Nunito',
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

class _Subtitle extends StatelessWidget {
  const _Subtitle();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: AppSizes.sm),
      child: Text(
        'Toca una categoría para distribuir tus monedas',
        style: TextStyle(
          color: Colors.white60,
          fontSize: AppSizes.fontMd,
          fontFamily: 'Nunito',
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Categories row
// ─────────────────────────────────────────────
class _CategoriesRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final available = wallet?.totalCoins ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < categories.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.xs),
                child: _CategoryCard(
                  category: categories[i],
                  totalEver: totalEver,
                  available: available,
                  onAdjust: (newBalance) async {
                    final delta = newBalance - categories[i].balance;
                    final newWalletTotal = available - delta;
                    await ref
                        .read(walletRepositoryProvider)
                        .distributeCoins(
                          categoryId: categories[i].id,
                          newCategoryBalance: newBalance,
                          walletId: wallet!.id,
                          newWalletTotal: newWalletTotal,
                        );
                    ref.invalidate(walletCategoriesProvider);
                    ref.invalidate(currentWalletProvider);

                    // Distribuir monedas agrega combustible al cohete 🚀
                    // Solo cuando se agrega (delta > 0), no cuando se retira.
                    if (delta > 0) {
                      // Guardar y Banco Estelar recompensan más (ahorro)
                      final cat = categories[i].category;
                      final fuelAmount = (cat == WalletCategoryType.banco_estelar ||
                                          cat == WalletCategoryType.guardar)
                          ? 5
                          : 3;
                      await ref
                          .read(fuelNotifierProvider.notifier)
                          .addFuel('space', fuelAmount);
                    }
                  },
                )
                    .animate()
                    .fadeIn(delay: (i * 80).ms, duration: 350.ms)
                    .slideY(begin: 0.25, end: 0, curve: Curves.easeOut),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Category card
// ─────────────────────────────────────────────
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.totalEver,
    required this.available,
    required this.onAdjust,
  });

  final WalletCategory category;
  final int totalEver;
  final int available;
  final Future<void> Function(int newBalance) onAdjust;

  // Colores derivados directamente del enum para evitar duplicación
  static Color _dark(WalletCategoryType cat) => Color(cat.colorDarkHex);
  static Color _light(WalletCategoryType cat) => Color(cat.colorLightHex);

  void _openAdjustDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _AdjustDialog(
        category: category,
        available: available,
        onConfirm: (newBalance) => onAdjust(newBalance),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark  = _CategoryCard._dark(category.category);
    final light = _CategoryCard._light(category.category);
    final pct = totalEver > 0 ? (category.balance / totalEver).clamp(0.0, 1.0) : 0.0;
    final pctLabel = totalEver > 0 ? '${(pct * 100).toStringAsFixed(0)}%' : '0%';
    final canTap = available > 0 || category.balance > 0;

    return GestureDetector(
      onTap: canTap ? () => _openAdjustDialog(context) : null,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [light.withOpacity(0.9), dark],
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          boxShadow: [
            BoxShadow(
              color: dark.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: canTap
              ? Border.all(color: Colors.white38, width: 1.5)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(category.category.emoji,
                  style: const TextStyle(fontSize: 38)),
              Text(
                category.category.displayName,
                style: const TextStyle(
                  fontSize: AppSizes.fontMd,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  fontFamily: 'Nunito',
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                category.category.description,
                style: const TextStyle(
                  fontSize: AppSizes.fontXs,
                  color: Colors.white70,
                  fontFamily: 'Nunito',
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSizes.radiusRound),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 7,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pctLabel,
                    style: const TextStyle(
                      fontSize: AppSizes.fontXs,
                      color: Colors.white60,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  Text(
                    '${category.balance}',
                    style: const TextStyle(
                      fontSize: AppSizes.fontXxl,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontFamily: 'Nunito',
                      shadows: [Shadow(blurRadius: 4, color: Colors.black38)],
                    ),
                  ),
                ],
              ),
              if (canTap)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(AppSizes.radiusRound),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        category.balance > 0
                            ? Icons.tune_rounded
                            : Icons.add_circle_outline,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        category.balance > 0 ? 'Ajustar' : 'Distribuir',
                        style: const TextStyle(
                          fontSize: AppSizes.fontXs,
                          color: Colors.white,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
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
}

// ─────────────────────────────────────────────
// Adjust dialog (distribute + withdraw)
// ─────────────────────────────────────────────
class _AdjustDialog extends StatefulWidget {
  const _AdjustDialog({
    required this.category,
    required this.available,
    required this.onConfirm,
  });

  final WalletCategory category;
  final int available;
  final Future<void> Function(int newBalance) onConfirm;

  @override
  State<_AdjustDialog> createState() => _AdjustDialogState();
}

class _AdjustDialogState extends State<_AdjustDialog> {
  late double _sliderValue;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _sliderValue = widget.category.balance.toDouble();
  }

  int get _newBalance => _sliderValue.toInt();
  int get _delta => _newBalance - widget.category.balance;
  int get _maxBalance => widget.category.balance + widget.available;

  Future<void> _confirm() async {
    if (_delta == 0) return;
    setState(() => _saving = true);
    try {
      await widget.onConfirm(_newBalance);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdding = _delta > 0;
    final isWithdrawing = _delta < 0;
    final deltaColor = isAdding
        ? Colors.green[700]!
        : isWithdrawing
            ? Colors.orange[700]!
            : Colors.grey[500]!;
    final deltaLabel = _delta == 0
        ? 'Sin cambios'
        : isAdding
            ? '+$_delta monedas'
            : '${_delta} monedas';

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg,
            vertical: AppSizes.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.category.category.emoji,
                  style: const TextStyle(fontSize: 40)),
              const SizedBox(height: AppSizes.xs),
              Text(
                widget.category.category.displayName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Actual: ${widget.category.balance} 🪙',
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: AppSizes.fontSm)),
                  const SizedBox(width: AppSizes.sm),
                  if (widget.available > 0)
                    Text('• Disponible: ${widget.available} 🪙',
                        style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: AppSizes.fontSm)),
                ],
              ),
              const SizedBox(height: AppSizes.sm),
              // New balance big display
              Text(
                '🪙 $_newBalance',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                ),
              ),
              // Delta indicator
              Text(
                deltaLabel,
                style: TextStyle(
                  fontSize: AppSizes.fontSm,
                  fontWeight: FontWeight.w700,
                  color: deltaColor,
                  fontFamily: 'Nunito',
                ),
              ),
              // Slider
              Slider(
                value: _sliderValue,
                min: 0,
                max: _maxBalance.toDouble(),
                divisions: _maxBalance > 0 ? _maxBalance : 1,
                onChanged: (v) => setState(() => _sliderValue = v),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('0',
                      style:
                          TextStyle(color: Colors.grey[500], fontSize: 12)),
                  Text('$_maxBalance',
                      style:
                          TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
              const SizedBox(height: AppSizes.sm),
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
                      onPressed: _delta != 0 && !_saving ? _confirm : null,
                      style: _delta != 0
                          ? ElevatedButton.styleFrom(
                              backgroundColor: isWithdrawing
                                  ? Colors.orange[700]
                                  : null,
                            )
                          : null,
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isWithdrawing ? '¡Retirar!' : '¡Guardar!'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.xs),
            ],
          ),
        ),
      ),
    );
  }
}
