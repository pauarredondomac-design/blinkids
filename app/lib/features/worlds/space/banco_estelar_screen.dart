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
import '../../../shared/widgets/blink_character.dart';
import '../../../shared/theme/game_tokens.dart';
import '../misiones/misiones_screen.dart';

// Tasa de crecimiento semanal de "Invertir" — visible como "+3% Semanal".
// Nota: es un valor INFORMATIVO/proyectado. El saldo real (el que se mueve
// en Mi Bolsa) no cambia solo — aquí solo se VE cómo iría creciendo.
const double _weeklyInvestRate = 0.03;

double _investedCurrentValue(WalletCategory cat) {
  final elapsedSeconds = DateTime.now().difference(cat.updatedAt).inSeconds;
  final weeks = elapsedSeconds / (7 * 24 * 3600);
  // Se usan solo semanas COMPLETAS — antes esto crecía en tiempo real con
  // fracciones de semana (ej. 169 monedas × 1.06% a los 2.5 días), pero la
  // tarjeta siempre mostraba la fórmula fija "× 3%", así que el resultado
  // no cuadraba con lo que se veía en pantalla ("169 × 3% = 1"). Al cobrar
  // solo semanas enteras, la fórmula mostrada y el número siempre coinciden.
  final fullWeeks = weeks.floor();
  if (fullWeeks <= 0) return cat.balance.toDouble();
  return cat.balance * math.pow(1 + _weeklyInvestRate, fullWeeks).toDouble();
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
    pageBuilder: (ctx, _, __) =>
        const BancoEstelarDialogShell(isFullScreen: false),
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
                body:
                    'Puedes retirar las ganancias de tu inversión cuando quieras.',
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
                        child: CircularProgressIndicator(
                            color: Color(0xFFFFB300))),
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

    // Dos columnas independientes, como en la referencia:
    //  IZQUIERDA: encabezado + "Cuánto crecieron" + gráfica + "Día X de 7".
    //  DERECHA: "+3% cada semana" + "¿Cómo pasó?" + botón de retirar.
    // Cada columna solo tiene UN elemento flexible (la gráfica a la
    // izquierda, la tarjeta de matemática a la derecha) — todo lo demás es
    // de tamaño natural y se protege con FittedBox, así que Expanded solo
    // tiene que repartir la altura entre 2 cosas por columna, no 5+, lo
    // que lo hace mucho más predecible.
    const gap = 10.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 46, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Columna izquierda ──────────────────────────────────────
          // Proporciones medidas directamente sobre la imagen de referencia
          // (image_2.jpeg, columna izquierda = 790px de alto en esa imagen):
          // header 52px (6.6%), tarjeta "Cuánto crecieron" 202px (25.6%),
          // gráfica 396px (50.1%), fila "Día X de 7" 90px (11.4%). Los gaps
          // NO son parejos: header→tarjeta 28px (3.5%), pero tarjeta→gráfica
          // y gráfica→fila son casi inexistentes (12px y 10px, ~1.5% c/u).
          // Se agarra el alto real disponible con LayoutBuilder y se reparte
          // en esas mismas proporciones, con un clamp mínimo (legibilidad en
          // pantallas compactas) y máximo (no crecer de forma absurda en
          // tablets) — la gráfica sigue siendo el único Expanded, se queda
          // con lo que sobra.
          Expanded(
            flex: 3,
            child: LayoutBuilder(
              builder: (ctx, leftConstraints) {
                final h = leftConstraints.maxHeight;
                final headerH = (h * 0.07).clamp(28.0, 60.0);
                final gap1 = (h * 0.035).clamp(4.0, 24.0);
                final trophyH = (h * 0.26).clamp(64.0, 160.0);
                final gap2 = (h * 0.015).clamp(2.0, 14.0);
                final gap3 = (h * 0.015).clamp(2.0, 12.0);
                final journeyH = (h * 0.11).clamp(40.0, 90.0);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: headerH,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
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
                        ),
                      ),
                    ),
                    SizedBox(height: gap1),
                    SizedBox(
                      height: trophyH,
                      child: _InfoCard(
                        icon: '🏆',
                        iconColor: Colors.white,
                        label: 'Cuánto crecieron',
                        value: '+$invertGain',
                        subtitle: invertGain > 0
                            ? 'Listos para retirar'
                            : 'Empieza a invertir',
                      ),
                    ),
                    SizedBox(height: gap2),
                    Expanded(
                      child: _GrowthChartCard(
                        balance: invertBalance,
                        currentValue: invertCurrent,
                        currentDay: (daysClamped.floor() + 1).clamp(1, 7),
                      ),
                    ),
                    SizedBox(height: gap3),
                    SizedBox(
                      height: journeyH,
                      child: _JourneyProgressRow(
                        currentDay: (daysClamped.floor() + 1).clamp(1, 7),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          // ── Columna derecha ────────────────────────────────────────
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _GrowthBadge(),
                const SizedBox(height: gap),
                Expanded(
                  child: _HowItWorkedCard(
                    balance: invertBalance,
                    rawGain: invertCurrent - invertBalance,
                    roundedGain: invertGain,
                  ),
                ),
                const SizedBox(height: gap),
                _WithdrawAllButton(
                  enabled: invertir != null && invertGain > 0 && !_busy,
                  onTap: invertir == null
                      ? null
                      : () => _collectInvestmentGains(invertir, invertGain),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B3E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      // FittedBox: red de seguridad — si el espacio que le tocó a esta
      // tarjeta es más chico de lo que el contenido necesita, se achica
      // SOLO el contenido de esta tarjeta (nunca el panel completo).
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: GameTokens.textSecondary,
                        fontSize: 11,
                        fontFamily: 'Nunito')),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
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
          ],
        ),
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
    const purple = Color(0xFF7B2FBE);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [purple.withOpacity(0.32), purple.withOpacity(0.14)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: purple.withOpacity(0.55)),
        boxShadow: [BoxShadow(color: purple.withOpacity(0.25), blurRadius: 14)],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎁', style: TextStyle(fontSize: 30))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(
                    begin: 1.0,
                    end: 1.15,
                    duration: 1100.ms,
                    curve: Curves.easeInOut),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tu inversión crece',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        fontFamily: 'Nunito')),
                const Text('+3%',
                    style: TextStyle(
                        color: Color(0xFF69F0AE),
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        fontFamily: 'Nunito')),
                const Text('cada semana ✨',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontFamily: 'Nunito')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta "Así ha crecido tu inversión" — gráfica de 7 días + mensaje de Blink
