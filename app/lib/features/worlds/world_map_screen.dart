import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_sizes.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/wallet_provider.dart';
import '../../shared/widgets/screen_tutorial.dart';
import '../../shared/widgets/coin_display.dart';
import 'widgets/space_buildings.dart';

class WorldMapScreen extends ConsumerWidget {
  const WorldMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(currentWalletProvider);
    final user = ref.watch(currentUserProvider);
    final coins = wallet.valueOrNull?.totalCoins ?? 0;
    final username = user?.userMetadata?['username'] as String? ??
        user?.email?.split('@').first ??
        'Aventurero';

    return ScreenTutorial(
      tutorialKey: 'world_map',
      steps: const [
        TutorialStep(
          title: '🗺️ El Mapa Espacial',
          body:
              '¡Bienvenido a Blinkids! Aquí viven todas las actividades. Cada estación es un lugar diferente.',
        ),
        TutorialStep(
          title: '🚀 Las Estaciones',
          body:
              'Toca una estación para entrar. Empieza por "Mi Bolsa" para distribuir tus monedas de inicio.',
        ),
      ],
      child: Scaffold(
        body: Stack(
          children: [
            const _SpaceBackground(),
            const _StarField(),
            const _SpaceDecorations(),
            SafeArea(
              child: Column(
                children: [
                  _SpaceHud(username: username, coins: coins),
                  Expanded(
                    child: _SpaceMap(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Fondo
// ─────────────────────────────────────────────
class _SpaceBackground extends StatelessWidget {
  const _SpaceBackground();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF020817), Color(0xFF0D1B4B), Color(0xFF1A0533)],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Estrellas
// ─────────────────────────────────────────────
class _StarField extends StatelessWidget {
  const _StarField();
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: List.generate(65, (i) {
        final x = ((i * 37.3 + i * i * 0.7) % 97) / 100;
        final y = ((i * 17.7 + i * 13.1) % 93) / 100;
        final sz = (i % 4 == 0)
            ? 2.5
            : (i % 4 == 1)
                ? 1.8
                : 1.2;
        final op = 0.4 + (i % 5) * 0.12;
        return Positioned(
          left: size.width * x,
          top: size.height * y,
          child: Container(
            width: sz,
            height: sz,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((op * 255).toInt()),
              shape: BoxShape.circle,
            ),
          )
              .animate(
                  onPlay: (c) => c.repeat(reverse: true),
                  delay: Duration(milliseconds: i * 80 % 2000))
              .fadeIn(duration: 900.ms)
              .then()
              .fadeOut(duration: 900.ms),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────
// Decoraciones
// ─────────────────────────────────────────────
class _SpaceDecorations extends StatelessWidget {
  const _SpaceDecorations();
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          right: -15,
          top: 20,
          child: Opacity(
            opacity: .55,
            child: const Text('🪐', style: TextStyle(fontSize: 90))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(
                    begin: 0,
                    end: -10,
                    duration: 5000.ms,
                    curve: Curves.easeInOut)
                .then()
                .moveY(begin: -10, end: 0, duration: 5000.ms),
          ),
        ),
        Positioned(
          left: 5,
          bottom: 30,
          child: Opacity(
            opacity: .4,
            child: const Text('🌑', style: TextStyle(fontSize: 55))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(
                    begin: 0,
                    end: -6,
                    duration: 3500.ms,
                    curve: Curves.easeInOut)
                .then()
                .moveY(begin: -6, end: 0, duration: 3500.ms),
          ),
        ),
        Positioned(
          right: 70,
          bottom: 15,
          child: Opacity(
            opacity: .5,
            child: const Text('🛸', style: TextStyle(fontSize: 32))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(
                    begin: 0,
                    end: -8,
                    duration: 2000.ms,
                    curve: Curves.easeInOut)
                .then()
                .moveY(begin: -8, end: 0, duration: 2000.ms),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// HUD
// ─────────────────────────────────────────────
class _SpaceHud extends StatelessWidget {
  const _SpaceHud({required this.username, required this.coins});
  final String username;
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md, vertical: AppSizes.xs),
      child: Row(
        children: [
          // Avatar + nombre
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.sm, vertical: AppSizes.xs),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(18),
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              border: Border.all(color: Colors.white.withAlpha(30)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                        colors: [Color(0xFF7C4DFF), Color(0xFF00BCD4)]),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C4DFF).withAlpha(120),
                        blurRadius: 8,
                      )
                    ],
                  ),
                  child: const Center(
                      child: Text('🧑‍🚀', style: TextStyle(fontSize: 18))),
                ),
                const SizedBox(width: AppSizes.xs),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(username,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: AppSizes.fontSm,
                            fontFamily: 'Nunito')),
                    const Text('Nivel 1 · Explorador',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            fontFamily: 'Nunito')),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          // Monedas
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.sm, vertical: AppSizes.xs),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC107).withAlpha(38),
              borderRadius: BorderRadius.circular(AppSizes.radiusRound),
              border: Border.all(
                  color: const Color(0xFFFFC107).withAlpha(153), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFFFFC107).withAlpha(50), blurRadius: 8)
              ],
            ),
            child: Row(
              children: [
                const AnimatedCoin(size: 16),
                const SizedBox(width: 4),
                Text('$coins',
                    style: const TextStyle(
                        color: Color(0xFFFFC107),
                        fontWeight: FontWeight.w800,
                        fontSize: AppSizes.fontMd,
                        fontFamily: 'Nunito')),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withAlpha(30)),
            ),
            child: const Icon(Icons.notifications_outlined,
                color: Colors.white70, size: 18),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Mapa con edificios 2D
// ─────────────────────────────────────────────
class _SpaceMap extends StatelessWidget {
  static const _stations = [
    _Station('Mi Bolsa', SpaceBuildingType.vault, '/wallet', Color(0xFF00E5FF),
        true),
    _Station(
        'Misiones', SpaceBuildingType.command, null, Color(0xFFFF6E40), false),
    _Station(
        'Trabajos', SpaceBuildingType.workshop, null, Color(0xFFFFD740), false),
    _Station(
        'Preguntas', SpaceBuildingType.lab, null, Color(0xFFCE93D8), false),
    _Station(
        'Mercado', SpaceBuildingType.market, null, Color(0xFF69F0AE), false),
    _Station('Tienda', SpaceBuildingType.store, null, Color(0xFFF48FB1), false),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bw = constraints.maxWidth;
        final bh = constraints.maxHeight;
        // Posiciones de cada estación (6 en 2 filas de 3)
        final positions = [
          Offset(bw * .16, bh * .10), // Mi Bolsa
          Offset(bw * .50, bh * .08), // Misiones
          Offset(bw * .84, bh * .10), // Trabajos
          Offset(bw * .16, bh * .58), // Preguntas
          Offset(bw * .50, bh * .60), // Mercado
          Offset(bw * .84, bh * .58), // Tienda
        ];

        return Stack(
          children: [
            // Caminos entre estaciones
            Positioned.fill(
              child: CustomPaint(
                painter: _PathPainter(positions),
              ),
            ),
            // Edificios
            for (int i = 0; i < _stations.length; i++)
              Positioned(
                left: positions[i].dx - 55,
                top: positions[i].dy - 10,
                child: _StationNode(
                  station: _stations[i],
                  index: i,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Station {
  const _Station(this.name, this.type, this.route, this.color, this.unlocked);
  final String name;
  final SpaceBuildingType type;
  final String? route;
  final Color color;
  final bool unlocked;
}

// ─────────────────────────────────────────────
// Nodo de estación
// ─────────────────────────────────────────────
class _StationNode extends StatelessWidget {
  const _StationNode({required this.station, required this.index});
  final _Station station;
  final int index;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: station.route != null ? () => context.go(station.route!) : null,
      child: SizedBox(
        width: 110,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Edificio 2D
            Stack(
              alignment: Alignment.center,
              children: [
                if (station.unlocked)
                  Container(
                    width: 106,
                    height: 106,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: station.color.withAlpha(80),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                SpaceBuilding(type: station.type, size: 100),
                if (!station.unlocked)
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(140),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text('🔒', style: TextStyle(fontSize: 30)),
                    ),
                  ),
              ],
            )
                .animate()
                .fadeIn(
                    delay: Duration(milliseconds: index * 90), duration: 400.ms)
                .scale(
                    begin: const Offset(.7, .7),
                    end: const Offset(1, 1),
                    curve: Curves.easeOutBack),
            const SizedBox(height: 6),
            // Etiqueta
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: station.unlocked
                    ? station.color.withAlpha(38)
                    : Colors.white.withAlpha(13),
                borderRadius: BorderRadius.circular(AppSizes.radiusRound),
                border: Border.all(
                  color: station.unlocked
                      ? station.color.withAlpha(128)
                      : Colors.white.withAlpha(50),
                ),
              ),
              child: Text(
                station.name,
                style: TextStyle(
                  fontSize: AppSizes.fontXs,
                  fontWeight: FontWeight.w700,
                  color: station.unlocked ? Colors.white : Colors.white38,
                  fontFamily: 'Nunito',
                ),
              ),
            ).animate().fadeIn(
                delay: Duration(milliseconds: index * 90 + 180),
                duration: 300.ms),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Caminos entre estaciones
// ─────────────────────────────────────────────
class _PathPainter extends CustomPainter {
  const _PathPainter(this.positions);
  final List<Offset> positions;

  static const _connections = [
    [0, 1], [1, 2], // fila superior
    [3, 4], [4, 5], // fila inferior
    [0, 3], [1, 4], [2, 5], // verticales
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final dashPaint = Paint()
      ..color = Colors.white.withAlpha(45)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withAlpha(25)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    for (final conn in _connections) {
      final p1 = positions[conn[0]];
      final p2 = positions[conn[1]];
      // Brillo
      canvas.drawLine(
          Offset(p1.dx, p1.dy + 50), Offset(p2.dx, p2.dy + 50), glowPaint);
      // Línea punteada
      _drawDashed(canvas, Offset(p1.dx, p1.dy + 50), Offset(p2.dx, p2.dy + 50),
          dashPaint);
    }
  }

  void _drawDashed(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashLen = 6.0;
    const gapLen = 5.0;
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final dist = (dx * dx + dy * dy) == 0 ? 1 : (dx * dx + dy * dy);
    final len = dist == 1
        ? 0.0
        : (dx * dx + dy * dy) == 0
            ? 0.0
            : (p2 - p1).distance;
    if (len == 0) return;
    final ux = dx / len;
    final uy = dy / len;
    double drawn = 0;
    bool isDash = true;
    while (drawn < len) {
      final seg = isDash ? dashLen : gapLen;
      final end = drawn + seg > len ? len : drawn + seg;
      if (isDash) {
        canvas.drawLine(
          Offset(p1.dx + ux * drawn, p1.dy + uy * drawn),
          Offset(p1.dx + ux * end, p1.dy + uy * end),
          paint,
        );
      }
      drawn = end;
      isDash = !isDash;
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
