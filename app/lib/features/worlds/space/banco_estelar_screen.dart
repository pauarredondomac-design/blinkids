import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/wallet.dart';
import '../../../shared/providers/wallet_provider.dart';
import '../../../shared/widgets/screen_tutorial.dart';
import '../../../shared/widgets/activity_player.dart';
import '../../../shared/widgets/coin_display.dart';
import '../../../shared/widgets/screen_background.dart';
import '../../../shared/widgets/modal_corners.dart';
import '../../../shared/widgets/return_to_mission_banner.dart';
import '../../../shared/theme/game_tokens.dart';
import '../misiones/misiones_screen.dart';

// Tasa de crecimiento semanal de "Invertir" — visible como "+3% Semanal".
// Nota: es un valor INFORMATIVO/proyectado. El saldo real (el que se mueve
// en Mi Bolsa) no cambia solo — aquí solo se VE cómo iría creciendo.
const double _weeklyInvestRate = 0.03;

double _investedCurrentValue(WalletCategory cat) {
  final elapsedSeconds = DateTime.now().difference(cat.updatedAt).inSeconds;
  final weeks = elapsedSeconds / (7 * 24 * 3600);
  if (weeks <= 0) return cat.balance.toDouble();
  return cat.balance * math.pow(1 + _weeklyInvestRate, weeks).toDouble();
}

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC API
// ─────────────────────────────────────────────────────────────────────────────

/// Muestra el Banco Estelar como panel flotante sobre el mapa espacial.
Future<void> showBancoEstelarDialog(BuildContext context) {
  return showGeneralDialog(
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
    pageBuilder: (ctx, _, __) => const BancoEstelarDialogShell(isFullScreen: false),
  );
}

