// Pantalla de selección de mundos.
// Muestra todos los biomas disponibles; permite comprar los bloqueados.
// Uso: context.push('/worlds', extra: 'forest')  ← ID del mundo actual.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/world.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../shared/providers/wallet_provider.dart';
import '../../shared/providers/world_provider.dart';

class WorldSelectorScreen extends ConsumerStatefulWidget {
  const WorldSelectorScreen({super.key, this.currentWorldId = 'forest'});

  /// ID del mundo donde está el jugador ahora (para destacarlo).
  final String currentWorldId;

  @override
  ConsumerState<WorldSelectorScreen> createState() =>
      _WorldSelectorScreenState();
}

class _WorldSelectorScreenState extends ConsumerState<WorldSelectorScreen> {
  bool _busy = false;

  // ── Compra / desbloqueo ──────────────────────────────────────────────
  Future<void> _handlePurchase(World world) async {
    final coins =
        ref.read(currentWalletProvider).valueOrNull?.totalCoins ?? 0;

    if (coins < world.unlockCost) {
      if (!mounted) return;
      _showSnack(
        '¡Necesitas ${world.unlockCost} 🪙! Solo tienes $coins.',
        Colors.red.shade700,
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _PurchaseDialog(world: world, currentCoins: coins),
    );
    if (confirm != true || !mounted) return;

    setState(() => _busy = true);
    try {
      // purchaseWorld es atómico (RPC SECURITY DEFINER):
      // descuenta las monedas y registra el world_progress en una sola
      // transacción. No puede quedar a medias ni ser explotado con dos
      // llamadas paralelas.
      await WalletRepository().purchaseWorld(world.id);

      ref.invalidate(unlockedWorldsProvider);
      ref.invalidate(currentWalletProvider);

      if (mounted) {
        _showSnack('🎉 ¡${world.name} desbloqueado!', world.accentColor);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        final friendly = msg.contains('insuficiente')
            ? 'No tienes suficientes monedas 😔'
            : msg.contains('ya está desbloqueado')
                ? '¡Ya tienes este mundo! 🌍'
                : 'Error al comprar. Intenta de nuevo.';
        _showSnack(friendly, Colors.red.shade700);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Nunito')),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final unlockedAsync = ref.watch(unlockedWorldsProvider);
    final walletAsync   = ref.watch(currentWalletProvider);
    final coins         = walletAsync.valueOrNull?.totalCoins ?? 0;
    final unlocked      = unlockedAsync.valueOrNull ?? ['forest'];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0A20),
              Color(0xFF12124A),
              Color(0xFF080E1F),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                child: Row(
                  children: [
                    const Text('🌌', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selector de Mundos',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Nunito',
                            ),
                          ),
                          Text(
                            '${unlocked.length} / ${allWorlds.length} desbloqueados',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                              fontFamily: 'Nunito',
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Monedas disponibles
                    _CoinsChip(coins: coins),
                    const SizedBox(width: 10),
                    // Cerrar
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white60,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Divisor ─────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    Colors.white24,
                    Colors.transparent,
                  ]),
                ),
              ),

              // ── Tarjetas de mundo ───────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: allWorlds.map((world) {
                      final isUnlocked =
                          world.isFree || unlocked.contains(world.id);
                      final isCurrent =
                          world.id == widget.currentWorldId;
                      final canAfford = coins >= world.unlockCost;

                      return Expanded(
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 5),
                          child: _WorldCard(
                            world:      world,
                            isUnlocked: isUnlocked,
                            isCurrent:  isCurrent,
                            canAfford:  canAfford,
                            busy:       _busy,
                            onEnter:    () => context.go(world.route),
                            onBuy:      () => _handlePurchase(world),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta individual de mundo
// ─────────────────────────────────────────────────────────────────────────────
class _WorldCard extends StatelessWidget {
  const _WorldCard({
    required this.world,
    required this.isUnlocked,
    required this.isCurrent,
    required this.canAfford,
    required this.busy,
    required this.onEnter,
    required this.onBuy,
  });

  final World        world;
  final bool         isUnlocked;
  final bool         isCurrent;
  final bool         canAfford;
  final bool         busy;
  final VoidCallback onEnter;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final dimmed = world.comingSoon || !isUnlocked;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: world.comingSoon
              ? [const Color(0xFF252535), const Color(0xFF151520)]
              : [
                  world.accentColor.withAlpha(isUnlocked ? 210 : 70),
                  world.accentColor.withAlpha(isUnlocked ? 80 : 25),
                ],
        ),
        border: Border.all(
          color: isCurrent
              ? Colors.white
              : world.comingSoon
                  ? Colors.white12
                  : world.accentColor
                      .withAlpha(isUnlocked ? 220 : 70),
          width: isCurrent ? 2.5 : 1.5,
        ),
        boxShadow: isCurrent && isUnlocked
            ? [
                BoxShadow(
                  color: world.accentColor.withAlpha(90),
                  blurRadius: 18,
                  spreadRadius: 3,
                )
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // ── Emoji ────────────────────────────────────────────────
            Text(
              dimmed && !world.comingSoon ? '🔒' : (world.comingSoon ? '🔒' : world.emoji),
              style: const TextStyle(fontSize: 42),
            ),

            // ── Info ─────────────────────────────────────────────────
            Column(
              children: [
                if (isCurrent && isUnlocked) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '📍 AQUÍ',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito',
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  world.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:
                        world.comingSoon ? Colors.white30 : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Nunito',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  world.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: world.comingSoon
                        ? Colors.white24
                        : (isUnlocked ? Colors.white60 : Colors.white38),
                    fontSize: 10,
                    fontFamily: 'Nunito',
                    height: 1.35,
                  ),
                ),
              ],
            ),

            // ── Botón ────────────────────────────────────────────────
            _buildButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildButton() {
    if (world.comingSoon) {
      return _Pill(
        label: '🔒 Próximamente',
        bg: Colors.white10,
        fg: Colors.white24,
      );
    }
    if (isUnlocked) {
      return _Pill(
        label: isCurrent ? '✅ Estás aquí' : '🚀 Entrar',
        bg: isCurrent ? Colors.white : world.accentColor,
        fg: isCurrent ? Colors.black : Colors.white,
        onTap: busy ? null : onEnter,
      );
    }
    // Bloqueado + comprable
    return _Pill(
      label: canAfford
          ? '🔓 ${world.unlockCost} 🪙'
          : '🔒 ${world.unlockCost} 🪙',
      bg: canAfford ? Colors.amber : Colors.grey.shade800,
      fg: canAfford ? Colors.black : Colors.white38,
      onTap: (busy || !canAfford) ? null : onBuy,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets de apoyo
// ─────────────────────────────────────────────────────────────────────────────
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.bg,
    required this.fg,
    this.onTap,
  });
  final String        label;
  final Color         bg;
  final Color         fg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _CoinsChip extends StatelessWidget {
  const _CoinsChip({required this.coins});
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🪙', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 4),
          Text(
            '$coins',
            style: const TextStyle(
              color: Color(0xFFFFD600),
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

// ─────────────────────────────────────────────────────────────────────────────
// Diálogo de confirmación de compra
// ─────────────────────────────────────────────────────────────────────────────
class _PurchaseDialog extends StatelessWidget {
  const _PurchaseDialog({
    required this.world,
    required this.currentCoins,
  });
  final World world;
  final int   currentCoins;

  @override
  Widget build(BuildContext context) {
    final after = currentCoins - world.unlockCost;
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A3E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: world.accentColor.withAlpha(160)),
      ),
      title: Text(
        '${world.emoji} Desbloquear ${world.name}',
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '¿Gastar ${world.unlockCost} 🪙 para acceder a este mundo\npara siempre?',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontFamily: 'Nunito',
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$currentCoins 🪙',
                style: const TextStyle(
                  color: Color(0xFFFFD600),
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white38,
                  size: 16,
                ),
              ),
              Text(
                '$after 🪙',
                style: TextStyle(
                  color:
                      after >= 0 ? Colors.greenAccent : Colors.redAccent,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            'Cancelar',
            style:
                TextStyle(color: Colors.white54, fontFamily: 'Nunito'),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: world.accentColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            '¡Comprar!',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
