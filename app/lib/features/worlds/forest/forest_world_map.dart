import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/wallet_provider.dart';
import '../../../shared/providers/profile_provider.dart';
import '../../../shared/providers/world_provider.dart';
import '../../../shared/providers/fuel_provider.dart';
import '../../../shared/providers/salary_provider.dart';
import '../../../shared/widgets/screen_tutorial.dart';
import '../../../shared/helpers/notification_helper.dart';
import '../../../shared/widgets/blink_character.dart';
import '../../../shared/widgets/world_side_panels.dart';
import '../../../shared/widgets/game_popup.dart';
import '../misiones/misiones_screen.dart';
import '../misiones/quizzes_screen.dart';
import '../tienda/tienda_screen.dart';
import '../mercado/mercado_screen.dart';
import '../trabajos/trabajos_screen.dart';
import '../../wallet/screens/wallet_screen.dart';

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
  const imgRatio = _imgW / _imgH;
  final screenRatio = screenW / screenH;

  double scale, dx, dy;

  if (screenRatio > imgRatio) {
    scale = screenW / _imgW;
    dx = 0;
    dy = -(_imgH * scale - screenH) / 2;
  } else {
    scale = screenH / _imgH;
    dx = -(_imgW * scale - screenW) / 2;
    dy = 0;
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
    this.dialogBuilder,
  });

  final String asset;
  final String name;
  final String emoji;
  final double imgX;
  final double imgY;
  final double widthImg;
  final void Function(BuildContext)? dialogBuilder;
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
      asset: 'assets/worlds/forest/building_misiones.png',
      name: 'Misiones',
      emoji: '⚔️',
      imgX: 450,
      imgY: 430,
      widthImg: 520,
      dialogBuilder: showMisionesDialog,
    ),
    _BuildingData(
      asset: 'assets/worlds/forest/building_preguntas.png',
      name: 'Quizzes',
      emoji: '🧠',
      imgX: 1120,
      imgY: 280,
      widthImg: 520,
      dialogBuilder: showQuizzesDialog,
    ),
    _BuildingData(
      asset: 'assets/worlds/forest/building_tienda.png',
      name: 'Tienda',
      emoji: '🔮',
      imgX: 1780,
      imgY: 280,
      widthImg: 520,
      dialogBuilder: showTiendaDialog,
    ),
    // ── FILA INFERIOR ─────────────────────────
    _BuildingData(
      asset: 'assets/worlds/forest/building_bolsa.png',
      name: 'Mi Bolsa',
      emoji: '🎒',
      imgX: 850,
      imgY: 1000,
      widthImg: 520,
      dialogBuilder: showWalletDialog,
    ),
    _BuildingData(
      asset: 'assets/worlds/forest/building_mercado.png',
      name: 'Mercado',
      emoji: '🛒',
      imgX: 1600,
      imgY: 960,
      widthImg: 640,
      dialogBuilder: showMercadoDialog,
    ),
    _BuildingData(
      asset: 'assets/worlds/forest/building_trabajos.png',
      name: 'Trabajos',
      emoji: '🔨',
      imgX: 2200,
      imgY: 850,
      widthImg: 620,
      dialogBuilder: showTrabajosDialog,
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

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(currentWalletProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final fuelAsync = ref.watch(spaceFuelProvider);
    final salaryAsync = ref.watch(mySalaryStatusProvider);

    final coins = walletAsync.valueOrNull?.totalCoins ?? 0;
    final profile = profileAsync.valueOrNull;
    final fuel = fuelAsync.valueOrNull?.fuel ?? 0;
    final salaryStatus = salaryAsync.valueOrNull ?? {};
    final hasSalary = (salaryStatus['has_salary'] as bool? ?? false) &&
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
          body: 'Toca cualquier edificio para entrar. Algunos se desbloquean '
              'conforme avanzas en el juego.',
        ),
        TutorialStep(
          title: 'Tus monedas 🪙',
          body: 'Tus monedas disponibles aparecen arriba a la derecha. '
              '¡Gánalas completando misiones y preguntas!',
        ),
      ],
      child: Scaffold(
        backgroundColor: const Color(0xFF061206),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final panelW = w * 0.16;

            const imgRatio = _imgW / _imgH;
            final screenRatio = w / h;
            final scale = screenRatio > imgRatio ? w / _imgW : h / _imgH;

            // Centro del mapa en coordenadas del PNG
            final blinkCenter = _imgToScreen(1100, 560, w, h);
            final blinkWidth = 240 * scale;

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
                  top: blinkCenter.dy,
                  child: BlinkCharacterWidget(
                    width: blinkWidth,
                    enableBounce: false,
                  ),
                ),

                // ── Panel izquierdo — mismo formato que Galaxia ─────────
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: panelW,
                  child: WorldLeftPanel(profile: profile),
                ),

                // ── Panel derecho — mismo formato que Galaxia ───────────
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: panelW,
                  child: WorldRightPanel(
                    fuel: fuel,
                    hasSalary: hasSalary,
                    onSalaryClaim: hasSalary
                        ? () => handleSalaryClaim(context, ref)
                        : null,
                  ),
                ),

                // ── HUD central — mismo formato que Galaxia ─────────────
                buildWorldCenterHud(context, ref, coins, panelW),
              ],
            );
          },
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
      top: center.dy,
      child: GestureDetector(
        onTap: () {
          if (b.dialogBuilder != null) {
            b.dialogBuilder!(context);
          } else {
            showGamePopup(
              context,
              '${b.emoji} ${b.name} — ¡Próximamente!',
              accentColor: const Color(0xFF7C3AED),
              autoDismiss: const Duration(seconds: 2),
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