// ─────────────────────────────────────────────────────────────────────────────
class _GrowthChartCard extends StatelessWidget {
  const _GrowthChartCard({
    required this.balance,
    required this.currentValue,
    required this.currentDay,
  });
  final int balance;
  final double currentValue; // valor exacto (sin redondear) a hoy
  final int currentDay; // 1..7

  @override
  Widget build(BuildContext context) {
    // Proyección solo ilustrativa: si el ciclo llegara completo a 7 días.
    final projectedEnd = balance * (1 + _weeklyInvestRate);
    final total = currentValue.floor();

    return LayoutBuilder(builder: (ctx, chartCardConstraints) {
      return _buildChartCard(balance, total, projectedEnd);
    });
  }

  Widget _buildChartCard(int balance, int total, double projectedEnd) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B3E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      // El bloque de encabezado+valores y la gráfica se reparten el alto
      // REAL de la tarjeta (medido aquí, no fijo) en proporción a lo
      // medido sobre la referencia: ~42% encabezado+valores, resto para
      // la gráfica. Cada bloque va en su propio ClipRect — así, si en el
      // caso más extremo el contenido todavía no cupiera del todo, se
      // recorta DENTRO de su propia caja en vez de pintarse encima de la
      // sección vecina (que era la causa real del traslape visual).
      child: LayoutBuilder(builder: (ctx, cardConstraints) {
        final h = cardConstraints.maxHeight;
        final valueBlockH = (h * 0.42).clamp(50.0, 95.0);
        final midGap = (h * 0.02).clamp(3.0, 10.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: valueBlockH,
              child: ClipRect(
                child: LayoutBuilder(
                  builder: (ctx, c) => FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: c.maxWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Text('📈', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 6),
                              const Text('Así ha crecido tu inversión',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      fontFamily: 'Nunito')),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _ValuePill(
                                        label: 'Monedas invertidas',
                                        value: '$balance',
                                        color: Colors.white,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6),
                                      child: Icon(Icons.arrow_forward_rounded,
                                          size: 18, color: Colors.white38),
                                    ),
                                    Expanded(
                                      child: _ValuePill(
                                        label: 'Monedas totales',
                                        value: '$total',
                                        color: const Color(0xFF69F0AE),
                                        highlight: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color:
                                              Colors.white.withOpacity(0.06),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Text(
                                          '¡Tu dinero está\ntrabajando para ti! 🚀',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'Nunito',
                                              height: 1.15),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    const BlinkCharacterWidget(
                                        width: 26, enableBounce: false),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: midGap),
            Expanded(
              child: ClipRect(
                child: _SevenDayChart(
                  startValue: balance.toDouble(),
                  endValue: projectedEnd,
                  currentDay: currentDay,
                  currentValue: currentValue,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _ValuePill extends StatelessWidget {
  const _ValuePill({
    required this.label,
    required this.value,
    required this.color,
    this.highlight = false,
  });
  final String label;
  final String value;
  final Color color;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                color: GameTokens.textSecondary,
                fontSize: 9.5,
                fontFamily: 'Nunito')),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                    fontFamily: 'Nunito')),
            const SizedBox(width: 4),
            const AnimatedCoin(size: 15),
          ],
        ),
      ],
    );
    if (!highlight) return content;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: content,
    );
  }
}

