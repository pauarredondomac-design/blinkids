import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      Future.delayed(_navDelay, _navigate);
    });
  }

  Future<void> _navigate() async {
    if (!mounted) return;

    final client = Supabase.instance.client;
    final user   = client.auth.currentUser;

    if (user == null) {
      context.go('/adventurer-name');
      return;
    }

    try {
      final profileData = await client
          .from('profiles')
          .select('account_type, pin_hash')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (profileData == null) {
        await client.auth.signOut();
        if (mounted) context.go('/adventurer-name');
        return;
      }

      final accountType = profileData['account_type'] as String? ?? 'demo';
      final pinHash     = profileData['pin_hash']     as String?;

      if (accountType == 'demo') {
        final tutorialRecord = await client
            .from('tutorial_progress')
            .select('is_completed')
            .eq('user_id', user.id)
            .maybeSingle();
        if (!mounted) return;
        final tutorialDone = tutorialRecord?['is_completed'] == true;
        context.go(tutorialDone ? '/world' : '/tutorial');
      } else {
        final hasPinLocal = await _hasPinLocal();
        if (!mounted) return;
        final hasPin = hasPinLocal || (pinHash != null && pinHash.isNotEmpty);
        context.go(!hasPin ? '/setup-pin' : '/enter-pin');
      }
    } catch (_) {
      if (mounted) context.go('/adventurer-name');
    }
  }

  Future<bool> _hasPinLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pin   = prefs.getString('child_pin');
      return pin != null && pin.isNotEmpty;
    } catch (_) {
      return false;
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
                end:   Alignment.bottomRight,
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
              children: [

                // Blink cae desde arriba con rebote
                _BlinkHero(),

                const SizedBox(height: 28),

                // "Blinkids" letra por letra
                _LetterByLetter(text: 'Blinkids'),

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
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
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
      width: 220,
      height: 220,
      child: Image.asset(
        'assets/characters/blink/blink_base.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFF3D5AFE), Color(0xFF1A237E)],
              ),
              boxShadow: const [
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

// ─── Título letra por letra ───────────────────────────────────────────────────
class _LetterByLetter extends StatelessWidget {
  const _LetterByLetter({required this.text});
  final String text;

  static const _startDelay  = 1000; // ms cuando empieza la primera letra
  static const _letterGap   = 90;   // ms entre letras
  static const _letterDur   = 380;  // duración de cada letra

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: List.generate(text.length, (i) {
        final delay   = Duration(milliseconds: _startDelay + i * _letterGap);
        final isFirst = i == 0;

        return Text(
          text[i],
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w900,
            fontSize: isFirst ? 80.0 : 72.0,
            color: isFirst ? const Color(0xFFFFD700) : Colors.white,
            letterSpacing: 1.2,
            height: 1.0,
            shadows: [
              Shadow(
                color: isFirst
                    ? const Color(0xAAFFD700)
                    : const Color(0x553D5AFE),
                blurRadius: isFirst ? 24 : 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(
              delay: delay,
              duration: Duration(milliseconds: _letterDur),
            )
            .slideY(
              begin: 0.8,
              end: 0,
              delay: delay,
              duration: Duration(milliseconds: _letterDur),
              curve: Curves.easeOutBack,
            )
            .scaleXY(
              begin: 0.4,
              end: 1.0,
              delay: delay,
              duration: Duration(milliseconds: _letterDur),
              curve: Curves.easeOutBack,
            );
      }),
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
            final rng     = i * 2971 + 53;
            final left    = (rng % 1000) / 1000 * w;
            final top     = ((rng * 137) % 1000) / 1000 * h;
            final radius  = 0.7 + (rng % 4) * 0.6;
            final opacity = 0.1 + (rng % 6) / 15.0;
            final delay   = Duration(milliseconds: (i * 60) % 1000);

            return Positioned(
              left: left,
              top:  top,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width:  radius * 2,
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
