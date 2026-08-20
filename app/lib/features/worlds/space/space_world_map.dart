import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/providers/profile_provider.dart';
import '../../../data/models/profile.dart';
import '../../../shared/widgets/blink_avatar.dart';
import '../../../shared/widgets/blink_reaction.dart';
import '../../../shared/theme/game_tokens.dart';
import '../../../data/repositories/building_question_repository.dart';
import '../../../data/repositories/wallet_repository.dart';
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
import '../../../data/services/analytics_service.dart';
import '../../../shared/providers/badge_provider.dart';
import '../../../shared/providers/map_badge_provider.dart';
import '../../../shared/widgets/badge_unlock_celebration.dart';
import '../../../shared/widgets/modal_corners.dart';

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
  Timer? _linkReminderTimer;

  // ── Mover la estructura + edificios como un solo bloque ───────────────────
  // Cámbialos y guarda para mover TODO junto (la imagen estructuras.png y
  // los 5 edificios), sin perder la alineación entre ellos.
  // Positivo en X = mueve a la derecha. Positivo en Y = mueve hacia abajo.
  static const double structureOffsetX =
      -35.0; // -1.0 = mueve 1px a la izquierda
  static const double structureOffsetY = 0;

  // ── Guía interactiva de bienvenida (solo primera vez, sesión real) ────────
  // Demo: recorrido corto (solo Mi Bolsa + Banco Estelar, el ciclo
  // "reparto → veo crecer") para una demo rápida. Cuenta real: los 5 edificios.
  static const _kFullGuideOrder = [
    'alcancia',
    'trabajos',
    'misiones',
    'banco',
    'tienda',
  ];
  static const _kDemoGuideOrder = ['alcancia', 'banco'];
  bool _isDemoGuide = false;
  List<String> get _guideOrder =>
      _isDemoGuide ? _kDemoGuideOrder : _kFullGuideOrder;
  static const _guideMessages = {
    'alcancia': (
      'Mi Bolsa',
      '¡Explora Mi Bolsa! Aquí puedes repartir y mover todas tus monedas.',
    ),
    'trabajos': (
      'Trabajos',
      'Aquí ganas monedas ayudando a los personajes con pequeños trabajos.',
    ),
    'misiones': (
      'Misiones',
      'Aquí encuentras tu historia y retos para ganar recompensas.',
    ),
    'banco': (
      'Banco Estelar',
      'Aquí eliges una meta y ves crecer lo que ahorras e inviertes.',
    ),
    'tienda': (
      'Tienda',
      'Aquí gastas tus monedas en cosas divertidas para Blink.',
    ),
  };
  int? _guideStep;

  @override
  void initState() {
    super.initState();
    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentWorldProvider.notifier).state = 'space';
      AnalyticsService.instance.worldEntered('space');
      NotificationHelper.checkEngagement();
      BlinkAmbientHelper.maybeGreet(ref);
      _checkOnboarding();
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

      // Cuenta real sin vincular (account_type = 'limited'): aviso al entrar
      // y luego cada minuto para que pida a papá/mamá que lo vincule.
      // Ojo: no usar una bandera "ya evaluado" de una sola vez — el perfil
      // puede resolver null/"full" primero (mientras la sesión termina de
      // cargar) y luego llegar el valor real; hay que revisar CADA emisión.
      ref.listenManual<AsyncValue<Profile?>>(
        currentProfileProvider,
        (prev, next) {
          next.whenData((profile) {
            final shouldRemind = profile?.accountType == AccountType.limited;
            if (shouldRemind && _linkReminderTimer == null) {
              if (mounted) _showLinkParentReminder();
              _linkReminderTimer =
                  Timer.periodic(const Duration(minutes: 1), (_) {
                if (mounted) _showLinkParentReminder();
              });
            } else if (!shouldRemind) {
              _linkReminderTimer?.cancel();
              _linkReminderTimer = null;
            }
          });
        },
        fireImmediately: true,
      );
    });
  }

  @override
  void dispose() {
    _orbitCtrl.dispose();
    _linkReminderTimer?.cancel();
    super.dispose();
  }

  void _showLinkParentReminder() {
    // No mostrarlo encimado con el recorrido guiado — reintenta al minuto
    // siguiente (el Timer sigue corriendo, esta llamada solo se salta).
    if (_guideStep != null) return;
    final reaction = BlinkReactionController();
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        reaction.react(BlinkMood.sorprendido,
            hold: const Duration(minutes: 5));
        return Dialog(
          backgroundColor: const Color(0xFF0D1B3E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.amberAccent.withOpacity(0.55)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BlinkAvatar(size: 110, reaction: reaction),
                const SizedBox(height: 14),
                const Text(
                  '¡Todavía no estás vinculado! 👀',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    fontFamily: 'Nunito',
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Pídele a tu papá o mamá que te vinculen para guardar tu progreso y no perder nada.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: GameTokens.textSecondary,
                    fontSize: 14,
                    fontFamily: 'Nunito',
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      showDialog<void>(
                        context: context,
                        builder: (_) => const RedeemCodeDialog(),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          Color(0xFFFFB300),
                          Color(0xFFFF8C00),
                        ]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Vincular ahora',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Después',
                      style: TextStyle(
                          color: GameTokens.textSecondary,
                          fontFamily: 'Nunito')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Cuentas reales: la guía solo sale la primera vez (se recuerda en
  // profiles.tutorials_seen). Demo (sin sesión o anónima): no hay cuenta
  // real que recuerde nada, así que sale siempre que se abra el juego sin
  // haber iniciado sesión — se "reinicia" sola en cada apertura.
  Future<void> _checkOnboarding() async {
    final user = Supabase.instance.client.auth.currentUser;
    final isDemo = user == null || user.isAnonymous;
    if (isDemo) {
      if (mounted) setState(() {
        _isDemoGuide = true;
        _guideStep = 0;
      });
      return;
    }
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('tutorials_seen')
          .eq('id', user.id)
          .maybeSingle();
      final map = (data?['tutorials_seen'] as Map<String, dynamic>?) ?? {};
      final seen = map['map_guide'] == true;
      if (!seen && mounted) setState(() => _guideStep = 0);
    } catch (_) {}
  }

  void _advanceGuide() {
    if (_guideStep == null) return;
    final next = _guideStep! + 1;
    if (next >= _guideOrder.length) {
      _completeGuide();
    } else if (mounted) {
      setState(() => _guideStep = next);
    }
  }

  Future<void> _completeGuide() async {
    if (mounted) setState(() => _guideStep = null);
    final user = Supabase.instance.client.auth.currentUser;
    final isDemo = user == null || user.isAnonymous;

    // El día en que se termina el recorrido guiado no debe tener preguntas
    // diarias todavía — empiezan al día siguiente. Damos por "mostradas hoy"
    // las de todos los edificios ahora mismo.
    await BuildingQuestionRepository().markAllShownToday();

    if (isDemo) {
      // Demo: recompensa local nada más — cero conexión a Supabase.
      DemoStore.instance.introComplete = true;
      ref.read(demoProgressProvider).addCoins(200);
      return;
    }
    try {
      await Supabase.instance.client
          .rpc('mark_tutorial_seen', params: {'p_key': 'map_guide'});
    } catch (_) {}
    try {
      await WalletRepository().awardStarterCoins(user.id, 200);
      ref.invalidate(currentWalletProvider);
    } catch (_) {}
    final newBadges = await ref.read(badgeCheckerProvider.notifier).check();
    if (mounted) showBadgeUnlockCelebrations(context, ref, newBadges);
  }

  void _showWorldNameDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B3E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        // El juego corre en horizontal — cuando el teclado abre, queda muy
        // poco alto disponible y el diálogo se aprieta. Sin scroll, el
        // campo de texto (en medio del título y el botón) terminaba
        // recortado/invisible. SingleChildScrollView garantiza que siempre
        // se pueda llegar a él.
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🚀', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 6),
              const Text(
                '¡Ponle nombre a tu galaxia!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
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
            ],
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

          // ── Rect de estructuras.png en coordenadas de pantalla ────────────
          // TODO MOVER AQUÍ: structureOffsetX / structureOffsetY (arriba de
          // esta clase) mueven la estructura Y los edificios juntos, como
          // un solo bloque, porque ambos usan este mismo imgLeft/imgTop.
          const double natW = 3954, natH = 1767;
          final imgH = h * 0.90;
          final imgW = imgH * natW / natH;
          final imgLeft = (w - imgW) / 2 + structureOffsetX;
          final imgTop = (h - imgH) / 2 + structureOffsetY;

          final (buildingWidgets, guideRect) =
              _buildBuildings(imgLeft, imgTop, imgW, imgH, demoMode: isDemo);
          final guideActive = _guideStep != null;

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
              Positioned(
                left: imgLeft,
                top: imgTop,
                width: imgW,
                height: imgH,
                child: Image.asset(
                  'assets/worlds/space/estructuras.png',
                  width: imgW,
                  height: imgH,
                  fit: BoxFit.fill,
                ),
              ),

              // ── Edificios ─────────────────────────────────────────────────
              ...buildingWidgets,

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
                left: w * 0.5 - (h * 0.20) / 1.35,
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
                child: IgnorePointer(
                  ignoring: guideActive,
                  child: WorldLeftPanel(profile: profile),
                ),
              ),

              // ── Panel derecho ─────────────────────────────────────────────
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: panelW,
                child: IgnorePointer(
                  ignoring: guideActive,
                  child: WorldRightPanel(
                    fuel: fuelLevel,
                    hasSalary: hasSalary,
                    onSalaryClaim: hasSalary
                        ? () => handleSalaryClaim(context, ref)
                        : null,
                  ),
                ),
              ),

              // ── HUD central superior ──────────────────────────────────────
              // buildWorldCenterHud() ya devuelve un Positioned — debe ser
              // hijo DIRECTO del Stack (envolverlo en IgnorePointer rompía
              // el layout: "Positioned must be direct child of Stack",
              // causaba pantalla en blanco al abrir el juego).
              buildWorldCenterHud(context, ref, coins, panelW),

              // ── Guía interactiva de bienvenida ─────────────────────────────
              if (guideActive && guideRect != null) ...[
                _MapGuideOverlay(
                  targetRect: guideRect,
                  screenSize: Size(w, h),
                  title: _guideMessages[_guideOrder[_guideStep!]]!.$1,
                  body: _guideMessages[_guideOrder[_guideStep!]]!.$2,
                  stepIndex: _guideStep!,
                  totalSteps: _guideOrder.length,
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: SafeArea(
                    child: GestureDetector(
                      onTap: _completeGuide,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.35)),
                        ),
                        child: const Text(
                          'Saltar intro ✕',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            fontFamily: 'Nunito',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
  // Para mover TODO el bloque (imagen + edificios) junto: usa
  // structureOffsetX / structureOffsetY arriba de esta clase.
  (List<Widget>, Rect?) _buildBuildings(
      double imgLeft, double imgTop, double imgW, double imgH,
      {bool demoMode = false}) {
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

    // La guía interactiva (map_guide) ya obliga a entrar a cada edificio en
    // orden — el candado/desbloqueo progresivo del demo quedaría redundante
    // (y podía desincronizarse con el orden de la guía), así que todos los
    // edificios están disponibles desde el inicio.

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
        size: imgW * 0.20,
        locked: false,
        islandFx: 0.36,
        islandFy: 1.04,
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
        size: imgW * 0.22,
        locked: false,
        islandFx: 0.80,
        islandFy: 0.70,
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
        size: imgW * 0.22,
        locked: false,
        islandFx: 0.67,
        islandFy: 1.02,
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
        size: imgW * 0.22,
        locked: false,
        islandFx: 0.67,
        islandFy: 0.54,
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
        size: imgW * 0.20,
        locked: false,
        islandFx: 0.31,
        islandFy: 0.52,
        topPad: 0.065,
        rightPad: 0.266,
        bottomPad: 0.378,
      ),
      // _BuildingData(id: 'mercado', ..., islandFx: 0.72, islandFy: 0.48),
    ];

    Rect? guideRect;
    final widgets = buildings.map((b) {
      // Centro de la isla en coordenadas de pantalla
      final cx = imgLeft + b.islandFx! * imgW;
      final cy = imgTop + b.islandFy! * imgH;
      // Edificio centrado horizontalmente; base del edificio en el centro de la isla
      final bx = cx - b.size / 2;
      final by = cy - b.size;
      final isGuideTarget =
          _guideStep != null && _guideOrder[_guideStep!] == b.id;
      if (isGuideTarget) {
        // Mismo recorte que el hit-box real del edificio (ver
        // _BuildingButton más abajo): el 50% central del lienzo, centrado
        // verticalmente sobre el dibujo real vía topPad/bottomPad — así el
        // resaltado calza con el edificio/botón, no con todo el lienzo
        // transparente que lo rodea.
        final hitSize = b.size * 0.5;
        final hitTop =
            b.size * ((b.topPad + 1 - b.bottomPad) / 2) - hitSize / 2;
        final hitLeft = (b.size - hitSize) / 2;
        guideRect =
            Rect.fromLTWH(bx + hitLeft, by + hitTop, hitSize, hitSize);
      }
      final guideDim = _guideStep != null && !isGuideTarget;
      return Positioned(
        left: bx,
        top: by,
        child: _BuildingButton(
          data: b,
          demoMode: demoMode,
          guideDim: guideDim,
          guideTarget: isGuideTarget,
          onGuideAdvance: isGuideTarget ? _advanceGuide : null,
        ),
      );
    }).toList();
    return (widgets, guideRect);
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
Future<void> _showDemoDialog(
    BuildContext context, WidgetRef ref, String demoRoute) {
  // Mapeo demoRoute → widget. El mensaje/etapa de "desbloqueo" que había
  // aquí antes ya no aplica: map_guide es quien ahora explica cada edificio.
  final configs = <String, (Widget, String)>{
    '/demo/bolsa': (const WalletScreen(), 'Mi Bolsa'),
    '/demo/banco': (const BancoEstelarScreen(), 'Banco Estelar'),
    '/demo/misiones': (const MisionesScreen(), 'Misiones'),
    '/demo/trabajos': (const TrabajosScreen(), 'Trabajos'),
    '/demo/tienda': (const TiendaScreen(), 'Tienda'),
  };
  // Mismas medidas exactas que cada showXDialog() de la sesión real —
  // así el modal se ve idéntico en demo (radio, ancho, alto, margen).
  final geoms = <String, (double radius, double w, double h, double insetH)>{
    '/demo/bolsa': (24, 0.92, 0.84, 12),
    '/demo/misiones': (20, 0.94, 0.85, 12),
    '/demo/trabajos': (20, 0.94, 0.85, 12),
    '/demo/tienda': (20, 0.94, 0.85, 10),
  };
  final cfg = configs[demoRoute] ?? configs['/demo/bolsa']!;
  final screen = cfg.$1;
  final title = cfg.$2;
  final geom = geoms[demoRoute] ?? geoms['/demo/bolsa']!;

  final size = MediaQuery.of(context).size;
  return showGeneralDialog(
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
      // Banco Estelar ya trae su propio marco completo incrustado
      // (BancoEstelarDialogShell → _BEFrame, con sus esquinas, tiras,
      // placa de título y botón de cerrar) y se muestra exactamente
      // igual que en la sesión real: SIN Dialog/ClipRRect/SizedBox
      // extra por fuera, porque esos recortan la placa/botón que
      // sobresalen del marco y dejan ver un fondo sólido alrededor.
      if (demoRoute == '/demo/banco') {
        return const BancoEstelarDialogShell(isFullScreen: false);
      }

      final content = ClipRRect(
        borderRadius: BorderRadius.circular(geom.$1),
        child: SizedBox(
          width: size.width * geom.$2,
          height: size.height * geom.$3,
          child: screen,
        ),
      );
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.fromLTRB(geom.$4, 60, geom.$4, geom.$4),
        child: ModalCorners(
          onClose: () => Navigator.of(ctx).pop(),
          title: title,
          child: content,
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Botón de edificio — con glow base, animación flotante, label, badge, candado
// ─────────────────────────────────────────────────────────────────────────────
class _BuildingButton extends ConsumerWidget {
  const _BuildingButton({
    required this.data,
    this.demoMode = false,
    this.guideDim = false,
    this.guideTarget = false,
    this.onGuideAdvance,
  });
  final _BuildingData data;
  final bool demoMode;
  final bool guideDim;
  final bool guideTarget;
  final VoidCallback? onGuideAdvance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Trabajos y Misiones muestran cuántos trabajos/misiones se pueden
    // completar AHORA MISMO (desbloqueados + con todo lo necesario), en vez
    // de un número fijo — se recalcula cada vez que se cierra un edificio.
    final badgeCount = switch (data.id) {
      'trabajos' => ref.watch(trabajosPendingCountProvider).valueOrNull ?? 0,
      'misiones' => ref.watch(misionesPendingCountProvider).valueOrNull ?? 0,
      _ => data.badgeCount,
    };

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
    if (badgeCount > 0) {
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
                badgeCount > 9 ? '9+' : '$badgeCount',
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

    if (guideTarget) {
      building = building
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(
              begin: 1.0, end: 1.08, duration: 650.ms, curve: Curves.easeInOut);
    }

    Future<void> handleTap() async {
      if (demoMode && data.demoRoute.isNotEmpty) {
        // Demo: abrir como diálogo con DemoStageGate envolviendo la pantalla
        await _showDemoDialog(context, ref, data.demoRoute);
        if (guideTarget) onGuideAdvance?.call();
        ref.invalidate(trabajosPendingCountProvider);
        ref.invalidate(misionesPendingCountProvider);
        return;
      }
      await data.dialogBuilder?.call(context);
      if (guideTarget) onGuideAdvance?.call();
      // Cualquier edificio puede cambiar si un trabajo o misión ya se puede
      // completar (comprar materiales en Tienda, mover monedas en Mi
      // Bolsa...), así que se refresca siempre, no solo al salir de esos dos.
      ref.invalidate(trabajosPendingCountProvider);
      ref.invalidate(misionesPendingCountProvider);
    }

    final tapEnabled = !(data.locked || guideDim);

    // Zona de toque centrada y más chica que el lienzo completo del PNG
    // (que tiene bastante margen transparente alrededor del dibujo real).
    // Bug reportado: tocar la esquina de Trabajos abría Tienda, porque sus
    // lienzos de 3000×3000 se superponen ahí — al usar solo el 50% central
    // (centrado verticalmente sobre el dibujo real vía topPad/bottomPad) los
    // edificios vecinos dejan de "robarse" el tap en esa esquina.
    final hitSize = data.size * 0.5;
    final hitTop =
        data.size * ((data.topPad + 1 - data.bottomPad) / 2) - hitSize / 2;
    final hitLeft = (data.size - hitSize) / 2;

    Widget result = Stack(
      clipBehavior: Clip.none,
      children: [
        IgnorePointer(
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
        ),
        Positioned(
          left: hitLeft,
          top: hitTop,
          width: hitSize,
          height: hitSize,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: tapEnabled ? handleTap : null,
          ),
        ),
      ],
    );

    if (guideDim) {
      result = IgnorePointer(child: Opacity(opacity: 0.30, child: result));
    }

    return result;
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
  final Future<void> Function(BuildContext)? dialogBuilder;
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

// ─────────────────────────────────────────────────────────────────────────────
// Guía interactiva de bienvenida — resalta el edificio objetivo con un
// "spotlight" y bloquea todo lo demás. Es puramente visual (IgnorePointer):
// el edificio real de abajo sigue recibiendo el tap normalmente; los demás
// quedan deshabilitados por su propio `guideDim` en _BuildingButton.
// ─────────────────────────────────────────────────────────────────────────────
class _MapGuideOverlay extends StatelessWidget {
  const _MapGuideOverlay({
    required this.targetRect,
    required this.screenSize,
    required this.title,
    required this.body,
    required this.stepIndex,
    required this.totalSteps,
  });

  final Rect targetRect;
  final Size screenSize;
  final String title;
  final String body;
  final int stepIndex;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    // Un poco de aire alrededor del edificio/botón real para que el
    // resaltado no quede pegado al dibujo.
    final holeRect = targetRect.inflate(targetRect.shortestSide * 0.16);
    const bubbleW = 280.0;
    const estBubbleH = 175.0;
    final anchor = targetRect.center;

    double top;
    if (anchor.dy < screenSize.height * 0.55) {
      top = holeRect.bottom + 16;
    } else {
      top = holeRect.top - 16 - estBubbleH;
    }
    top = top.clamp(8.0, screenSize.height - estBubbleH - 8);
    final left =
        (anchor.dx - bubbleW / 2).clamp(12.0, screenSize.width - bubbleW - 12);

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SpotlightPainter(rect: holeRect),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: bubbleW,
            child: _GuideBubble(
              title: title,
              body: body,
              stepIndex: stepIndex,
              totalSteps: totalSteps,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({required this.rect});
  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(rect.shortestSide * 0.22);
    final full = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final hole = Path()..addRRect(RRect.fromRectAndRadius(rect, radius));
    final scrim = Path.combine(PathOperation.difference, full, hole);
    canvas.drawPath(scrim, Paint()..color = Colors.black.withOpacity(0.68));
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.rect != rect;
}

class _GuideBubble extends StatelessWidget {
  const _GuideBubble({
    required this.title,
    required this.body,
    required this.stepIndex,
    required this.totalSteps,
  });
  final String title;
  final String body;
  final int stepIndex;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Colors.black45, blurRadius: 20, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (totalSteps > 1)
            Row(
              children: List.generate(totalSteps, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(right: 5),
                  width: i == stepIndex ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == stepIndex
                        ? const Color(0xFF2563EB)
                        : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          if (totalSteps > 1) const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: Color(0xFF334155),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '👆 Tócalo para continuar',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: Color(0xFF2563EB),
            ),
          ),
        ],
      ),
    )
        .animate(key: ValueKey(stepIndex))
        .fadeIn(duration: 250.ms)
        .slideY(begin: 0.08, end: 0, duration: 250.ms, curve: Curves.easeOut);
  }
}
