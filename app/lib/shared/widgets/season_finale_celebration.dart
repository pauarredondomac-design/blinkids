import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Celebración de fin de temporada — se muestra al reclamar la última misión
// de historia ("Aterrizar y fundar base"). Inspirada visualmente en
// HangarScreen ("¡Llegaste a Marte!") pero SIN sus efectos secundarios
// (no reinicia el combustible ni desbloquea el traje del hangar — esos
// pertenecen al ciclo de combustible, un sistema aparte). Las recompensas
// de la misión ya se otorgaron por el flujo normal de reclamo de Misiones.
// ─────────────────────────────────────────────────────────────────────────────
Future<void> showSeasonFinaleCelebration(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim, __) => FadeTransition(
        opacity: anim,
        child: const _SeasonFinaleScreen(),
      ),
    ),
  );
}

class _SeasonFinaleScreen extends StatelessWidget {
  const _SeasonFinaleScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080818),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.3),
                  radius: 1.4,
                  colors: [Color(0xFF1A237E), Color(0xFF080818)],
                ),
              ),
            ),
          ),
          ..._buildStars(),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🚀', style: TextStyle(fontSize: 80))
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .moveY(
                      begin: 0,
                      end: -20,
                      duration: 800.ms,
                      curve: Curves.easeInOut,
                    ),
                const SizedBox(height: 24),
                const Text(
                  '¡Llegaste a Marte!',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontFamily: 'Nunito',
                    shadows: [
                      Shadow(blurRadius: 20, color: Colors.orangeAccent),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(duration: 600.ms).scale(
                      begin: const Offset(0.7, 0.7),
                      end: const Offset(1.0, 1.0),
                    ),
                const SizedBox(height: 12),
                const Text(
                  '¡Completaste toda la historia espacial!\nBlink fundó su nueva base en el planeta rojo 🔴',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontFamily: 'Nunito',
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.of(context, rootNavigator: true).maybePop(),
                  icon: const Icon(Icons.celebration_rounded),
                  label: const Text(
                    '¡Increíble aventura!',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ).animate().fadeIn(delay: 800.ms, duration: 400.ms).scale(
                      begin: const Offset(0.8, 0.8),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStars() {
    const positions = [
      Offset(0.10, 0.05),
      Offset(0.85, 0.08),
      Offset(0.45, 0.03),
      Offset(0.70, 0.15),
      Offset(0.20, 0.20),
      Offset(0.90, 0.25),
      Offset(0.05, 0.45),
      Offset(0.95, 0.60),
      Offset(0.15, 0.75),
      Offset(0.80, 0.80),
      Offset(0.50, 0.90),
      Offset(0.30, 0.95),
    ];
    return [
      for (int i = 0; i < positions.length; i++)
        Positioned(
          left: positions[i].dx * 800,
          top: positions[i].dy * 400,
          child: Text(
            '✨',
            style: TextStyle(fontSize: 14 + (i % 3) * 4.0),
          )
              .animate(onPlay: (c) => c.repeat())
              .fadeIn(delay: (i * 150).ms)
              .then()
              .fadeOut(duration: 1500.ms)
              .then()
              .fadeIn(duration: 1500.ms),
        ),
    ];
  }
}
