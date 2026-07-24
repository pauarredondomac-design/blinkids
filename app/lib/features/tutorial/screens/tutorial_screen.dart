import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/repositories/blink_dialogues_repository.dart';
import '../../../data/repositories/wallet_repository.dart';
import '../../../data/services/supabase_service.dart';
import '../../../shared/providers/auth_provider.dart';

// ─── Pasos del tutorial (fallback hardcodeado) ────────────────────────────────
class _TutorialStep {
  const _TutorialStep({required this.title, required this.body, required this.bg});
  final String title;
  final String body;
  final List<Color> bg;
}

const _bgColors = [
  [Color(0xFF0D0D2B), Color(0xFF1A237E)],
  [Color(0xFF1A237E), Color(0xFF4A148C)],
  [Color(0xFF4A148C), Color(0xFF1A1A2E)],
  [Color(0xFF1A1A2E), Color(0xFF0D2B1A)],
];

const _fallbackSteps = [
  _TutorialStep(
    title: '¡Hola!',
    body: '¡Hola! Soy Blink, el zorro más curioso de la galaxia. 🦊 ¡Por fin llegaste! Estaba esperando un compañero de viaje.',
    bg: [Color(0xFF0D0D2B), Color(0xFF1A237E)],
  ),
  _TutorialStep(
    title: 'Monedas con superpoderes',
    body: 'Cada misión nos lleva un poco más lejos. Algunas fáciles, otras nos harán pensar, pero en todas aprendemos algo. ¡Cada decisión cuenta!',
    bg: [Color(0xFF1A237E), Color(0xFF4A148C)],
  ),
  _TutorialStep(
    title: 'Nuestras misiones',
    body: 'Cada misión nos lleva un poco más lejos. Algunas fáciles, otras nos harán pensar, pero en todas aprendemos algo. ¡Cada decisión cuenta!',
    bg: [Color(0xFF4A148C), Color(0xFF1A1A2E)],
  ),
  _TutorialStep(
    title: 'Tu Bolsa Espacial',
    body: 'Antes de despegar te muestro tu Bolsa: Ahorro, Inversión,  Compartir, Gastor . Aquí cada moneda encuentra su misión.',
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
  List<_TutorialStep> _steps = _fallbackSteps;

  @override
  void initState() {
    super.initState();
    _loadFromSupabase();
  }

  Future<void> _loadFromSupabase() async {
    final remote = await BlinkDialoguesRepository.getSteps('intro');
    if (remote.isNotEmpty && mounted) {
      setState(() {
        _steps = remote.asMap().entries.map((e) {
          final bg = _bgColors[e.key % _bgColors.length];
          return _TutorialStep(title: e.value.title, body: e.value.body, bg: bg);
        }).toList();
      });
    }
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
      _complete();
    }
  }

  Future<void> _complete() async {
    setState(() => _isCompleting = true);

    // Siempre guardar localmente (funciona en demo y con sesión)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('tutorial_seen', true);
    } catch (_) {}

    final user = ref.read(currentUserProvider);
    if (user != null) {
      // Con sesión → también guardar en Supabase
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
      } catch (_) {}
    }

    if (mounted) context.go('/world');
  }

  @override
  Widget build(BuildContext context) {
    final step   = _steps[_step];
    final isLast = _step == _steps.length - 1;

    final size        = MediaQuery.of(context).size;
    final blinkW      = (size.width * 0.22).clamp(100.0, 190.0);
    final blinkH      = blinkW * 0.85;
    final bubbleLeft  = blinkW - 10;
    final bubbleRight = size.width * 0.03;
    // Máximo alto del globo: toda la pantalla menos margen superior e inferior
    final bubbleMaxH  = size.height - blinkH - 24;

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
              clipBehavior: Clip.none,
              children: [
                ...List.generate(18, (i) => _Star(seed: i)),

                // Globo de diálogo responsivo
                Positioned(
                  bottom: 16,
                  left: bubbleLeft,
                  right: bubbleRight,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: bubbleMaxH),
                    child: _IntroBubble(
                      key: ValueKey('intro_$_step'),
                      step: step,
                      stepIndex: _step,
                      totalSteps: _steps.length,
                      isLast: isLast,
                      isCompleting: _isCompleting,
                      typingDone: _typingDone,
                      maxBubbleH: bubbleMaxH,
                      onTypingDone: () {
                        if (mounted) setState(() => _typingDone = true);
                      },
                      onPageContinue: () {
                        // Al avanzar página interna, reinicia el flag de typing
                        if (mounted) setState(() => _typingDone = false);
                      },
                      onAdvance: _advance,
                    ),
                  ),
                ),

                // Blink — tamaño relativo al ancho de pantalla
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: SizedBox(
                    width: blinkW,
                    height: blinkH,
                    child: Image.asset(
                      'assets/blink/poses/dialogo.png',
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.topCenter,
                      filterQuality: FilterQuality.high,
                    ).animate(key: ValueKey('blink_$_step'))
                      .scale(
                        begin: const Offset(0.7, 0.7),
                        end:   const Offset(1.0, 1.0),
                        duration: 500.ms,
                        curve: Curves.elasticOut,
                      ),
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
// Globo de diálogo — mismo diseño visual que ScreenTutorial (dots + botón)
// ─────────────────────────────────────────────────────────────────────────────
class _IntroBubble extends StatefulWidget {
  const _IntroBubble({
    super.key,
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.isLast,
    required this.isCompleting,
    required this.typingDone,
    required this.maxBubbleH,
    required this.onTypingDone,
    required this.onPageContinue,
    required this.onAdvance,
  });
  final _TutorialStep step;
  final int          stepIndex;
  final int          totalSteps;
  final bool         isLast;
  final bool         isCompleting;
  final bool         typingDone;
  final double       maxBubbleH;
  final VoidCallback onTypingDone;
  final VoidCallback onPageContinue;
  final VoidCallback onAdvance;

  @override
  State<_IntroBubble> createState() => _IntroBubbleState();
}

class _IntroBubbleState extends State<_IntroBubble> {
  // Texto completo del paso (título + cuerpo separados)
  late final String _title;
  late final String _body;

  // Paginación del body
  int    _pageStart  = 0;   // offset en _body donde empieza la página actual
  int    _pageEnd    = 0;   // offset donde termina (calculado tras layout)
  bool   _pageReady  = false; // true una vez que _pageEnd está calculado
  bool   _hasMore    = false; // hay texto después de esta página

  // Typewriter
  String _displayed  = '';
  int    _charIndex  = 0;

  @override
  void initState() {
    super.initState();
    _title = widget.step.title;
    _body  = widget.step.body;
  }

  // Llamado por LayoutBuilder cuando conocemos el ancho y alto disponibles
  void _initPage(double maxW, double maxH, double bodyFontSize) {
    if (_pageReady) return;
    _pageEnd  = _findChunkEnd(_body, _pageStart, maxW, maxH, bodyFontSize);
    _hasMore  = _pageEnd < _body.length;
    _pageReady = true;
    _startTyping();
  }

  // Devuelve el índice hasta el que cabe el texto (body[start..result]) en maxH px
  int _findChunkEnd(String text, int start, double maxW, double maxH, double fontSize) {
    final sub   = text.substring(start);
    final style = TextStyle(
      fontFamily: 'Nunito',
      fontWeight: FontWeight.w500,
      fontSize: fontSize,
      height: 1.45,
    );

    // Búsqueda binaria: cuántos caracteres caben
    int lo = 1, hi = sub.length, best = sub.length;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      final tp  = TextPainter(
        text: TextSpan(text: sub.substring(0, mid), style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxW);

      if (tp.height <= maxH) {
        best = mid;
        lo   = mid + 1;
      } else {
        hi   = mid - 1;
      }
    }

    // Retrocede hasta el último espacio para no cortar una palabra
    if (best < sub.length) {
      final cut = sub.lastIndexOf(' ', best);
      if (cut > 0) best = cut;
    }
    return start + best;
  }

  void _startTyping() {
    _displayed = '';
    _charIndex = 0;
    _typeNext();
  }

  // El chunk visible es title + '\n\n' + body[_pageStart.._pageEnd]
  String get _chunk => _body.substring(_pageStart, _pageEnd);

  void _typeNext() {
    if (!mounted) return;
    final full = _chunk;
    if (_charIndex >= full.length) {
      widget.onTypingDone();
      return;
    }
    setState(() {
      _displayed = full.substring(0, _charIndex + 1);
      _charIndex++;
    });
    Future.delayed(const Duration(milliseconds: 22), _typeNext);
  }

  @override
  void didUpdateWidget(_IntroBubble old) {
    super.didUpdateWidget(old);
    // Tap mientras escribe → mostrar todo el chunk de golpe
    if (!old.typingDone && widget.typingDone && _charIndex < _chunk.length) {
      setState(() {
        _displayed = _chunk;
        _charIndex = _chunk.length;
      });
    }
  }

  // Avanzar a la siguiente página interna (sin cambiar de paso)
  void advancePage(double maxW, double maxBodyH, double bodyFontSize) {
    if (!_hasMore) return;
    setState(() {
      _pageStart = _pageEnd;
      _pageEnd   = 0;
      _pageReady = false;
      _hasMore   = false;
      _displayed = '';
      _charIndex = 0;
    });
    // Recalcular con las mismas dimensiones
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initPage(maxW, maxBodyH, bodyFontSize);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sw    = MediaQuery.of(context).size.width;
    final sh    = MediaQuery.of(context).size.height;
    final scale = (sw / 360).clamp(0.75, 1.4);
    final titleSize = 16.0 * scale;
    final bodySize  = 13.0 * scale;
    final btnSize   = 12.0 * scale;
    final pad       = (sh * 0.025).clamp(8.0, 18.0);

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
          padding: EdgeInsets.fromLTRB(pad, pad, pad, pad),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 20, offset: Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dots de progreso de pasos
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
              if (widget.totalSteps > 1) SizedBox(height: pad * 0.6),

              // Título siempre completo
              Text(
                _title,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize: titleSize,
                  color: const Color(0xFF1A1A2E),
                  height: 1.3,
                ),
              ),
              SizedBox(height: pad * 0.4),

              // Body paginado — LayoutBuilder determina el espacio disponible
              Flexible(
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    // Reservamos espacio para: título + dots + botón + paddings
                    final dotsH    = widget.totalSteps > 1 ? 7 + pad * 0.6 : 0.0;
                    final titleH   = titleSize * 1.3 + pad * 0.4;
                    final buttonH  = btnSize * 2.0 + pad * 0.55 * 2 + pad * 0.8;
                    final reserved = dotsH + titleH + buttonH + pad * 2;
                    final bodyMaxH = (widget.maxBubbleH - reserved).clamp(40.0, double.infinity);

                    // Inicializar paginación la primera vez
                    if (!_pageReady) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _initPage(constraints.maxWidth, bodyMaxH, bodySize);
                      });
                    }

                    if (!_pageReady) {
                      return SizedBox(height: bodySize * 1.45 * 2);
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Texto con "…" al final si hay más páginas
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w500,
                              fontSize: bodySize,
                              color: const Color(0xFF334155),
                              height: 1.45,
                            ),
                            children: [
                              TextSpan(text: _displayed),
                              if (_hasMore && _charIndex >= _chunk.length)
                                const TextSpan(
                                  text: '…',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (widget.isCompleting) ...[
                          SizedBox(height: pad * 0.8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: const Color(0xFF2563EB),
                                strokeWidth: 2.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    )
        .animate(key: ValueKey('${widget.stepIndex}_$_pageStart'))
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
