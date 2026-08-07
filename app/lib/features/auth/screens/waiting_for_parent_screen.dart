import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/widgets/blink_character.dart';
import '../../../shared/widgets/game_popup.dart';

class WaitingForParentScreen extends StatefulWidget {
  const WaitingForParentScreen({super.key});

  @override
  State<WaitingForParentScreen> createState() => _WaitingForParentScreenState();
}

class _WaitingForParentScreenState extends State<WaitingForParentScreen> {
  bool _checking = false;

  Future<void> _checkIfLinked() async {
    setState(() => _checking = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final data = await Supabase.instance.client
          .from('profiles')
          .select('account_type, pin_hash')
          .eq('id', userId)
          .maybeSingle();

      if (!mounted) return;

      if (data?['account_type'] == 'full') {
        final hasPin = (data?['pin_hash'] as String?)?.isNotEmpty == true;
        if (mounted) context.go(hasPin ? '/enter-pin' : '/setup-pin');
      } else {
        if (mounted) {
          showGamePopup(
            context,
            '¡Tu papá aún no ha activado tu cuenta! Pídele que lo haga.',
            accentColor: const Color(0xFF1A237E),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fondo degradado
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0D0D2B),
                  Color(0xFF1A237E),
                  Color(0xFF0D0D2B)
                ],
              ),
            ),
          ),

          // Estrellas (no interactivas)
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
                    '¡Tu aventura te espera! 🌌',
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
                      'Pídele a tu papá o mamá que activen tu cuenta para poder jugar de verdad.\n\n¡Hay misiones, monedas y aventuras esperándote! 🚀✨',
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

                  // Instrucciones para papá
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Row(
                      children: [
                        Text('👨‍👩‍👧', style: TextStyle(fontSize: 28)),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Para los papás:',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Descarga Blinkids en tu teléfono y entra a "Activar cuenta de hijo" para activar el juego completo.',
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontWeight: FontWeight.w500,
                                  fontSize: 11,
                                  color: Colors.white60,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 700.ms),

                  const SizedBox(height: 16),

                  // Botón principal
                  GestureDetector(
                    onTap: _checking ? null : _checkIfLinked,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
                      child: _checking
                          ? const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  '¡Ya me activaron!',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: Colors.white,
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

                  // Volver al mapa
                  TextButton.icon(
                    onPressed: () => context.go('/world'),
                    icon: const Icon(Icons.map_rounded,
                        color: Colors.white54, size: 16),
                    label: const Text(
                      'Volver al mapa',
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
