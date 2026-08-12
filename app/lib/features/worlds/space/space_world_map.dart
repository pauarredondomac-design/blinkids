import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/providers/profile_provider.dart';
import '../../../data/models/profile.dart';
import '../../../shared/providers/wallet_provider.dart';
import '../../../shared/providers/fuel_provider.dart';
import '../../../shared/providers/salary_provider.dart';
import '../../../shared/widgets/blink_character.dart';
import '../../../shared/helpers/notification_helper.dart';
import '../../../shared/providers/demo_progress_provider.dart';
import '../../../shared/providers/world_provider.dart';
import '../../../shared/providers/blink_ambient_provider.dart';
import '../../../shared/helpers/blink_ambient_helper.dart';
import 'banco_estelar_screen.dart';
import '../trabajos/trabajos_screen.dart';
import '../misiones/misiones_screen.dart';
import '../tienda/tienda_screen.dart';
import '../../wallet/screens/wallet_screen.dart';
import '../../../shared/widgets/world_side_panels.dart';
import '../../../shared/widgets/game_popup.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SpaceWorldMap — Mundo único por ahora
// Layout: fondo espacial + paneles laterales + órbita + 5 edificios + planeta + Blink
// ─────────────────────────────────────────────────────────────────────────────

class SpaceWorldMap extends ConsumerStatefulWidget {
  const SpaceWorldMap({super.key});

  @override
  ConsumerState<SpaceWorldMap> createState() => _SpaceWorldMapState();
}

