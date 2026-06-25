import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// Widget envoltorio — llama al painter correcto
// ─────────────────────────────────────────────
enum SpaceBuildingType { vault, command, workshop, lab, market, store }

class SpaceBuilding extends StatelessWidget {
  const SpaceBuilding({
    super.key,
    required this.type,
    this.size = 110,
  });

  final SpaceBuildingType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _painterFor(type),
    );
  }

  CustomPainter _painterFor(SpaceBuildingType t) {
    switch (t) {
      case SpaceBuildingType.vault:
        return _VaultPainter();
      case SpaceBuildingType.command:
        return _CommandPainter();
      case SpaceBuildingType.workshop:
        return _WorkshopPainter();
      case SpaceBuildingType.lab:
        return _LabPainter();
      case SpaceBuildingType.market:
        return _MarketPainter();
      case SpaceBuildingType.store:
        return _StorePainter();
    }
  }
}

// ─────────────────────────────────────────────
// Helpers comunes
// ─────────────────────────────────────────────
Paint _fill(Color c) => Paint()
  ..color = c
  ..style = PaintingStyle.fill;

Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round;

Paint _glow(Color c, double blur) => Paint()
  ..color = c.withAlpha(120)
  ..style = PaintingStyle.fill
  ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

Paint _gradientFill(Rect r, List<Color> colors, [AlignmentGeometry? begin, AlignmentGeometry? end]) {
  final gradient = LinearGradient(
    begin: begin as Alignment? ?? Alignment.topCenter,
    end: end as Alignment? ?? Alignment.bottomCenter,
    colors: colors,
  );
  return Paint()
    ..shader = gradient.createShader(r)
    ..style = PaintingStyle.fill;
}

// ─────────────────────────────────────────────
// 1. VAULT — Mi Bolsa
// ─────────────────────────────────────────────
class _VaultPainter extends CustomPainter {
  static const _cyan = Color(0xFF00E5FF);
  static const _dark = Color(0xFF0A1628);
  static const _steel = Color(0xFF263850);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;

    // -- Plataforma flotante --
    final platRect = RRect.fromLTRBR(w * .1, h * .82, w * .9, h * .92,
        const Radius.circular(6));
    canvas.drawRRect(platRect,
        _gradientFill(platRect.outerRect, [_steel, _dark]));
    canvas.drawRRect(platRect, _stroke(_cyan, 1));
    // Brillo plataforma
    canvas.drawRRect(platRect, _glow(_cyan, 8));

    // -- Cuerpo principal (hexágono aplanado) --
    final body = Path()
      ..moveTo(w * .25, h * .35)
      ..lineTo(w * .5, h * .18)
      ..lineTo(w * .75, h * .35)
      ..lineTo(w * .75, h * .80)
      ..lineTo(w * .25, h * .80)
      ..close();
    canvas.drawPath(
        body,
        _gradientFill(
            Rect.fromLTWH(0, 0, w, h), [_steel, const Color(0xFF0D2137)]));
    canvas.drawPath(body, _stroke(_cyan, 1.5));

    // -- Techo triangular superior --
    final roof = Path()
      ..moveTo(w * .20, h * .38)
      ..lineTo(w * .5, h * .15)
      ..lineTo(w * .80, h * .38)
      ..close();
    canvas.drawPath(roof, _fill(const Color(0xFF0E2644)));
    canvas.drawPath(roof, _stroke(_cyan, 1.2));

    // -- Puerta de bóveda (círculo con engranaje) --
    final cx = w * .5;
    final cy = h * .60;
    canvas.drawCircle(Offset(cx, cy), w * .18, _glow(_cyan, 14));
    canvas.drawCircle(Offset(cx, cy), w * .18, _fill(const Color(0xFF071424)));
    canvas.drawCircle(Offset(cx, cy), w * .18, _stroke(_cyan, 2));
    canvas.drawCircle(Offset(cx, cy), w * .11, _stroke(_cyan, 1));
    // Líneas de engranaje
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      canvas.drawLine(
        Offset(cx + math.cos(angle) * w * .11, cy + math.sin(angle) * w * .11),
        Offset(cx + math.cos(angle) * w * .18, cy + math.sin(angle) * w * .18),
        _stroke(_cyan, 1.5),
      );
    }
    // Símbolo moneda centro
    _drawText(canvas, '🪙', Offset(cx - 9, cy - 9), 18);

    // -- Ventanas laterales --
    for (final dx in [w * .32, w * .63]) {
      final wr = Rect.fromCenter(center: Offset(dx, h * .44), width: 10, height: 7);
      canvas.drawRRect(RRect.fromRectAndRadius(wr, const Radius.circular(2)),
          _fill(const Color(0xFF00BCD4).withAlpha(180)));
      canvas.drawRRect(RRect.fromRectAndRadius(wr, const Radius.circular(2)),
          _stroke(_cyan, .8));
    }

    // -- Antena superior --
    canvas.drawLine(Offset(w * .5, h * .15), Offset(w * .5, h * .05),
        _stroke(_cyan, 1.5));
    canvas.drawCircle(Offset(w * .5, h * .05), 3, _fill(_cyan));
    canvas.drawCircle(Offset(w * .5, h * .05), 5, _glow(_cyan, 6));
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────
// 2. COMMAND — Misiones
// ─────────────────────────────────────────────
class _CommandPainter extends CustomPainter {
  static const _orange = Color(0xFFFF6E40);
  static const _dark = Color(0xFF1A0800);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;

