import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/blink_dialogues_repository.dart';
import '../../data/services/analytics_service.dart';
import '../providers/demo_progress_provider.dart';

class TutorialStep {
  const TutorialStep({required this.title, required this.body});
  final String title;
  final String body;
}

/// Muestra un tutorial la primera vez que el usuario entra a una pantalla.
/// El estado se guarda en Supabase (columna tutorials_seen de profiles).
/// Los textos se cargan desde Supabase (tabla blink_dialogues) con fallback hardcodeado.
/// Layout: imagen "dialogo blink.png" esquina inferior-izquierda + globo a la derecha.
class ScreenTutorial extends StatefulWidget {
  const ScreenTutorial({
    super.key,
    required this.tutorialKey,
    required this.steps,
    required this.child,
    this.onReady,
  });

  final String tutorialKey;
  final List<TutorialStep> steps; // fallback hardcodeado
  final Widget child;

  /// Se dispara una sola vez por montaje de esta pantalla: de inmediato si
  /// el tutorial ya se había visto antes, o justo al cerrarlo si se está
  /// viendo por primera vez. Útil como gancho para mostrar algo DESPUÉS
  /// de la intro/instrucciones (ej. la pregunta diaria del edificio).
  final VoidCallback? onReady;

  @override
  State<ScreenTutorial> createState() => _ScreenTutorialState();
}

class _ScreenTutorialState extends State<ScreenTutorial> {
  int _step = 0;
  bool? _show;
  bool _typingDone = false;
  late List<TutorialStep> _steps;

  @override
  void initState() {
    super.initState();
    _steps = widget.steps;
    _load();
  }

  Future<void> _load() async {
    // Cargar textos desde Supabase (nunca escribe, solo lee)
    final remoteDialogues =
        await BlinkDialoguesRepository.getSteps(widget.tutorialKey);
    if (remoteDialogues.isNotEmpty && mounted) {
      setState(() {
        _steps = remoteDialogues
            .map((d) => TutorialStep(title: d.title, body: d.body))
            .toList();
      });
    }

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null || user.isAnonymous) {
      final seen = DemoStore.instance.isTutorialSeen(widget.tutorialKey);
      if (mounted) setState(() => _show = !seen);
      if (seen) widget.onReady?.call();
      return;
    }
    final userId = user.id;
    try {
      final data = await client
          .from('profiles')
          .select('tutorials_seen')
          .eq('id', userId)
          .maybeSingle();
      final map = (data?['tutorials_seen'] as Map<String, dynamic>?) ?? {};
      final seen = map[widget.tutorialKey] == true;
      if (mounted) setState(() => _show = !seen);
      if (seen) widget.onReady?.call();
    } catch (_) {
      if (mounted) setState(() => _show = false);
      widget.onReady?.call();
    }
  }

  Future<void> _dismiss() async {
    if (mounted) setState(() => _show = false);
    widget.onReady?.call();
    AnalyticsService.instance
        .track('tutorial_completed', properties: {'key': widget.tutorialKey});
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null || user.isAnonymous) {
      DemoStore.instance.markTutorialSeen(widget.tutorialKey);
      return;
    }
    try {
      await client
          .rpc('mark_tutorial_seen', params: {'p_key': widget.tutorialKey});
    } catch (_) {}
  }

  void _advance() {
    if (!_typingDone) {
      setState(() => _typingDone = true);
      return;
    }
    if (_step < _steps.length - 1) {
      setState(() {
        _step++;
        _typingDone = false;
      });
    } else {
      _dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_show != true) return widget.child;

    final step = _steps[_step];
    final isLast = _step == _steps.length - 1;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,

        Positioned.fill(
          child: GestureDetector(
            onTap: _advance,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.black.withValues(alpha: 0.55)),
          ),
        ),

        // Globo de diálogo — esquina inferior derecha, deja espacio para Blink
        Positioned(
          bottom: 16,
          left: 160,
          right: 24,
          child: GestureDetector(
            onTap: _advance,
            behavior: HitTestBehavior.opaque,
            child: _Bubble(
              key: ValueKey('${widget.tutorialKey}_$_step'),
              step: step,
              stepIndex: _step,
              totalSteps: _steps.length,
              isLast: isLast,
              typingDone: _typingDone,
              onTypingDone: () {
                if (mounted) setState(() => _typingDone = true);
              },
              onAdvance: _advance,
            ),
          ),
        ),

        // Blink pegado al borde inferior.
        // SizedBox recorta el espacio transparente inferior de la imagen
        // para que los pies queden en el borde de la pantalla.
        Positioned(
          bottom: 0,
          left: 0,
          child: GestureDetector(
            onTap: _advance,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 170,
              height: 145,
              child: Image.asset(
                'assets/blink/poses/dialogo.png',
                width: 170,
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

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
  final int stepIndex;
  final int totalSteps;
  final bool isLast;
  final bool typingDone;
  final VoidCallback onTypingDone;
  final VoidCallback onAdvance;

  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> {
  String _displayed = '';
  int _charIndex = 0;
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
    final body = lines.length > 1 ? lines.sublist(1).join('\n\n') : '';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -13,
          bottom: 20,
          child: CustomPaint(
            size: const Size(16, 24),
            painter: _TailPainter(),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black38, blurRadius: 20, offset: Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.totalSteps > 1)
                Row(
                  children: List.generate(widget.totalSteps, (i) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(right: 5),
                      width: i == widget.stepIndex ? 22 : 7,
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

class _TailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shadow = Paint()
      ..color = Colors.black26
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final paint = Paint()..color = Colors.white;
    final path = Path()
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
