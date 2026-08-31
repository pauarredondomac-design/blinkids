import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../providers/world_provider.dart';
import '../../data/models/world.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Punto de entrada único para los 3 lugares donde se puede completar el
// combustible (Misiones, Mi Bolsa, Trabajos).
//
// La primera vez que se llega a 100%: desbloquea el Bosque gratis (sin
// cobrar monedas) y muestra la animación de despegue.
// Si el Bosque ya estaba desbloqueado, no repite nada — el combustible se
// queda lleno como recordatorio visual de que ya se completó esa meta.
// ─────────────────────────────────────────────────────────────────────────────
Future<void> handleFuelReachedFull(BuildContext context, WidgetRef ref) async {
  final unlocked = await ref.read(unlockedWorldsProvider.future);
  if (unlocked.contains('forest')) return;

  await ref.read(worldRepositoryProvider).unlockWorld('forest');
  ref.invalidate(unlockedWorldsProvider);

  if (context.mounted) await showRocketLaunchOverlay(context);
}

// ─────────────────────────────────────────────────────────────────────────────
// Animación de despegue a pantalla completa (video).
// No se puede saltar tocando la pantalla — se cierra sola al terminar.
// ─────────────────────────────────────────────────────────────────────────────
Future<void> showRocketLaunchOverlay(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim, __) => FadeTransition(
        opacity: anim,
        child: const _RocketLaunchScreen(),
      ),
    ),
  );
}

class _RocketLaunchScreen extends StatefulWidget {
  const _RocketLaunchScreen();

  @override
  State<_RocketLaunchScreen> createState() => _RocketLaunchScreenState();
}

class _RocketLaunchScreenState extends State<_RocketLaunchScreen>
    with SingleTickerProviderStateMixin {
  late final VideoPlayerController _video;
  AnimationController? _textCtrl;
  bool _showUnlocked = false;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    _video = VideoPlayerController.asset('assets/animations/rocket_launch.mp4');
    _video.addListener(_onVideoTick);
    _video.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _videoReady = true;
        _textCtrl =
            AnimationController(vsync: this, duration: _video.value.duration)
              ..forward();
      });
      _video.play();
    });
  }

  void _onVideoTick() {
    final v = _video.value;
    if (v.isInitialized &&
        v.duration > Duration.zero &&
        !v.isPlaying &&
        v.position >= v.duration &&
        !_showUnlocked) {
      setState(() => _showUnlocked = true);
    }
  }

  @override
  void dispose() {
    _video.removeListener(_onVideoTick);
    _video.dispose();
    _textCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060618),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_videoReady)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _video.value.size.width,
                height: _video.value.size.height,
                child: VideoPlayer(_video),
              ),
            ),

          // ── Texto ──────────────────────────────────────────────────────
          if (_textCtrl != null)
            Positioned(
              left: 24,
              right: 24,
              bottom: 60,
              child: AnimatedBuilder(
                animation: _textCtrl!,
                builder: (context, _) {
                  final t = _textCtrl!.value;
                  final opacity =
                      t < 0.15 ? t / 0.15 : (t > 0.85 ? (1 - t) / 0.15 : 1.0);
                  return Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '¡Combustible al 100%! 🚀',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w900,
                            fontSize: 26,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '¡Desbloqueaste el Bosque Encantado! 🌲',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          // ── Tarjeta de mundo desbloqueado (aparece al terminar) ─────────
          if (_showUnlocked)
            Positioned.fill(
              child: _ForestUnlockedCard(
                onGoToForest: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  context.go('/world/forest');
                },
                onDismiss: () =>
                    Navigator.of(context, rootNavigator: true).maybePop(),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta final — celebra el desbloqueo y ofrece ir al Bosque de inmediato
// ─────────────────────────────────────────────────────────────────────────────
class _ForestUnlockedCard extends StatelessWidget {
  const _ForestUnlockedCard(
      {required this.onGoToForest, required this.onDismiss});
  final VoidCallback onGoToForest;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final forest = allWorlds.firstWhere((w) => w.id == 'forest');
    return Container(
      color: Colors.black87,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.elasticOut,
          builder: (context, t, child) =>
              Transform.scale(scale: t.clamp(0.0, 1.2), child: child),
          child: Container(
            width: (MediaQuery.sizeOf(context).width - 32)
                .clamp(260.0, 420.0)
                .toDouble(),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF12124A), Color(0xFF0D0D2B)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: const Color(0xFF69F0AE).withOpacity(0.6), width: 1.6),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF69F0AE).withOpacity(0.25),
                    blurRadius: 24,
                    spreadRadius: 2)
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🗺️ ¡Mapa desbloqueado!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        color: Colors.white)),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: forest.unlockedImagePath != null
                      ? Image.asset(forest.unlockedImagePath!,
                      width: double.infinity, height: 140, fit: BoxFit.cover)
                      : Container(
                          width: double.infinity,
                          height: 140,
                          color: forest.accentColor.withOpacity(0.3),
                          child: const Center(
                              child:
                                  Text('🌲', style: TextStyle(fontSize: 56)))),
                ),
                const SizedBox(height: 14),
                Text('¡Desbloqueaste el ${forest.name}! 🌲',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF69F0AE))),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onGoToForest,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF69F0AE),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Ir al Bosque 🌲',
                        style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onDismiss,
                  child: const Text('Seguir explorando',
                      style: TextStyle(
                          fontFamily: 'Nunito', color: Colors.white54)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
