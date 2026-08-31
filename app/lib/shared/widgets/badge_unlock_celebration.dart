import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/badge.dart';
import '../providers/badge_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BadgeUnlockCelebration — overlay a pantalla completa que se muestra cuando
// el jugador desbloquea una medalla: la medalla aparece en el centro con
// líneas de luz girando alrededor. Reemplaza al toast pequeño de antes.
// ─────────────────────────────────────────────────────────────────────────────

/// Muestra la celebración de cada medalla nueva, una tras otra (espera a que
/// el jugador la cierre —o el auto-dismiss— antes de mostrar la siguiente).
/// Seguro de llamar con una lista vacía.
Future<void> showBadgeUnlockCelebrations(
  BuildContext context,
  WidgetRef ref,
  List<String> newBadgeIds,
) async {
  if (newBadgeIds.isEmpty) return;
  final defs = await ref.read(badgeDefinitionsProvider.future);
  for (final id in newBadgeIds) {
    if (!context.mounted) return;
    BadgeDefinition? def;
    for (final d in defs) {
      if (d.id == id) {
        def = d;
        break;
      }
    }
    await _showCelebration(context, badgeId: id, def: def);
  }
}

Future<void> _showCelebration(
  BuildContext context, {
  required String badgeId,
  BadgeDefinition? def,
}) {
  final completer = Completer<void>();
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _CelebrationEntry(
      badgeId: badgeId,
      def: def,
      onDone: () {
        entry.remove();
        if (!completer.isCompleted) completer.complete();
      },
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _CelebrationEntry extends StatefulWidget {
  const _CelebrationEntry({
    required this.badgeId,
    required this.def,
    required this.onDone,
  });

  final String badgeId;
  final BadgeDefinition? def;
  final VoidCallback onDone;

  @override
  State<_CelebrationEntry> createState() => _CelebrationEntryState();
}

class _CelebrationEntryState extends State<_CelebrationEntry>
    with TickerProviderStateMixin {
  late final AnimationController _rayCtrl;
  late final AnimationController _popCtrl;
  late final Animation<double> _pop;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _rayCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _popCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _pop = CurvedAnimation(parent: _popCtrl, curve: Curves.elasticOut);
    _popCtrl.forward();
    Future.delayed(const Duration(seconds: 5), _close);
  }

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;
    await _popCtrl.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _rayCtrl.dispose();
    _popCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.def?.name ?? '¡Nueva medalla!';
    final description = widget.def?.description;
    final emoji = widget.def?.emoji ?? '🏅';
    final imageAsset = widget.def?.imageAsset;
    final artSize = (MediaQuery.sizeOf(context).height * 0.48)
        .clamp(180.0, 320.0)
        .toDouble();

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        child: FadeTransition(
          opacity: _pop,
          child: Container(
            color: Colors.black.withAlpha(210),
            child: Center(
              child: ScaleTransition(
                scale: _pop,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: artSize,
                      height: artSize,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _rayCtrl,
                            builder: (context, _) => CustomPaint(
                            size: Size.square(artSize),
                              painter: _LightRaysPainter(_rayCtrl.value),
                            ),
                          ),
                          _BadgeArt(imageAsset: imageAsset, emoji: emoji),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '¡MEDALLA DESBLOQUEADA!',
                      style: TextStyle(
                        color: Color(0xFFFFD54A),
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    GestureDetector(
                      onTap: _close,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black54,
                                blurRadius: 12,
                                offset: Offset(0, 4)),
                          ],
                        ),
                        child: const Text(
                          '¡Genial!',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgeArt extends StatelessWidget {
  const _BadgeArt({required this.imageAsset, required this.emoji});
  final String? imageAsset;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      height: 190,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD54A).withAlpha(140),
            blurRadius: 40,
            spreadRadius: 6,
          ),
        ],
      ),
      child: imageAsset != null
          ? Image.asset(
              imageAsset!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Center(
                child: Text(emoji, style: const TextStyle(fontSize: 96)),
              ),
            )
          : Center(
              child: Text(emoji, style: const TextStyle(fontSize: 96)),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Líneas de luz girando alrededor de la medalla
// ─────────────────────────────────────────────────────────────────────────────
class _LightRaysPainter extends CustomPainter {
  _LightRaysPainter(this.t);
  final double t;

  static const _rayCount = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.width / 2;
    final rotation = t * 2 * math.pi;

    for (int i = 0; i < _rayCount; i++) {
      final angle = rotation + (i / _rayCount) * 2 * math.pi;
      final pulse = 0.55 + 0.45 * math.sin(rotation * 2 + i);
      final innerR = maxRadius * 0.36;
      final outerR = maxRadius * (0.75 + 0.2 * pulse);

      final dir = Offset(math.cos(angle), math.sin(angle));
      final perp = Offset(-dir.dy, dir.dx);
      final halfWidth = 5.0 + 4.0 * pulse;

      final p1 = center + dir * innerR + perp * halfWidth;
      final p2 = center + dir * innerR - perp * halfWidth;
      final p3 = center + dir * outerR;

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..close();

      final color = i.isEven
          ? const Color(0xFFFFD54A)
          : const Color(0xFFFFF4C2);
      final paint = Paint()
        ..color = color.withAlpha((110 * pulse + 40).round())
        ..style = PaintingStyle.fill;

      canvas.drawPath(path, paint);
    }

    // Anillo de brillo suave alrededor del centro
    final ringPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFE9A8).withAlpha(90),
          const Color(0xFFFFE9A8).withAlpha(0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius * 0.6));
    canvas.drawCircle(center, maxRadius * 0.6, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _LightRaysPainter oldDelegate) =>
      oldDelegate.t != t;
}
