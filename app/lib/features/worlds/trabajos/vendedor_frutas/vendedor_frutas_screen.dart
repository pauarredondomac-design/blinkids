import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../data/models/job.dart';
import '../../../../data/repositories/job_repository.dart';
import '../../../../data/repositories/wallet_repository.dart';
import '../../../../shared/providers/wallet_provider.dart';
import '../../../../shared/providers/character_provider.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../shared/widgets/coin_display.dart';
import '../../../../shared/widgets/badges_row.dart';

// ─── Denominaciones de monedas/billetes disponibles ──────────────────────────
class _Denom {
  const _Denom(this.value, this.emoji, this.label);
  final int value;
  final String emoji;
  final String label;
}

const _denoms = [
  _Denom(1, '🪙', '\$1'),
  _Denom(2, '🪙', '\$2'),
  _Denom(5, '💛', '\$5'),
  _Denom(10, '💵', '\$10'),
  _Denom(20, '💵', '\$20'),
  _Denom(50, '💵', '\$50'),
];

// ─── Estado del juego ─────────────────────────────────────────────────────────
enum _GameState { playing, levelPassed, won, lost }

class VendedorFrutasScreen extends ConsumerStatefulWidget {
  const VendedorFrutasScreen({super.key, this.job});
  final Job? job;

  @override
  ConsumerState<VendedorFrutasScreen> createState() =>
      _VendedorFrutasScreenState();
}

class _VendedorFrutasScreenState extends ConsumerState<VendedorFrutasScreen> {
  // Niveles del juego (usa los del Job o los por defecto)
  late final List<JobLevel> _levels;

  int _levelIndex = 0;
  int _changeGiven = 0;
  _GameState _gameState = _GameState.playing;
  int _secondsLeft = 60;
  bool _showFeedback = false;
  Timer? _timer;

  // Monedas seleccionadas en el nivel actual (para el undo)
  final List<int> _selectedDenoms = [];

  JobLevel get _current => _levels[_levelIndex];
  int get _changeNeeded => _current.change;

