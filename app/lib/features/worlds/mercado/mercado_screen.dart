import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/item.dart';
import '../../../data/repositories/wallet_repository.dart';
import '../../../shared/providers/demo_progress_provider.dart';
import '../../../shared/providers/item_provider.dart';
import '../../../shared/providers/profile_provider.dart';
import '../../../shared/providers/wallet_provider.dart';
import '../../../shared/providers/world_provider.dart';
import '../../../shared/widgets/screen_tutorial.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/widgets/coin_display.dart';
import '../../../shared/widgets/game_popup.dart';

// ─────────────────────────────────────────────────────────────────────────────
void showMercadoDialog(BuildContext context) {
  final size = MediaQuery.of(context).size;
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Mercado',
    barrierColor: Colors.black.withOpacity(0.75),
    transitionDuration: const Duration(milliseconds: 280),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
        child: FadeTransition(opacity: anim, child: child),
      );
    },
    pageBuilder: (ctx, _, __) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: size.width * 0.94,
          height: size.height * 0.90,
          child: const MercadoScreen(),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MercadoScreen — 3 pestañas: Mi Inventario | Mi Tienda | Explorar
// ─────────────────────────────────────────────────────────────────────────────
class MercadoScreen extends ConsumerStatefulWidget {
  const MercadoScreen({super.key});

  @override
  ConsumerState<MercadoScreen> createState() => _MercadoScreenState();
}

