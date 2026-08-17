import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/blink_character.dart';
import '../../../shared/widgets/modal_corners.dart';

class DemoCompleteScreen extends StatelessWidget {
  const DemoCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ModalCorners(
        size: 100,
        child: Stack(
        fit: StackFit.expand,
        children: [
          // Fondo
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0D0D2B),
                  Color(0xFF1A1A6E),
                  Color(0xFF0D0D2B)
                ],
              ),
            ),
          ),

          // Estrellas
          IgnorePointer(child: _Stars()),

          // Contenido scrolleable
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: Column(
                children: [
                  const BlinkCharacterWidget(width: 120, enableBounce: true)
                      .animate()
                      .scale(duration: 700.ms, curve: Curves.elasticOut),

                  const SizedBox(height: 12),

                  const Text(
                    '¡Increíble explorador! 🚀',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: Colors.white,
                    ),
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black38,
                            blurRadius: 20,
                            offset: Offset(0, 6)),
                      ],
                    ),
                    child: const Text(
                      '¡Ya viste el Mundo Espacio! 🌌\n\nPara explorar estaciones, completar misiones y ganar monedas de verdad...\n\n¡pídele a tu papá o mamá que active tu cuenta! 💫',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF1A1A2E),
                        height: 1.5,
                      ),
                    ),
                  ).animate().fadeIn(delay: 500.ms),

                  const SizedBox(height: 14),

                  // Cards de desbloqueo
                  const Row(
                    children: [
                      _UnlockCard(emoji: '🏦', label: 'Banco\nEstelar'),
                      SizedBox(width: 8),
                      _UnlockCard(emoji: '⚔️', label: 'Misiones'),
                      SizedBox(width: 8),
                      _UnlockCard(emoji: '💰', label: 'Monedas\nReales'),
                      SizedBox(width: 8),
                      _UnlockCard(emoji: '🎨', label: 'Cosméticos'),
                    ],
                  ).animate().fadeIn(delay: 700.ms),

                  const SizedBox(height: 16),

                  // Botón principal
                  GestureDetector(
                    onTap: () => context.go('/waiting-parent'),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x55FFD700),
                              blurRadius: 16,
                              offset: Offset(0, 4)),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.family_restroom_rounded,
                              color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '¡Pídele a tu papá que active el juego!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(
                      begin: 1.0,
                      end: 1.02,
                      duration: 900.ms,
                      curve: Curves.easeInOut),

                  const SizedBox(height: 10),

                  TextButton.icon(
                    onPressed: () => context.go('/world'),
                    icon: const Icon(Icons.map_rounded,
                        color: Colors.white54, size: 16),
                    label: const Text(
                      'Seguir explorando el mapa',
                      style: TextStyle(
                        color: Colors.white54,
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          children: List.generate(16, (i) {
            final rng = i * 1693 + 17;
            final left = (rng % 100) / 100 * w;
            final top = ((rng * 37) % 100) / 100 * h;
            final radius = 1.0 + (rng % 3).toDouble();
            final opacity = 0.2 + (rng % 5) / 12.0;
            return Positioned(
              left: left,
              top: top,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: radius * 2,
                  height: radius * 2,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _UnlockCard extends StatelessWidget {
  const _UnlockCard({required this.emoji, required this.label});
  final String emoji;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize: 10,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