  @override
  void initState() {
    super.initState();
    _levels = widget.job?.levels.isNotEmpty == true
        ? widget.job!.levels
        : const [
            JobLevel(price: 15, paid: 20, change: 5),
            JobLevel(price: 32, paid: 50, change: 18),
            JobLevel(price: 67, paid: 100, change: 33),
          ];
    _secondsLeft = widget.job?.durationSeconds ?? 60;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _timer?.cancel();
          _gameState = _GameState.lost;
        }
      });
    });
  }

  void _addCoin(int value) {
    if (_gameState != _GameState.playing) return;
    if (_changeGiven + value > _changeNeeded * 2) return; // límite anti-spam

    setState(() {
      _changeGiven += value;
      _selectedDenoms.add(value);
    });

    // Comprobar si es correcto
    if (_changeGiven == _changeNeeded) {
      _timer?.cancel();
      setState(() {
        _showFeedback = true;
        _gameState = _levelIndex < _levels.length - 1
            ? _GameState.levelPassed
            : _GameState.won;
      });
    }
  }

  void _removeLast() {
    if (_selectedDenoms.isEmpty || _gameState != _GameState.playing) return;
    setState(() {
      final last = _selectedDenoms.removeLast();
      _changeGiven -= last;
    });
  }

  void _resetChange() {
    setState(() {
      _changeGiven = 0;
      _selectedDenoms.clear();
    });
  }

  void _nextLevel() {
    setState(() {
      _levelIndex++;
      _changeGiven = 0;
      _selectedDenoms.clear();
      _gameState = _GameState.playing;
      _showFeedback = false;
    });
    _startTimer();
  }

  Future<void> _finish() async {
    _timer?.cancel();
    final coinReward = widget.job?.coinReward ?? 25;
    final xpReward = widget.job?.xpReward ?? 15;
    final userId = Supabase.instance.client.auth.currentUser?.id;

    List<String> newBadges = [];
    if (userId != null) {
      // Otorgar monedas, XP y registrar completado en paralelo
      final xpFuture = awardXp(ref, xpReward);
      final futures = <Future>[
        WalletRepository()
            .awardStarterCoins(userId, coinReward)
            .catchError((_) => null),
      ];
      if (widget.job != null) {
        futures.add(JobRepository().recordCompletion(
          userId: userId,
          jobId: widget.job!.id,
          coinsEarned: coinReward,
        ));
      }
      await Future.wait(futures);
      newBadges = await xpFuture;
      ref.invalidate(currentWalletProvider);
    }

    if (mounted) showBadgeUnlockToasts(context, ref, newBadges);
    if (mounted) context.go('/world/trabajos');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E7D32),
      body: SafeArea(
        child: Column(
          children: [
            // ── Barra superior ──────────────────────────────────────────────
            _TopBar(
              levelIndex: _levelIndex,
              totalLevels: _levels.length,
              secondsLeft: _secondsLeft,
              totalSeconds: widget.job?.durationSeconds ?? 60,
              coinReward: widget.job?.coinReward ?? 25,
              onExit: () => context.go('/world/trabajos'),
            ),

            // ── Cuerpo ──────────────────────────────────────────────────────
            Expanded(
              child: _gameState == _GameState.won
                  ? _WonView(
                      coinReward: widget.job?.coinReward ?? 25,
                      onFinish: _finish,
                    )
                  : _gameState == _GameState.lost
                      ? _LostView(onRetry: () => context.go('/world/trabajos'))
                      : _PlayView(
                          level: _current,
                          changeGiven: _changeGiven,
                          selectedDenoms: _selectedDenoms,
                          showFeedback: _showFeedback,
                          gameState: _gameState,
                          onAddCoin: _addCoin,
                          onUndo: _removeLast,
                          onReset: _resetChange,
                          onNextLevel: _nextLevel,
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Barra superior ───────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.levelIndex,
    required this.totalLevels,
    required this.secondsLeft,
    required this.totalSeconds,
    required this.coinReward,
    required this.onExit,
  });

  final int levelIndex;
  final int totalLevels;
  final int secondsLeft;
  final int totalSeconds;
  final int coinReward;
  final VoidCallback onExit;

  Color get _timerColor {
    final pct = secondsLeft / totalSeconds;
    if (pct > 0.5) return const Color(0xFF4CAF50);
    if (pct > 0.25) return const Color(0xFFFFC107);
    return const Color(0xFFF44336);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black26,
      child: Row(
        children: [
          // Salir
          IconButton(
            onPressed: onExit,
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          ),

          // Título
          const Text(
            '🍎 Vendedor de Frutas',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const Spacer(),

          // Nivel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Nivel ${levelIndex + 1}/$totalLevels',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Timer
          Row(
            children: [
              Icon(Icons.timer, color: _timerColor, size: 20),
              const SizedBox(width: 4),
              Text(
                '${secondsLeft}s',
                style: TextStyle(
                  color: _timerColor,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Recompensa
          Row(
            children: [
              const AnimatedCoin(size: 18),
              const SizedBox(width: 4),
              Text(
                '+$coinReward',
                style: const TextStyle(
                  color: Color(0xFFFFD600),
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Vista de juego activo ────────────────────────────────────────────────────
class _PlayView extends StatelessWidget {
  const _PlayView({
    required this.level,
    required this.changeGiven,
    required this.selectedDenoms,
    required this.showFeedback,
    required this.gameState,
    required this.onAddCoin,
    required this.onUndo,
    required this.onReset,
    required this.onNextLevel,
  });

  final JobLevel level;
  final int changeGiven;
  final List<int> selectedDenoms;
  final bool showFeedback;
  final _GameState gameState;
  final void Function(int) onAddCoin;
  final VoidCallback onUndo;
  final VoidCallback onReset;
  final VoidCallback onNextLevel;

  int get _changeNeeded => level.change;
  bool get _isCorrect => changeGiven == _changeNeeded;
  bool get _isOver => changeGiven > _changeNeeded;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Cliente (izquierda) ───────────────────────────────────────────
        Expanded(
          flex: 3,
          child: _CustomerPanel(level: level, changeGiven: changeGiven),
        ),

        // ── Cambio a dar (centro) ─────────────────────────────────────────
        Expanded(
          flex: 4,
          child: _ChangePanel(
            changeGiven: changeGiven,
            changeNeeded: _changeNeeded,
            selectedDenoms: selectedDenoms,
            isCorrect: _isCorrect,
            isOver: _isOver,
            showFeedback: showFeedback,
            gameState: gameState,
            onUndo: onUndo,
            onReset: onReset,
            onNextLevel: onNextLevel,
          ),
        ),

        // ── Monedas/billetes (derecha) ────────────────────────────────────
        Expanded(
          flex: 3,
          child: _DenomPanel(onAddCoin: onAddCoin, enabled: !showFeedback),
        ),
      ],
    );
  }
}

// ─── Panel del cliente ────────────────────────────────────────────────────────
class _CustomerPanel extends StatelessWidget {
  const _CustomerPanel({required this.level, required this.changeGiven});
  final JobLevel level;
  final int changeGiven;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1B5E20),
      padding: const EdgeInsets.all(AppSizes.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Cliente
          const Text('🧑‍🌾', style: TextStyle(fontSize: 60))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(
                  begin: 0,
                  end: -5,
                  duration: 1000.ms,
                  curve: Curves.easeInOut),

          const SizedBox(height: AppSizes.sm),

          // Burbuja de diálogo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 6)
              ],
            ),
            child: Column(
              children: [
                const Text(
                  '¡Quiero comprar!',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Precio: \$${level.price}',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Te pago: \$${level.paid}',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.md),

          // Pregunta
          const Text(
            '¿Cuánto de cambio\ndebo dar?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD600),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '\$${level.change} de cambio',
              style: const TextStyle(
                color: Colors.black87,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Panel de cambio dado ─────────────────────────────────────────────────────
class _ChangePanel extends StatelessWidget {
  const _ChangePanel({
    required this.changeGiven,
    required this.changeNeeded,
    required this.selectedDenoms,
    required this.isCorrect,
    required this.isOver,
    required this.showFeedback,
    required this.gameState,
    required this.onUndo,
    required this.onReset,
    required this.onNextLevel,
  });

  final int changeGiven;
  final int changeNeeded;
  final List<int> selectedDenoms;
  final bool isCorrect;
  final bool isOver;
  final bool showFeedback;
  final _GameState gameState;
  final VoidCallback onUndo;
  final VoidCallback onReset;
  final VoidCallback onNextLevel;

  Color get _counterColor {
    if (isCorrect) return const Color(0xFF2E7D32);
    if (isOver) return const Color(0xFFC62828);
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Contador de cambio
          const Text(
            'Cambio dado:',
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'Nunito',
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: _counterColor,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w900,
              fontSize: 56,
            ),
            child: Text('\$$changeGiven'),
          ),
          Text(
            'de \$$changeNeeded',
            style: const TextStyle(
              color: Colors.white54,
              fontFamily: 'Nunito',
              fontSize: 14,
            ),
          ),
          const SizedBox(height: AppSizes.md),

          // Monedas seleccionadas (últimas 6)
          if (selectedDenoms.isNotEmpty)
            Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: selectedDenoms.reversed.take(8).map((v) {
                final d = _denoms.firstWhere((d) => d.value == v,
                    orElse: () => _Denom(v, '🪙', '\$$v'));
                return Chip(
                  label: Text(d.label,
                      style: const TextStyle(
                          fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
                  avatar: Text(d.emoji),
                  backgroundColor: Colors.white24,
                  labelStyle:
                      const TextStyle(color: Colors.white, fontSize: 12),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),

          const SizedBox(height: AppSizes.md),

          // Botones de acción
          if (!showFeedback) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: selectedDenoms.isEmpty ? null : onUndo,
                  icon: const Icon(Icons.undo, color: Colors.white70),
                  label: const Text('Deshacer',
                      style: TextStyle(
                          color: Colors.white70, fontFamily: 'Nunito')),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white30),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: selectedDenoms.isEmpty ? null : onReset,
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                  label: const Text('Borrar',
                      style: TextStyle(
                          color: Colors.white70, fontFamily: 'Nunito')),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white30),
                  ),
                ),
              ],
            ),

            // Feedback de exceso
            if (isOver) ...[
              const SizedBox(height: AppSizes.sm),
              const Text(
                '⚠️ ¡Demasiado! Deshaz\nalguna moneda.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFFF8A80),
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ],

          // Feedback correcto / siguiente nivel
          if (showFeedback) ...[
            const Text('✅ ¡Correcto!',
                    style: TextStyle(
                      color: Color(0xFF69F0AE),
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ))
                .animate()
                .fadeIn(duration: 300.ms)
                .scale(begin: const Offset(0.7, 0.7)),
            const SizedBox(height: AppSizes.md),
            if (gameState == _GameState.levelPassed)
              FilledButton(
                onPressed: onNextLevel,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD600),
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Siguiente nivel →',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ─── Panel de denominaciones ──────────────────────────────────────────────────
class _DenomPanel extends StatelessWidget {
  const _DenomPanel({required this.onAddCoin, required this.enabled});
  final void Function(int) onAddCoin;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black12,
      padding: const EdgeInsets.all(AppSizes.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Toca para dar:',
            style: TextStyle(
              color: Colors.white60,
              fontFamily: 'Nunito',
              fontSize: 12,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          ..._denoms.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DenomButton(
                  denom: d,
                  enabled: enabled,
                  onTap: () => onAddCoin(d.value),
                ),
              )),
        ],
      ),
    );
  }
}

class _DenomButton extends StatelessWidget {
  const _DenomButton({
    required this.denom,
    required this.enabled,
    required this.onTap,
  });
  final _Denom denom;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: denom.value >= 10
                ? const Color(0xFF1B5E20)
                : const Color(0xFF33691E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black26, blurRadius: 3, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(denom.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(
                denom.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Pantalla de victoria ─────────────────────────────────────────────────────
class _WonView extends StatelessWidget {
  const _WonView({required this.coinReward, required this.onFinish});
  final int coinReward;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        color: const Color(0xFF1B5E20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        ),
        elevation: 12,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 72))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.15, 1.15),
                    duration: 700.ms,
                  ),
              const SizedBox(height: AppSizes.md),
              const Text(
                '¡Excelente!\n¡Diste el cambio correcto en todos los niveles!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: AppSizes.md),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD600).withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFD600)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AnimatedCoin(size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '+$coinReward monedas ganadas',
                      style: const TextStyle(
                        color: Color(0xFFFFD600),
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.lg),
              FilledButton(
                onPressed: onFinish,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD600),
                  foregroundColor: Colors.black87,
                  minimumSize: const Size(200, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  '¡Cobrar y salir! 💰',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 400.ms).scale(
            begin: const Offset(0.8, 0.8),
            end: const Offset(1, 1),
            curve: Curves.easeOutBack,
          ),
    );
  }
}

// ─── Pantalla de derrota ──────────────────────────────────────────────────────
class _LostView extends StatelessWidget {
  const _LostView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        color: const Color(0xFF7F0000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        ),
        elevation: 12,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⏰', style: TextStyle(fontSize: 64)),
              const SizedBox(height: AppSizes.md),
              const Text(
                '¡Se acabó el tiempo!\n¡El cliente se fue sin cambio!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: AppSizes.md),
              const Text(
                'Practica más rápido con las\ndenominaciones y vuelve a intentarlo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontFamily: 'Nunito',
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: AppSizes.lg),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD600),
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  '← Volver a trabajos',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      )
          .animate()
          .fadeIn(duration: 300.ms)
          .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1)),
    );
  }
}