class _MercadoScreenState extends ConsumerState<MercadoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final worldId = ref.watch(currentWorldProvider);
    final coins = DemoStore.isActive
        ? ref.watch(demoProgressProvider).coins
        : (ref.watch(currentWalletProvider).valueOrNull?.totalCoins ?? 0);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A18),
      body: ScreenTutorial(
        tutorialKey: 'mercado_v2',
        steps: const [
          TutorialStep(
            title: '¡Mercado Galáctico! 🛒',
            body: 'Aquí tienes 3 secciones: ver lo que tienes, '
                'poner cosas a la venta, y explorar lo que venden otros jugadores.',
          ),
          TutorialStep(
            title: 'Tu Tienda Personal 🏪',
            body: 'Puedes poner hasta 10 artículos a la venta. '
                'Otros jugadores pueden comprártelos. ¡Pon un precio justo!',
          ),
          TutorialStep(
            title: 'Explorar el Mercado 🔍',
            body: 'Aquí ves lo que venden otros jugadores. '
                'Si encuentras algo que necesitas para un trabajo, ¡cómpralo aquí!',
          ),
        ],
        child: Row(
          children: [
            _MercadoSidebar(
              coins: coins,
              selectedTab: _tabCtrl.index,
              onBack: () => context.pop(),
              onSelectTab: (i) => _tabCtrl.animateTo(i),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  const _InventoryTab(),
                  _MyShopTab(coins: coins),
                  _ExploreTab(coins: coins, worldId: worldId),
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
// Sidebar oscura del Mercado
// ─────────────────────────────────────────────────────────────────────────────
class _MercadoSidebar extends StatelessWidget {
  const _MercadoSidebar({
    required this.coins,
    required this.selectedTab,
    required this.onBack,
    required this.onSelectTab,
  });
  final int coins;
  final int selectedTab;
  final VoidCallback onBack;
  final ValueChanged<int> onSelectTab;

  static const _tabs = [
    ('🎒', 'INVENTARIO'),
    ('🏪', 'MI TIENDA'),
    ('🔍', 'EXPLORAR'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D0A2A), Color(0xFF08061A)],
        ),
        border: Border(
          right: BorderSide(color: Color(0xFF2A1A5E), width: 1.5),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),

            // Botón volver
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.18),
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Título
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'MERCADO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  shadows: [
                    Shadow(
                      color: const Color(0xFFFFB300).withOpacity(0.60),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Coins pill
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.withOpacity(0.55)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AnimatedCoin(size: 14),
                    const SizedBox(width: 5),
                    Text(
                      '$coins',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            // Divider con label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      color: const Color(0xFF2A1A5E),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'SECCIONES',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: const Color(0xFF2A1A5E),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Nav items
            ..._tabs.asMap().entries.map((entry) {
              final i = entry.key;
              final (emoji, label) = entry.value;
              final isSelected = selectedTab == i;
              return _MercadoSidebarItem(
                emoji: emoji,
                label: label,
                isSelected: isSelected,
                onTap: () => onSelectTab(i),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _MercadoSidebarItem extends StatelessWidget {
  const _MercadoSidebarItem({
    required this.emoji,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String emoji;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF7B2FBE).withOpacity(0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? const Border(
                  left: BorderSide(color: Color(0xFF7B2FBE), width: 3),
                )
              : null,
        ),
        child: Row(
          children: [
            Text(emoji, style: TextStyle(fontSize: isSelected ? 16 : 14)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withOpacity(0.45),
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pestaña 1 — Mi Inventario
// ─────────────────────────────────────────────────────────────────────────────
class _InventoryTab extends ConsumerWidget {
  const _InventoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invAsync = ref.watch(inventoryProvider);
    return invAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF4FC3F7)),
      ),
      error: (_, __) => Center(
        child: Text(
          'Error al cargar inventario',
          style: TextStyle(color: Colors.white.withOpacity(0.65)),
        ),
      ),
      data: (stacks) {
        if (stacks.isEmpty) {
          return const _EmptyState(
            emoji: '🎒',
            title: 'Tu inventario está vacío',
            body: 'Compra materiales en la Tienda para llenar tu mochila. '
                '¡Los necesitarás para los Trabajos!',
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(AppSizes.md),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: AppSizes.sm,
            mainAxisSpacing: AppSizes.sm,
            childAspectRatio: 0.88,
          ),
          itemCount: stacks.length,
          itemBuilder: (ctx, i) {
            final s = stacks[i];
            return _InventoryCard(stack: s)
                .animate(delay: (50 * i).ms)
                .fadeIn(duration: 260.ms)
                .scale(
                  begin: const Offset(0.90, 0.90),
                  end: const Offset(1, 1),
                  curve: Curves.easeOut,
                );
          },
        );
      },
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({required this.stack});
  final InventoryStack stack;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B3E).withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                Text(stack.item.emoji, style: const TextStyle(fontSize: 36))
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .moveY(
                      begin: 0,
                      end: -3,
                      duration: 2200.ms,
                      curve: Curves.easeInOut,
                    ),
                if (stack.qty > 1)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '×${stack.qty}',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              stack.item.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pestaña 2 — Mi Tienda personal
// ─────────────────────────────────────────────────────────────────────────────
class _MyShopTab extends ConsumerStatefulWidget {
  const _MyShopTab({required this.coins});
  final int coins;

  @override
  ConsumerState<_MyShopTab> createState() => _MyShopTabState();
}

class _MyShopTabState extends ConsumerState<_MyShopTab> {
  bool _busy = false;

  Future<void> _showAddListingDialog() async {
    final invAsync = ref.read(inventoryProvider);
    final stacks = invAsync.valueOrNull ?? [];
    if (stacks.isEmpty) {
      _snack('Tu inventario está vacío. Compra algo en la Tienda primero.',
          Colors.orange.shade700);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => _AddListingDialog(stacks: stacks, onSubmit: _addListing),
    );
  }

  Future<void> _addListing({
    required String itemId,
    required int qty,
    required int price,
  }) async {
    setState(() => _busy = true);
    try {
      final profile = ref.read(currentProfileProvider).valueOrNull;
      final sellerName = profile?.displayName ?? 'Jugador';
      final repo = ref.read(itemRepositoryProvider);
      final ok = await repo.addListing(
        itemId: itemId,
        qty: qty,
        pricePerUnit: price,
        sellerName: sellerName,
      );
      if (!ok) {
        _snack('Ya tienes 10 artículos en venta. Quita uno primero.',
            Colors.orange.shade700);
      } else {
        ref.invalidate(myListingsProvider);
        ref.invalidate(inventoryProvider);
        _snack('¡Artículo publicado en tu tienda! 🏪', const Color(0xFF2E7D32));
      }
    } catch (e) {
      _snack('Error: $e', Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeListing(String listingId) async {
    setState(() => _busy = true);
    try {
      await ref.read(itemRepositoryProvider).removeListing(listingId);
      ref.invalidate(myListingsProvider);
      ref.invalidate(inventoryProvider);
      _snack('Artículo retirado del mercado.', Colors.blueGrey);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg, Color bg) =>
      showGamePopup(context, msg, accentColor: bg);

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(myListingsProvider);
    return listingsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF4FC3F7)),
      ),
      error: (_, __) => Center(
        child: Text('Error',
            style: TextStyle(color: Colors.white.withOpacity(0.65))),
      ),
      data: (listings) => Column(
        children: [
          // Sub-cabecera: contador + botón Vender
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '${listings.length} / 10 artículos en venta',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: (_busy || listings.length >= 10)
                      ? null
                      : _showAddListingDialog,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: (_busy || listings.length >= 10)
                          ? null
                          : const LinearGradient(
                              colors: [
                                Color(0xFFFF8C00),
                                Color(0xFFFFB300),
                              ],
                            ),
                      color: (_busy || listings.length >= 10)
                          ? Colors.white.withOpacity(0.08)
                          : null,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: (_busy || listings.length >= 10)
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.35),
                                blurRadius: 8,
                              )
                            ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 15,
                          color: (_busy || listings.length >= 10)
                              ? Colors.white.withOpacity(0.38)
                              : Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Vender',
                          style: TextStyle(
                            color: (_busy || listings.length >= 10)
                                ? Colors.white.withOpacity(0.38)
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista de listings
          Expanded(
            child: listings.isEmpty
                ? const _EmptyState(
                    emoji: '🏪',
                    title: 'Tu tienda está vacía',
                    body: 'Pulsa "Vender" para poner artículos a la venta. '
                        '¡Otros jugadores podrán comprártelos!',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSizes.md),
                    itemCount: listings.length,
                    itemBuilder: (ctx, i) {
                      final listing = listings[i];
                      return _ListingCard(
                        listing: listing,
                        onRemove: () => _removeListing(listing.id),
                      ).animate(delay: (60 * i).ms).fadeIn(duration: 260.ms);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({required this.listing, required this.onRemove});
  final PlayerListing listing;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final item = listing.item;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B3E).withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Text(item?.emoji ?? '❓', style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item?.name ?? listing.itemId,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '× ${listing.qty}  •  ',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.50),
                          fontSize: 11,
                        ),
                      ),
                      const AnimatedCoin(size: 11),
                      Text(
                        ' ${listing.pricePerUnit} c/u',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.50),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.redAccent.withOpacity(0.35),
                  ),
                ),
                child: const Icon(
                  Icons.remove_rounded,
                  color: Colors.redAccent,
                  size: 16,
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
// Pestaña 3 — Explorar tiendas de otros jugadores
// ─────────────────────────────────────────────────────────────────────────────
class _ExploreTab extends ConsumerStatefulWidget {
  const _ExploreTab({required this.coins, required this.worldId});
  final int coins;
  final String worldId;

  @override
  ConsumerState<_ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends ConsumerState<_ExploreTab> {
  bool _buying = false;
  bool _loading = true;
  List<PlayerListing> _listings = [];

  @override
  void initState() {
    super.initState();
    _loadListings();
  }

  Future<void> _loadListings() async {
    final items = await ref
        .read(itemRepositoryProvider)
        .getMarketListings(widget.worldId);
    if (mounted)
      setState(() {
        _listings = items;
        _loading = false;
      });
  }

  Future<void> _buyListing(PlayerListing listing) async {
    final total = listing.qty * listing.pricePerUnit;
    if (widget.coins < total) {
      _snack('Necesitas 🪙 $total. Solo tienes ${widget.coins}.',
          Colors.red.shade700);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _BuyMarketDialog(listing: listing, coins: widget.coins),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _buying = true);
    try {
      if (DemoStore.isActive) {
        final ok = ref.read(demoProgressProvider).spendCoins(total);
        if (!ok) {
          _snack('No tienes suficientes monedas 😔', Colors.red.shade700);
          return;
        }
      } else {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          final ok = await WalletRepository().spendCoins(userId, total);
          if (!ok) {
            _snack('No tienes suficientes monedas 😔', Colors.red.shade700);
            return;
          }
          ref.invalidate(currentWalletProvider);
        }
      }
      await ref
          .read(itemRepositoryProvider)
          .addToInventory(listing.itemId, listing.qty);
      ref.invalidate(inventoryProvider);
      _snack(
        '¡Compraste ${listing.item?.emoji ?? ''} ${listing.item?.name ?? ''} ×${listing.qty}!',
        const Color(0xFF2E7D32),
      );
    } catch (e) {
      _snack('Error: $e', Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  void _snack(String msg, Color bg) =>
      showGamePopup(context, msg, accentColor: bg);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4FC3F7)),
      );
    }
    if (_listings.isEmpty) {
      return const _EmptyState(
        emoji: '🔍',
        title: 'No hay artículos en el mercado',
        body: 'Vuelve más tarde o sé el primero en vender algo.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSizes.md),
      itemCount: _listings.length,
      itemBuilder: (ctx, i) {
        final listing = _listings[i];
        final total = listing.qty * listing.pricePerUnit;
        final canAfford = widget.coins >= total;
        return _MarketListingCard(
          listing: listing,
          canAfford: canAfford,
          busy: _buying,
          onBuy: () => _buyListing(listing),
        )
            .animate(delay: (60 * i).ms)
            .fadeIn(duration: 260.ms)
            .slideY(begin: 0.10, end: 0, curve: Curves.easeOut);
      },
    );
  }
}

class _MarketListingCard extends StatelessWidget {
  const _MarketListingCard({
    required this.listing,
    required this.canAfford,
    required this.busy,
    required this.onBuy,
  });
  final PlayerListing listing;
  final bool canAfford;
  final bool busy;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final item = listing.item;
    final total = listing.qty * listing.pricePerUnit;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B3E).withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: canAfford
              ? const Color(0xFFFFB300).withOpacity(0.30)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Text(item?.emoji ?? '❓', style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item?.name ?? listing.itemId,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '× ${listing.qty}  •  vendedor: ${listing.sellerName}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.48),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const AnimatedCoin(size: 12),
                      Text(
                        ' ${listing.pricePerUnit} c/u  •  Total: ',
                        style: TextStyle(
                          color: canAfford
                              ? const Color(0xFFFFB300)
                              : Colors.red.shade300,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const AnimatedCoin(size: 12),
                      Text(
                        ' $total',
                        style: TextStyle(
                          color: canAfford
                              ? const Color(0xFFFFB300)
                              : Colors.red.shade300,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: (canAfford && !busy) ? onBuy : null,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: (canAfford && !busy)
                      ? const LinearGradient(
                          colors: [
                            Color(0xFFFF8C00),
                            Color(0xFFFFB300),
                          ],
                        )
                      : null,
                  color: (canAfford && !busy)
                      ? null
                      : Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: (canAfford && !busy)
                      ? [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.35),
                            blurRadius: 8,
                          )
                        ]
                      : null,
                ),
                child: Text(
                  canAfford ? 'Comprar' : 'Sin fondos',
                  style: TextStyle(
                    color: (canAfford && !busy)
                        ? Colors.white
                        : Colors.white.withOpacity(0.35),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
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
// Diálogo — Agregar listing a Mi Tienda
// ─────────────────────────────────────────────────────────────────────────────
class _AddListingDialog extends StatefulWidget {
  const _AddListingDialog({required this.stacks, required this.onSubmit});
  final List<InventoryStack> stacks;
  final Future<void> Function({
    required String itemId,
    required int qty,
    required int price,
  }) onSubmit;

  @override
  State<_AddListingDialog> createState() => _AddListingDialogState();
}

class _AddListingDialogState extends State<_AddListingDialog> {
  late InventoryStack _selected;
  int _qty = 1;
  int _price = 10;

  @override
  void initState() {
    super.initState();
    _selected = widget.stacks.first;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF07101F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: const Color(0xFFFFB300).withOpacity(0.45),
          width: 1.5,
        ),
      ),
      title: const Row(
        children: [
          Text('🏪', style: TextStyle(fontSize: 22)),
          SizedBox(width: 8),
          Text(
            'Poner a la venta',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selector de ítem
          DropdownButtonFormField<InventoryStack>(
            value: _selected,
            dropdownColor: const Color(0xFF0D1B3E),
            decoration: InputDecoration(
              labelText: 'Artículo',
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.55)),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white.withOpacity(0.20)),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFFFFB300)),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            style: const TextStyle(color: Colors.white),
            items: widget.stacks
                .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text('${s.item.emoji} ${s.item.name} (×${s.qty})'),
                    ))
                .toList(),
            onChanged: (s) {
              if (s != null)
                setState(() {
                  _selected = s;
                  _qty = 1;
                });
            },
          ),
          const SizedBox(height: 12),

          // Cantidad
          _SpinRow(
            label: 'Cantidad:',
            value: _qty,
            onDec: _qty > 1 ? () => setState(() => _qty--) : null,
            onInc: _qty < _selected.qty ? () => setState(() => _qty++) : null,
          ),

          // Precio
          _SpinRow(
            label: 'Precio 🪙 c/u:',
            value: _price,
            valueColor: const Color(0xFFFFD600),
            onDec: _price > 5
                ? () => setState(() => _price = (_price - 5).clamp(1, 9999))
                : null,
            onInc: () => setState(() => _price = (_price + 5).clamp(1, 9999)),
          ),

          // Total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB300).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: const Color(0xFFFFB300).withOpacity(0.30)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Total: ',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 12,
                  ),
                ),
                const AnimatedCoin(size: 14),
                const SizedBox(width: 4),
                Text(
                  '${_qty * _price}',
                  style: const TextStyle(
                    color: Color(0xFFFFD600),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancelar',
            style: TextStyle(color: Colors.white.withOpacity(0.50)),
          ),
        ),
        GestureDetector(
          onTap: () async {
            Navigator.pop(context);
            await widget.onSubmit(
              itemId: _selected.item.id,
              qty: _qty,
              price: _price,
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF8C00), Color(0xFFFFB300)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '¡Publicar!',
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

// Fila de control +/- reutilizable
class _SpinRow extends StatelessWidget {
  const _SpinRow({
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
    required this.onDec,
    required this.onInc,
  });
  final String label;
  final int value;
  final Color valueColor;
  final VoidCallback? onDec;
  final VoidCallback? onInc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.65), fontSize: 13)),
          const Spacer(),
          IconButton(
            onPressed: onDec,
            icon: Icon(Icons.remove_circle,
                color: onDec != null
                    ? Colors.white54
                    : Colors.white.withOpacity(0.20)),
            iconSize: 22,
          ),
          Text(
            '$value',
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          IconButton(
            onPressed: onInc,
            icon: Icon(Icons.add_circle,
                color: onInc != null
                    ? Colors.white54
                    : Colors.white.withOpacity(0.20)),
            iconSize: 22,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Diálogo — Confirmar compra en Explorar
// ─────────────────────────────────────────────────────────────────────────────
class _BuyMarketDialog extends StatelessWidget {
  const _BuyMarketDialog({required this.listing, required this.coins});
  final PlayerListing listing;
  final int coins;

  @override
  Widget build(BuildContext context) {
    final item = listing.item;
    final total = listing.qty * listing.pricePerUnit;
    final after = coins - total;

    return AlertDialog(
      backgroundColor: const Color(0xFF07101F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: const Color(0xFFFFB300).withOpacity(0.45),
          width: 1.5,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(item?.emoji ?? '❓', style: const TextStyle(fontSize: 48))
              .animate()
              .scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1, 1),
                duration: 350.ms,
                curve: Curves.easeOutBack,
              ),
          const SizedBox(height: 10),
          Text(
            '¿Comprar ${item?.name ?? listing.itemId} × ${listing.qty}?',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Vendedor: ${listing.sellerName}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.50),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$coins',
                style: const TextStyle(
                  color: Color(0xFFFFD600),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              const AnimatedCoin(size: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded,
                    color: Colors.white.withOpacity(0.35), size: 16),
              ),
              Text(
                '$after',
                style: TextStyle(
                  color: after >= 0 ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              const AnimatedCoin(size: 14),
            ],
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
                colors: [Color(0xFFFF8C00), Color(0xFFFFB300)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '¡Comprar! 🛒',
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

// ─────────────────────────────────────────────────────────────────────────────
// Estado vacío reutilizable
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.emoji,
    required this.title,
    required this.body,
  });
  final String emoji, title, body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