class _SpaceWorldMapState extends ConsumerState<SpaceWorldMap>
    with SingleTickerProviderStateMixin {
  late AnimationController _orbitCtrl;
  bool _worldNameChecked = false;
  String? _localWorldName;

  @override
  void initState() {
    super.initState();
    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentWorldProvider.notifier).state = 'space';
      NotificationHelper.checkEngagement();
      BlinkAmbientHelper.maybeGreet(ref);
      ref.listenManual<AsyncValue<Profile?>>(
        currentProfileProvider,
        (prev, next) {
          next.whenData((profile) {
            if (_worldNameChecked) return;
            _worldNameChecked = true;
            // No pedir nombre de galaxia a usuarios demo (ni con perfil isDemo, ni sin sesión)
            final isDemoUser = profile?.isDemo == true ||
                Supabase.instance.client.auth.currentUser == null;
            if (isDemoUser) return;
            final name = profile?.worldName ?? '';
            if (name.isEmpty && mounted) {
              _showWorldNameDialog();
            }
          });
        },
        fireImmediately: true,
      );

      ref.listenManual<DemoStore>(
        demoProgressProvider,
        (prev, next) {
          if (next.pendingMessage != null && mounted) {
            showGamePopup(context, next.pendingMessage!,
                accentColor: const Color(0xFF7C3AED));
            ref.read(demoProgressProvider.notifier).clearPendingMessage();
          }
        },
      );
    });
  }

  @override
  void dispose() {
    _orbitCtrl.dispose();
    super.dispose();
  }

  void _showWorldNameDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B3E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Column(
          children: [
            Text('🚀', style: TextStyle(fontSize: 48)),
            SizedBox(height: 8),
            Text(
              '¡Ponle nombre a tu galaxia!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            hintText: 'Ej: Galaxia Blink',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            counterStyle: const TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          _WorldNameButton(
            controller: controller,
            onSaved: (String savedName) {
              Navigator.of(ctx).pop();
              if (mounted) setState(() => _localWorldName = savedName);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).value;
    final wallet = ref.watch(currentWalletProvider).value;
    final worldName = _localWorldName ?? profile?.worldName ?? 'Mi Galaxia';
    // Demo = sin sesión real. Un niño con PIN tiene sesión real → no es demo.
    final supaUser = Supabase.instance.client.auth.currentUser;
    final isDemo = supaUser == null || (supaUser.isAnonymous == true);
    final demoState = ref.watch(demoProgressProvider);
    final spaceFuel = ref.watch(spaceFuelProvider).valueOrNull;
    // En demo, monedas/combustible viven solo en memoria — nunca en Supabase.
    final coins = isDemo ? demoState.coins : (wallet?.totalCoins ?? 0);
    final fuelLevel = isDemo ? demoState.fuel : (spaceFuel?.fuel ?? 0);
    final ambientMessage = ref.watch(blinkAmbientMessageProvider);
    final salaryStatus = ref.watch(mySalaryStatusProvider).valueOrNull ?? {};
    final hasSalary = (salaryStatus['has_salary'] as bool? ?? false) &&
        !(salaryStatus['already_claimed'] as bool? ?? true);

    return Scaffold(
      backgroundColor: const Color(0xFF020A18),
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final panelW = w * 0.16;

          return Stack(
            children: [
              // ── Fondo estático (RepaintBoundary = no se repinta en rebuilds) ──
              const Positioned.fill(
                  child: RepaintBoundary(child: _StaticBackground())),

              // ── Partículas ambientales flotantes ──────────────────────────
              const Positioned.fill(child: _SpaceParticles()),

              // ── Estrellas fugaces ─────────────────────────────────────────
              const Positioned.fill(child: _ShootingStars()),

              // ── Plataforma base (edificios se renderizan encima) ──────────
              Positioned.fill(
                child: Align(
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/worlds/space/estructuras.png',
                    height: h * 0.90,
                    fit: BoxFit.fitHeight,
                  ),
                ),
              ),

              // ── Edificios ─────────────────────────────────────────────────
              ..._buildBuildings(w, h, demoMode: isDemo),

              // ── Sombra/glow bajo Blink ────────────────────────────────────
              Positioned(
                left: w * 0.5 - h * 0.095,
                top: h * 0.25 + h * 0.38,
                child: Container(
                  width: h * 0.19,
                  height: h * 0.028,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF4FC3F7).withOpacity(0.55),
                        const Color(0xFF4FC3F7).withOpacity(0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // ── Blink ─────────────────────────────────────────────────────
              Positioned(
                left: w * 0.5 - (h * 0.20) / 3.2,
                top: h * 0.29,
                child: BlinkCharacterWidget(
                  width: h * 0.15,
                  enableBounce: false,
                ),
              ),

              // ── Burbuja ambiental de Blink ───────────────────────────────
              if (ambientMessage != null)
                Positioned(
                  left: w * 0.5 - (h * 0.20) / 3.2 + h * 0.14,
                  top: h * 0.29 - h * 0.02,
                  child: _AmbientBubble(
                    text: ambientMessage,
                    onDismiss: () => ref
                        .read(blinkAmbientMessageProvider.notifier)
                        .state = null,
                  ),
                ),

              // ── Nombre del mundo (watermark central) ──────────────────────
              Positioned(
                bottom: h * 0.04,
                left: panelW,
                right: panelW,
                child: Center(
                  child: Text(
                    worldName.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.06),
                      fontSize: h * 0.065,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ),

              // ── Panel izquierdo ───────────────────────────────────────────
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: panelW,
                child: WorldLeftPanel(profile: profile),
              ),

              // ── Panel derecho ─────────────────────────────────────────────
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: panelW,
                child: WorldRightPanel(
                  fuel: fuelLevel,
                  hasSalary: hasSalary,
                  onSalaryClaim:
                      hasSalary ? () => handleSalaryClaim(context, ref) : null,
                ),
              ),

              // ── HUD central superior ──────────────────────────────────────
              buildWorldCenterHud(context, ref, coins, panelW),
            ],
          );
        },
      ),
    );
  }

  // ── Edificios posicionados sobre las estructuras ───────────────────────────
  // fx/fy = fracción del rect de estructuras.png (no de la pantalla).
  // Así los edificios escalan y se mueven junto con la imagen de islas.
  //
  // estructuras.png: 3954×1767 px → aspect 2.237
  //   rendered width  = w * 0.80
  //   rendered height = (w * 0.80) / 2.237  ≈  w * 0.3576
  //   left            = w * 0.10  (centrada horizontalmente)
  //   top             = h - renderedHeight   (anclada al fondo)
  //
  // Para mover un edificio: cambia islandFx / islandFy.
  // Para cambiar tamaño:    cambia el campo size (fracción de imgW).
  List<Widget> _buildBuildings(double w, double h, {bool demoMode = false}) {
    // Rect de la imagen estructuras.png en coordenadas de pantalla
    const double natW = 3954, natH = 1767;
    final imgH = h * 0.90;
    final imgW = imgH * natW / natH; // ancho derivado del alto
    final imgLeft = (w - imgW) / 2; // centrada horizontalmente
    final imgTop = (h - imgH) / 2; // centrada verticalmente

    // Tamaño base de edificios como fracción del ancho de la imagen
    final bSize = imgW * 0.20; // ~20% del ancho de la imagen

    // Los PNG de edificios tienen distinto margen transparente alrededor del
    // dibujo (todos son lienzos de 3000×3000, pero el dibujo real ocupa un
    // % distinto de cada uno). Como Image.asset solo fija el ANCHO del
    // lienzo completo, sin este multiplicador cada edificio se vería de un
    // tamaño visual distinto aunque `size` sea igual. Multiplicador =
    // (relleno promedio del set) / (relleno real de ese PNG) — así el
    // dibujo de cada edificio queda del mismo tamaño visual en pantalla.
    const fillCompensation = {
      'banco': 0.97, // building_bolsa.png     — relleno 54.6%
      'trabajos':
          1.40, // building_trabajos.png   — relleno 37.9% (el más recortado)
      'misiones': 0.86, // building_misiones.png   — relleno 61.8%
      'tienda': 0.91, // building_tienda.png     — relleno 58.4%
      'alcancia': 1.02, // alcancia.png            — relleno 52.0%
    };
    double sizeFor(String id) => bSize * (fillCompensation[id] ?? 1.0);

    final demoState = ref.read(demoProgressProvider);
    bool locked(String id) => demoMode && !demoState.isUnlocked(id);

    // islandFx/islandFy: posición del centro de la isla en estructuras.png (0..1)
    // El edificio se centra horizontalmente y su base toca el centro de la isla.
    final buildings = [
      _BuildingData(
        id: 'banco',
        asset: 'assets/worlds/space/building_bolsa.png',
        label: 'Banco Estelar',
        openAsDialog: true,
        dialogBuilder: showBancoEstelarDialog,
        demoRoute: '/demo/banco',
        size: imgW * 0.22,
        locked: locked('banco'),
        islandFx: 0.31,
        islandFy: 0.59,
        topPad: 0.111,
        rightPad: 0.227,
        bottomPad: 0.432,
      ),
      _BuildingData(
        id: 'trabajos',
        asset: 'assets/worlds/space/building_trabajos.png',
        label: 'Trabajos',
        openAsDialog: true,
        dialogBuilder: showTrabajosDialog,
        demoRoute: '/demo/trabajos',
        size: imgW * 0.25,
        badgeCount: 1,
        locked: locked('trabajos'),
        islandFx: 0.66,
        islandFy: 0.54,
        topPad: 0.058,
        rightPad: 0.309,
        bottomPad: 0.370,
      ),
      _BuildingData(
        id: 'misiones',
        asset: 'assets/worlds/space/building_misiones.png',
        label: 'Misiones',
        openAsDialog: true,
        dialogBuilder: showMisionesDialog,
        demoRoute: '/demo/misiones',
        size: imgW * 0.25,
        badgeCount: 3,
        locked: locked('misiones'),
        islandFx: 0.35,
        islandFy: 1.05,
        topPad: 0.080,
        rightPad: 0.203,
        bottomPad: 0.364,
      ),
      _BuildingData(
        id: 'tienda',
        asset: 'assets/worlds/space/building_tienda.png',
        label: 'Tienda',
        openAsDialog: true,
        dialogBuilder: showTiendaDialog,
        demoRoute: '/demo/tienda',
        size: imgW * 0.25,
        locked: locked('tienda'),
        islandFx: 0.79,
        islandFy: 0.80,
        topPad: 0.155,
        rightPad: 0.230,
        bottomPad: 0.327,
      ),
      _BuildingData(
        id: 'alcancia',
        asset: 'assets/worlds/space/alcancia.png',
        label: 'Mi Bolsa',
        openAsDialog: true,
        dialogBuilder: showWalletDialog,
        demoRoute: '/demo/bolsa',
        size: imgW * 0.23,
        locked: locked('alcancia'),
        islandFx: 0.65,
        islandFy: 1.03,
        topPad: 0.065,
        rightPad: 0.266,
        bottomPad: 0.378,
      ),
      // _BuildingData(id: 'mercado', ..., islandFx: 0.72, islandFy: 0.48),
    ];

    return buildings.map((b) {
      // Centro de la isla en coordenadas de pantalla
      final cx = imgLeft + b.islandFx! * imgW;
      final cy = imgTop + b.islandFy! * imgH;
      // Edificio centrado horizontalmente; base del edificio en el centro de la isla
      final bx = cx - b.size / 2;
      final by = cy - b.size;
      return Positioned(
        left: bx,
        top: by,
        child: _BuildingButton(data: b, demoMode: demoMode),
      );
    }).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Burbuja de diálogo ambiental de Blink
// ─────────────────────────────────────────────────────────────────────────────
class _AmbientBubble extends StatelessWidget {
  const _AmbientBubble({required this.text, required this.onDismiss});
  final String text;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 210),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black38, blurRadius: 14, offset: Offset(0, 4)),
            ],
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Color(0xFF1A1A2E),
              height: 1.3,
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 250.ms)
        .slideY(begin: 0.2, end: 0, duration: 250.ms, curve: Curves.easeOut);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pantalla de carga mientras se precachean las imágenes del mapa
