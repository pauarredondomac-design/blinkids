import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  static const _navDelay = Duration(milliseconds: 5500);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheWorldAssets();
      Future.delayed(_navDelay, _navigate);
    });
  }

  // Precachea los assets del mapa durante el splash para evitar parpadeo al cargar
  void _precacheWorldAssets() {
    const worldAssets = [
      'assets/worlds/space/space_background.png',
      'assets/worlds/space/estructuras.png',
      'assets/worlds/space/building_bolsa.png',
      'assets/worlds/space/building_trabajos.png',
      'assets/worlds/space/building_misiones.png',
      'assets/worlds/space/building_tienda.png',
      'assets/worlds/space/alcancia.png',
      'assets/blink/blink_dressed.png',
      'assets/blink/blink_base.png',
    ];
    for (final a in worldAssets) {
      precacheImage(AssetImage(a), context);
    }
  }

  Future<void> _navigate() async {
    if (!mounted) return;

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    // Sin sesión → modo demo
    if (user == null) {
      if (mounted) context.go('/world');
      return;
    }

    try {
      final profileData = await client
          .from('profiles')
          .select('role, account_type')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (profileData == null) {
        // Perfil no encontrado — puede ser padre recién registrado sin perfil
        // o RLS bloqueando la lectura. Ir al mundo en demo.
        if (mounted) context.go('/world');
        return;
      }

      final role = profileData['role'] as String? ?? 'child';

      if (role == 'parent') {
        context.go('/parent');
        return;
      }

      context.go('/world');
    } catch (_) {
      if (mounted) context.go('/world');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fondo degradado espacial
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF060618),
                  Color(0xFF0D0D2B),
                  Color(0xFF12124A),
                  Color(0xFF0D0D2B),
                ],
                stops: [0.0, 0.35, 0.65, 1.0],
              ),
            ),
          ),

          // Estrellas de fondo
          IgnorePointer(child: _StarField()),

          // Contenido centrado
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Blink cae desde arriba con rebote — el PNG trae bastante
                // margen transparente propio debajo de los pies, así que se
                // reserva menos alto del que ocupa la imagen (OverflowBox
                // deja que Blink se siga viendo completo, pero el logo de
                // abajo se acerca porque el layout solo cuenta el alto
                // reducido).
                SizedBox(
                  height: 250,
                  child: OverflowBox(
                    maxHeight: 300,
                    alignment: Alignment.topCenter,
                    child: _BlinkHero(),
                  ),
                ),

                // Logo "Blinkids"
                SizedBox(
                  width: 260,
                  child: Image.asset(
                    'assets/ui/blinkids_logo.png',
                    fit: BoxFit.contain,
                  ),
                )
                    .animate()
                    .fadeIn(
                      delay: const Duration(milliseconds: 1000),
                      duration: const Duration(milliseconds: 500),
                    )
                    .slideY(
                      begin: 0.4,
                      end: 0,
                      delay: const Duration(milliseconds: 1000),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutBack,
                    ),

                const SizedBox(height: 14),

                // Tagline
                const Text(
                  '¡Tu aventura financiera comienza aquí!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.white60,
                    letterSpacing: 0.4,
                  ),
                )
                    .animate()
                    .fadeIn(
                      delay: const Duration(milliseconds: 2200),
                      duration: const Duration(milliseconds: 700),
                    )
                    .slideY(
                      begin: 0.4,
                      end: 0,
                      delay: const Duration(milliseconds: 2200),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOut,
                    ),

                const SizedBox(height: 48),

                // Barra de progreso sutil
                SizedBox(
                  width: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      backgroundColor: Colors.white12,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                      minHeight: 3,
                    ),
                  ),
                ).animate().fadeIn(
                      delay: const Duration(milliseconds: 2800),
                      duration: const Duration(milliseconds: 500),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Blink con animación de caída con rebote ──────────────────────────────────
class _BlinkHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 300,
      child: Image.asset(
        'assets/blink/blink_base.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Color(0xFF3D5AFE), Color(0xFF1A237E)],
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x883D5AFE),
                blurRadius: 30,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(Icons.pets_rounded, size: 80, color: Colors.white),
        ),
      ),
    )
        .animate()
        .fadeIn(
          delay: const Duration(milliseconds: 150),
          duration: const Duration(milliseconds: 300),
        )
        .slideY(
          begin: -1.8,
          end: 0,
          delay: const Duration(milliseconds: 150),
          duration: const Duration(milliseconds: 900),
          curve: Curves.elasticOut,
        );
  }
}

// ─── Campo de estrellas ───────────────────────────────────────────────────────
class _StarField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          children: List.generate(45, (i) {
            final rng = i * 2971 + 53;
            final left = (rng % 1000) / 1000 * w;
            final top = ((rng * 137) % 1000) / 1000 * h;
            final radius = 0.7 + (rng % 4) * 0.6;
            final opacity = 0.1 + (rng % 6) / 15.0;
            final delay = Duration(milliseconds: (i * 60) % 1000);

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
                )
                    .animate(
                      onPlay: (c) => c.repeat(reverse: true),
                      delay: delay,
                    )
                    .fadeIn(
                      duration: Duration(milliseconds: 400 + (i * 50) % 600),
                    ),
              ),
            );
          }),
        );
      },
    );
  }
}
