import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/item.dart';
import '../../../data/repositories/mission_tracker.dart';
import '../../../data/repositories/wallet_repository.dart';
import '../../../shared/providers/item_provider.dart';
import '../../../shared/providers/wallet_provider.dart';
import '../../../shared/providers/world_provider.dart';
import '../../../shared/widgets/screen_tutorial.dart';
import '../../../core/constants/app_sizes.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TiendaScreen
// ─────────────────────────────────────────────────────────────────────────────
class TiendaScreen extends ConsumerStatefulWidget {
  const TiendaScreen({super.key});

  @override
  ConsumerState<TiendaScreen> createState() => _TiendaScreenState();
}

class _TiendaScreenState extends ConsumerState<TiendaScreen> {
  bool _buying = false;

  Future<void> _handleBuy(Item item, int currentCoins) async {
    if (_buying) return;
    if (currentCoins < item.shopPrice) {
      _snack('¡Necesitas ${item.shopPrice} 🪙! Solo tienes $currentCoins.', Colors.red.shade700);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _BuyDialog(item: item, currentCoins: currentCoins),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _buying = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final ok = await WalletRepository().spendCoins(userId, item.shopPrice);
        if (!ok) {
          _snack('No tienes suficientes monedas 😔', Colors.red.shade700);
          return;
        }
        ref.invalidate(currentWalletProvider);
      }

      await ref.read(itemRepositoryProvider).addToInventory(item.id, 1);
      await MissionTracker().recordPurchase();
      ref.invalidate(inventoryProvider);

      if (mounted) {
        _snack('¡Compraste ${item.emoji} ${item.name}!', const Color(0xFF2E7D32));
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  void _snack(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final worldId = ref.watch(currentWorldProvider);
    final coins   = ref.watch(currentWalletProvider).valueOrNull?.totalCoins ?? 0;
    final items   = shopItemsForWorld(worldId);

    return ScreenTutorial(
      tutorialKey: 'tienda_v2',
      steps: const [
        TutorialStep(
          title: '¡La Tienda Espacial! 🔮',
          body: 'Aquí puedes comprar materiales y herramientas con tus monedas. '
              '¡Los necesitarás para completar trabajos de crafting!',
        ),
        TutorialStep(
          title: 'Guarda los materiales 🎒',
          body: 'Todo lo que compras va a tu inventario. '
              'Ve al Mercado para ver lo que tienes y también '
              'para vender cosas a otros jugadores.',
        ),
      ],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // ── Fondo espacial ─────────────────────────────────────────────
            Positioned.fill(
              child: Image.asset(
                'assets/images/worlds/space/space_background.png',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: Container(color: Colors.black.withOpacity(0.55)),
            ),

            // ── Contenido ──────────────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  // Header
                  _ShopHeader(coins: coins, onBack: () => context.pop()),

                  // Grid de artículos
                  Expanded(
                    child: items.isEmpty
                        ? Center(
                            child: Text(
                              '😔 No hay artículos disponibles.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.60),
                                fontSize: 14,
                              ),
                            ),
                          )
                        : LayoutBuilder(
                            builder: (ctx, constraints) {
                              const cols = 3;
                              const hPad = AppSizes.md * 2 + AppSizes.sm * 2;
                              final cardW = (constraints.maxWidth - hPad) / cols;
                              final cardH =
                                  (constraints.maxHeight - 48).clamp(120.0, 300.0);
                              final ratio = cardW / cardH;
                              return GridView.builder(
                                padding: const EdgeInsets.all(AppSizes.md),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cols,
                                  crossAxisSpacing: AppSizes.sm,
                                  mainAxisSpacing: AppSizes.sm,
                                  childAspectRatio: ratio,
                                ),
                                itemCount: items.length,
                                itemBuilder: (ctx, i) {
                                  final item = items[i];
                                  return _ItemCard(
                                    item:  item,
                                    coins: coins,
                                    busy:  _buying,
                                    onBuy: () => _handleBuy(item, coins),
                                  )
                                      .animate(delay: (55 * i).ms)
                                      .fadeIn(duration: 280.ms)
                                      .scale(
                                        begin: const Offset(0.88, 0.88),
                                        end: const Offset(1, 1),
                                        curve: Curves.easeOut,
                                      );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header con placa "TIENDA ESPACIAL" + volver + monedas
// ─────────────────────────────────────────────────────────────────────────────
class _ShopHeader extends StatelessWidget {
  const _ShopHeader({required this.coins, required this.onBack});
  final int          coins;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.70),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // Botón volver
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.25),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),

          // Placa del título
          Expanded(
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF1A0A35),
                      Color(0xFF2D1260),
                      Color(0xFF1A0A35),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFCE93D8).withOpacity(0.55),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFCE93D8).withOpacity(0.22),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: Text(
                  'TIENDA ESPACIAL',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                    shadows: [
                      Shadow(
                        color: const Color(0xFFCE93D8).withOpacity(0.80),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Monedas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.50),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amber.withOpacity(0.70)),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.15),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🪙', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 5),
                Text(
                  '$coins',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
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
// Tarjeta de artículo — estilo espacial
// ─────────────────────────────────────────────────────────────────────────────
class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.coins,
    required this.busy,
    required this.onBuy,
  });

  final Item         item;
  final int          coins;
  final bool         busy;
  final VoidCallback onBuy;

  bool get _canAfford => coins >= item.shopPrice;

  // Colores según rareza
  Color get _borderColor => item.isRare
      ? const Color(0xFFFFD600).withOpacity(0.65)
      : const Color(0xFFCE93D8).withOpacity(0.28);

  Color get _glowColor => item.isRare
      ? const Color(0xFFFFD600).withOpacity(0.12)
      : const Color(0xFFCE93D8).withOpacity(0.06);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0A24).withOpacity(0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor, width: item.isRare ? 1.5 : 1),
        boxShadow: [
          BoxShadow(color: _glowColor, blurRadius: 14),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Badge raro / spacer
            if (item.isRare)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD600),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '✨ MISIÓN',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w800,
                    fontSize: 8,
                  ),
                ),
              )
            else
              const SizedBox(height: 8),

            // Emoji animado
            Text(item.emoji, style: const TextStyle(fontSize: 34))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(
                  begin: 0, end: -3,
                  duration: 2000.ms,
                  curve: Curves.easeInOut,
                ),

            // Nombre
            Text(
              item.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Descripción
            Text(
              item.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.50),
                fontSize: 9,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Precio + botón
            Column(
              children: [
                Text(
                  '🪙 ${item.shopPrice}',
                  style: TextStyle(
                    color: _canAfford
                        ? const Color(0xFFFFD600)
                        : Colors.red.shade300,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: (_canAfford && !busy) ? onBuy : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        gradient: _canAfford
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFF7B2FBE),
                                  Color(0xFFAB47BC),
                                ],
                              )
                            : null,
                        color: _canAfford ? null : Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _canAfford
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFAB47BC).withOpacity(0.40),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Text(
                        _canAfford ? 'Comprar' : 'Sin fondos',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _canAfford
                              ? Colors.white
                              : Colors.white.withOpacity(0.38),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Diálogo de confirmación de compra — estilo espacial
// ─────────────────────────────────────────────────────────────────────────────
class _BuyDialog extends StatelessWidget {
  const _BuyDialog({required this.item, required this.currentCoins});
  final Item item;
  final int  currentCoins;

  @override
  Widget build(BuildContext context) {
    final after = currentCoins - item.shopPrice;
    return AlertDialog(
      backgroundColor: const Color(0xFF0F0A24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: const Color(0xFFCE93D8).withOpacity(0.50),
          width: 1.5,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Emoji grande
          Text(item.emoji, style: const TextStyle(fontSize: 52))
              .animate()
              .scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1, 1),
                duration: 350.ms,
                curve: Curves.easeOutBack,
              ),
          const SizedBox(height: 10),

          // Pregunta
          Text(
            '¿Comprar "${item.name}"?',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),

          // Monedas antes → después
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$currentCoins 🪙',
                style: const TextStyle(
                  color: Color(0xFFFFD600),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white.withOpacity(0.35),
                  size: 16,
                ),
              ),
              Text(
                '$after 🪙',
                style: TextStyle(
                  color: after >= 0
                      ? Colors.greenAccent
                      : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Se guardará en tu inventario.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.50),
              fontSize: 11,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancelar',
            style: TextStyle(color: Colors.white.withOpacity(0.50)),
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pop(context, true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7B2FBE), Color(0xFFAB47BC)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFAB47BC).withOpacity(0.40),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Text(
              '¡Comprar! 🔮',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
