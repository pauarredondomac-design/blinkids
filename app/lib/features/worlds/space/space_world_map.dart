import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/providers/profile_provider.dart';
import '../../../data/models/profile.dart';
import '../../../shared/providers/wallet_provider.dart';
import '../../../shared/providers/fuel_provider.dart';
import '../../../shared/widgets/profile_bottom_sheet.dart';
import '../../../shared/widgets/blink_character.dart';
import '../../../shared/widgets/child_notification_bell.dart';
import '../../../shared/helpers/notification_helper.dart';
import 'banco_estelar_screen.dart';

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
      NotificationHelper.checkEngagement();
      ref.listenManual<AsyncValue<Profile?>>(
        currentProfileProvider,
        (prev, next) {
          next.whenData((profile) {
            if (_worldNameChecked) return;
            _worldNameChecked = true;
            // No pedir nombre de galaxia a usuarios demo
            if (profile?.isDemo == true) return;
            final name = profile?.worldName ?? '';
            if (name.isEmpty && mounted) {
              _showWorldNameDialog();
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
    final profile   = ref.watch(currentProfileProvider).value;
    final wallet    = ref.watch(currentWalletProvider).value;
    final fuelAsync = ref.watch(fuelNotifierProvider);
    final fuelLevel = (fuelAsync is AsyncData<int> ? fuelAsync.value : null) ?? 0;
    final coins     = wallet?.totalCoins ?? 0;
    final worldName = _localWorldName ?? profile?.worldName ?? 'Mi Galaxia';
    final isDemo    = profile?.isDemo ?? false;

    return Scaffold(
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          final w      = constraints.maxWidth;
          final h      = constraints.maxHeight;
          final panelW = w * 0.16;

          return Stack(
            children: [
              // ── Fondo espacial ────────────────────────────────────────────
              Positioned.fill(
                child: Image.asset(
                  'assets/images/worlds/space/space_background.png',
                  fit: BoxFit.cover,
                ),
              ),

              // ── Overlay oscuro sutil ──────────────────────────────────────
              Positioned.fill(
                child: Container(color: Colors.black.withOpacity(0.15)),
              ),

              // ── Partículas ambientales flotantes ──────────────────────────
              const Positioned.fill(child: _SpaceParticles()),

              // ── Órbita elíptica (con glow) ────────────────────────────────
              Positioned.fill(
                child: CustomPaint(painter: _OrbitPainter(w: w, h: h)),
              ),

              // ── Estrellas fugaces ─────────────────────────────────────────
              const Positioned.fill(child: _ShootingStars()),

              // ── Planeta Marte ─────────────────────────────────────────────
              Positioned(
                right: w * -0.15,
                top: h * 0.06,
                child: Image.asset(
                  'assets/images/worlds/space/planet_mars.png',
                  width: w * 0.65,
                ).animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(begin: 0, end: -10, duration: 3.seconds,
                         curve: Curves.easeInOut),
              ),

              // ── Edificios ─────────────────────────────────────────────────
              ..._buildBuildings(w, h, demoMode: isDemo),

              // ── Sombra/glow bajo Blink ────────────────────────────────────
              Positioned(
                left: w * 0.5 - h * 0.095,
                top:  h * 0.25 + h * 0.38,
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
                left: w * 0.5 - (h * 0.42) / 2,
                top:  h * 0.25,
                child: BlinkCharacterWidget(
                  width: h * 0.35,
                  enableBounce: false,
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
                left: 0, top: 0, bottom: 0,
                width: panelW,
                child: _LeftPanel(profile: profile),
              ),

              // ── Panel derecho ─────────────────────────────────────────────
              Positioned(
                right: 0, top: 0, bottom: 0,
                width: panelW,
                child: _RightPanel(fuel: fuelLevel),
              ),

              // ── HUD central superior ──────────────────────────────────────
              _buildCenterHud(context, ref, coins, panelW),

              // ── Badge demo (esquina inferior izquierda, compacto) ─────────
              if (isDemo)
                Positioned(
                  bottom: 14,
                  left: panelW + 10,
                  child: GestureDetector(
                    onTap: () => context.push('/demo-end'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(color: Color(0x55FFD700), blurRadius: 10, offset: Offset(0, 3)),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded, color: Colors.white, size: 13),
                          SizedBox(width: 5),
                          Text(
                            'Demo',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(begin: 1.0, end: 1.04, duration: 1400.ms, curve: Curves.easeInOut),
                ),
            ],
          );
        },
      ),
    );
  }

  // ── Edificios posicionados en la órbita ────────────────────────────────────
  List<Widget> _buildBuildings(double w, double h, {bool demoMode = false}) {
    final cx    = w * 0.5;
    final cy    = h * 0.54;   // bajado para dar aire arriba (HUD)
    final rx    = w * 0.34;   // órbita más ajustada
    final ry    = h * 0.27;   // órbita más ajustada
    final bSize = h * 0.22;   // edificios ligeramente más pequeños

    final buildings = [
      _BuildingData(
        angle: 120,
        asset: 'assets/images/worlds/space/building_misiones.png',
        label: 'Misiones',
        route: '/space/misiones',
        size: bSize,
        badgeCount: 3,
      ),
      _BuildingData(
        angle: 245,
        asset: 'assets/images/worlds/space/building_bolsa.png',
        label: 'Banco Estelar',
        openAsDialog: true,
        size: bSize,
      ),
      _BuildingData(
        angle: 200,          // ignorado — posición libre activa
        asset: 'assets/images/worlds/space/building_trabajos.png',
        label: 'Trabajos',
        route: '/space/trabajos',
        size: bSize,
        badgeCount: 1,
        //freeLeft: 0.165,   // justo fuera del panel izquierdo
        //freeTop:  0.410,   // debajo de Banco Estelar, a la altura de Marte
      ),
      _BuildingData(
        angle: 295,
        asset: 'assets/images/worlds/space/building_mercado.png',
        label: 'Mercado',
        route: '/space/mercado',
        size: bSize,
      ),
      _BuildingData(
        angle: 60,
        asset: 'assets/images/worlds/space/building_tienda.png',
        label: 'Tienda',
        route: '/space/tienda',
        size: bSize,
        locked: false,
      ),
    ];

    return buildings.map((b) {
      final double bx;
      final double by;
      if (b.freeLeft != null && b.freeTop != null) {
        // Posición libre — no usa la órbita
        bx = b.freeLeft! * w;
        by = b.freeTop!  * h;
      } else {
        final rad = b.angle * pi / 180;
        bx = cx + rx * cos(rad) - b.size / 2;
        by = cy + ry * sin(rad) - b.size / 2;
      }
      return Positioned(
        left: bx,
        top:  by,
        child: _BuildingButton(data: b, demoMode: demoMode),
      );
    }).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HUD central superior — monedas + botón créditos + campana
// ─────────────────────────────────────────────────────────────────────────────
Widget _buildCenterHud(
  BuildContext context,
  WidgetRef ref,
  int coins,
  double panelW,
) {
  return Positioned(
    top: 0,
    left: panelW,
    right: panelW,
    child: Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.65),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // ── Monedas ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.amber.withOpacity(0.80), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.25),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🪙', style: TextStyle(fontSize: 20))
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15),
                           duration: 1800.ms, curve: Curves.easeInOut),
                const SizedBox(width: 6),
                Text(
                  '$coins',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    shadows: [
                      Shadow(color: Colors.amber, blurRadius: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // ── Botón "Mis Créditos" ──────────────────────────────────────────
          GestureDetector(
            onTap: () => context.push('/space/bolsa'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B00), Color(0xFFFFB300)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF8C00).withOpacity(0.55),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.25),
                  width: 1,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('💰', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 7),
                  Text(
                    'Mis Créditos',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 0.5,
                      shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
                    ),
                  ),
                ],
              ),
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              begin: const Offset(1.00, 1.00),
              end:   const Offset(1.03, 1.03),
              duration: 2200.ms,
              curve: Curves.easeInOut,
            ),
          ),

          const Spacer(),

          // ── Campana ───────────────────────────────────────────────────────
          ChildNotificationBell(),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel izquierdo — Perfil de Blink + botón Papá Comandante
// ─────────────────────────────────────────────────────────────────────────────
class _LeftPanel extends StatelessWidget {
  const _LeftPanel({required this.profile});
  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF020D1F).withOpacity(0.92),
            const Color(0xFF020D1F).withOpacity(0.78),
            Colors.transparent,
          ],
          stops: const [0.0, 0.65, 1.0],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Card de perfil ─────────────────────────────────────────────
          _PanelCard(
            borderColor: const Color(0xFF4FC3F7).withOpacity(0.55),
            glowColor: const Color(0xFF4FC3F7).withOpacity(0.12),
            child: Column(
              children: [
                // Avatar con glow — círculo más grande, Blink completo
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF4FC3F7).withOpacity(0.70),
                      width: 2,
                    ),
                    color: const Color(0xFF0D1B3E),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4FC3F7).withOpacity(0.30),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Image.asset(
                      'assets/characters/blink/blink_dressed.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Nombre — hasta 2 líneas para nombres largos
                Text(
                  profile?.displayName ?? 'Blink',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 1),

                // Nivel con badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0277BD), Color(0xFF01579B)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Nivel 1',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 7),

                // Estrellas XP
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Icon(
                      i < 2
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: i < 2 ? Colors.amber : Colors.white24,
                      size: 13,
                    ),
                  )),
                ),
                const SizedBox(height: 5),

                // Barra de progreso XP
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 0.40,  // 200/500 XP (mockup)
                    backgroundColor: Colors.white.withOpacity(0.10),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF4FC3F7)),
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '200 / 500 XP',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.40),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // ── Botón Papá Comandante ──────────────────────────────────────
          GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const ProfileBottomSheet(
                accentColor: Color(0xFF00BCD4),
              ),
            ),
            child: _PanelCard(
              borderColor: const Color(0xFF4FC3F7).withOpacity(0.30),
              glowColor: Colors.transparent,
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF4FC3F7).withOpacity(0.25),
                          const Color(0xFF4FC3F7).withOpacity(0.10),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF4FC3F7).withOpacity(0.40),
                        width: 1,
                      ),
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: Color(0xFF4FC3F7), size: 17),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Papá Comandante',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Ver progreso',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.45),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: const Color(0xFF4FC3F7).withOpacity(0.60), size: 15),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel derecho — Destino Marte + combustible + Hangar de Despegue
// ─────────────────────────────────────────────────────────────────────────────
class _RightPanel extends StatelessWidget {
  const _RightPanel({required this.fuel});
  final int fuel;

