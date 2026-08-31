import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../data/models/wallet.dart';
import '../../../data/models/donation_cause.dart';
import '../../../shared/providers/fuel_provider.dart';
import '../../../shared/providers/wallet_provider.dart';
import '../../../shared/providers/donation_provider.dart';
import '../../../shared/providers/character_provider.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/music_provider.dart';
import '../../../shared/providers/sfx_provider.dart';
import '../../../shared/widgets/screen_tutorial.dart';
import '../../../shared/widgets/activity_player.dart';
import '../../../shared/widgets/coin_display.dart';
import '../../../shared/widgets/game_popup.dart';
import '../../../shared/widgets/rocket_launch_overlay.dart';
import '../../../shared/widgets/screen_background.dart';
import '../../../shared/widgets/game_icon.dart';
import '../../../shared/widgets/goal_dream_flow.dart';
import '../../../shared/widgets/modal_corners.dart';
import '../../../shared/widgets/return_to_mission_banner.dart';
import '../../../shared/theme/game_tokens.dart';
import '../../worlds/misiones/misiones_screen.dart';
import '../../worlds/tienda/tienda_screen.dart';
import '../../worlds/space/banco_estelar_screen.dart';

// Valor especial que _AddCoinsDialog devuelve cuando el niño toca "Ver Mis
// Sueños" en vez de repartir monedas — así el diálogo se cierra primero y
// Mis Sueños se abre con el contexto estable de la pantalla (no el del
// diálogo, que ya se desmontó).
const _kOpenGoalDream = 'open_goal_dream';

