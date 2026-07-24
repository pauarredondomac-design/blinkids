import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/character.dart';
import '../../../shared/providers/wallet_provider.dart';
import '../../../shared/providers/profile_provider.dart';
import '../../../shared/providers/character_provider.dart';
import '../../../shared/providers/world_provider.dart';
import '../../../shared/providers/fuel_provider.dart';
import '../../../shared/providers/salary_provider.dart';
import '../../../shared/widgets/screen_tutorial.dart';
import '../../../shared/widgets/child_notification_bell.dart';
import '../../../shared/helpers/notification_helper.dart';
import '../../../shared/widgets/profile_bottom_sheet.dart';
import '../../../shared/widgets/fuel_bar.dart';
import '../../../shared/widgets/blink_character.dart';
import '../../../shared/widgets/coin_display.dart';

// ─────────────────────────────────────────────
// Tamaño real de la imagen de fondo
// ─────────────────────────────────────────────
const double _imgW = 2752;
const double _imgH = 1536;

// ─────────────────────────────────────────────
// Convierte un punto en el espacio de la imagen
// al espacio de la pantalla (BoxFit.cover).
// ─────────────────────────────────────────────
Offset _imgToScreen(double px, double py, double screenW, double screenH) {
  final imgRatio    = _imgW / _imgH;
  final screenRatio = screenW / screenH;

  double scale, dx, dy;

  if (screenRatio > imgRatio) {
    scale = screenW / _imgW;
    dx    = 0;
    dy    = -(_imgH * scale - screenH) / 2;
  } else {
    scale = screenH / _imgH;
    dx    = -(_imgW * scale - screenW) / 2;
    dy    = 0;
  }

  return Offset(px * scale + dx, py * scale + dy);
}

// ─────────────────────────────────────────────
// Datos de cada edificio
// ─────────────────────────────────────────────
class _BuildingData {
  const _BuildingData({
    required this.asset,
    required this.name,
    required this.emoji,
    required this.imgX,
    required this.imgY,
    required this.widthImg,
    this.route,
  });

  final String asset;
  final String name;
  final String emoji;
  final double imgX;
  final double imgY;
  final double widthImg;
  final String? route;
}

// ─────────────────────────────────────────────
// ForestWorldMap
// ─────────────────────────────────────────────
class ForestWorldMap extends ConsumerStatefulWidget {
  const ForestWorldMap({super.key});

  @override
  ConsumerState<ForestWorldMap> createState() => _ForestWorldMapState();
}