// ─────────────────────────────────────────────────────────────────────────────
class _WorldLoadingOverlay extends StatelessWidget {
  const _WorldLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060618),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/blink/blink_base.png',
              width: 100,
              height: 100,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 100,
              child: LinearProgressIndicator(
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                minHeight: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fondo estático — aislado en RepaintBoundary para no repintarse en rebuilds
// ─────────────────────────────────────────────────────────────────────────────
class _StaticBackground extends StatelessWidget {
  const _StaticBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/worlds/space/space_background.png',
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        ),
        Positioned.fill(
          child: ColoredBox(color: Colors.black.withOpacity(0.15)),
        ),
      ],
    );
  }
}

// Abre la pantalla demo (banco) como diálogo avanzando el stage al cerrar
void _showDemoDialog(BuildContext context, WidgetRef ref, String demoRoute) {
  // Mapeo demoRoute → widget
  final configs = <String, (Widget, int, String)>{
    '/demo/bolsa': (
      const WalletScreen(),
      0,
      '🔓 ¡Desbloqueaste Banco Estelar!'
    ),
    '/demo/banco': (
      const BancoEstelarScreen(),
      1,
      '🔓 ¡Desbloqueaste Misiones!'
    ),
    '/demo/misiones': (
      const MisionesScreen(),
      2,
      '🔓 ¡Desbloqueaste Trabajos!'
    ),
    '/demo/trabajos': (
      const TrabajosScreen(),
      3,
      '🔓 ¡Desbloqueaste la Tienda!'
    ),
    '/demo/tienda': (const TiendaScreen(), 4, '🎉 ¡Has completado la demo!'),
  };
  final cfg = configs[demoRoute] ?? configs['/demo/bolsa']!;
  final screen = cfg.$1;
  final atStage = cfg.$2;
  final unlockMsg = cfg.$3;

  final size = MediaQuery.of(context).size;
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: demoRoute,
    barrierColor: Colors.black.withOpacity(0.65),
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return ScaleTransition(
        scale: Tween<double>(begin: 0.90, end: 1.0).animate(curved),
        child: FadeTransition(opacity: anim, child: child),
      );
    },
    pageBuilder: (ctx, _, __) {
      final store = ref.read(demoProgressProvider);
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            width: size.width * 0.92,
            height: size.height * 0.88,
            child: PopScope(
              canPop: true,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) return;
                if (store.stage == atStage) {
                  store.addXp(50);
                  store.advanceStage();
                  store.setPendingMessage(unlockMsg);
                }
              },
              child: screen,
            ),
          ),
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Botón de edificio — con glow base, animación flotante, label, badge, candado
// ─────────────────────────────────────────────────────────────────────────────
class _BuildingButton extends ConsumerWidget {
  const _BuildingButton({required this.data, this.demoMode = false});
  final _BuildingData data;
  final bool demoMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── Imagen base (grises si bloqueado) ──────────────────────────────────
    Widget image = Image.asset(data.asset, width: data.size);
    if (data.locked) {
      image = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          0.6,
          0,
        ]),
        child: image,
      );
    }

    // ── Imagen + glow elíptico debajo (se animan juntos) ───────────────────
    Widget imageWithShadow = Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        // Glow base (anclaje al suelo)
        Positioned(
          bottom: -4,
          child: Container(
            width: data.size * 0.55,
            height: data.size * 0.055,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF4FC3F7)
                      .withOpacity(data.locked ? 0.12 : 0.42),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        image,
      ],
    );

    Widget building = imageWithShadow;

    // ── Overlay: candado ───────────────────────────────────────────────────
    if (data.locked) {
      building = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          building,
          Container(
            width: data.size * 0.35,
            height: data.size * 0.35,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.65),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white30, width: 1.2),
            ),
            child:
                const Icon(Icons.lock_rounded, color: Colors.white70, size: 18),
          ),
        ],
      );
    }

    // ── Overlay: badge de notificación ─────────────────────────────────────
    if (data.badgeCount > 0) {
      building = Stack(
        clipBehavior: Clip.none,
        children: [
          building,
          Positioned(
            // Se ancla a la esquina superior-derecha del DIBUJO real
            // (usando el margen transparente medido por PNG), no del
            // lienzo completo — así no queda "flotando" en el aire.
            top: max(2, data.size * data.topPad - 9),
            right: max(2, data.size * data.rightPad - 10),
            child: Container(
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B3B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.60),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Text(
                data.badgeCount > 9 ? '9+' : '${data.badgeCount}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // ── Label del edificio ─────────────────────────────────────────────────
    final label = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.60),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: data.locked
              ? Colors.white.withOpacity(0.15)
              : const Color(0xFF4FC3F7).withOpacity(0.40),
          width: 1,
        ),
        boxShadow: data.locked
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF4FC3F7).withOpacity(0.15),
                  blurRadius: 6,
                ),
              ],
      ),
      child: Text(
        data.label,
        style: TextStyle(
          color: data.locked ? Colors.white.withOpacity(0.40) : Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );

    return GestureDetector(
      onTap: data.locked
          ? null
          : () {
              if (demoMode && data.demoRoute.isNotEmpty) {
                // Demo: abrir como diálogo con DemoStageGate envolviendo la pantalla
                _showDemoDialog(context, ref, data.demoRoute);
                return;
              }
              data.dialogBuilder?.call(context);
            },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          building,
          // El label se sube para pegarse a la base visual del dibujo
          // (descontando el margen transparente inferior del PNG) en vez
          // de quedar lejos, pegado a la base del lienzo completo.
          Transform.translate(
            offset: Offset(0, -(data.size * data.bottomPad) + 8),
            child: label,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data de cada edificio
// ─────────────────────────────────────────────────────────────────────────────
class _BuildingData {
  final String id;
  final String asset;
  final String label;
  final String demoRoute;
  final bool openAsDialog;
  final void Function(BuildContext)? dialogBuilder;
  final double size;
  final int badgeCount;
  final bool locked;
  // Posición como fracción del rect de estructuras.png (0..1)
  final double? islandFx;
  final double? islandFy;
  // Margen transparente del PNG (fracción 0..1 del lienzo) alrededor del
  // dibujo real, medido con Python/PIL. Se usa para pegar el badge y el
  // label al dibujo en vez de al lienzo completo.
  final double topPad;
  final double rightPad;
  final double bottomPad;

  const _BuildingData({
    required this.id,
    required this.asset,
    required this.label,
    this.demoRoute = '',
    this.openAsDialog = false,
    this.dialogBuilder,
    required this.size,
    this.badgeCount = 0,
    this.locked = false,
    this.islandFx,
    this.islandFy,
    this.topPad = 0.10,
    this.rightPad = 0.25,
    this.bottomPad = 0.37,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Painter de la órbita elíptica — con capas de glow
// ─────────────────────────────────────────────────────────────────────────────
class _OrbitPainter extends CustomPainter {
  final double w, h;
  const _OrbitPainter({required this.w, required this.h});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = w * 0.5;
    final cy = h * 0.54;
    final rx = w * 0.34;
    final ry = h * 0.27;
    final rect =
        Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2);

    // ── Capa 1: glow exterior difuso ──────────────────────────────────────
    canvas.drawOval(
      rect,
      Paint()
        ..color = const Color(0xFF4FC3F7).withOpacity(0.07)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // ── Capa 2: glow medio ────────────────────────────────────────────────
    canvas.drawOval(
      rect,
      Paint()
        ..color = const Color(0xFF4FC3F7).withOpacity(0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // ── Capa 3: línea principal nítida ────────────────────────────────────
    canvas.drawOval(
      rect,
      Paint()
        ..color = const Color(0xFF4FC3F7).withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // ── Segunda órbita decorativa interior ───────────────────────────────
    final rect2 = Rect.fromCenter(
        center: Offset(cx, cy), width: rx * 1.3, height: ry * 1.3);
    canvas.drawOval(
      rect2,
      Paint()
        ..color = const Color(0xFF4FC3F7).withOpacity(0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.w != w || old.h != h;
}

// ─────────────────────────────────────────────────────────────────────────────
// Partículas ambientales flotantes — puntos de luz
// ─────────────────────────────────────────────────────────────────────────────
class _SpaceParticles extends StatefulWidget {
  const _SpaceParticles();

  @override
  State<_SpaceParticles> createState() => _SpaceParticlesState();
}

class _SpaceParticlesState extends State<_SpaceParticles> {
  late final List<_ParticleData> _particles;

  @override
  void initState() {
    super.initState();
    final rng = Random(42);
    _particles = List.generate(
        22,
        (i) => _ParticleData(
              x: rng.nextDouble(),
              y: rng.nextDouble(),
              size: 1.2 + rng.nextDouble() * 2.4,
              opacity: 0.20 + rng.nextDouble() * 0.55,
              durationMs: 2400 + (rng.nextDouble() * 3800).toInt(),
              delayMs: (rng.nextDouble() * 3200).toInt(),
              moveY: 4.0 + rng.nextDouble() * 10.0,
              isCyan: rng.nextBool(),
            ));
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return Stack(
            children: _particles.map((p) {
              final color = p.isCyan ? const Color(0xFF4FC3F7) : Colors.white;
              return Positioned(
                left: p.x * w,
                top: p.y * h,
                child: Container(
                  width: p.size,
                  height: p.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(p.opacity),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(p.opacity * 0.70),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                )
                    .animate(
                      onPlay: (c) => c.repeat(reverse: true),
                      delay: Duration(milliseconds: p.delayMs),
                    )
                    .moveY(
                      begin: 0,
                      end: -p.moveY,
                      duration: Duration(milliseconds: p.durationMs),
                      curve: Curves.easeInOut,
                    )
                    .fade(
                      begin: p.opacity * 0.30,
                      end: p.opacity,
                      duration: Duration(milliseconds: p.durationMs),
                    ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _ParticleData {
  final double x, y, size, opacity, moveY;
  final int durationMs, delayMs;
  final bool isCyan;

  const _ParticleData({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.durationMs,
    required this.delayMs,
    required this.moveY,
    required this.isCyan,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Estrellas fugaces — disparan en ráfagas aleatorias cruzando la pantalla
// ─────────────────────────────────────────────────────────────────────────────
class _ShootingStars extends StatefulWidget {
  const _ShootingStars();
  @override
  State<_ShootingStars> createState() => _ShootingStarsState();
}

class _ShootingStarsState extends State<_ShootingStars>
    with TickerProviderStateMixin {
  static const _count = 4;
  late final List<AnimationController> _ctrls;
  late final List<_StarData> _data;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(
      _count,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 650),
      ),
    );
    _data = List.generate(_count, (_) => _randomStar());

    // Arrancar con delays escalonados
    for (int i = 0; i < _count; i++) {
      Future.delayed(Duration(milliseconds: 800 + i * 2200), () {
        if (mounted) _fire(i);
      });
    }
  }

  _StarData _randomStar() => _StarData(
        startX: _rng.nextDouble() * 0.90,
        startY: _rng.nextDouble() * 0.80,
        angleDeg: 15.0 + _rng.nextDouble() * 35.0,
        length: 0.12 + _rng.nextDouble() * 0.14,
        width: 1.2 + _rng.nextDouble() * 1.2,
      );

  void _fire(int i) {
    if (!mounted) return;
    _data[i] = _randomStar();
    _ctrls[i].forward(from: 0).then((_) {
      if (!mounted) return;
      final delay = 2200 + _rng.nextInt(5000);
      Future.delayed(Duration(milliseconds: delay), () => _fire(i));
    });
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge(_ctrls),
        builder: (ctx, _) => CustomPaint(
          painter: _ShootingStarPainter(ctrls: _ctrls, data: _data),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _StarData {
  final double startX, startY, angleDeg, length, width;
  const _StarData({
    required this.startX,
    required this.startY,
    required this.angleDeg,
    required this.length,
    required this.width,
  });
}

class _ShootingStarPainter extends CustomPainter {
  final List<AnimationController> ctrls;
  final List<_StarData> data;
  const _ShootingStarPainter({required this.ctrls, required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < ctrls.length; i++) {
      final t = ctrls[i].value;
      if (t <= 0) continue;

      final d = data[i];
      final rad = d.angleDeg * pi / 180;
      final dx = cos(rad);
      final dy = sin(rad);
      final travel = d.length * size.width;
      final trailLen = travel * 0.40;

      // Cabeza: avanza a lo largo de la dirección
      final hx = d.startX * size.width + dx * travel * t;
      final hy = d.startY * size.height + dy * travel * t;

      // Cola: posición fija detrás de la cabeza
      final tx = hx - dx * trailLen;
      final ty = hy - dy * trailLen;

      // Opacidad: entra rápido, sale suave al final
      final alpha = (t < 0.15
              ? t / 0.15
              : t > 0.70
                  ? (1.0 - t) / 0.30
                  : 1.0)
          .clamp(0.0, 1.0)
          .toDouble();

      if (alpha <= 0) continue;

      // ── Trazo degradado ────────────────────────────────────────────────
      canvas.drawLine(
        Offset(tx, ty),
        Offset(hx, hy),
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              Colors.white.withOpacity(0.80 * alpha),
            ],
          ).createShader(Rect.fromPoints(Offset(tx, ty), Offset(hx, hy)))
          ..strokeWidth = d.width * alpha
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );

      // ── Punto brillante en la cabeza ───────────────────────────────────
      canvas.drawCircle(
        Offset(hx, hy),
        d.width * 1.5 * alpha,
        Paint()
          ..color = Colors.white.withOpacity(0.95 * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  @override
  bool shouldRepaint(_ShootingStarPainter old) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Botón del diálogo de nombre del mundo
// ─────────────────────────────────────────────────────────────────────────────
class _WorldNameButton extends StatefulWidget {
  const _WorldNameButton({required this.controller, required this.onSaved});
  final TextEditingController controller;
  final void Function(String savedName) onSaved;

  @override
  State<_WorldNameButton> createState() => _WorldNameButtonState();
}

class _WorldNameButtonState extends State<_WorldNameButton> {
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4FC3F7),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _saving
                ? null
                : () async {
                    final name = widget.controller.text.trim();
                    if (name.isEmpty) return;
                    setState(() {
                      _saving = true;
                      _error = null;
                    });
                    try {
                      await Supabase.instance.client
                          .rpc('set_world_name', params: {'p_name': name});
                      widget.onSaved(name);
                    } catch (e) {
                      if (mounted) {
                        setState(() {
                          _saving = false;
                          _error = 'Error al guardar. Inténtalo de nuevo.';
                        });
                      }
                    }
                  },
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    '¡Listo, despeguemos! 🌟',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