Future<void> showWalletDialog(BuildContext context) {
  final size = MediaQuery.of(context).size;
  return showGeneralDialog(
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
      insetPadding: const EdgeInsets.fromLTRB(12, 60, 12, 12),
      child: ModalCorners(
        onClose: () => Navigator.of(ctx).pop(),
        title: 'Mi Bolsa',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            width: size.width * 0.92,
            height: size.height * 0.84,
            child: const WalletScreen(),
          ),
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
      onReady: () => maybeShowDailyBuildingQuestion(
        context,
        ref,
        buildingSlug: 'mi_bolsa',
        accentColor: const Color(0xFF4FC3F7),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(children: [
          ScreenBackground(
              child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 38),
                _CoinStackSource(available: available, enabled: true),
                const SizedBox(height: 4),
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
    if (available <= 0) {
      showGamePopup(
        context,
        'No tienes monedas sin repartir todavía 🪙\nGana más en Trabajos o Misiones.',
        accentColor: const Color(0xFFF59E0B),
      );
      return;
    }

    // Igual que Guardar/Invertir/Disfrutar: asigna monedas del pool libre
    // al saldo de Donar. "Elegir causa" (_openDonarCauses) es un paso
    // APARTE que reparte lo que YA está en Donar entre las 3 causas — no
    // toca el pool libre.
    final result = await showDialog<Object>(
      context: context,
      builder: (_) => _AddCoinsDialog(category: category, available: available),
    );
    if (result == _kOpenGoalDream) {
      if (mounted) showGoalDreamDialog(context);
      return;
    }
    if (result is int) await _assignCoins(category, result);
  }

  /// "Elegir causa" — reparte lo que YA está en el saldo de Donar entre las
  /// 3 causas, RESTANDO cada reparto del saldo de Donar (igual que gastar
  /// monedas). Si Donar llega a 0 hay que agregarle más desde el ícono.
  Future<void> _openDonarCauses(WalletCategory category) async {
    if (widget.wallet == null) return;
    if (category.balance <= 0) {
      showGamePopup(
        context,
        'Primero asigna monedas a Donar 💛\nToca el ícono para repartir.',
        accentColor: const Color(0xFFF59E0B),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => _DonarCausesDialog(
        category: category,
        walletId: widget.wallet!.id,
      ),
    );
  }

  Widget _cardFor(WalletCategory cat, int i) {
    return _CategoryDropZone(
      category: cat,
      totalEver: widget.totalEver,
      onCoinDropped: (amount) => _assignCoins(cat, amount),
      onTap: () => _openAddDialog(cat),
      onDonarCausesTap: () => _openDonarCauses(cat),
      ref: widget.ref,
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

    // Una sola fila con las 4 categorías — ahora que cada una es solo un
    // ícono grande (sin tarjeta rectangular), entra cómodo en una línea.
    return Row(
      children: [
        for (int i = 0; i < ordered.length; i++) ...[
          if (i != 0) const SizedBox(width: AppSizes.sm),
          Expanded(child: _cardFor(ordered[i], i)),
        ],
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

  /// Redondeo "amigable" para un niño: sin decimales, entero simple si el
  /// monto es chico, múltiplo de 5 si es grande (ej. 39.5 → 40).
  static int _friendlyRound(double raw) {
    if (raw < 10) return raw.round();
    return (raw / 5).round() * 5;
  }

  /// Los 4 montos arrastrables — 10/25/50% del saldo restante, redondeados
  /// "amigable" con piso de 1 (nunca 0), y 100% siempre el saldo EXACTO
  /// (nunca pasa por la regla de redondeo, para que "Todo" jamás deje una
  /// moneda suelta sin poder repartirse). Los repetidos se deduplican —
  /// con saldos chicos varios tiers pueden colapsar al mismo número.
  List<int> get _tierAmounts {
    if (available <= 0) return const [];
    final tiers = <int>{
      math.max(1, _friendlyRound(available * 0.10)),
      math.max(1, _friendlyRound(available * 0.25)),
      math.max(1, _friendlyRound(available * 0.50)),
      available,
    }.where((v) => v <= available).toList()
      ..sort();
    return tiers;
  }

  @override
  Widget build(BuildContext context) {
    if (available <= 0 || !enabled) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white24),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedCoin(size: 18),
              SizedBox(width: 6),
              Text(
                '¡Ya repartiste todo! 🎉',
                style: TextStyle(
                  color: GameTokens.textSecondary,
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

    final tiers = _tierAmounts;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Arrastra las monedas',
          style: TextStyle(
            color: GameTokens.textSecondary,
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        // FittedBox: si con el tamaño más grande no caben las 4 en
        // pantallas angostas, se reduce proporcionalmente en vez de
        // desbordarse — nunca se rompe el layout.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final amount in tiers) ...[
                _CoinChipDraggable(amount: amount),
                if (amount != tiers.last) const SizedBox(width: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Un chip arrastrable con un monto real de moneda — visual = CoinChip,
/// el mismo componente que ya se usa en todo el juego.
class _CoinChipDraggable extends StatelessWidget {
  const _CoinChipDraggable({required this.amount});
  final int amount;

  @override
  Widget build(BuildContext context) {
    final chip = CoinChip(coins: amount, size: CoinChipSize.md);
    return Draggable<int>(
      data: amount,
      feedback: Material(color: Colors.transparent, child: chip),
      childWhenDragging: Opacity(opacity: 0.35, child: chip),
      child: chip,
    );
  }
}

// ─────────────────────────────────────────────
// Category drop zone — recibe monedas una por una
// ─────────────────────────────────────────────
const _categoryIcons = <String, IconData>{
  'guardar': Icons.shield_rounded,
  'invertir': Icons.rocket_launch_rounded,
  'donar': Icons.favorite_rounded,
  'gastar': Icons.celebration_rounded,
};

// Ilustraciones de Blink por misión (assets/blink/Bolsa) — los nombres de
// archivo traen typos de origen ("isfrutar", "onar"), se respetan tal cual
// están en disco.
const _categoryImages = <String, String>{
  'guardar': 'assets/blink/Bolsa/blink_guardar.png',
  'invertir': 'assets/blink/Bolsa/blink_invertir.png',
  'donar': 'assets/blink/Bolsa/blink_onar.png',
  'gastar': 'assets/blink/Bolsa/blink_isfrutar.png',
};

// A dónde lleva el botón de cada categoría. Donar todavía no tiene destino
// (falta definir con Pau el sistema de asociaciones ficticias) — null =
// botón "Próximamente" sin acción.
void Function(BuildContext)? _destinationFor(WalletCategoryType type) {
  switch (type) {
    case WalletCategoryType.guardar:
      return (ctx) {
        Navigator.of(ctx).pop();
        showTiendaDialog(ctx);
      };
    case WalletCategoryType.invertir:
      return (ctx) {
        Navigator.of(ctx).pop();
        showBancoEstelarDialog(ctx);
      };
    case WalletCategoryType.gastar:
      return (ctx) {
        Navigator.of(ctx).pop();
        showGoalDreamDialog(ctx);
      };
    case WalletCategoryType.donar:
    case WalletCategoryType.banco_estelar:
      return null;
  }
}

String _destinationLabel(WalletCategoryType type) {
  switch (type) {
    case WalletCategoryType.guardar:
      return 'Ir a Tienda';
    case WalletCategoryType.invertir:
      return 'Ir a Banco Estelar';
    case WalletCategoryType.gastar:
      return 'Ver mis metas';
    case WalletCategoryType.donar:
      return 'Elegir causa';
    default:
      return 'Próximamente';
  }
}

class _CategoryDropZone extends StatefulWidget {
  const _CategoryDropZone({
    required this.category,
    required this.totalEver,
    required this.onCoinDropped,
    required this.onTap,
    required this.onDonarCausesTap,
    required this.ref,
  });

  final WalletCategory category;
  final int totalEver;
  final ValueChanged<int> onCoinDropped;
  final VoidCallback onTap;

  /// Solo se usa en la categoría Donar — abre el selector de causas.
  final VoidCallback onDonarCausesTap;
  final WidgetRef ref;

  /// Acento de color por categoría — se conserva como identidad de cada
  /// misión (mismo criterio que los botones de color por acción en
  /// Trabajos/Misiones); ahora solo se usa como halo suave al arrastrar
  /// una moneda encima, ya que el ícono no tiene tarjeta de fondo.
  static Color accent(WalletCategoryType cat) {
    switch (cat) {
      case WalletCategoryType.guardar:
        return const Color(0xFF3B82F6);
      case WalletCategoryType.invertir:
        return const Color(0xFF34D399);
      case WalletCategoryType.donar:
        return const Color(0xFFF59E0B);
      case WalletCategoryType.gastar:
        return const Color(0xFF2DD4BF);
      case WalletCategoryType.banco_estelar:
        return const Color(0xFFCE93D8);
    }
  }

  @override
  State<_CategoryDropZone> createState() => _CategoryDropZoneState();
}

class _CategoryDropZoneState extends State<_CategoryDropZone>
    with SingleTickerProviderStateMixin {
  // Un único AnimationController para toda la vida de la card — nunca se
  // crea uno nuevo por moneda, así que no hay forma de que se acumulen.
  // forward(from: 0) reinicia limpio sin importar en qué punto esté,
  // así que el scale siempre termina exactamente en 1.0.
  // value: 1.0 de entrada — el glow (Tween begin:0.6, end:0.0) se lee en el
  // valor ACTUAL del controller. Sin esto, el estado de reposo (0.0) caía
  // justo en "begin" del tween y el brillo dorado quedaba prendido todo el
  // tiempo en las 4 categorías (nunca llegaba a "end"). Con value:1.0 en
  // reposo el glow ya está en 0, y forward(from:0) lo hace destellar y
  // volver a apagarse cuando cae una moneda.
  late final AnimationController _landCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
    value: 1.0,
  );
  late final Animation<double> _scaleAnim = TweenSequence<double>([
    TweenSequenceItem(
      tween:
          Tween(begin: 1.0, end: 1.07).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween:
          Tween(begin: 1.07, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
      weight: 65,
    ),
  ]).animate(_landCtrl);
  late final Animation<double> _glowAnim = Tween<double>(begin: 0.6, end: 0.0)
      .animate(CurvedAnimation(parent: _landCtrl, curve: Curves.easeOut));

  @override
  void dispose() {
    _landCtrl.dispose();
    super.dispose();
  }

  void _onDrop(int amount) {
    widget.onCoinDropped(amount);
    _landCtrl.forward(from: 0);
    final soundOn = widget.ref.read(musicProvider);
    if (soundOn) widget.ref.read(coinSfxProvider).play();
  }

  @override
  Widget build(BuildContext context) {
    final accent = _CategoryDropZone.accent(widget.category.category);
    final category = widget.category;

    return DragTarget<int>(
      onAcceptWithDetails: (details) => _onDrop(details.data),
      builder: (context, candidate, __) {
        final hovering = candidate.isNotEmpty;
        // Sin tarjeta rectangular — solo el ícono grande, con nombre arriba
        // y monedas abajo. El resaltado al arrastrar es un halo suave, no
        // un rectángulo permanente.
        final card = GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: hovering ? accent.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hovering ? accent.withOpacity(0.55) : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category.category.displayName.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.6,
                    fontFamily: 'Nunito',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${category.balance}',
                  style: const TextStyle(
                    color: GameTokens.gold,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Image.asset(
                  _categoryImages[category.category.name] ?? '',
                  width: 110,
                  height: 110,
                  errorBuilder: (_, __, ___) => GameIcon(
                    name: category.category.name,
                    fallback: _categoryIcons[category.category.name] ??
                        Icons.star_rounded,
                    size: 110,
                  ),
                ),
                const SizedBox(height: 6),
                _DestinationButton(
                  label: _destinationLabel(category.category),
                  accent: accent,
                  // Donar no sale a otra pantalla — reparte lo que ya está
                  // en su saldo entre las 3 causas (onDonarCausesTap), un
                  // paso APARTE de asignar monedas nuevas (widget.onTap).
                  onTap: category.category == WalletCategoryType.donar
                      ? (_) => widget.onDonarCausesTap()
                      : _destinationFor(category.category),
                ),
              ],
            ),
          ),
        );

        // El "cling" prometido en el tutorial: bounce + brillo dorado
        // momentáneo cuando la moneda aterriza. Un solo controller para
        // toda la vida de la card — forward(from: 0) reinicia limpio en
        // cada moneda sin importar si la anterior seguía en curso.
        return AnimatedBuilder(
          animation: _landCtrl,
          child: card,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnim.value,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(GameTokens.cardRadius),
                  boxShadow: _glowAnim.value > 0.01
                      ? [
                          BoxShadow(
                            color: GameTokens.gold.withOpacity(_glowAnim.value),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: child,
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Botón "Ir a..." — lleva a la pantalla donde esa categoría cobra vida
// (Tienda, Banco Estelar, Mis Metas). Toque independiente del ícono de
// arriba (que sigue abriendo el diálogo de repartir monedas).
// ─────────────────────────────────────────────
class _DestinationButton extends StatelessWidget {
  const _DestinationButton({
    required this.label,
    required this.accent,
    required this.onTap,
  });
  final String label;
  final Color accent;
  final void Function(BuildContext)? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: enabled ? () => onTap!(context) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: enabled ? accent.withOpacity(0.16) : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: enabled ? accent.withOpacity(0.55) : Colors.white24),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: enabled ? accent : GameTokens.textMuted,
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito',
            fontSize: 10.5,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Diálogo — agregar la cantidad que el niño quiera (solo suma)
// ─────────────────────────────────────────────
class _AddCoinsDialog extends ConsumerStatefulWidget {
  const _AddCoinsDialog({required this.category, required this.available});
  final WalletCategory category;
  final int available;

  @override
  ConsumerState<_AddCoinsDialog> createState() => _AddCoinsDialogState();
}

class _AddCoinsDialogState extends ConsumerState<_AddCoinsDialog> {
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

    // Pantalla completa (sin scroll): Blink se mueve a un ícono chico en la
    // esquina superior izquierda junto al título, para liberar espacio
    // vertical para el slider y los botones rápidos.
    return Dialog(
      backgroundColor: const Color(0xFF0D1B3E),
      insetPadding: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SizedBox.expand(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.lg, vertical: AppSizes.md),
            child: Column(
              children: [
                Row(
                  children: [
                    Image.asset(
                      _categoryImages[widget.category.category.name] ?? '',
                      width: 44,
                      height: 44,
                      errorBuilder: (_, __, ___) => GameIcon(
                        name: widget.category.category.name,
                        fallback:
                            _categoryIcons[widget.category.category.name] ??
                                Icons.star_rounded,
                        size: 44,
                        color: _accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.category.category.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Nunito',
                              fontSize: AppSizes.fontLg,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tienes ${widget.available} monedas por repartir',
                            style: const TextStyle(
                                color: GameTokens.textSecondary,
                                fontFamily: 'Nunito',
                                fontSize: AppSizes.fontSm),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded,
                          color: GameTokens.textSecondary),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const AnimatedCoin(size: 32),
                    const SizedBox(width: 10),
                    Text(
                      '$amount',
                      style: TextStyle(
                          color: _accent,
                          fontWeight: FontWeight.w900,
                          fontSize: 56,
                          fontFamily: 'Nunito'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.md),
                Slider(
                  value: _amount,
                  min: 1,
                  max: widget.available.toDouble(),
                  divisions: widget.available > 1 ? widget.available - 1 : 1,
                  activeColor: _accent,
                  onChanged: (v) => setState(() => _amount = v),
                ),
                const SizedBox(height: AppSizes.sm),
                Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final q in [1, 5, 10, 25])
                      if (q <= widget.available)
                        _QuickPickChip(
                            label: '$q',
                            accent: _accent,
                            onTap: () =>
                                setState(() => _amount = q.toDouble())),
                    _QuickPickChip(
                        label: 'Todo',
                        accent: _accent,
                        onTap: () => setState(
                            () => _amount = widget.available.toDouble())),
                  ],
                ),
                const Spacer(),
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
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Donar — elegir causa (v1: meta personal, ver donation_cause.dart)
// ─────────────────────────────────────────────
class _DonarCausesDialog extends ConsumerStatefulWidget {
  const _DonarCausesDialog({required this.category, required this.walletId});

  /// Categoría Donar en el momento de abrir el diálogo (saldo inicial,
  /// mientras carga el valor en vivo desde el provider).
  final WalletCategory category;
  final String walletId;

  @override
  ConsumerState<_DonarCausesDialog> createState() => _DonarCausesDialogState();
}

class _DonarCausesDialogState extends ConsumerState<_DonarCausesDialog> {
  bool _busy = false;

  Future<void> _pickCause(DonationCause cause, int remaining) async {
    if (remaining <= 0 || _busy) return;
    final amount = await showDialog<int>(
      context: context,
      builder: (_) => _DonateAmountDialog(cause: cause, available: remaining),
    );
    if (amount == null || amount <= 0 || !mounted) return;

    setState(() => _busy = true);
    try {
      // Registra el progreso de la causa Y resta el monto del saldo de
      // Donar (igual que gastar monedas) — así "Donar" siempre muestra
      // lo que queda por repartir, no el histórico total.
      final user = ref.read(currentRealUserProvider);
      var reachedGoal = false;
      if (user != null) {
        reachedGoal = await ref.read(donationRepositoryProvider).donate(
              userId: user.id,
              causeId: cause.id,
              amount: amount,
              goal: cause.goal,
            );
        ref.invalidate(donationProgressProvider);
      }

      final currentTotal =
          ref.read(currentWalletProvider).valueOrNull?.totalCoins ??
              widget.category.balance;
      await ref.read(walletRepositoryProvider).distributeCoins(
            categoryId: widget.category.id,
            newCategoryBalance: (remaining - amount).clamp(0, remaining),
            walletId: widget.walletId,
            newWalletTotal: currentTotal,
          );
      ref.invalidate(walletCategoriesProvider);

      if (reachedGoal && mounted) {
        await awardXp(ref, 20);
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (_) => _DonationCompleteDialog(cause: cause),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(walletCategoriesProvider);
    final progressAsync = ref.watch(donationProgressProvider);
    final progress = progressAsync.valueOrNull ?? {};
    WalletCategory? liveCategory;
    for (final c in categoriesAsync.valueOrNull ?? const <WalletCategory>[]) {
      if (c.id == widget.category.id) {
        liveCategory = c;
        break;
      }
    }
    final remaining = liveCategory?.balance ?? widget.category.balance;

    return Dialog(
      backgroundColor: const Color(0xFF060618),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        side: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg, vertical: AppSizes.md),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌍', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 6),
              const Text(
                'Desde aquí vemos que en la Tierra\nhay causas que necesitan ayuda',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AnimatedCoin(size: 16),
                  const SizedBox(width: 4),
                  Text('$remaining sin repartir entre causas',
                      style: const TextStyle(
                          color: GameTokens.gold,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ],
              ),
              const SizedBox(height: 12),
              for (final cause in donationCauses) ...[
                _CauseCard(
                  cause: cause,
                  progress: progress[cause.id] ?? DonationCauseProgress.empty,
                  enabled: !_busy && remaining > 0,
                  onTap: () => _pickCause(cause, remaining),
                ),
                if (cause != donationCauses.last) const SizedBox(height: 10),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar',
                    style: TextStyle(
                        color: GameTokens.textMuted, fontFamily: 'Nunito')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CauseCard extends StatelessWidget {
  const _CauseCard({
    required this.cause,
    required this.progress,
    required this.enabled,
    required this.onTap,
  });
  final DonationCause cause;
  final DonationCauseProgress progress;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pct = (progress.amount / cause.goal).clamp(0.0, 1.0);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: GameTokens.bgPanel.withOpacity(0.75),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              Text(cause.emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(cause.label,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Nunito',
                                fontSize: 14)),
                        const Spacer(),
                        Text('${progress.amount}/${cause.goal}',
                            style: const TextStyle(
                                color: GameTokens.gold,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Nunito',
                                fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 8,
                        backgroundColor: Colors.white12,
                        color: const Color(0xFFF59E0B),
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

class _DonateAmountDialog extends StatefulWidget {
  const _DonateAmountDialog({required this.cause, required this.available});
  final DonationCause cause;
  final int available;

  @override
  State<_DonateAmountDialog> createState() => _DonateAmountDialogState();
}

class _DonateAmountDialogState extends State<_DonateAmountDialog> {
  static const _accent = Color(0xFFF59E0B);
  late double _amount;

  @override
  void initState() {
    super.initState();
    _amount = widget.available.clamp(1, widget.available).toDouble();
  }

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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.cause.emoji, style: const TextStyle(fontSize: 46)),
              const SizedBox(height: 6),
              Text(
                widget.cause.label,
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
                style: const TextStyle(
                    color: GameTokens.textSecondary,
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
                    style: const TextStyle(
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
                      onTap: () => setState(
                          () => _amount = widget.available.toDouble())),
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
                      child: const Text('¡Donar!'),
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

class _DonationCompleteDialog extends StatelessWidget {
  const _DonationCompleteDialog({required this.cause});
  final DonationCause cause;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0D1B3E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        side: const BorderSide(color: Color(0xFFF59E0B)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(cause.emoji, style: const TextStyle(fontSize: 56))
                .animate()
                .scale(
                    begin: const Offset(0.6, 0.6),
                    end: const Offset(1, 1),
                    duration: 350.ms,
                    curve: Curves.elasticOut),
            const SizedBox(height: 10),
            const Text('¡Meta cumplida! 🎉',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Nunito',
                    fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              cause.impactMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: GameTokens.textSecondary,
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  height: 1.3),
            ),
            const SizedBox(height: 10),
            const Text('+20 XP',
                style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                    fontSize: 14)),
            const SizedBox(height: AppSizes.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.black87),
                child: const Text('¡Genial!'),
              ),
            ),
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
