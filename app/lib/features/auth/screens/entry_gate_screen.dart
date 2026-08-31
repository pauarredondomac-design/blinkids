import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/blink_character.dart';

/// Pantalla "¿Quién va a entrar?" — la app arrancaba directo en modo demo
/// sin preguntar nada, así que ni padres ni niños se daban cuenta de que
/// podían/debían iniciar sesión. Ahora esta pantalla se muestra primero y
/// deja elegir entre padre/niño, con la opción de probar la demo aparte.
class EntryGateScreen extends ConsumerWidget {
  const EntryGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF060618),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF060618),
              Color(0xFF0D0D2B),
              Color(0xFF12124A),
              Color(0xFF0D0D2B),
            ],
            stops: [0.0, 0.35, 0.65, 1.0],
          ),
        ),
        child: Stack(
          children: [
            IgnorePointer(child: _StarField()),
            Positioned(
              left: -60,
              bottom: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFF3D2B6E).withOpacity(0.9),
                    const Color(0xFF3D2B6E).withOpacity(0.0),
                  ]),
                ),
              ),
            ),
            SafeArea(
              // FittedBox(scaleDown) en vez de scroll: el contenido se
              // dibuja a su tamaño "de diseño" (los números de abajo) y se
              // achica entero, proporcionalmente, para caber siempre en
              // pantalla sin scroll — nunca se corta ni queda más grande de
              // lo que cabe. Mismo patrón usado en las pantallas de login.
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final narrow = constraints.maxWidth < 720;
                  final availableWidth = (constraints.maxWidth - 40).clamp(280.0, 1040.0).toDouble();
                  final contentWidth = availableWidth;
                  return Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: narrow
                            ? SizedBox(
                                width: contentWidth,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _BlinkGreeting(compact: true),
                                    const SizedBox(height: 20),
                                    const _RoleCards(),
                                    const SizedBox(height: 14),
                                    const _DemoLink(),
                                    const SizedBox(height: 6),
                                    const _SecurityFooter(),
                                  ],
                                ),
                              )
                            : SizedBox(
                                width: contentWidth,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: _BlinkGreeting(compact: false),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      flex: 6,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const _RoleCards(),
                                          const SizedBox(height: 14),
                                          const _DemoLink(),
                                          const SizedBox(height: 6),
                                          const _SecurityFooter(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
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

// ── Blink + saludo ─────────────────────────────────────────────────────────
class _BlinkGreeting extends StatelessWidget {
  const _BlinkGreeting({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        BlinkCharacterWidget(width: compact ? 150 : 180, enableBounce: true)
            .animate()
            .scale(duration: 700.ms, curve: Curves.elasticOut),
        const SizedBox(height: 14),
        Text(
          '¡Hola,\naventurero!',
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w900,
            fontSize: 32,
            height: 1.1,
            color: Colors.white,
          ),
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
        const SizedBox(height: 10),
        Text(
          'Para empezar tu aventura,\nnecesitamos saber ¿quién va a entrar?',
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w600,
            fontSize: 15,
            height: 1.4,
            color: Colors.white60,
          ),
        ).animate().fadeIn(delay: 300.ms),
      ],
    );
  }
}

// ── Las dos tarjetas de rol ─────────────────────────────────────────────────
class _RoleCards extends StatelessWidget {
  const _RoleCards();

  @override
  Widget build(BuildContext context) {
    final parentCard = _RoleCard(
      color: const Color(0xFF66BB6A),
      glow: const Color(0xFF43A047),
      icon: Icons.diversity_1_rounded,
      badgeIcon: Icons.star_rounded,
      title: 'SOY\nMAMÁ / PAPÁ',
      subtitle: 'Crear cuenta\no iniciar sesión',
      footer: 'Tú gestionas y proteges\nsu experiencia.',
      footerIcon: Icons.shield_outlined,
      onTap: () => context.push('/parent-auth'),
    );
    final childCard = _RoleCard(
      color: const Color(0xFF29B6F6),
      glow: const Color(0xFF0288D1),
      icon: Icons.rocket_launch_rounded,
      badgeIcon: null,
      title: 'SOY\nAVENTURERO',
      subtitle: 'Entrar a mi aventura',
      footer: 'Aquí continúas tu misión\ny ganas recompensas.',
      footerIcon: Icons.shield_moon_outlined,
      onTap: () => context.push('/child-login'),
    );
    return LayoutBuilder(builder: (ctx, c) {
      final stacked = c.maxWidth < 460;
      if (stacked) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [parentCard, const SizedBox(height: 18), childCard],
        );
      }
      return IntrinsicHeight(
        child: Row(
          children: [
            Expanded(child: parentCard),
            const SizedBox(width: 18),
            Expanded(child: childCard),
          ],
        ),
      );
    });
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.color,
    required this.glow,
    required this.icon,
    required this.badgeIcon,
    required this.title,
    required this.subtitle,
    required this.footer,
    required this.footerIcon,
    required this.onTap,
  });

  final Color color;
  final Color glow;
  final IconData icon;
  final IconData? badgeIcon;
  final String title;
  final String subtitle;
  final String footer;
  final IconData footerIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 22, vertical: 26),
              decoration: BoxDecoration(
                color: const Color(0xFF10102E),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: color.withOpacity(0.55), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: glow.withOpacity(0.25),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(icon, color: color, size: 34),
                        if (badgeIcon != null)
                          Positioned(
                            top: 10,
                            right: 8,
                            child: Icon(badgeIcon,
                                color: const Color(0xFFFFD54F), size: 17),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w900,
                      fontSize: 19,
                      height: 1.15,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: Colors.white70,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, glow],
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 22),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(footerIcon, size: 14, color: Colors.white38),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                footer,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  color: Colors.white38,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.15, end: 0);
  }
}

// ── Link a la demo ──────────────────────────────────────────────────────────
class _DemoLink extends StatelessWidget {
  const _DemoLink();

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => context.go('/world'),
      icon: const Icon(Icons.explore_outlined,
          size: 16, color: Colors.white54),
      label: const Text(
        'Solo quiero explorar — probar la demo',
        style: TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: Colors.white54,
        ),
      ),
    );
  }
}

// ── Pie de confianza ─────────────────────────────────────────────────────────
class _SecurityFooter extends StatelessWidget {
  const _SecurityFooter();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline, size: 12, color: Colors.white30),
        SizedBox(width: 6),
        Text(
          'Tu información siempre está segura con nosotros.',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 10.5,
            color: Colors.white30,
          ),
        ),
      ],
    );
  }
}

// ── Campo de estrellas (mismo patrón que splash_screen.dart) ────────────────
class _StarField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          children: List.generate(45, (i) {
            final rng = i * 2971 + 53;
            final left = (rng % 1000) / 1000 * w;
            final top = ((rng * 137) % 1000) / 1000 * h;
            final radius = 0.7 + (rng % 4) * 0.6;
            final opacity = 0.1 + (rng % 6) / 15.0;
            final delay = Duration(milliseconds: (i * 60) % 1000);

            return Positioned(
              left: left,
              top: top,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: radius * 2,
                  height: radius * 2,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                )
                    .animate(
                      onPlay: (c) => c.repeat(reverse: true),
                      delay: delay,
                    )
                    .fadeIn(
                      duration: Duration(milliseconds: 400 + (i * 50) % 600),
                    ),
              ),
            );
          }),
        );
      },
    );
  }
}