    // -- Plataforma --
    final plat = RRect.fromLTRBR(w * .12, h * .82, w * .88, h * .92,
        const Radius.circular(5));
    canvas.drawRRect(plat,
        _gradientFill(plat.outerRect, [const Color(0xFF3E2000), _dark]));
    canvas.drawRRect(plat, _stroke(_orange, 1));
    canvas.drawRRect(plat, _glow(_orange, 6));

    // -- Torre base --
    final baseRect = Rect.fromLTWH(w * .35, h * .55, w * .30, h * .28);
    canvas.drawRect(baseRect,
        _gradientFill(baseRect, [const Color(0xFF3B1800), _dark]));
    canvas.drawRect(baseRect, _stroke(_orange, 1.2));

    // -- Módulo central --
    final midRect = Rect.fromLTWH(w * .28, h * .38, w * .44, h * .22);
    canvas.drawRRect(RRect.fromRectAndRadius(midRect, const Radius.circular(4)),
        _gradientFill(midRect, [const Color(0xFF4A2000), _dark]));
    canvas.drawRRect(
        RRect.fromRectAndRadius(midRect, const Radius.circular(4)), _stroke(_orange, 1.5));

    // -- Cúpula superior --
    final domeRect =
        Rect.fromLTWH(w * .32, h * .20, w * .36, h * .22);
    canvas.drawArc(domeRect, math.pi, math.pi, false,
        _fill(const Color(0xFF3A1500)));
    canvas.drawArc(domeRect, math.pi, math.pi, false, _stroke(_orange, 1.5));
    // Ventana cúpula
    canvas.drawArc(Rect.fromLTWH(w * .40, h * .22, w * .20, h * .13),
        math.pi, math.pi, false,
        _fill(const Color(0xFFFF6E40).withAlpha(60)));

    // -- Antena radar --
    canvas.drawLine(
        Offset(w * .5, h * .20), Offset(w * .5, h * .08), _stroke(_orange, 2));
    // Plato radar
    final radarPath = Path()
      ..moveTo(w * .35, h * .10)
      ..quadraticBezierTo(w * .50, h * .04, w * .65, h * .10)
      ..close();
    canvas.drawPath(radarPath, _fill(const Color(0xFF5A2800)));
    canvas.drawPath(radarPath, _stroke(_orange, 1.5));
    canvas.drawPath(radarPath, _glow(_orange, 5));

    // -- Ventanas --
    for (int i = 0; i < 3; i++) {
      final wr = Rect.fromCenter(
          center: Offset(w * (.36 + i * .14), h * .47), width: 8, height: 6);
      canvas.drawRRect(RRect.fromRectAndRadius(wr, const Radius.circular(2)),
          _fill(_orange.withAlpha(160)));
      canvas.drawRRect(
          RRect.fromRectAndRadius(wr, const Radius.circular(2)), _stroke(_orange, .8));
    }

    // -- Luces parpadeantes (estáticas) --
    canvas.drawCircle(Offset(w * .36, h * .38), 3, _fill(_orange));
    canvas.drawCircle(Offset(w * .36, h * .38), 5, _glow(_orange, 6));
    canvas.drawCircle(Offset(w * .64, h * .38), 3, _fill(_orange));
    canvas.drawCircle(Offset(w * .64, h * .38), 5, _glow(_orange, 6));
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────
// 3. WORKSHOP — Trabajos
// ─────────────────────────────────────────────
class _WorkshopPainter extends CustomPainter {
  static const _yellow = Color(0xFFFFD740);
  static const _dark = Color(0xFF1A1000);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;

