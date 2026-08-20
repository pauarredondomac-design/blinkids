import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/cosmetic.dart';
import '../../../data/models/item.dart';
import '../../../data/repositories/item_definitions_repository.dart';
import '../../../data/repositories/mission_tracker.dart';
import '../../../data/repositories/wallet_repository.dart';
import '../../../data/services/analytics_service.dart';
import '../../../shared/providers/badge_provider.dart';
import '../../../shared/providers/cosmetic_provider.dart';
import '../../../shared/providers/demo_progress_provider.dart';
import '../../../shared/providers/item_provider.dart';
import '../../../shared/providers/wallet_provider.dart';
import '../../../shared/providers/world_provider.dart';
import '../../../shared/widgets/screen_tutorial.dart';
import '../../../shared/widgets/return_to_mission_banner.dart';
import '../../../shared/widgets/activity_player.dart';
import '../misiones/misiones_screen.dart';
import '../../../shared/widgets/coin_display.dart';
import '../../../shared/widgets/screen_background.dart';
import '../../../shared/widgets/game_card.dart';
import '../../../shared/widgets/game_popup.dart';
import '../../../shared/widgets/blink_avatar.dart';
import '../../../shared/widgets/blink_reaction.dart';
import '../../../shared/widgets/tab_icon.dart';
import '../../../shared/widgets/modal_corners.dart';
import '../../../shared/widgets/badge_unlock_celebration.dart';
import '../../../shared/theme/game_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
Future<void> showTiendaDialog(BuildContext context) {
  final size = MediaQuery.of(context).size;
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tienda',
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
      insetPadding: const EdgeInsets.fromLTRB(10, 60, 10, 10),
      child: ModalCorners(
        onClose: () => Navigator.of(ctx).pop(),
        title: 'Tienda',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: size.width * 0.94,
            height: size.height * 0.85,
            child: const TiendaScreen(),
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
enum _TiendaCategory { todos, items, cosmeticos }

sealed class _ShopEntry {}

class _ItemEntry extends _ShopEntry {
  final Item item;
  _ItemEntry(this.item);
}

class _CosmeticEntry extends _ShopEntry {
  final CosmeticDefinition cosmetic;
  _CosmeticEntry(this.cosmetic);
}

// ─────────────────────────────────────────────────────────────────────────────
class TiendaScreen extends ConsumerStatefulWidget {
  const TiendaScreen({super.key});

  @override
  ConsumerState<TiendaScreen> createState() => _TiendaScreenState();
}

class _TiendaScreenState extends ConsumerState<TiendaScreen> {
  _TiendaCategory _category = _TiendaCategory.todos;
  bool _buying = false;
  List<Item>? _remoteItems;
  final _blinkReaction = BlinkReactionController();

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _blinkReaction.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final worldId = ref.read(currentWorldProvider);
    final items = await ItemDefinitionsRepository.getShopItemsForWorld(worldId);
    if (mounted) setState(() => _remoteItems = items);
  }

  // ── Comprar ítem ───────────────────────────────────────────────────────────
  Future<void> _buyItem(Item item, int coins) async {
    if (_buying) return;
    if (coins < item.shopPrice) {
      _snack('¡Necesitas ${item.shopPrice} 🪙! Solo tienes $coins.',
          Colors.red.shade700);
      return;
    }
    final qty = await showDialog<int>(
      context: context,
      builder: (_) => _ConfirmDialog(
        emoji: item.emoji,
        name: item.name,
        price: item.shopPrice,
        coins: coins,
        assetPath:
            item.imagePath != null ? 'assets/items/${item.imagePath}' : null,
        showQty: true,
      ),
    );
    if (qty == null || qty <= 0 || !mounted) return;
    final totalPrice = item.shopPrice * qty;
    if (coins < totalPrice) {
      _snack('No tienes suficientes monedas para $qty unidades 😔',
          Colors.red.shade700);
      return;
    }
    setState(() => _buying = true);
    try {
      if (DemoStore.isActive) {
        final spent = ref.read(demoProgressProvider).spendCoins(totalPrice);
        if (!spent) {
          _snack('No tienes suficientes monedas 😔', Colors.red.shade700);
          return;
        }
      } else {
        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid != null) {
          final spent = await WalletRepository().spendCoins(uid, totalPrice);
          if (!spent) {
            _snack('No tienes suficientes monedas 😔', Colors.red.shade700);
            return;
          }
          ref.invalidate(currentWalletProvider);
        }
      }
      await ref.read(itemRepositoryProvider).addToInventory(item.id, qty);
      await MissionTracker().recordPurchase();
      ref.invalidate(inventoryProvider);
      AnalyticsService.instance.itemPurchased(item.id, totalPrice);
      if (mounted) {
        _blinkReaction.react(BlinkMood.celebrando);
        _snack('¡Compraste ${qty}x ${item.name}!', const Color(0xFF2E7D32),
            leading: BlinkAvatar(size: 60, reaction: _blinkReaction));
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  // ── Comprar cosmético ──────────────────────────────────────────────────────
  Future<void> _buyCostume(CosmeticDefinition c, int coins) async {
    if (_buying) return;
    if (DemoStore.isActive) {
      _snack('Los cosméticos no están disponibles en modo demo.',
          Colors.orange.shade700);
      return;
    }
    if (coins < c.price) {
      _snack(
          '¡Necesitas ${c.price} 🪙! Solo tienes $coins.', Colors.red.shade700);
      return;
    }
    final qty = await showDialog<int>(
      context: context,
      builder: (_) => _ConfirmDialog(
        emoji: c.emoji,
        name: c.name,
        price: c.price,
        coins: coins,
        assetPath: c.assetPath,
        subtitle: c.slot.displayName,
      ),
    );
    if (qty == null || qty <= 0 || !mounted) return;
    setState(() => _buying = true);
    try {
      await ref.read(cosmeticShopProvider.notifier).buy(c.id);
      ref.invalidate(currentWalletProvider);
      AnalyticsService.instance.cosmeticPurchased(c.id, c.price);
      final newBadges = await ref.read(badgeCheckerProvider.notifier).check();
      if (mounted) {
        _blinkReaction.react(BlinkMood.celebrando);
        _snack('¡Compraste ${c.name}!', const Color(0xFF2E7D32),
            leading: BlinkAvatar(size: 60, reaction: _blinkReaction));
        showBadgeUnlockCelebrations(context, ref, newBadges);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  void _snack(String msg, Color bg, {Widget? leading}) =>
      showGamePopup(context, msg, accentColor: bg, leading: leading);

  @override
  Widget build(BuildContext context) {
    final worldId = ref.watch(currentWorldProvider);
    final coins = DemoStore.isActive
        ? ref.watch(demoProgressProvider).coins
        : (ref.watch(currentWalletProvider).valueOrNull?.totalCoins ?? 0);
    final items = _remoteItems ?? shopItemsForWorld(worldId);
    final cosmetics = ref.watch(cosmeticsInShopProvider).valueOrNull ?? [];

    final entries = <_ShopEntry>[
      if (_category != _TiendaCategory.cosmeticos) ...items.map(_ItemEntry.new),
      if (_category != _TiendaCategory.items)
        ...cosmetics.map(_CosmeticEntry.new),
    ];

    return ScreenTutorial(
      tutorialKey: 'tienda_v2',
      steps: const [
        TutorialStep(
          title: '¡La Tienda Espacial! 🔮',
          body: 'Aquí puedes comprar materiales y cosméticos con tus monedas. '
              'Usa la barra izquierda para filtrar lo que buscas.',
        ),
        TutorialStep(
          title: 'Filtra lo que buscas 🎯',
          body: 'Ítems = materiales para crafting. '
              'Cosméticos = ropa y accesorios para Blink.',
        ),
      ],
      onReady: () {
        if (mounted) {
          maybeShowDailyBuildingQuestion(
            context,
            ref,
            buildingSlug: 'tienda',
            accentColor: const Color(0xFFAB47BC),
          );
        }
      },
      child: Stack(children: [
        ScreenBackground(
          child: Row(
        children: [
          // ── Sidebar ────────────────────────────────────────────────────────
          _Sidebar(
            coins: coins,
            category: _category,
            onSelect: (c) => setState(() => _category = c),
          ),

          // ── Grid principal ─────────────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                Container(
                  color: Colors.transparent,
                  child: entries.isEmpty
                      ? const Center(
                          child: Text(
                            '😔 No hay artículos disponibles.',
                            style: TextStyle(
                                color: GameTokens.textMuted, fontSize: 14),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.72,
                          ),
                          itemCount: entries.length,
                          itemBuilder: (ctx, i) {
                            final e = entries[i];
                            return switch (e) {
                              _ItemEntry(item: final it) => _ShopCard(
                                  key: ValueKey(it.id),
                                  emoji: it.emoji,
                                  name: it.name,
                                  price: it.shopPrice,
                                  coins: coins,
                                  busy: _buying,
                                  assetPath: it.imagePath != null
                                      ? 'assets/items/${it.imagePath}'
                                      : null,
                                  badge: it.isRare ? '✨ MISIÓN' : null,
                                  badgeColor: const Color(0xFFFFD600),
                                  accentColor: const Color(0xFF7B2FBE),
                                  onBuy: () => _buyItem(it, coins),
                                )
                                    .animate(delay: (40 * i).ms)
                                    .fadeIn(duration: 220.ms)
                                    .moveY(begin: 12, end: 0),
                              _CosmeticEntry(cosmetic: final c) => _ShopCard(
                                  key: ValueKey(c.id),
                                  emoji: c.emoji,
                                  name: c.name,
                                  price: c.price,
                                  coins: coins,
                                  busy: _buying,
                                  assetPath: c.assetPath,
                                  badge: c.slot.displayName.toUpperCase(),
                                  badgeColor: const Color(0xFF00BCD4),
                                  accentColor: const Color(0xFF006064),
                                  iconScale: 1.35,
                                  onBuy: () => _buyCostume(c, coins),
                                )
                                    .animate(delay: (40 * i).ms)
                                    .fadeIn(duration: 220.ms)
                                    .moveY(begin: 12, end: 0),
                            };
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      )),
        ReturnToMissionBanner(
          onReturn: () {
            Navigator.of(context).pop();
            showMisionesDialog(context);
          },
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar
// ─────────────────────────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.coins,
    required this.category,
    required this.onSelect,
  });
  final int coins;
  final _TiendaCategory category;
  final ValueChanged<_TiendaCategory> onSelect;

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
        border: Border(right: BorderSide(color: Color(0xFF2A1A5E), width: 1.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Monedas
          Container(
            margin: const EdgeInsets.fromLTRB(12, 16, 12, 6),
            child: CoinChip(coins: coins),
          ),

          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Categorías'.toUpperCase(),
              style: const TextStyle(
                color: GameTokens.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Categorías
          _SidebarItem(
            icon: '🏪',
            iconName: 'tienda_todos',
            label: 'Todos',
            active: category == _TiendaCategory.todos,
            onTap: () => onSelect(_TiendaCategory.todos),
          ),
          _SidebarItem(
            icon: '⚙️',
            iconName: 'tienda_items',
            label: 'Ítems',
            active: category == _TiendaCategory.items,
            onTap: () => onSelect(_TiendaCategory.items),
          ),
          _SidebarItem(
            icon: '✨',
            iconName: 'tienda_cosmeticos',
            label: 'Cosméticos',
            active: category == _TiendaCategory.cosmeticos,
            onTap: () => onSelect(_TiendaCategory.cosmeticos),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.iconName,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String icon;
  final String iconName;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF7B2FBE).withOpacity(0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: active ? const Color(0xFFCE93D8) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            TabIcon(name: iconName, emoji: icon, size: 32),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: active ? Colors.white : GameTokens.textSecondary,
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ShopCard — imagen llena la tarjeta, texto superpuesto al fondo
// ─────────────────────────────────────────────────────────────────────────────
class _ShopCard extends StatefulWidget {
  const _ShopCard({
    super.key,
    required this.emoji,
    required this.name,
    required this.price,
    required this.coins,
    required this.busy,
    this.assetPath,
    this.badge,
    this.badgeColor,
    this.accentColor = const Color(0xFF7B2FBE),
    this.iconScale = 1.0,
    required this.onBuy,
  });

  final String emoji;
  final String name;
  final int price;
  final int coins;
  final bool busy;
  final String? assetPath;
  final String? badge;
  final Color? badgeColor;
  final Color accentColor;
  // Los PNG de cosméticos traen más margen transparente propio que los de
  // ítems, así que se ven más chicos con el mismo BoxFit.contain — este
  // multiplicador solo se usa para cosméticos, los ítems quedan intactos.
  final double iconScale;
  final VoidCallback onBuy;

  @override
  State<_ShopCard> createState() => _ShopCardState();
}

class _ShopCardState extends State<_ShopCard> {
  bool _hovered = false;

  bool get _canAfford => widget.coins >= widget.price;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _hovered = true),
      onTapUp: (_) => setState(() => _hovered = false),
      onTapCancel: () => setState(() => _hovered = false),
      onTap: (_canAfford && !widget.busy) ? widget.onBuy : null,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 150),
        scale: _hovered ? 0.96 : 1.0,
        child: GameCard(
          accentColor: widget.accentColor,
          highlighted: _hovered,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Panel "juguete" del ícono ─────────────────────────────────
              // Fondo suave y redondeado detrás del ícono en vez de imagen a
              // sangre completa — hace que íconos realistas/metálicos (llave,
              // martillo, etc.) se sientan menos "de adulto" mientras no
              // llegan sus reemplazos ilustrados. El PNG queda como placeholder.
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 58),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(18),
                    border:
                        Border.all(color: widget.accentColor.withOpacity(0.30)),
                  ),
                  child: widget.assetPath != null
                      ? Transform.scale(
                          scale: widget.iconScale,
                          child: Image.asset(
                            widget.assetPath!,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            errorBuilder: (_, __, ___) => _EmojiBackground(
                                emoji: widget.emoji, color: widget.accentColor),
                          ),
                        )
                      : _EmojiBackground(
                          emoji: widget.emoji, color: widget.accentColor),
                ),
              ),

              // ── Gradiente inferior ───────────────────────────────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 90,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.92),
                        Colors.black.withOpacity(0.70),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.55, 1],
                    ),
                  ),
                ),
              ),

              // ── Badge (slot / misión) ────────────────────────────────────
              if (widget.badge != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color:
                          (widget.badgeColor ?? Colors.amber).withOpacity(0.92),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.badge!,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 7,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

              // ── Nombre + precio ──────────────────────────────────────────
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _canAfford
                                ? widget.accentColor
                                : Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const AnimatedCoin(size: 11),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.price}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!_canAfford) ...[
                          const SizedBox(width: 6),
                          const Text(
                            'Sin fondos',
                            style: TextStyle(
                              color: Color(0xFFFF8A5C),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmojiBackground extends StatelessWidget {
  const _EmojiBackground({required this.emoji, required this.color});
  final String emoji;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withOpacity(0.12),
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 52))
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .moveY(
                begin: 0, end: -4, duration: 2200.ms, curve: Curves.easeInOut),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Diálogo de confirmación unificado (retorna int qty o null si cancela)
// ─────────────────────────────────────────────────────────────────────────────
class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({
    required this.emoji,
    required this.name,
    required this.price,
    required this.coins,
    this.assetPath,
    this.subtitle,
    this.showQty = false,
  });
  final String emoji;
  final String name;
  final int price;
  final int coins;
  final String? assetPath;
  final String? subtitle;
  final bool showQty;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    final total = widget.price * _qty;
    final after = widget.coins - total;
    final canAfford = after >= 0;

    return AlertDialog(
      backgroundColor: const Color(0xFF0D0A2A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
            color: const Color(0xFFCE93D8).withOpacity(0.45), width: 1.5),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Imagen o emoji
          if (widget.assetPath != null)
            Image.asset(
              widget.assetPath!,
              width: 80,
              height: 80,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Text(widget.emoji, style: const TextStyle(fontSize: 56)),
            ).animate().scale(
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(1, 1),
                  duration: 300.ms,
                  curve: Curves.easeOutBack,
                )
          else
            Text(widget.emoji, style: const TextStyle(fontSize: 56))
                .animate()
                .scale(
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(1, 1),
                  duration: 300.ms,
                  curve: Curves.easeOutBack,
                ),
          const SizedBox(height: 10),
          Text(
            '¿Comprar "${widget.name}"?',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.subtitle!,
              style: TextStyle(
                  color: const Color(0xFF4FC3F7).withOpacity(0.80),
                  fontSize: 12),
            ),
          ],
          // ── Selector de cantidad (solo ítems) ──────────────────────────────
          if (widget.showQty) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _QtyButton(
                  icon: Icons.remove,
                  onTap: _qty > 1 ? () => setState(() => _qty--) : null,
                ),
                const SizedBox(width: 16),
                Text(
                  '$_qty',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(width: 16),
                _QtyButton(
                  icon: Icons.add,
                  onTap: widget.coins >= widget.price * (_qty + 1)
                      ? () => setState(() => _qty++)
                      : null,
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          // ── Balance ────────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${widget.coins}',
                  style: const TextStyle(
                      color: Color(0xFFFFD600),
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              const SizedBox(width: 4),
              const AnimatedCoin(size: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded,
                    color: Colors.white.withOpacity(0.35), size: 16),
              ),
              Text('$after',
                  style: TextStyle(
                    color: canAfford ? Colors.greenAccent : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  )),
              const SizedBox(width: 4),
              const AnimatedCoin(size: 14),
            ],
          ),
          if (widget.showQty && _qty > 1) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Total: $total ',
                  style: const TextStyle(
                      color: GameTokens.textSecondary, fontSize: 11),
                ),
                const AnimatedCoin(size: 11),
                Text(
                  ' (${widget.price} × $_qty)',
                  style: const TextStyle(
                      color: GameTokens.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Text(
            widget.assetPath != null && widget.assetPath!.contains('cosmeticos')
                ? 'Se añadirá a tu guardarropa.'
                : 'Se guardará en tu inventario.',
            style: const TextStyle(color: GameTokens.textMuted, fontSize: 11),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancelar',
              style: TextStyle(color: GameTokens.textSecondary)),
        ),
        GestureDetector(
          onTap: canAfford ? () => Navigator.pop(context, _qty) : null,
          child: Opacity(
            opacity: canAfford ? 1.0 : 0.4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF7B2FBE), Color(0xFFAB47BC)]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFFAB47BC).withOpacity(0.40),
                      blurRadius: 10),
                ],
              ),
              child: const Text(
                '¡Comprar! 🔮',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: active ? 1.0 : 0.3,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF7B2FBE), width: 2),
            color: active
                ? const Color(0xFF7B2FBE).withOpacity(0.20)
                : Colors.transparent,
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