  @override
  Widget build(BuildContext context) {
    final weeksLeft     = ((100 - fuel) / 7.0).ceil().clamp(1, 20);
    const totalSegments = 5;
    final filledSegs    = (fuel / 100 * totalSegments).round();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [
            const Color(0xFF0A051A).withOpacity(0.92),
            const Color(0xFF0A051A).withOpacity(0.78),
            Colors.transparent,
          ],
          stops: const [0.0, 0.65, 1.0],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Destino Marte ──────────────────────────────────────────────
          _PanelCard(
            borderColor: Colors.deepOrange.withOpacity(0.60),
            glowColor: Colors.deepOrange.withOpacity(0.10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado con ícono de cohete
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withOpacity(0.20),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.flag_rounded,
                          color: Colors.deepOrange.shade300, size: 12),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Marte',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        shadows: [Shadow(color: Colors.deepOrange, blurRadius: 6)],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  'Nuestro destino final',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 10),

                // Porcentaje combustible
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$fuel',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        shadows: [
                          Shadow(color: Colors.deepOrange, blurRadius: 8),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        '%',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.70),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'combustible cargado',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.50),
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 8),

                // Barra segmentada con glow
                Row(
                  children: List.generate(totalSegments, (i) {
                    final filled = i < filledSegs;
                    return Expanded(
                      child: Container(
                        height: 10,
                        margin: EdgeInsets.only(
                            right: i < totalSegments - 1 ? 3 : 0),
                        decoration: BoxDecoration(
                          color: filled
                              ? const Color(0xFF4FC3F7)
                              : Colors.white.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: filled
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF4FC3F7).withOpacity(0.55),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  )
                                ]
                              : null,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 6),
                Text(
                  '$weeksLeft semanas para despegar',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Hangar de Despegue ─────────────────────────────────────────
          _PanelCard(
            borderColor: Colors.deepOrange.withOpacity(0.25),
            glowColor: Colors.transparent,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.deepOrange.withOpacity(0.25),
                        Colors.deepOrange.withOpacity(0.10),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.deepOrange.withOpacity(0.40),
                      width: 1,
                    ),
                  ),
                  child: Icon(Icons.rocket_launch_rounded,
                      color: Colors.deepOrange.shade300, size: 16),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Hangar de Despegue',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Prepárate para Marte',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card reutilizable para los paneles laterales — con glow opcional
// ─────────────────────────────────────────────────────────────────────────────
class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.child,
    required this.borderColor,
    this.glowColor = Colors.transparent,
  });
  final Widget child;
  final Color  borderColor;
  final Color  glowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628).withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          if (glowColor != Colors.transparent)
            BoxShadow(
              color: glowColor,
              blurRadius: 14,
              spreadRadius: 2,
            ),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Botón de edificio — con glow base, animación flotante, label, badge, candado