    // Plataforma
    final plat = RRect.fromLTRBR(w * .08, h * .82, w * .92, h * .92,
        const Radius.circular(5));
    canvas.drawRRect(plat,
        _gradientFill(plat.outerRect, [const Color(0xFF3A2800), _dark]));
    canvas.drawRRect(plat, _stroke(_yellow, 1));
    canvas.drawRRect(plat, _glow(_yellow, 6));

    // Cuerpo fábrica
    final factory =
        Rect.fromLTWH(w * .15, h * .45, w * .55, h * .38);
    canvas.drawRect(factory,
        _gradientFill(factory, [const Color(0xFF3D2A00), _dark]));
    canvas.drawRect(factory, _stroke(_yellow, 1.2));

    // Techo escalonado
    final roof1 = Path()
      ..moveTo(w * .12, h * .45)
      ..lineTo(w * .45, h * .28)
      ..lineTo(w * .73, h * .45)
      ..close();
    canvas.drawPath(roof1, _fill(const Color(0xFF4A3200)));
    canvas.drawPath(roof1, _stroke(_yellow, 1.2));

    // Chimenea
    canvas.drawRect(Rect.fromLTWH(w * .22, h * .24, w * .10, h * .22),
        _fill(const Color(0xFF3D2A00)));
    canvas.drawRect(Rect.fromLTWH(w * .22, h * .24, w * .10, h * .22),
        _stroke(_yellow, 1));
    // Humo
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(w * .27, h * (.22 - i * .06)),
          5.0 - i, _fill(Colors.grey.withAlpha(60 - i * 15)));
    }

    // Brazo mecánico
    final armPaint = _stroke(_yellow, 3);
    canvas.drawLine(Offset(w * .72, h * .60), Offset(w * .88, h * .50), armPaint);
    canvas.drawLine(Offset(w * .88, h * .50), Offset(w * .88, h * .70), armPaint);
    canvas.drawCircle(Offset(w * .88, h * .70), 6, _fill(const Color(0xFF4A3200)));
    canvas.drawCircle(Offset(w * .88, h * .70), 6, _stroke(_yellow, 1.5));
    canvas.drawCircle(Offset(w * .72, h * .60), 5, _fill(_yellow));
    canvas.drawCircle(Offset(w * .72, h * .60), 7, _glow(_yellow, 6));

    // Ventanas fábrica
    for (int i = 0; i < 3; i++) {
      final wr = Rect.fromCenter(
          center: Offset(w * (.24 + i * .15), h * .62), width: 10, height: 8);
      canvas.drawRRect(RRect.fromRectAndRadius(wr, const Radius.circular(2)),
          _fill(_yellow.withAlpha(140)));
      canvas.drawRRect(
          RRect.fromRectAndRadius(wr, const Radius.circular(2)), _stroke(_yellow, .8));
    }

    // Engranaje lateral
    _drawGear(canvas, Offset(w * .60, h * .60), w * .09, _yellow);
  }

  void _drawGear(Canvas canvas, Offset center, double r, Color c) {
    canvas.drawCircle(center, r * .6, _fill(const Color(0xFF1A1000)));
    canvas.drawCircle(center, r * .6, _stroke(c, 1.5));
    for (int i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      canvas.drawLine(
        Offset(center.dx + math.cos(a) * r * .6,
            center.dy + math.sin(a) * r * .6),
        Offset(center.dx + math.cos(a) * r, center.dy + math.sin(a) * r),
        _stroke(c, 3),
      );
    }
    canvas.drawCircle(center, r * .3, _fill(c.withAlpha(80)));
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────
// 4. LAB — Preguntas
// ─────────────────────────────────────────────
class _LabPainter extends CustomPainter {
  static const _purple = Color(0xFFCE93D8);
  static const _darkPurple = Color(0xFF12001F);
  static const _midPurple = Color(0xFF2A0040);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;

    // Plataforma
    final plat = RRect.fromLTRBR(
        w * .10, h * .82, w * .90, h * .92, const Radius.circular(5));
    canvas.drawRRect(plat,
        _gradientFill(plat.outerRect, [const Color(0xFF300050), _darkPurple]));
    canvas.drawRRect(plat, _stroke(_purple, 1));
    canvas.drawRRect(plat, _glow(_purple, 7));

    // Base cúpula
    final baseRect = Rect.fromLTWH(w * .20, h * .68, w * .60, h * .16);
    canvas.drawRRect(RRect.fromRectAndRadius(baseRect, const Radius.circular(4)),
        _fill(_midPurple));
    canvas.drawRRect(
        RRect.fromRectAndRadius(baseRect, const Radius.circular(4)), _stroke(_purple, 1.2));

    // Cúpula principal
    final domeRect = Rect.fromLTWH(w * .12, h * .28, w * .76, h * .46);
    canvas.drawArc(domeRect, math.pi, math.pi, false, _fill(_midPurple));
    canvas.drawArc(domeRect, math.pi, math.pi, false, _stroke(_purple, 1.8));
    canvas.drawArc(domeRect, math.pi, math.pi, false, _glow(_purple, 8));

    // Interior cúpula (cielo estrellado)
    final clip = Path()
      ..addArc(domeRect, math.pi, math.pi);
    canvas.save();
    canvas.clipPath(clip);
    for (int i = 0; i < 10; i++) {
      canvas.drawCircle(
          Offset(w * (.2 + i * .07), h * (.35 + (i % 3) * .07)),
          1.5,
          _fill(Colors.white.withAlpha(150)));
    }
    canvas.restore();

    // Líneas de cúpula decorativas
    for (int i = 1; i < 4; i++) {
      final angle = math.pi + i * math.pi / 4;
      canvas.drawLine(
        Offset(w * .5, h * .51),
        Offset(w * .5 + math.cos(angle) * w * .38,
            h * .51 + math.sin(angle) * h * .23),
        _stroke(_purple.withAlpha(80), 1),
      );
    }

    // Telescopio
    canvas.save();
    canvas.translate(w * .5, h * .35);
    canvas.rotate(-math.pi / 5);
    canvas.drawRect(Rect.fromLTWH(-5, -h * .16, 10, h * .16),
        _fill(const Color(0xFF4A0070)));
    canvas.drawRect(Rect.fromLTWH(-5, -h * .16, 10, h * .16),
        _stroke(_purple, 1));
    canvas.drawOval(Rect.fromLTWH(-7, -h * .18, 14, 10), _fill(_purple.withAlpha(180)));
    canvas.restore();

    // Símbolo "?"
    _drawText(canvas, '?',
        Offset(w * .46, h * .52), 22,
        color: _purple, bold: true);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────
// 5. MARKET — Mercado
// ─────────────────────────────────────────────
class _MarketPainter extends CustomPainter {
  static const _green = Color(0xFF69F0AE);
  static const _dark = Color(0xFF001A0A);
  static const _mid = Color(0xFF002810);


  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;

    // Plataforma
    final plat = RRect.fromLTRBR(
        w * .08, h * .82, w * .92, h * .92, const Radius.circular(5));
    canvas.drawRRect(plat,
        _gradientFill(plat.outerRect, [const Color(0xFF002A10), _dark]));
    canvas.drawRRect(plat, _stroke(_green, 1));
    canvas.drawRRect(plat, _glow(_green, 6));

    // Estructura principal
    final main = Rect.fromLTWH(w * .10, h * .50, w * .80, h * .33);
    canvas.drawRRect(RRect.fromRectAndRadius(main, const Radius.circular(6)),
        _gradientFill(main, [const Color(0xFF003A18), _dark]));
    canvas.drawRRect(
        RRect.fromRectAndRadius(main, const Radius.circular(6)), _stroke(_green, 1.2));

    // Toldo ondulado
    final aw = w * .82;
    final aw2 = 10.0;
    final awPath = Path()..moveTo(w * .09, h * .52);
    for (int i = 0; i < 6; i++) {
      awPath.relativeQuadraticBezierTo(aw2, -aw2, aw2 * 2, 0);
    }
    awPath.lineTo(w * .91, h * .52);
    // Rayas toldo
    for (int i = 0; i < 6; i++) {
      final x = w * .09 + i * (aw / 6);
      canvas.drawRect(
          Rect.fromLTWH(x, h * .40, aw / 6 / 2, h * .14),
          _fill(i.isEven
              ? _green.withAlpha(140)
              : const Color(0xFF004020).withAlpha(200)));
    }
    canvas.drawPath(awPath, _stroke(_green, 2));
    canvas.drawPath(awPath, _glow(_green, 5));

    // Techo plano
    canvas.drawRRect(
        RRect.fromLTRBR(w * .09, h * .38, w * .91, h * .52,
            const Radius.circular(4)),
        _fill(_mid));
    canvas.drawRRect(
        RRect.fromLTRBR(w * .09, h * .38, w * .91, h * .52,
            const Radius.circular(4)),
        _stroke(_green, 1.2));

    // Productos en estantes
    final colors = [_green, Colors.amber, Colors.cyan, Colors.pink, _green];
    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(
          Offset(w * (.20 + i * .15), h * .68), 5, _fill(colors[i]));
      canvas.drawCircle(
          Offset(w * (.20 + i * .15), h * .68), 7, _glow(colors[i], 5));
    }

    // Señal de mercado
    canvas.drawLine(Offset(w * .50, h * .22), Offset(w * .50, h * .38),
        _stroke(_green, 2));
    final sign = RRect.fromLTRBR(
        w * .35, h * .14, w * .65, h * .24, const Radius.circular(4));
    canvas.drawRRect(sign, _fill(_mid));
    canvas.drawRRect(sign, _stroke(_green, 1.2));
    _drawText(canvas, '🛒', Offset(w * .41, h * .145), 14);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────
// 6. STORE — Tienda
// ─────────────────────────────────────────────
class _StorePainter extends CustomPainter {
  static const _pink = Color(0xFFF48FB1);
  static const _dark = Color(0xFF1A0010);
  static const _mid = Color(0xFF2A0020);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;

    // Plataforma
    final plat = RRect.fromLTRBR(
        w * .10, h * .82, w * .90, h * .92, const Radius.circular(5));
    canvas.drawRRect(plat,
        _gradientFill(plat.outerRect, [const Color(0xFF3A0028), _dark]));
    canvas.drawRRect(plat, _stroke(_pink, 1));
    canvas.drawRRect(plat, _glow(_pink, 6));

    // Cuerpo principal
    final body = Path()
      ..moveTo(w * .30, h * .80)
      ..lineTo(w * .20, h * .60)
      ..lineTo(w * .30, h * .40)
      ..lineTo(w * .70, h * .40)
      ..lineTo(w * .80, h * .60)
      ..lineTo(w * .70, h * .80)
      ..close();
    canvas.drawPath(body,
        _gradientFill(Rect.fromLTWH(0, h * .35, w, h * .5), [_mid, _dark]));
    canvas.drawPath(body, _stroke(_pink, 1.5));
    canvas.drawPath(body, _glow(_pink, 8));

    // Cristal central grande
    _drawCrystal(canvas, Offset(w * .5, h * .55), h * .16, _pink);

    // Cristales pequeños
    _drawCrystal(canvas, Offset(w * .28, h * .58), h * .08, Colors.purpleAccent);
    _drawCrystal(canvas, Offset(w * .72, h * .58), h * .08, Colors.pinkAccent);
    _drawCrystal(canvas, Offset(w * .38, h * .72), h * .06, _pink.withAlpha(180));
    _drawCrystal(canvas, Offset(w * .62, h * .72), h * .06, _pink.withAlpha(180));

    // Arco de entrada
    canvas.drawArc(
        Rect.fromLTWH(w * .38, h * .64, w * .24, h * .18), math.pi, math.pi,
        false, _fill(_dark));
    canvas.drawArc(
        Rect.fromLTWH(w * .38, h * .64, w * .24, h * .18), math.pi, math.pi,
        false, _stroke(_pink, 1.5));

    // Spire superior
    final spire = Path()
      ..moveTo(w * .44, h * .40)
      ..lineTo(w * .50, h * .18)
      ..lineTo(w * .56, h * .40)
      ..close();
    canvas.drawPath(spire, _fill(_mid));
    canvas.drawPath(spire, _stroke(_pink, 1.5));
    canvas.drawCircle(Offset(w * .5, h * .17), 5, _fill(_pink));
    canvas.drawCircle(Offset(w * .5, h * .17), 8, _glow(_pink, 10));
  }

  void _drawCrystal(Canvas canvas, Offset center, double size, Color c) {
    final crystal = Path()
      ..moveTo(center.dx, center.dy - size)
      ..lineTo(center.dx + size * .45, center.dy - size * .1)
      ..lineTo(center.dx + size * .3, center.dy + size * .8)
      ..lineTo(center.dx - size * .3, center.dy + size * .8)
      ..lineTo(center.dx - size * .45, center.dy - size * .1)
      ..close();
    canvas.drawPath(crystal, _fill(c.withAlpha(80)));
    canvas.drawPath(crystal, _stroke(c, 1.2));
    canvas.drawPath(crystal, _glow(c, 6));
    // Brillo interno
    canvas.drawLine(
      Offset(center.dx - size * .15, center.dy - size * .6),
      Offset(center.dx + size * .05, center.dy + size * .2),
      _stroke(Colors.white.withAlpha(100), 1.5),
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────
// Helper texto
// ─────────────────────────────────────────────
void _drawText(Canvas canvas, String text, Offset offset, double size,
    {Color color = Colors.white, bool bold = false}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: size,
        color: color,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, offset);
}