class _ForestWorldMapState extends ConsumerState<ForestWorldMap> {
  // Posiciones en coordenadas del PNG 2048 × 1143
  static const _buildings = [
    // ── FILA SUPERIOR ─────────────────────────
    _BuildingData(
      asset:    'assets/worlds/forest/building_misiones.png',
      name:     'Misiones',
      emoji:    '⚔️',
      imgX:     450,
      imgY:     430,
      widthImg: 520,
      route:    '/world/misiones',
    ),
    _BuildingData(
      asset:    'assets/worlds/forest/building_preguntas.png',
      name:     'Preguntas',
      emoji:    '❓',
      imgX:     1120,
      imgY:     280,
      widthImg: 520,
      route:    '/world/preguntas',
    ),
    _BuildingData(
      asset:    'assets/worlds/forest/building_tienda.png',
      name:     'Tienda',
      emoji:    '🔮',
      imgX:     1780,
      imgY:     280,
      widthImg: 520,
      route:    '/world/tienda',
    ),
    // ── FILA INFERIOR ─────────────────────────
    _BuildingData(
      asset:    'assets/worlds/forest/building_bolsa.png',
      name:     'Mi Bolsa',
      emoji:    '🎒',
      imgX:     850,
      imgY:     1000,
      widthImg: 520,
      route:    '/wallet',
    ),
    _BuildingData(
      asset:    'assets/worlds/forest/building_mercado.png',
      name:     'Mercado',
      emoji:    '🛒',
      imgX:     1600,
      imgY:     960,
      widthImg: 640,
      route:    '/world/mercado',
    ),
    _BuildingData(
      asset:    'assets/worlds/forest/building_trabajos.png',
      name:     'Trabajos',
      emoji:    '🔨',
      imgX:     2200,
      imgY:     850,
      widthImg: 620,
      route:    '/world/trabajos',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentWorldProvider.notifier).state = 'forest';
      NotificationHelper.checkEngagement();
      // Registrar actividad diaria → racha + combustible
      ref.read(fuelNotifierProvider.notifier).recordDailyActivity();
    });
  }

  Future<void> _showSalaryDialog(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(salaryNotifierProvider.notifier).claim();
    if (!context.mounted) return;
    if (result.alreadyClaimed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya cobraste tu salario esta semana 😊',
              style: TextStyle(fontFamily: 'Nunito')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    ref.invalidate(currentWalletProvider);
    ref.invalidate(mySalaryStatusProvider);
    ref.invalidate(spaceFuelProvider);
    showDialog<void>(
      context: context,
      builder: (_) => _SalaryReceivedDialog(
        amount: result.amount,
        fuelAdded: result.fuelAdded,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync    = ref.watch(currentWalletProvider);
    final profileAsync   = ref.watch(currentProfileProvider);
    final characterAsync = ref.watch(currentCharacterProvider);
    final fuelAsync      = ref.watch(spaceFuelProvider);
    final salaryAsync    = ref.watch(mySalaryStatusProvider);

    final coins        = walletAsync.valueOrNull?.totalCoins ?? 0;
    final name         = profileAsync.valueOrNull?.displayName ?? 'Aventurero';
    final character    = characterAsync.valueOrNull;
    final fuel         = fuelAsync.valueOrNull?.fuel ?? 0;
    final salaryStatus = salaryAsync.valueOrNull ?? {};
    final hasSalary    = (salaryStatus['has_salary'] as bool? ?? false) &&
                         !(salaryStatus['already_claimed'] as bool? ?? true);

    return ScreenTutorial(
      tutorialKey: 'forest_map',
      steps: const [
        TutorialStep(
          title: '¡Bienvenido al Bosque! 🌲',
          body:
              'Este es tu mundo de aventuras. Cada edificio tiene actividades '
              'para aprender sobre finanzas.',
        ),
        TutorialStep(
          title: 'Explora los edificios 🏠',
          body:
              'Toca cualquier edificio para entrar. Algunos se desbloquean '
              'conforme avanzas en el juego.',
        ),
        TutorialStep(
          title: 'Tus monedas 🪙',
          body:
              'Tus monedas disponibles aparecen arriba a la derecha. '
              '¡Gánalas completando misiones y preguntas!',
        ),
      ],
      child: Scaffold(
        backgroundColor: const Color(0xFF061206),
        extendBody: true,
        body: Column(
          children: [
            // ── Header fijo ─────────────────────
            _ForestHeader(
              coins:       coins,
              playerName:  name,
              character:   character,
              fuel:        fuel,
              hasSalary:   hasSalary,
              onSalaryClaim: hasSalary
                  ? () => _showSalaryDialog(context, ref)
                  : null,
              onAvatarTap: () => showModalBottomSheet(
                context:            context,
                backgroundColor:    Colors.transparent,
                barrierColor:       Colors.black45,
                isScrollControlled: true,
                builder: (_) => const ProfileBottomSheet(
                  accentColor: Color(0xFF69F0AE),
                ),
              ),
            ),
            // ── Mundo ───────────────────────────
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = constraints.maxHeight;

                  final imgRatio    = _imgW / _imgH;
                  final screenRatio = w / h;
                  final scale =
                      screenRatio > imgRatio ? w / _imgW : h / _imgH;

                  // Centro del mapa en coordenadas del PNG
                  final blinkCenter = _imgToScreen(1100, 560, w, h);
                  final blinkWidth  = 240 * scale;

                  return Stack(
                    children: [
                      // ── Fondo ──────────────────────
                      Positioned.fill(
                        child: Image.asset(
                          'assets/worlds/forest/forest_background.png',
                          fit: BoxFit.cover,
                        ),
                      ),

                      // ── Edificios ──────────────────
                      for (final b in _buildings)
                        _buildingNode(context, b, w, h, scale),

                      // ── Blink en el centro ─────────
                      Positioned(
                        left: blinkCenter.dx - blinkWidth / 2,
                        top:  blinkCenter.dy,
                        child: BlinkCharacterWidget(
                          width: blinkWidth,
                          enableBounce: false,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildingNode(
    BuildContext context,
    _BuildingData b,
    double screenW,
    double screenH,
    double scale,
  ) {
    final center = _imgToScreen(b.imgX, b.imgY, screenW, screenH);
    final bWidth = b.widthImg * scale;

    return Positioned(
      left: center.dx - bWidth / 2,
      top:  center.dy,
      child: GestureDetector(
        onTap: () {
          if (b.route != null) {
            context.push(b.route!);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${b.emoji} ${b.name} — ¡Próximamente!',
                  style: const TextStyle(fontFamily: 'Nunito'),
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              b.asset,
              width: bWidth,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Helpers de XP para la barra del HUD
// ─────────────────────────────────────────────
// Emoji fijo del personaje (cosméticos pendientes → siempre 🦊)
const String _characterEmoji = '🦊';

double _xpProgress(int xp) => (xp % 100) / 100.0;

String _xpLabel(int xp) => '${xp % 100} / 100 XP';

// ─────────────────────────────────────────────
// Header fijo del bosque
// ─────────────────────────────────────────────
class _ForestHeader extends StatelessWidget {
  const _ForestHeader({
    required this.coins,
    required this.playerName,
    required this.fuel,
    required this.hasSalary,
    this.character,
    this.onAvatarTap,
    this.onSalaryClaim,
  });

  final int        coins;
  final String     playerName;
  final int        fuel;
  final bool       hasSalary;
  final Character? character;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onSalaryClaim;

  @override
  Widget build(BuildContext context) {
    final xp    = character?.xp    ?? 0;
    final level = character?.level ?? 1;
    const emoji = _characterEmoji;

    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xE5061206), Color(0xE5112211)],
        ),
        border: Border(
          bottom: BorderSide(color: const Color(0xFF69F0AE).withAlpha(70), width: 1),
        ),
      ),
      child: Row(
        children: [
          // ── Avatar + nombre + nivel + XP ───────────────────────
          GestureDetector(
            onTap: onAvatarTap,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withAlpha(60),
                border: Border.all(
                    color: const Color(0xFF69F0AE).withAlpha(150), width: 2),
              ),
              child: ClipOval(
                child: OverflowBox(
                  maxWidth: 84,
                  maxHeight: 84,
                  alignment: Alignment.topCenter,
                  child: Transform.translate(
                    offset: const Offset(0, -6),
                    child: const BlinkCharacterWidget(
                      width: 84,
                      enableBounce: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    playerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD600),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Nv. $level',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              SizedBox(
                width: 130,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _xpProgress(xp),
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF69F0AE)),
                        minHeight: 5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _xpLabel(xp),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontFamily: 'Nunito',
                        fontSize: 9,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // ── Barra de Combustible ──────────────────────
                    FuelBar(
                      fuel: fuel,
                      width: 130,
                      accentColor: const Color(0xFFFF6D00),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Spacer(),

          // ── Selector de mundos ──────────────────────────────────
          GestureDetector(
            onTap: () => context.push('/worlds', extra: 'forest'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(130),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text('🌐', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 5),
                  Text(
                    'Mundos',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // ── Chip salario disponible ─────────────────────────────
          if (hasSalary)
            GestureDetector(
              onTap: onSalaryClaim,
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD600).withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFD600)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('💰', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 4),
                    Text(
                      '¡Cobrar!',
                      style: TextStyle(
                        color: Color(0xFFFFD600),
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 600.ms)
              .then()
              .shimmer(duration: 1200.ms, color: Colors.white24),
            ),

          // ── Campana de notificaciones ───────────────────────────
          const ChildNotificationBell(
            accentColor: Color(0xFF69F0AE),
          ),

          const SizedBox(width: 14),

          // ── Monedas ─────────────────────────────────────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AnimatedCoin(size: 20),
              const SizedBox(width: 6),
              Text(
                '$coins',
                style: const TextStyle(
                  color: Color(0xFFFFD600),
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SalaryReceivedDialog — celebración al cobrar salario
// ─────────────────────────────────────────────────────────────────────────────
class _SalaryReceivedDialog extends StatelessWidget {
  const _SalaryReceivedDialog({required this.amount, required this.fuelAdded});
  final int amount;
  final int fuelAdded;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF061206),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💰', style: TextStyle(fontSize: 56))
                .animate()
                .scale(begin: const Offset(0.5, 0.5), duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: 12),
            const Text(
              '¡Salario cobrado!',
              style: TextStyle(
                color: Color(0xFFFFD600),
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '+$amount monedas Blink',
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'Nunito',
                fontSize: 15,
              ),
            ),
            if (fuelAdded > 0) ...[
              const SizedBox(height: 4),
              Text(
                '🚀 +$fuelAdded% combustible',
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFD600),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text(
                '¡Genial!',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