// ─────────────────────────────────────────────────────────────────────────────
class _BuildingButton extends StatelessWidget {
  const _BuildingButton({required this.data, this.demoMode = false});
  final _BuildingData data;
  final bool          demoMode;

  @override
  Widget build(BuildContext context) {
    // ── Imagen base (grises si bloqueado) ──────────────────────────────────
    Widget image = Image.asset(data.asset, width: data.size);
    if (data.locked) {
      image = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      0.6, 0,
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
                  const Color(0xFF4FC3F7).withOpacity(data.locked ? 0.12 : 0.42),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        image,
      ],
    );

    // ── Animación de flotación ─────────────────────────────────────────────
    Widget building = imageWithShadow
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(begin: 0, end: -6, duration: 2500.ms, curve: Curves.easeInOut);

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
            child: const Icon(Icons.lock_rounded, color: Colors.white70, size: 18),
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
            top: 2,
            right: 2,
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
          color: data.locked
              ? Colors.white.withOpacity(0.40)
              : Colors.white,
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
              if (demoMode) {
                context.push('/demo-end');
                return;
              }
              if (data.openAsDialog) {
                showBancoEstelarDialog(context);
              } else if (data.route.isNotEmpty) {
                context.push(data.route);
              }
            },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          building,
          const SizedBox(height: 3),
          label,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data de cada edificio
