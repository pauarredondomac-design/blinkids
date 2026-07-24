import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Animación de despegue a pantalla completa — se dispara cuando el
// combustible de un mundo llega al 100%. Se cierra sola al terminar
// o al tocar la pantalla.
// ─────────────────────────────────────────────────────────────────────────────
Future<void> showRocketLaunchOverlay(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim, __) => FadeTransition(
        opacity: anim,
        child: const _RocketLaunchScreen(),
      ),
    ),
  );
}

class _RocketLaunchScreen extends StatefulWidget {
  const _RocketLaunchScreen();

  @override
  State<_RocketLaunchScreen> createState() => _RocketLaunchScreenState();
}

class _RocketLaunchScreenState extends State<_RocketLaunchScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Fases: 0.00–0.20 cuenta regresiva / vibración
  //        0.20–1.00 despegue hacia arriba, acelerando
  late final Animation<double> _shake;
  late final Animation<double> _liftoff;
  late final Animation<double> _fadeOutRocket;
  late final Animation<double> _flameScale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -3.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -3.0, end: 3.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 3.0, end: -3.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -3.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.22)));

    _liftoff = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.22, 1.0, curve: Curves.easeInCubic),
      ),
    );

    _fadeOutRocket = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.78, 1.0)),
    );

    _flameScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.6, end: 1.3), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.22)));

    _ctrl.forward();
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(context).maybePop();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF060618), Color(0xFF0D0D2B), Color(0xFF12124A)],
                ),
              ),
            ),
            ...List.generate(50, (i) => _Star(seed: i)),

            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, child) {
                final liftPixels = _liftoff.value * size.height * 1.15;
                final dx = _ctrl.value < 0.22 ? _shake.value : 0.0;
                return Positioned(
                  left: size.width / 2 - 60 + dx,
                  top:  size.height * 0.55 - 90 - liftPixels,
                  child: Opacity(
                    opacity: _fadeOutRocket.value,
                    child: Column(
                      children: [
                        SizedBox(
                          width: 120,
                          height: 160,
                          child: CustomPaint(painter: BlinkShipPainter()),
                        ),
                        Transform.scale(
                          scale: _flameScale.value,
                          child: Container(
                            width: 46,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFFFFEB3B), Color(0xFFFF6E40), Colors.transparent],
                              ),
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // ── Texto ──────────────────────────────────────────────────────
            Positioned(
              left: 24, right: 24, bottom: 60,
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  final opacity = _ctrl.value < 0.15
                      ? _ctrl.value / 0.15
                      : (_ctrl.value > 0.85 ? (1 - _ctrl.value) / 0.15 : 1.0);
                  return Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '¡Combustible al 100%! 🚀',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w900,
                            fontSize: 26,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '¡Rumbo a Marte!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Colors.white70,
                          ),
                        ),
                      ],
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

// ─────────────────────────────────────────────────────────────────────────────
class _Star extends StatelessWidget {
  const _Star({required this.seed});
  final int seed;

  @override
  Widget build(BuildContext context) {
    final size    = MediaQuery.of(context).size;
    final rng     = seed * 1693 + 17;
    final left    = (rng % 100) / 100 * size.width;
    final top     = ((rng * 37) % 100) / 100 * size.height;
    final radius  = 0.8 + (rng % 3).toDouble();
    final opacity = 0.25 + (rng % 5) / 10.0;

    return Positioned(
      left: left,
      top:  top,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width:  radius * 2,
          height: radius * 2,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nave de Blink — cohete pintado con Canvas
// ─────────────────────────────────────────────────────────────────────────────
class BlinkShipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;

    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * .5, h * .88), width: w * .45, height: h * .18),
      Paint()
        ..color = const Color(0xFFFF6E40).withOpacity(0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );

    final lw = Path()
      ..moveTo(w * .28, h * .58)
      ..lineTo(w * .02, h * .80)
      ..lineTo(w * .28, h * .74)
      ..close();
    canvas.drawPath(lw, Paint()..color = const Color(0xFF01579B));
    canvas.drawPath(lw, Paint()
      ..color = const Color(0xFF4FC3F7).withOpacity(.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);

    final rw = Path()
      ..moveTo(w * .72, h * .58)
      ..lineTo(w * .98, h * .80)
      ..lineTo(w * .72, h * .74)
      ..close();
    canvas.drawPath(rw, Paint()..color = const Color(0xFF01579B));
    canvas.drawPath(rw, Paint()
      ..color = const Color(0xFF4FC3F7).withOpacity(.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);

    final bodyR = RRect.fromLTRBR(
        w * .24, h * .20, w * .76, h * .84, const Radius.circular(16));
    canvas.drawRRect(bodyR, Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF4FC3F7), Color(0xFF0277BD)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h)));
    canvas.drawRRect(bodyR, Paint()
      ..color = const Color(0xFF81D4FA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);

    final nose = Path()
      ..moveTo(w * .5, h * .04)
      ..lineTo(w * .73, h * .22)
      ..lineTo(w * .27, h * .22)
      ..close();
    canvas.drawPath(nose, Paint()..color = const Color(0xFF0288D1));
    canvas.drawPath(nose, Paint()
      ..color = const Color(0xFF4FC3F7).withOpacity(.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);

    canvas.drawCircle(Offset(w * .5, h * .40), w * .13, Paint()
      ..color = const Color(0xFFE1F5FE).withOpacity(.9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawCircle(Offset(w * .5, h * .40), w * .11,
        Paint()..color = const Color(0xFF81D4FA));
    canvas.drawCircle(Offset(w * .43, h * .36), w * .04,
        Paint()..color = Colors.white.withOpacity(.75));

    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * .5, h * .87), width: w * .22, height: h * .10),
        Paint()..color = const Color(0xFFFFCC02));
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * .5, h * .86), width: w * .12, height: h * .06),
        Paint()..color = Colors.white);

    for (int i = 0; i < 2; i++) {
      canvas.drawLine(
        Offset(w * .30, h * (.52 + i * .12)),
        Offset(w * .70, h * (.52 + i * .12)),
        Paint()
          ..color = const Color(0xFF4FC3F7).withOpacity(.35)
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