/// Pantalla completa — mantiene la ruta GoRouter /space/banco_estelar activa.
class BancoEstelarScreen extends StatelessWidget {
  const BancoEstelarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: GameTokens.bgDeep,
      body: Center(child: BancoEstelarDialogShell(isFullScreen: true)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shell — obtiene datos Supabase y decide qué vista mostrar
// ─────────────────────────────────────────────────────────────────────────────
class BancoEstelarDialogShell extends ConsumerWidget {
  const BancoEstelarDialogShell({required this.isFullScreen});
  final bool isFullScreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final catsAsync = ref.watch(walletCategoriesProvider);
    final wallet = ref.watch(currentWalletProvider).valueOrNull;

    void onClose() {
      if (isFullScreen) {
        context.pop();
      } else {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
      child: Material(
        color: Colors.transparent,
        child: ScreenTutorial(
          tutorialKey: 'banco_estelar_v4',
          steps: const [
            TutorialStep(
              title: '¡Bienvenido al Banco Estelar!',
              body:
                  'Aquí ves las monedas que mandaste a Invertir desde Mi Bolsa.',
            ),
            TutorialStep(
              title: 'Dales tiempo',
              body:
                  'Lo que inviertes puede ir creciendo con el tiempo. Entre más esperes, más crece.',
            ),
            TutorialStep(
              title: 'Retira lo que ganaste',
              body: 'Puedes retirar las ganancias de tu inversión cuando quieras.',
            ),
          ],
          onReady: () => maybeShowDailyBuildingQuestion(
            context,
            ref,
            buildingSlug: 'banco_estelar',
            questionModuleSlug: 'banco_estelar_diario',
            accentColor: const Color(0xFFFFB300),
          ),
          child: SizedBox(
            width: size.width * (isFullScreen ? 0.85 : 0.90),
            height: size.height * (isFullScreen ? 0.80 : 0.83),
            child: Stack(children: [
              _BEFrame(
              onClose: onClose,
              child: catsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFFB300))),
                error: (_, __) => const Center(
                  child: Text('No se pudo cargar tu información.',
                      style: TextStyle(
                          color: GameTokens.textSecondary,
                          fontFamily: 'Nunito')),
                ),
                data: (cats) =>
                    _AccountDashboard(categories: cats, wallet: wallet),
              ),
              ),
              ReturnToMissionBanner(
                onReturn: () {
                  onClose();
                  showMisionesDialog(context);
                },
              ),
            ]),
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
  const _BEFrame({required this.child, required this.onClose});
  final Widget child;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ModalCorners(
      onClose: onClose,
      title: 'Banco Estelar',
      child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFF3A7BD5).withOpacity(0.45), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF4FC3F7).withOpacity(0.18),
              blurRadius: 30,
              spreadRadius: 3),
          BoxShadow(color: Colors.black.withOpacity(0.70), blurRadius: 20),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ScreenBackground(
          child: Stack(
            children: [
              // Edificio del Banco Estelar de fondo, como en la referencia.
              Positioned(
                right: -30,
                top: -20,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.16,
                    child: Image.asset(
                      'assets/worlds/space/building_bolsa.png',
                      width: 260,
                    ),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Circulito numerado — "①", "②"
// ─────────────────────────────────────────────────────────────────────────────
class _NumberBadge extends StatelessWidget {
  const _NumberBadge(this.n);
  final int n;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFFFB300),
        shape: BoxShape.circle,
      ),
      child: Text('$n',
          style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              fontFamily: 'Nunito')),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard — Banco Estelar es EXCLUSIVO de "Invertir" (lo que el niño
// mandó a invertir desde Mi Bolsa). "Guardar" vive solo en Mi Bolsa: son
// monedas reservadas para después/una meta, no una inversión.
// "Invertir" crece +3% semanal (proyectado); "Retirar Fondos" cobra solo lo
// GENERADO (el capital invertido se queda intacto y sigue creciendo).
// Repartir monedas HACIA una categoría se sigue haciendo solo en Mi Bolsa.
// ─────────────────────────────────────────────────────────────────────────────
class _AccountDashboard extends ConsumerStatefulWidget {
  const _AccountDashboard({required this.categories, required this.wallet});
  final List<WalletCategory> categories;
  final Wallet? wallet;

  @override
  ConsumerState<_AccountDashboard> createState() => _AccountDashboardState();
}

class _AccountDashboardState extends ConsumerState<_AccountDashboard> {
  Timer? _ticker;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Refresca cada segundo para que el valor invertido se vea "crecer".
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  WalletCategory? _catFor(WalletCategoryType type) {
    for (final c in widget.categories) {
      if (c.category == type) return c;
    }
    return null;
  }

  Future<void> _withdraw({
    required WalletCategory category,
    required int amount,
    required int newCategoryBalance,
  }) async {
    final wallet = widget.wallet;
    if (wallet == null || amount <= 0 || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(walletRepositoryProvider).distributeCoins(
            categoryId: category.id,
            newCategoryBalance: newCategoryBalance,
            walletId: wallet.id,
            newWalletTotal: wallet.totalCoins + amount,
          );
      ref.invalidate(walletCategoriesProvider);
      ref.invalidate(currentWalletProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Cobra solo la GANANCIA generada por "Invertir" — el capital invertido
  // (balance) no se toca, así que sigue creciendo desde ahí.
  Future<void> _collectInvestmentGains(
      WalletCategory invertir, int gain) async {
    if (gain <= 0) return;
    await _withdraw(
      category: invertir,
      amount: gain,
      newCategoryBalance: invertir.balance, // capital intacto
    );
    if (mounted) {
      await showDialog<void>(
        context: context,
        builder: (_) => _WithdrawResultDialog(
          title: '¡Ganancias cobradas! 🎉',
          message: 'Cobraste +$gain monedas de intereses.',
          color: const Color(0xFF69F0AE),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final invertir = _catFor(WalletCategoryType.invertir);
    final invertBalance = invertir?.balance ?? 0;
    final invertCurrent =
        invertir != null ? _investedCurrentValue(invertir) : 0.0;
    final invertGain = (invertCurrent - invertBalance).floor();

    final daysSinceInvest = invertir != null
        ? DateTime.now().difference(invertir.updatedAt).inMinutes / (60 * 24)
        : 0.0;
    final daysClamped = daysSinceInvest.clamp(0.0, 7.0);

    return Column(
      children: [
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── ① Estado de Cuenta ─────────────────────────────
                Row(
                  children: [
                    const _NumberBadge(1),
                    const SizedBox(width: 8),
                    const Text('Estado de Cuenta',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            fontFamily: 'Nunito')),
                    const SizedBox(width: 8),
                    const _Tag('CRÉDITOS'),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _InfoCard(
                        icon: '🏆',
                        iconColor: const Color(0xFFFFB300),
                        label: 'Cuánto crecieron',
                        value: '+$invertGain',
                        subtitle: invertGain > 0
                            ? 'Listos para retirar'
                            : 'Empieza a invertir',
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(flex: 2, child: _GrowthBadge()),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _InvestmentCard(
                        balance: invertBalance,
                        gain: invertGain,
                        daysProgress: daysClamped,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _PillButton(
                        label: 'Retirar Fondos',
                        color: const Color(0xFF69F0AE),
                        enabled:
                            invertir != null && invertGain > 0 && !_busy,
                        onTap: invertir == null
                            ? null
                            : () =>
                                _collectInvestmentGains(invertir, invertGain),
                      ),
                    ),
                  ],
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
// Etiqueta pequeña tipo pill (ej. "CRÉDITOS")
// ─────────────────────────────────────────────────────────────────────────────
class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Text(text,
          style: TextStyle(
              color: GameTokens.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              fontFamily: 'Nunito')),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta "Intereses Acumulados" — icono + valor + subtítulo
// ─────────────────────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.subtitle,
  });
  final String icon;
  final Color iconColor;
  final String label;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B3E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 30)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: GameTokens.textSecondary,
                        fontSize: 11,
                        fontFamily: 'Nunito')),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(value,
                        style: TextStyle(
                            color: iconColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            fontFamily: 'Nunito')),
                    const SizedBox(width: 4),
                    const AnimatedCoin(size: 15),
                  ],
                ),
                Text(subtitle,
                    style: TextStyle(
                        color: GameTokens.textMuted,
                        fontSize: 10,
                        fontFamily: 'Nunito')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge "+3% Semanal"
// ─────────────────────────────────────────────────────────────────────────────
class _GrowthBadge extends StatelessWidget {
  const _GrowthBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFB300).withOpacity(0.18),
            const Color(0xFFFFB300).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.45)),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFFFB300).withOpacity(0.25), blurRadius: 14),
        ],
      ),
      child: Column(
        children: [
          const Text('🎁', style: TextStyle(fontSize: 26))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(
                  begin: 1.0, end: 1.15, duration: 1100.ms,
                  curve: Curves.easeInOut),
          const SizedBox(height: 4),
          const Text('+3%',
              style: TextStyle(
                  color: Color(0xFFFFB300),
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  fontFamily: 'Nunito')),
          const Text('Semanal',
              style: TextStyle(
                  color: Colors.white70, fontSize: 10, fontFamily: 'Nunito')),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta "Inversión Activa" — capital + progreso del ciclo semanal
// ─────────────────────────────────────────────────────────────────────────────
class _InvestmentCard extends StatelessWidget {
  const _InvestmentCard(
      {required this.balance, required this.gain, required this.daysProgress});
  final int balance;
  final int gain;
  final double daysProgress; // 0..7

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B3E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('💎', style: TextStyle(fontSize: 30)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Monedas que invertiste',
                    style: TextStyle(
                        color: GameTokens.textSecondary,
                        fontSize: 11,
                        fontFamily: 'Nunito')),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text('$balance',
                        style: const TextStyle(
                            color: Color(0xFF4FC3F7),
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            fontFamily: 'Nunito')),
                    const SizedBox(width: 4),
                    const AnimatedCoin(size: 15),
                  ],
                ),
                if (gain > 0) ...[
                  const SizedBox(height: 3),
                  Text('$balance × 3% = $gain',
                      style: TextStyle(
                          color: const Color(0xFFFFB300).withOpacity(0.90),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          fontFamily: 'Nunito')),
                  const SizedBox(height: 1),
                  Text('$balance + $gain = ${balance + gain}',
                      style: TextStyle(
                          color: const Color(0xFF69F0AE).withOpacity(0.90),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          fontFamily: 'Nunito')),
                ],
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (daysProgress / 7).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.white.withOpacity(0.10),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF4FC3F7)),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                    '${daysProgress.toStringAsFixed(1)} días / 7 días de crecimiento',
                    style: TextStyle(
                        color: GameTokens.textMuted,
                        fontSize: 9,
                        fontFamily: 'Nunito')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Botón pill de acción (Retirar Fondos)
// ─────────────────────────────────────────────────────────────────────────────
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final darker = Color.lerp(color, Colors.black, 0.35)!;

    Widget button = GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        decoration: BoxDecoration(
          gradient: enabled
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, darker],
                )
              : null,
          color: enabled ? null : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color:
                  enabled ? Colors.white.withOpacity(0.35) : Colors.white12,
              width: 1),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.50),
                    blurRadius: 14,
                    spreadRadius: 1,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.arrow_circle_down_rounded,
                size: 17, color: enabled ? Colors.white : Colors.white24),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: enabled ? Colors.white : Colors.white24,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      fontFamily: 'Nunito')),
            ),
          ],
        ),
      ),
    );

    if (enabled) {
      button = button
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(
              begin: 1.0, end: 1.035, duration: 900.ms, curve: Curves.easeInOut);
    }
    return button;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Diálogo — confirmación de retiro exitoso
// ─────────────────────────────────────────────────────────────────────────────
class _WithdrawResultDialog extends StatelessWidget {
  const _WithdrawResultDialog(
      {required this.title, required this.message, required this.color});
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF07101F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withOpacity(0.5)),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Nunito',
                  fontSize: 17)),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: GameTokens.textSecondary,
                  fontFamily: 'Nunito',
                  fontSize: 13)),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(backgroundColor: color),
          child: const Text('¡Genial!',
              style: TextStyle(
                  fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
