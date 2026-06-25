import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/wallet.dart';
import '../../../shared/providers/wallet_provider.dart';
import '../../../shared/widgets/screen_tutorial.dart';

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
              'assets/images/worlds/space/space_background.png',
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
// Shell — obtiene datos Supabase y monta el modal
// ─────────────────────────────────────────────────────────────────────────────
class _BEDialogShell extends ConsumerWidget {
  const _BEDialogShell({required this.isFullScreen});
  final bool isFullScreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final cats = ref.watch(walletCategoriesProvider);

    int balance = 0;
    if (cats is AsyncData<List<WalletCategory>>) {
      try {
        balance = cats.value
            .firstWhere((c) => c.category == WalletCategoryType.banco_estelar)
            .balance;
      } catch (_) {}
    }

    void onClose() {
      if (isFullScreen) {
        context.pop();
      } else {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ScreenTutorial(
          tutorialKey: 'banco_estelar',
          steps: const [
            TutorialStep(
              title: '¡Bienvenido al Banco Estelar!',
              body: 'Aquí puedes guardar tus monedas y hacerlas crecer con intereses semanales.',
            ),
            TutorialStep(
              title: 'Tu inversión trabaja por ti',
              body: 'Cuanto más tiempo dejes tus créditos aquí, más intereses recibirás cada semana.',
            ),
            TutorialStep(
              title: 'Misiones financieras',
              body: 'Completa misiones especiales del Banco Estelar para ganar XP y bonos extra.',
            ),
          ],
          child: _BEModal(
            size: size,
            balance: balance,
            isLoading: cats is AsyncLoading,
            onClose: onClose,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modal principal
// ─────────────────────────────────────────────────────────────────────────────
class _BEModal extends StatelessWidget {
  const _BEModal({
    required this.size,
    required this.balance,
    required this.isLoading,
    required this.onClose,
  });

  final Size         size;
  final int          balance;
  final bool         isLoading;
  final VoidCallback onClose;

  static const double _interestPct  = 3.5;
  static const int    _daysInvested = 3;
  static const int    _totalDays    = 7;

  @override
  Widget build(BuildContext context) {
    final mw = size.width  * 0.78;
    final mh = size.height * 0.88;

    return Container(
      width:  mw,
      height: mh,
      decoration: BoxDecoration(
        color: const Color(0xFF07101F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF3A7BD5).withOpacity(0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4FC3F7).withOpacity(0.18),
            blurRadius: 30,
            spreadRadius: 3,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.70),
            blurRadius: 20,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            _BEHeaderBar(onClose: onClose),

            // ── Cuerpo ──────────────────────────────────────────────────────
            if (isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFFFB300)),
                ),
              )
            else
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 58,
                        child: _BELeftCol(
                          balance: balance,
                          daysInvested: _daysInvested,
                          totalDays: _totalDays,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 42,
                        child: _BERightCol(
                          balance:     balance,
                          interestPct: _interestPct,
                          onRetire:    () => _snack(context, 'Retirar fondos'),
                          onIncrement: () => _snack(context, 'Incrementar inversión'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Footer ──────────────────────────────────────────────────────
            _BEFooter(onClose: onClose),
          ],
        ),
      ),
    );
  }

  void _snack(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('🚀 $label — próximamente disponible'),
      backgroundColor: const Color(0xFF0D1B3E),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header: placa "BANCO ESTELAR" + botón ✕
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
          // ── Placa central ──────────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0A1835),
                  Color(0xFF152B5E),
                  Color(0xFF0A1835),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF4FC3F7).withOpacity(0.55),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4FC3F7).withOpacity(0.28),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Text(
              'BANCO ESTELAR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: 3.5,
                shadows: [
                  Shadow(
                    color: const Color(0xFF4FC3F7).withOpacity(0.80),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .shimmer(
                duration: 3.seconds,
                color: const Color(0xFF81D4FA).withOpacity(0.35),
              ),

          // ── Botón cerrar ───────────────────────────────────────────────
          Positioned(
            right: 0,
            child: GestureDetector(
              onTap: onClose,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.09),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.22),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white70,
                  size: 17,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Columna izquierda: secciones 1, 2, 3
// ─────────────────────────────────────────────────────────────────────────────
class _BELeftCol extends StatelessWidget {
  const _BELeftCol({
    required this.balance,
    required this.daysInvested,
    required this.totalDays,
  });
  final int balance;
  final int daysInvested;
  final int totalDays;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // ── 1 Estado de Cuenta ─────────────────────────────────────────
          _SectionCard(
            number: '1',
            numColor: const Color(0xFFFFB300),
            title: 'Estado de Cuenta',
            chip: 'CRÉDITOS',
            child: Row(
              children: [
                const Text('🏆', style: TextStyle(fontSize: 40))
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scaleXY(
                      begin: 1.0, end: 1.09,
                      duration: 2000.ms,
                      curve: Curves.easeInOut,
                    ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Intereses Acumulados',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '+${balance > 0 ? balance.toStringAsFixed(2) : '0.00'}',
                          style: const TextStyle(
                            color: Color(0xFFFFB300),
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 3, left: 5),
                          child: Text('🪙', style: TextStyle(fontSize: 18)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      balance > 0 ? '+5 🪙 esta semana' : 'Empieza a invertir hoy',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── 2 Inversión Activa ─────────────────────────────────────────
          _SectionCard(
            number: '2',
            numColor: const Color(0xFF4FC3F7),
            title: 'Inversión Activa',
            child: Row(
              children: [
                const Text('🔷', style: TextStyle(fontSize: 32))
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .moveY(
                      begin: 0, end: -5,
                      duration: 2200.ms,
                      curve: Curves.easeInOut,
                    ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tiempo de Inversión',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 3),
                      RichText(
                        text: TextSpan(children: [
                          TextSpan(
                            text: '$daysInvested días',
                            style: const TextStyle(
                              color: Color(0xFF4FC3F7),
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: ' / $totalDays días',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 14,
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: daysInvested / totalDays,
                          backgroundColor: Colors.white.withOpacity(0.13),
                          valueColor: const AlwaysStoppedAnimation(
                              Color(0xFF4FC3F7)),
                          minHeight: 7,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── 3 Misiones Financieras ──────────────────────────────────────
          _SectionCard(
            number: '3',
            numColor: const Color(0xFFCE93D8),
            title: 'Misiones Financieras',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF4FC3F7).withOpacity(0.18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Micro-especifico acanual',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.45),
                            fontSize: 9,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Misión: Ahorra 100 C en 3 días',
                          style: TextStyle(
                            color: Color(0xFF4FC3F7),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '⭐ +10 XP + Bonus',
                          style: TextStyle(
                            color: Color(0xFFFFB300),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1B3E).withOpacity(0.60),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF4FC3F7).withOpacity(0.18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Información',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'El Banco Estelar te ayuda a gestionar tus créditos y aumentar tu riqueza estelar de forma segura.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.58),
                            fontSize: 10,
                            height: 1.4,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Columna derecha: edificio 3D + stats + botones
// ─────────────────────────────────────────────────────────────────────────────
class _BERightCol extends StatelessWidget {
  const _BERightCol({
    required this.balance,
    required this.interestPct,
    required this.onRetire,
    required this.onIncrement,
  });
  final int          balance;
  final double       interestPct;
  final VoidCallback onRetire;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Edificio 3D + stats superpuestas ───────────────────────────────
        Expanded(
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/worlds/space/building_bolsa.png',
                  fit: BoxFit.contain,
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .moveY(
                      begin: 0, end: -8,
                      duration: 2800.ms,
                      curve: Curves.easeInOut,
                    ),
              ),
              // Degradado inferior con estadísticas
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF07101F).withOpacity(0.70),
                      const Color(0xFF07101F).withOpacity(0.96),
                    ],
                    stops: const [0.30, 0.65, 1.0],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(8, 32, 8, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tu dinero crece',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+$interestPct%',
                      style: const TextStyle(
                        color: Color(0xFFFFB300),
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      'Semanal',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ── Saldo actual ────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Saldo: $balance 🪙',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(height: 10),

        // ── Botones de acción ───────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _PillButton(
                label: 'Retirar\nFondos',
                icon: Icons.remove_circle_outline_rounded,
                bgColor: const Color(0xFF455A64),
                onTap: onRetire,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PillButton(
                label: 'Incrementar\nInversión',
                icon: Icons.add_circle_outline_rounded,
                bgColor: const Color(0xFFD4830A),
                onTap: onIncrement,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Text(
          'Tu dinero crece mientras descansas',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.35),
            fontSize: 9,
          ),
        ),

        const SizedBox(height: 4),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Footer: botón Volver
// ─────────────────────────────────────────────────────────────────────────────
class _BEFooter extends StatelessWidget {
  const _BEFooter({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: GestureDetector(
          onTap: onClose,
          child: Container(
            width: 180,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(0.22),
                width: 1,
              ),
            ),
            child: const Text(
              'Volver',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card de sección — reutilizable (1, 2, 3)
// ─────────────────────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.number,
    required this.numColor,
    required this.title,
    this.chip,
    required this.child,
  });
  final String  number;
  final Color   numColor;
  final String  title;
  final String? chip;
  final Widget  child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 21,
              height: 21,
              decoration: BoxDecoration(
                color: numColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: numColor.withOpacity(0.50),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  number,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (chip != null) ...[
              const SizedBox(width: 7),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.28),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.18),
                  ),
                ),
                child: Text(
                  chip!,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1B3E).withOpacity(0.75),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.09),
            ),
          ),
          child: child,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Botón de acción en píldora
// ─────────────────────────────────────────────────────────────────────────────
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.onTap,
  });
  final String     label;
  final IconData   icon;
  final Color      bgColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: bgColor.withOpacity(0.40),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                ),
                textAlign: TextAlign.left,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
