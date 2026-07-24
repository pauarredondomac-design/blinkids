import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/providers/fuel_provider.dart';
import '../../shared/providers/wallet_provider.dart';
import '../../shared/widgets/coin_display.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HangarScreen  — Pantalla de celebración al llegar a 100% de combustible
// en el mundo espacio (Hangar de Despegue).
//
// Flujo:
//  1. Animación de cohete/celebración
//  2. +50 monedas via RPC award_coins
//  3. Desbloqueo del traje dorado via RPC unlock_hangar_suit (migración 028)
//  4. Reinicio del combustible (cycle++)
//  5. Botón para volver al mundo
// ─────────────────────────────────────────────────────────────────────────────
class HangarScreen extends ConsumerStatefulWidget {
  const HangarScreen({super.key});

  @override
  ConsumerState<HangarScreen> createState() => _HangarScreenState();
}

class _HangarScreenState extends ConsumerState<HangarScreen> {
  bool _rewardClaimed = false;
  bool _loading = true;
  int  _coinsEarned = 50;

  static const _rewardCoins = 50;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _claimReward());
  }

  Future<void> _claimReward() async {
    if (_rewardClaimed) return;
    setState(() => _loading = true);

    try {
      final db = Supabase.instance.client;

      // 1. Otorgar +50 monedas
      await db.rpc('award_coins', params: {'p_amount': _rewardCoins});

      // 2. Desbloquear traje dorado (migración 028 crea este RPC)
      //    Si el RPC no existe aún, silencia el error.
      try {
        await db.rpc('unlock_hangar_suit');
      } catch (_) {}

      // 3. Reiniciar combustible
      await ref.read(fuelNotifierProvider.notifier).resetFuel('space');

      setState(() {
        _rewardClaimed  = true;
        _coinsEarned    = _rewardCoins;
        _loading        = false;
      });

      // Refrescar monedas en el HUD
      ref.invalidate(currentWalletProvider);
    } catch (e) {
      // Aunque falle, mostrar la pantalla de celebración
      setState(() {
        _rewardClaimed = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080818),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.orangeAccent),
            )
          : _buildCelebration(context),
    );
  }

  Widget _buildCelebration(BuildContext context) {
    return Stack(
      children: [
        // ── Fondo radial oscuro ──────────────────────────────────
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

        // ── Estrellas ─────────────────────────────────────────────
        ..._buildStars(),

        // ── Contenido central ─────────────────────────────────────
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cohete animado
              const Text('🚀', style: TextStyle(fontSize: 80))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(
                    begin: 0,
                    end: -20,
                    duration: 800.ms,
                    curve: Curves.easeInOut,
                  ),

              const SizedBox(height: 24),

              // Título
              const Text(
                '¡Llegaste a Marte!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  fontFamily: 'Nunito',
                  shadows: [Shadow(blurRadius: 20, color: Colors.orangeAccent)],
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .scale(
                    begin: const Offset(0.7, 0.7),
                    end: const Offset(1.0, 1.0),
                  ),

              const SizedBox(height: 12),

              // Subtítulo
              const Text(
                '¡Completaste la misión espacial!\nBlink ha llegado al planeta rojo 🔴',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontFamily: 'Nunito',
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 300.ms, duration: 500.ms),

              const SizedBox(height: 32),

              // Tarjetas de recompensa
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RewardChip(
                    emoji: '🪙',
                    label: '+$_coinsEarned monedas',
                    color: const Color(0xFFFFD600),
                  ),
                  const SizedBox(width: 16),
                  const _RewardChip(
                    emoji: '🥇',
                    label: 'Traje Dorado',
                    color: Colors.orangeAccent,
                  ),
                ],
              )
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 500.ms)
                  .slideY(begin: 0.3, end: 0),

              const SizedBox(height: 40),

              // Botón volver
              ElevatedButton.icon(
                onPressed: () => context.go('/world'),
                icon: const Icon(Icons.rocket_launch_rounded),
                label: const Text(
                  '¡Siguiente aventura!',
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
              )
                  .animate()
                  .fadeIn(delay: 800.ms, duration: 400.ms)
                  .scale(begin: const Offset(0.8, 0.8)),
            ],
          ),
        ),
      ],
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
          top:  positions[i].dy * 400,
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

// ─────────────────────────────────────────────────────────────────────────────
// _RewardChip
// ─────────────────────────────────────────────────────────────────────────────
class _RewardChip extends StatelessWidget {
  const _RewardChip({
    required this.emoji,
    required this.label,
    required this.color,
  });

  final String emoji;
  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          emoji == '🪙'
              ? const AnimatedCoin(size: 20)
              : Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
