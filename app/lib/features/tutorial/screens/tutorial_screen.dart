import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/repositories/wallet_repository.dart';
import '../../../data/services/supabase_service.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/blink_character.dart';

// ─── Pasos del tutorial ───────────────────────────────────────────────────────
class _TutorialStep {
  const _TutorialStep({required this.text, required this.bg});
  final String text;
  final List<Color> bg;
}

const _steps = [
  _TutorialStep(
    text: '¡Hola! Soy Blink, tu guía en Blinkids. ¡Estoy muy emocionado de conocerte!',
    bg: [Color(0xFF0D0D2B), Color(0xFF1A237E)],
  ),
  _TutorialStep(
    text: 'Aquí aprenderás a ahorrar, invertir y manejar tus monedas como todo un experto financiero.',
    bg: [Color(0xFF1A237E), Color(0xFF4A148C)],
  ),
  _TutorialStep(
    text: 'Explora el Mundo Espacio, completa misiones y gana monedas. ¡Cada decisión cuenta!',
    bg: [Color(0xFF4A148C), Color(0xFF1A1A2E)],
  ),
  _TutorialStep(
    text: 'Tu bolsa tiene 5 categorías: Ahorro, Inversión, Emergencia, Gastos y Metas. ¡Aprende a distribuir!',
    bg: [Color(0xFF1A1A2E), Color(0xFF0D2B1A)],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// TutorialScreen
// ─────────────────────────────────────────────────────────────────────────────
class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key});

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  int  _step         = 0;
  bool _isCompleting = false;
  bool _typingDone   = false;

  // Avanzar al siguiente paso o completar
  void _advance() {
    if (!_typingDone) {
      // Si el texto aún está escribiéndose, forzar fin
      setState(() => _typingDone = true);
      return;
    }
    if (_step < _steps.length - 1) {
      setState(() {
        _step++;
        _typingDone = false;
      });
    } else {
      _complete();
    }
  }

  Future<void> _complete() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _isCompleting = true);
    try {
      await Future.wait([
        supabase.from('tutorial_progress').upsert(
          {
            'user_id': user.id,
            'current_step': _steps.length,
            'is_completed': true,
            'completed_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'user_id',
        ),
        WalletRepository().awardStarterCoins(user.id, 200),
      ]);
    } catch (_) {
      // Si falla el registro DB, navegamos igual.
    } finally {
      if (mounted) context.go('/world');
    }
  }

  @override
  Widget build(BuildContext context) {
    final step   = _steps[_step];
    final isLast = _step == _steps.length - 1;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: step.bg,
          ),
        ),
        child: GestureDetector(
          onTap: _advance,
          behavior: HitTestBehavior.opaque,
          child: SafeArea(
            child: Stack(
              children: [
                // ── Estrellas de fondo ──────────────────────────────────────
                ...List.generate(18, (i) => _Star(seed: i)),

                // ── Indicador de pasos (arriba centro) ─────────────────────
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_steps.length, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        width: i == _step ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _step
                              ? Colors.white
                              : Colors.white30,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),

                // ── Blink grande arriba + globo abajo ──────────────────────
                Positioned.fill(
                  top: 50, // debajo del indicador de pasos
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Blink grande con rebote
                      BlinkCharacterWidget(
                        width: 200,
                        enableBounce: true,
                      ).animate(key: ValueKey('blink_$_step'))
                        .scale(
                          begin: const Offset(0.7, 0.7),
                          end:   const Offset(1.0, 1.0),
                          duration: 500.ms,
                          curve: Curves.elasticOut,
                        ),

                      const SizedBox(height: 12),

                      // Globo de texto centrado
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: _SpeechBubble(
                          key: ValueKey(_step),
                          text: step.text,
                          onDone: () {
                            if (mounted) setState(() => _typingDone = true);
                          },
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Hint "toca para continuar"
                      AnimatedOpacity(
                        opacity: _typingDone ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 400),
                        child: Text(
                          isLast
                              ? (_isCompleting ? '...' : 'Toca para comenzar 🚀')
                              : 'Toca para continuar...',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Globo de diálogo con texto tipo máquina de escribir
// ─────────────────────────────────────────────────────────────────────────────
class _SpeechBubble extends StatefulWidget {
  const _SpeechBubble({
    super.key,
    required this.text,
    required this.onDone,
  });
  final String text;
  final VoidCallback onDone;

  @override
  State<_SpeechBubble> createState() => _SpeechBubbleState();
}

class _SpeechBubbleState extends State<_SpeechBubble> {
  String _displayed = '';
  int    _charIndex = 0;

  @override
  void initState() {
    super.initState();
    _typeNext();
  }

  void _typeNext() {
    if (!mounted) return;
    if (_charIndex >= widget.text.length) {
      widget.onDone();
      return;
    }
    setState(() {
      _displayed = widget.text.substring(0, _charIndex + 1);
      _charIndex++;
    });
    // Velocidad: 28 ms por carácter
    Future.delayed(const Duration(milliseconds: 28), _typeNext);
  }

  // Si el padre pide mostrar todo de golpe
  @override
  void didUpdateWidget(_SpeechBubble old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _displayed = '';
      _charIndex = 0;
      _typeNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // Globo
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 20,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            _displayed,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: Color(0xFF1A1A2E),
              height: 1.5,
            ),
          ),
        ),
        // Cola del globo apuntando hacia arriba (hacia Blink)
        Positioned(
          top: -13,
          child: CustomPaint(
            size: const Size(24, 16),
            painter: _BubbleTailPainterUp(),
          ),
        ),
      ],
    )
        .animate(key: ValueKey(widget.text))
        .fadeIn(duration: 300.ms)
        .slideY(begin: -0.08, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cola del globo (triángulo hacia abajo)
// ─────────────────────────────────────────────────────────────────────────────
// Cola apuntando hacia arriba (triángulo con punta hacia arriba)
class _BubbleTailPainterUp extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shadow = Paint()
      ..color = Colors.black26
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final paint = Paint()..color = Colors.white;
    final path  = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, 0)
      ..close();
    canvas.drawPath(path, shadow);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Botón de acción (siguiente / iniciar aventura)
// ─────────────────────────────────────────────────────────────────────────────
class _TapButton extends StatelessWidget {
  const _TapButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isLoading = false,
  });
  final String   label;
  final IconData icon;
  final VoidCallback onTap;
  final bool     isLoading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.secondary, AppColors.secondaryDark],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(icon, color: Colors.white, size: 20),
                ],
              ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(begin: 1.0, end: 1.04, duration: 900.ms, curve: Curves.easeInOut);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Estrella decorativa de fondo
// ─────────────────────────────────────────────────────────────────────────────
class _Star extends StatelessWidget {
  const _Star({required this.seed});
  final int seed;

  @override
  Widget build(BuildContext context) {
    final size   = MediaQuery.of(context).size;
    final rng    = seed * 1693 + 17;
    final left   = (rng % 100) / 100 * size.width;
    final top    = ((rng * 37) % 100) / 100 * (size.height * 0.65);
    final radius = 1.5 + (rng % 3).toDouble();
    final opacity = 0.3 + (rng % 5) / 10.0;

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
        ),
      )
          .animate(
            onPlay: (c) => c.repeat(reverse: true),
            delay: Duration(milliseconds: (seed * 317) % 1500),
          )
          .fadeIn(duration: Duration(milliseconds: 800 + (seed * 200) % 600)),
    );
  }
}