// Gráfica de línea con 7 puntos (Día 1..7). El día actual se resalta; el
// día 7 lleva un cofre — solo ilustrativo, no representa capitalización
// diaria real (la inversión solo capitaliza en semanas completas).
class _SevenDayChart extends StatelessWidget {
  const _SevenDayChart({
    required this.startValue,
    required this.endValue,
    required this.currentDay,
    required this.currentValue,
  });
  final double startValue;
  final double endValue;
  final int currentDay;
  final double currentValue;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      return CustomPaint(
        size: Size(c.maxWidth, c.maxHeight),
        painter: _ChartPainter(
          startValue: startValue,
          endValue: endValue,
          currentDay: currentDay,
          currentValue: currentValue,
        ),
      );
    });
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.startValue,
    required this.endValue,
    required this.currentDay,
    required this.currentValue,
  });
  final double startValue;
  final double endValue;
  final int currentDay;
  final double currentValue;

  @override
  void paint(Canvas canvas, Size size) {
    const days = 7;
    // Espacio reservado abajo para "Día N" + la píldora "HOY" — se achica
    // solo si la caja es muy chica, y chartH nunca baja de un mínimo, para
    // que los puntos de la línea (yFor) jamás caigan fuera de este lienzo.
    // CustomPaint no recorta su contenido solo: si yFor devolviera un
    // número negativo aquí, la línea se pintaría literalmente encima del
    // widget de arriba (el bloque de valores) en vez de dentro de su caja.
    final labelH = math.min(36.0, size.height * 0.35).clamp(14.0, 36.0);
    final chartH = math.max(size.height - labelH, 16.0);
    final stepX = size.width / (days - 1);

    double valueAt(int day) {
      final t = (day - 1) / (days - 1);
      return startValue + (endValue - startValue) * t;
    }

    final maxVal = math.max(endValue, currentValue);
    final minVal = startValue;
    final range = (maxVal - minVal).abs() < 0.001 ? 1.0 : maxVal - minVal;

    double yFor(double v) {
      final t = (v - minVal) / range;
      final y = chartH - (t * chartH * 0.80) - 6;
      // Nunca fuera de [0, chartH]: red de seguridad final contra el bug
      // de puntos pintándose fuera de este lienzo.
      return y.clamp(4.0, chartH - 2.0);
    }

    final points = <Offset>[];
    for (var d = 1; d <= days; d++) {
      final v = d == currentDay ? currentValue : valueAt(d);
      points.add(Offset((d - 1) * stepX, yFor(v)));
    }

    // Línea de tendencia — un solo trazo verde sólido, como en la
    // referencia (ilustrativa: no representa capitalización diaria real).
    final linePaint = Paint()
      ..color = const Color(0xFF69F0AE)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, linePaint);

    // Guías verticales punteadas — de cada punto baja hasta el eje, como
    // en la referencia.
    final guidePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    for (final p in points) {
      _drawDashedLine(canvas, p, Offset(p.dx, chartH), guidePaint);
    }

    // Puntos (estrella dorada) + etiquetas de día.
    final dayLabelStyle = const TextStyle(
        color: Colors.white70,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        fontFamily: 'Nunito');
    for (var d = 1; d <= days; d++) {
      final p = points[d - 1];
      final isToday = d == currentDay;
      final isLast = d == days;

      if (isLast) {
        _drawEmoji(canvas, '🎁', p, 20);
      } else {
        final r = isToday ? 9.0 : 6.5;
        canvas.drawCircle(
            p,
            r + 3,
            Paint()
              ..color =
                  const Color(0xFFFFD600).withOpacity(isToday ? 0.35 : 0.0));
        canvas.drawCircle(p, r, Paint()..color = const Color(0xFFFFD600));
        _drawEmoji(canvas, '⭐', p, r * 1.5);
      }

      final tp = TextPainter(
        text: TextSpan(text: 'Día $d', style: dayLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(p.dx - tp.width / 2, chartH + 4));

      if (isToday) {
        const hoyStyle = TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            fontFamily: 'Nunito');
        final hoyTp = TextPainter(
          text: const TextSpan(text: 'HOY', style: hoyStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        final pillW = hoyTp.width + 12;
        const pillH = 15.0;
        final pillRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(p.dx, chartH + 20 + pillH / 2),
              width: pillW,
              height: pillH),
          const Radius.circular(8),
        );
        canvas.drawRRect(pillRect, Paint()..color = const Color(0xFF4FC3F7));
        hoyTp.paint(canvas,
            Offset(pillRect.center.dx - hoyTp.width / 2, pillRect.top + 3));
      }
    }
  }

  void _drawEmoji(Canvas canvas, String emoji, Offset center, double size) {
    final tp = TextPainter(
      text: TextSpan(text: emoji, style: TextStyle(fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dashLen = 3.0, gapLen = 2.5;
    final total = (b - a).distance;
    if (total < 1) return;
    final dir = (b - a) / total;
    var dist = 0.0;
    while (dist < total) {
      final segEnd = math.min(dist + dashLen, total);
      canvas.drawLine(a + dir * dist, a + dir * segEnd, paint);
      dist += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.currentValue != currentValue || old.currentDay != currentDay;
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta "¿Cómo pasó?" — desglose de la multiplicación, paso a paso
// ─────────────────────────────────────────────────────────────────────────────
class _HowItWorkedCard extends StatelessWidget {
  const _HowItWorkedCard({
    required this.balance,
    required this.rawGain,
    required this.roundedGain,
  });
  final int balance;
  final double rawGain; // sin redondear (ej. 5.07)
  final int roundedGain; // redondeado hacia abajo (ej. 5)

  @override
  Widget build(BuildContext context) {
    // Antes de que se cumpla la primera semana, rawGain/roundedGain vienen
    // en 0 (no hay ganancia real que cobrar todavía) y la tarjeta se veía
    // vacía. Ahora siempre se muestra el mismo desglose — con la ganancia
    // real si ya existe, o si no con la proyección de "balance × 3%" — para
    // que la tarjeta explique el mecanismo desde el primer día, igual que
    // en la referencia.
    final effectiveRawGain =
        rawGain > 0 ? rawGain : balance * _weeklyInvestRate;
    final effectiveRoundedGain =
        roundedGain > 0 ? roundedGain : effectiveRawGain.floor();
    final rawTotal = balance + effectiveRawGain;
    final roundedTotal = balance + effectiveRoundedGain;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B3E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      // FittedBox: red de seguridad — si el contenido no cabe en el
      // espacio que le tocó a esta tarjeta, se achica SOLO esta tarjeta.
      // Izquierda = fórmula, derecha = resultado redondeado: al ir lado a
      // lado en vez de apilados, cada lado necesita menos alto, así que
      // el texto puede ser más grande dentro del mismo cuadro.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calculate_outlined,
                          size: 21, color: Color(0xFFFFB300)),
                      const SizedBox(width: 9),
                      const Text('¿Cómo pasó?',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              fontFamily: 'Nunito')),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _MathLine('$balance', '×', '3%', '=',
                      effectiveRawGain.toStringAsFixed(2),
                      const Color(0xFF4FC3F7)),
                  const SizedBox(height: 11),
                  _MathLine(
                      '$balance',
                      '+',
                      effectiveRawGain.toStringAsFixed(2),
                      '=',
                      rawTotal.toStringAsFixed(2),
                      const Color(0xFF69F0AE)),
                ],
              ),
              const SizedBox(width: 22),
              VerticalDivider(
                  color: Colors.white.withOpacity(0.12),
                  width: 1,
                  thickness: 1),
              const SizedBox(width: 22),
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 14, color: Color(0xFFFFD600)),
                      const SizedBox(width: 5),
                      SizedBox(
                        width: 100,
                        child: Text('Redondeamos para que sea más fácil',
                            textAlign: TextAlign.left,
                            style: TextStyle(
                                color: GameTokens.textMuted,
                                fontSize: 11,
                                height: 1.2,
                                fontFamily: 'Nunito')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 13, horizontal: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF69F0AE).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFF69F0AE).withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$roundedTotal',
                            style: const TextStyle(
                                color: Color(0xFF69F0AE),
                                fontWeight: FontWeight.w900,
                                fontSize: 32,
                                fontFamily: 'Nunito')),
                        const SizedBox(width: 8),
                        const AnimatedCoin(size: 27),
                        const SizedBox(width: 10),
                        const Text('Monedas',
                            style: TextStyle(
                                color: Color(0xFF69F0AE),
                                fontWeight: FontWeight.w700,
                                fontSize: 19,
                                fontFamily: 'Nunito')),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MathLine extends StatelessWidget {
  const _MathLine(
      this.a, this.op1, this.b, this.op2, this.result, this.resultColor);
  final String a, op1, b, op2, result;
  final Color resultColor;

  @override
  Widget build(BuildContext context) {
    final numStyle = const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 18,
        fontFamily: 'Nunito');
    final opStyle = TextStyle(
        color: GameTokens.textMuted, fontSize: 16, fontFamily: 'Nunito');
    return Row(
      children: [
        Text(a, style: numStyle),
        const SizedBox(width: 7),
        Text(op1, style: opStyle),
        const SizedBox(width: 7),
        Text(b, style: numStyle),
        const SizedBox(width: 7),
        Text(op2, style: opStyle),
        const SizedBox(width: 7),
        Text(result,
            style: numStyle.copyWith(
                color: resultColor, fontWeight: FontWeight.w900, fontSize: 19)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fila "Día X de 7" — hitos del ciclo semanal de inversión
// ─────────────────────────────────────────────────────────────────────────────
class _JourneyProgressRow extends StatelessWidget {
  const _JourneyProgressRow({required this.currentDay});
  final int currentDay; // 1..7

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B3E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          Text('Día $currentDay de 7',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  fontFamily: 'Nunito')),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final day = i + 1;
                final isToday = day == currentDay;
                final isLast = day == 7;
                final isFirst = day == 1;

                if (isLast)
                  return const Text('🎁', style: TextStyle(fontSize: 22));
                if (isToday) {
                  return Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF69F0AE).withOpacity(0.18),
                      border:
                          Border.all(color: const Color(0xFF69F0AE), width: 2),
                    ),
                    alignment: Alignment.center,
                    child: const Text('⭐', style: TextStyle(fontSize: 15)),
                  );
                }
                if (isFirst)
                  return const Text('🌍', style: TextStyle(fontSize: 20));
                return Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white24,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Botón principal — "Sacar mis monedas"
// ─────────────────────────────────────────────────────────────────────────────
class _WithdrawAllButton extends StatelessWidget {
  const _WithdrawAllButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF69F0AE);
    final darker = Color.lerp(color, Colors.black, 0.35)!;

    Widget button = GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          gradient: enabled ? LinearGradient(colors: [color, darker]) : null,
          color: enabled ? null : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
              color: enabled ? Colors.white.withOpacity(0.35) : Colors.white12,
              width: 1),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.45),
                    blurRadius: 16,
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
                size: 18, color: enabled ? Colors.white : Colors.white24),
            const SizedBox(width: 8),
            Text('SACAR MIS MONEDAS',
                style: TextStyle(
                    color: enabled ? Colors.white : Colors.white24,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.4,
                    fontFamily: 'Nunito')),
          ],
        ),
      ),
    );

    if (enabled) {
      button = button.animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(
          begin: 1.0, end: 1.02, duration: 900.ms, curve: Curves.easeInOut);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        button,
        const SizedBox(height: 6),
        Text(
          'Tus monedas estarán listas para usarlas en Mi Bolsa.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: GameTokens.textMuted, fontSize: 9.5, fontFamily: 'Nunito'),
        ),
      ],
    );
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
              style:
                  TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