// ─────────────────────────────────────────────────────────────────────────────
class _BuildingData {
  final double angle;
  final String asset;
  final String label;
  final String route;
  final bool   openAsDialog;
  final double size;
  final int    badgeCount;
  final bool   locked;
  /// Posición libre (fracción de w/h). Cuando se define, ignora el ángulo
  /// orbital y posiciona el edificio directamente en estas coordenadas.
  final double? freeLeft;
  final double? freeTop;

  const _BuildingData({
    required this.angle,
    required this.asset,
    required this.label,
    this.route = '',
    this.openAsDialog = false,
    required this.size,
    this.badgeCount = 0,
    this.locked = false,
    this.freeLeft,
    this.freeTop,
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
    final cx   = w * 0.5;
    final cy   = h * 0.54;
    final rx   = w * 0.34;
    final ry   = h * 0.27;
    final rect = Rect.fromCenter(
        center: Offset(cx, cy), width: rx * 2, height: ry * 2);

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
    _particles = List.generate(22, (i) => _ParticleData(
      x:       rng.nextDouble(),
      y:       rng.nextDouble(),
      size:    1.2 + rng.nextDouble() * 2.4,
      opacity: 0.20 + rng.nextDouble() * 0.55,
      durationMs: 2400 + (rng.nextDouble() * 3800).toInt(),
      delayMs:    (rng.nextDouble() * 3200).toInt(),
      moveY:   4.0 + rng.nextDouble() * 10.0,
      isCyan:  rng.nextBool(),
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
              final color = p.isCyan
                  ? const Color(0xFF4FC3F7)
                  : Colors.white;
              return Positioned(
                left: p.x * w,
                top:  p.y * h,
                child: Container(
                  width:  p.size,
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
  final int    durationMs, delayMs;
  final bool   isCyan;

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
  late final List<_StarData>           _data;
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
        startX:   0.08 + _rng.nextDouble() * 0.65,
        startY:   0.01 + _rng.nextDouble() * 0.30,
        angleDeg: 18.0 + _rng.nextDouble() * 28.0,
        length:   0.12 + _rng.nextDouble() * 0.14,
        width:    1.2  + _rng.nextDouble() * 1.2,
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
    for (final c in _ctrls) { c.dispose(); }
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
  final List<_StarData>           data;
  const _ShootingStarPainter({required this.ctrls, required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < ctrls.length; i++) {
      final t = ctrls[i].value;
      if (t <= 0) continue;

      final d        = data[i];
      final rad      = d.angleDeg * pi / 180;
      final dx       = cos(rad);
      final dy       = sin(rad);
      final travel   = d.length * size.width;
      final trailLen = travel * 0.40;

      // Cabeza: avanza a lo largo de la dirección
      final hx = d.startX * size.width  + dx * travel * t;
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
          ..style       = PaintingStyle.stroke
          ..strokeCap   = StrokeCap.round,
      );

      // ── Punto brillante en la cabeza ───────────────────────────────────
      canvas.drawCircle(
        Offset(hx, hy),
        d.width * 1.5 * alpha,
        Paint()
          ..color      = Colors.white.withOpacity(0.95 * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  @override
  bool shouldRepaint(_ShootingStarPainter old) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Nave de Blink — cohete pintado con Canvas (reservado para uso futuro)
// ─────────────────────────────────────────────────────────────────────────────
class _BlinkShipPainter extends CustomPainter {
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
  bool   _saving = false;
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
                      _error  = null;
                    });
                    try {
                      await Supabase.instance.client
                          .rpc('set_world_name', params: {'p_name': name});
                      widget.onSaved(name);
                    } catch (e) {
                      if (mounted) {
                        setState(() {
                          _saving = false;
                          _error  = 'Error al guardar. Inténtalo de nuevo.';
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
