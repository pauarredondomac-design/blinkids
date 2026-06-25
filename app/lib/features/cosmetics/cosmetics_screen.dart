import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/cosmetic.dart';
import '../../shared/providers/cosmetic_provider.dart';
import '../../shared/providers/wallet_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CosmeticsScreen — Vestuario del personaje
// Muestra el mannequin con los 5 slots y el catálogo de cosméticos.
// ─────────────────────────────────────────────────────────────────────────────
class CosmeticsScreen extends ConsumerStatefulWidget {
  const CosmeticsScreen({super.key});

  @override
  ConsumerState<CosmeticsScreen> createState() => _CosmeticsScreenState();
}

class _CosmeticsScreenState extends ConsumerState<CosmeticsScreen>
    with SingleTickerProviderStateMixin {

  late final TabController _tabs;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _tabs = TabController(length: CosmeticSlot.values.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _handleBuy(CosmeticDefinition cosmetic) async {
    if (_busy) return;
    final coins = ref.read(currentWalletProvider).valueOrNull?.totalCoins ?? 0;
    if (coins < cosmetic.price) {
      _snack('Necesitas ${cosmetic.price} 🪙 (tienes $coins)', Colors.red.shade700);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _BuyDialog(cosmetic: cosmetic, coins: coins),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(cosmeticShopProvider.notifier).buy(cosmetic.id);
      ref.invalidate(currentWalletProvider);
      if (mounted) _snack('¡Compraste ${cosmetic.emoji} ${cosmetic.name}!',
          const Color(0xFF2E7D32));
    } catch (e) {
      if (mounted) _snack(_friendlyError(e), Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleEquip(CosmeticDefinition cosmetic) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(cosmeticShopProvider.notifier).equip(cosmetic.id);
      if (mounted) _snack('${cosmetic.emoji} Equipado: ${cosmetic.name}',
          const Color(0xFF1565C0));
    } catch (e) {
      if (mounted) _snack(_friendlyError(e), Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleUnequip(CosmeticSlot slot) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(cosmeticShopProvider.notifier).unequip(slot);
      if (mounted) _snack('Slot vacío', Colors.grey.shade700);
    } catch (_) {} finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Nunito')),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
    ));
  }

  String _friendlyError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('insuficiente') || s.contains('insufficient')) {
      return 'No tienes suficientes monedas 😔';
    }
    if (s.contains('ya tienes')) return 'Ya tienes este cosmético ✅';
    if (s.contains('no tienes este')) return 'Primero debes comprarlo 🛍️';
    return 'Error al procesar la acción';
  }

  @override
  Widget build(BuildContext context) {
    final loadoutAsync = ref.watch(equippedLoadoutProvider);
    final ownedAsync   = ref.watch(ownedCosmeticIdsProvider);
    final catalogAsync = ref.watch(cosmeticCatalogProvider);
    final coins = ref.watch(currentWalletProvider).valueOrNull?.totalCoins ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF06091A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1230),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          '🎭 Vestuario',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(children: [
              const Text('🪙', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 4),
              Text('$coins',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Color(0xFFFFD600),
                  )),
            ]),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: const Color(0xFFCE93D8),
          unselectedLabelColor: Colors.white38,
          indicatorColor: const Color(0xFF7C3AED),
          labelStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700),
          tabs: CosmeticSlot.values.map((s) => Tab(
            text: '${s.defaultEmoji} ${s.displayName}',
          )).toList(),
        ),
      ),
      body: catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white54))),
        data: (catalog) {
          final owned = ownedAsync.valueOrNull ?? {};
          final loadout = loadoutAsync.valueOrNull ?? EquippedLoadout.empty;

          return Row(
            children: [
              // ── Panel izquierdo: mannequin ─────────────────────────────
              SizedBox(
                width: 200,
                child: _MannequinPanel(loadout: loadout, onUnequip: _handleUnequip),
              ),
              const VerticalDivider(width: 1, color: Colors.white10),
              // ── Panel derecho: catálogo por slot ───────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: CosmeticSlot.values.map((slot) {
                    final items = catalog.where((c) => c.slot == slot).toList();
                    return _SlotGrid(
                      items:     items,
                      owned:     owned,
                      loadout:   loadout,
                      busy:      _busy,
                      onBuy:     _handleBuy,
                      onEquip:   _handleEquip,
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mannequin panel — muestra el personaje con los 5 slots
// ─────────────────────────────────────────────────────────────────────────────
class _MannequinPanel extends StatelessWidget {
  const _MannequinPanel({required this.loadout, required this.onUnequip});
  final EquippedLoadout loadout;
  final void Function(CosmeticSlot) onUnequip;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D1230),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            '🦊 Blink',
            style: TextStyle(
              color:      Colors.white,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize:   16,
            ),
          ),
          const SizedBox(height: 8),

          // Representación visual del personaje (emojis por slot)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                // Casco
                _SlotBadge(slot: CosmeticSlot.helmet,   loadout: loadout, onTap: onUnequip),
                const SizedBox(height: 4),
                // Personaje base
                const Text('🦊', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 4),
                // Traje + mochila (fila)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SlotBadge(slot: CosmeticSlot.suit,    loadout: loadout, onTap: onUnequip),
                    const SizedBox(width: 8),
                    _SlotBadge(slot: CosmeticSlot.backpack, loadout: loadout, onTap: onUnequip),
                  ],
                ),
                const SizedBox(height: 4),
                // Botas + bandera (fila)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SlotBadge(slot: CosmeticSlot.boots, loadout: loadout, onTap: onUnequip),
                    const SizedBox(width: 8),
                    _SlotBadge(slot: CosmeticSlot.flag,  loadout: loadout, onTap: onUnequip),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Text(
            'Toca un slot equipado para quitarlo',
            textAlign: TextAlign.center,
            style: TextStyle(
              color:      Colors.white30,
              fontFamily: 'Nunito',
              fontSize:   10,
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotBadge extends StatelessWidget {
  const _SlotBadge({required this.slot, required this.loadout, required this.onTap});
  final CosmeticSlot slot;
  final EquippedLoadout loadout;
  final void Function(CosmeticSlot) onTap;

  @override
  Widget build(BuildContext context) {
    final equipped = loadout[slot];
    final isEmpty  = equipped == null;
    return GestureDetector(
      onTap: isEmpty ? null : () => onTap(slot),
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: isEmpty
              ? Colors.white.withAlpha(8)
              : const Color(0xFF7C3AED).withAlpha(60),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isEmpty ? Colors.white12 : const Color(0xFF7C3AED),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isEmpty ? slot.defaultEmoji : equipped.emoji,
              style: TextStyle(fontSize: isEmpty ? 18 : 20),
            ),
            if (!isEmpty)
              const Icon(Icons.close_rounded, size: 8, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grid de cosméticos de un slot
// ─────────────────────────────────────────────────────────────────────────────
class _SlotGrid extends StatelessWidget {
  const _SlotGrid({
    required this.items,
    required this.owned,
    required this.loadout,
    required this.busy,
    required this.onBuy,
    required this.onEquip,
  });

  final List<CosmeticDefinition>     items;
  final Set<String>                  owned;
  final EquippedLoadout              loadout;
  final bool                         busy;
  final void Function(CosmeticDefinition) onBuy;
  final void Function(CosmeticDefinition) onEquip;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          '😔 No hay cosméticos disponibles.',
          style: TextStyle(color: Colors.white54, fontFamily: 'Nunito'),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final cosmetic   = items[i];
        final isOwned    = owned.contains(cosmetic.id);
        final isEquipped = loadout[cosmetic.slot]?.id == cosmetic.id;
        return _CosmeticCard(
          cosmetic:   cosmetic,
          isOwned:    isOwned,
          isEquipped: isEquipped,
          busy:       busy,
          onBuy:      () => onBuy(cosmetic),
          onEquip:    () => onEquip(cosmetic),
        )
            .animate(delay: (50 * i).ms)
            .fadeIn(duration: 250.ms)
            .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOut);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta de cosmético
// ─────────────────────────────────────────────────────────────────────────────
class _CosmeticCard extends StatelessWidget {
  const _CosmeticCard({
    required this.cosmetic,
    required this.isOwned,
    required this.isEquipped,
    required this.busy,
    required this.onBuy,
    required this.onEquip,
  });

  final CosmeticDefinition cosmetic;
  final bool isOwned, isEquipped, busy;
  final VoidCallback onBuy, onEquip;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        const Color(0xFF0D1230),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEquipped
              ? const Color(0xFF7C3AED)
              : isOwned
                  ? Colors.green.withAlpha(120)
                  : Colors.white12,
          width: isEquipped ? 2 : 1,
        ),
        boxShadow: isEquipped
            ? [const BoxShadow(color: Color(0x557C3AED), blurRadius: 8)]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Badges de estado
            if (isEquipped)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '✓ PUESTO',
                  style: TextStyle(
                    color:      Colors.white,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize:   8,
                  ),
                ),
              )
            else if (isOwned)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(60),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '✓ TUYO',
                  style: TextStyle(
                    color:      Colors.greenAccent,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize:   8,
                  ),
                ),
              )
            else
              const SizedBox(height: 14),

            // Emoji
            Text(cosmetic.emoji, style: const TextStyle(fontSize: 34)),

            // Nombre
            Text(
              cosmetic.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color:      Colors.white,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize:   10,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Precio
            if (!isOwned)
              Text(
                '🪙 ${cosmetic.price}',
                style: const TextStyle(
                  color:      Color(0xFFFFD600),
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize:   12,
                ),
              )
            else
              const SizedBox(height: 14),

            // Botón
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : (isOwned ? onEquip : onBuy),
                style: FilledButton.styleFrom(
                  backgroundColor: isEquipped
                      ? const Color(0xFF7C3AED)
                      : isOwned
                          ? Colors.green.shade700
                          : const Color(0xFFFFD600),
                  foregroundColor: isEquipped || isOwned ? Colors.white : Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize:   10,
                  ),
                ),
                child: Text(
                  isEquipped ? 'Equipado' : isOwned ? 'Equipar' : 'Comprar',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Diálogo de confirmación de compra
// ─────────────────────────────────────────────────────────────────────────────
class _BuyDialog extends StatelessWidget {
  const _BuyDialog({required this.cosmetic, required this.coins});
  final CosmeticDefinition cosmetic;
  final int coins;

  @override
  Widget build(BuildContext context) {
    final after = coins - cosmetic.price;
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1F3C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF7C3AED), width: 1),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(cosmetic.emoji, style: const TextStyle(fontSize: 52)),
          const SizedBox(height: 10),
          Text(
            '¿Comprar\n"${cosmetic.name}"?',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color:      Colors.white,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize:   16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            cosmetic.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color:      Colors.white54,
              fontFamily: 'Nunito',
              fontSize:   12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$coins 🪙',
                  style: const TextStyle(
                    color:      Color(0xFFFFD600),
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.bold,
                    fontSize:   14,
                  )),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded, color: Colors.white38, size: 16),
              ),
              Text('$after 🪙',
                  style: TextStyle(
                    color:      after >= 0 ? Colors.greenAccent : Colors.redAccent,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.bold,
                    fontSize:   14,
                  )),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar',
              style: TextStyle(color: Colors.white54, fontFamily: 'Nunito')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('¡Comprar!',
              style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
