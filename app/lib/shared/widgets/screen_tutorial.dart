import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'blink_character.dart';

class TutorialStep {
  const TutorialStep({required this.title, required this.body});
  final String title;
  final String body;
}

/// Muestra un tutorial la primera vez que el usuario entra a una pantalla.
/// El estado se guarda en Supabase (columna tutorials_seen de profiles).
/// Layout: Blink esquina inferior-izquierda + globo de texto a la derecha.
class ScreenTutorial extends StatefulWidget {
  const ScreenTutorial({
    super.key,
    required this.tutorialKey,
    required this.steps,
    required this.child,
  });

  final String             tutorialKey;
  final List<TutorialStep> steps;
  final Widget             child;

  @override
  State<ScreenTutorial> createState() => _ScreenTutorialState();
}

class _ScreenTutorialState extends State<ScreenTutorial> {
  int   _step      = 0;
  bool? _show;          // null = cargando
  bool  _typingDone = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _show = false);
      return;
    }
    try {
      final data = await client
          .from('profiles')
          .select('tutorials_seen')
          .eq('id', userId)
          .maybeSingle();
      final map  = (data?['tutorials_seen'] as Map<String, dynamic>?) ?? {};
      final seen = map[widget.tutorialKey] == true;
      if (mounted) setState(() => _show = !seen);
    } catch (_) {
      if (mounted) setState(() => _show = false);
    }
  }

  Future<void> _dismiss() async {
    if (mounted) setState(() => _show = false);
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) return;
    try {
      await client.rpc('mark_tutorial_seen', params: {'p_key': widget.tutorialKey});
    } catch (_) {}
  }

  void _advance() {
    if (!_typingDone) {
      setState(() => _typingDone = true);
      return;
    }
    if (_step < widget.steps.length - 1) {
      setState(() { _step++; _typingDone = false; });
    } else {
      _dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_show != true) return widget.child;

    final step   = widget.steps[_step];
    final isLast = _step == widget.steps.length - 1;

    return Stack(
      children: [
        widget.child,

        // Fondo oscuro semitransparente
        Positioned.fill(
          child: GestureDetector(
            onTap: _advance,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.black.withValues(alpha: 0.55)),
          ),
        ),

        // Blink esquina inferior-izquierda + globo a la derecha
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: GestureDetector(
            onTap: _advance,
            behavior: HitTestBehavior.opaque,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Blink
                BlinkCharacterWidget(
                  width: 140,
                  enableBounce: true,
                ),

                // Globo a la derecha
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 24, bottom: 52),
                    child: _Bubble(
                      key: ValueKey('${widget.tutorialKey}_$_step'),
                      step: step,
                      stepIndex: _step,
                      totalSteps: widget.steps.length,
                      isLast: isLast,
                      typingDone: _typingDone,
                      onTypingDone: () {
                        if (mounted) setState(() => _typingDone = true);
                      },
                      onAdvance: _advance,
                    ),
                  ),
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
// Globo con texto tipo máquina de escribir
// ─────────────────────────────────────────────────────────────────────────────
class _Bubble extends StatefulWidget {
  const _Bubble({
    super.key,
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.isLast,
    required this.typingDone,
    required this.onTypingDone,
    required this.onAdvance,
  });
  final TutorialStep step;
  final int          stepIndex;
  final int          totalSteps;
  final bool         isLast;
  final bool         typingDone;
  final VoidCallback onTypingDone;
  final VoidCallback onAdvance;

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> {
  String _displayed = '';
  int    _charIndex = 0;
  late String _fullText;

  @override
  void initState() {
    super.initState();
    _fullText = '${widget.step.title}\n\n${widget.step.body}';
    _typeNext();
  }

  @override
  void didUpdateWidget(_Bubble old) {
    super.didUpdateWidget(old);
    // Si el padre forzó typingDone, mostrar texto completo
    if (!old.typingDone && widget.typingDone && _charIndex < _fullText.length) {
      setState(() {
        _displayed = _fullText;
        _charIndex = _fullText.length;
      });
    }
  }

  void _typeNext() {
    if (!mounted) return;
    if (_charIndex >= _fullText.length) {
      widget.onTypingDone();
      return;
    }
    setState(() {
      _displayed = _fullText.substring(0, _charIndex + 1);
      _charIndex++;
    });
    Future.delayed(const Duration(milliseconds: 22), _typeNext);
  }

  @override
  Widget build(BuildContext context) {
    final lines = _displayed.split('\n\n');
    final title = lines.isNotEmpty ? lines[0] : '';
    final body  = lines.length > 1 ? lines.sublist(1).join('\n\n') : '';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Cola apuntando a la izquierda (hacia Blink)
        Positioned(
          left: -13,
          bottom: 20,
          child: CustomPaint(
            size: const Size(16, 24),
            painter: _TailPainter(),
          ),
        ),

        // Globo
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 20,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dots de paso
              if (widget.totalSteps > 1)
                Row(
                  children: List.generate(widget.totalSteps, (i) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(right: 5),
                      width:  i == widget.stepIndex ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == widget.stepIndex
                            ? const Color(0xFF2563EB)
                            : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              if (widget.totalSteps > 1) const SizedBox(height: 10),

              // Título
              if (title.isNotEmpty)
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Color(0xFF1A1A2E),
                    height: 1.3,
                  ),
                ),

              if (body.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: Color(0xFF334155),
                    height: 1.5,
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Botón
              AnimatedOpacity(
                opacity: widget.typingDone ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 350),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: widget.typingDone ? widget.onAdvance : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF1A237E)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        widget.isLast ? '¡Entendido!' : 'Siguiente →',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(
                        begin: 1.0,
                        end: 1.04,
                        duration: 900.ms,
                        curve: Curves.easeInOut,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    )
        .animate(key: ValueKey(widget.stepIndex))
        .fadeIn(duration: 280.ms)
        .slideX(begin: 0.06, end: 0, duration: 280.ms, curve: Curves.easeOut);
  }
}

// Cola apuntando a la izquierda
class _TailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shadow = Paint()
      ..color = Colors.black26
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final paint = Paint()..color = Colors.white;
    final path  = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height / 2)
      ..close();
    canvas.drawPath(path, shadow);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
