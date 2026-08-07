import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/cosmetic.dart';
import '../../../data/models/item.dart';
import '../../../shared/providers/cosmetic_provider.dart';
import '../../../shared/providers/item_provider.dart';
import '../../../shared/providers/blink_ambient_provider.dart';
import '../../../shared/providers/badge_provider.dart';
import '../../../data/models/badge.dart';
import '../../../shared/widgets/blink_avatar.dart';
import '../../../shared/widgets/blink_reaction.dart';
import '../../../shared/widgets/screen_background.dart';
import '../../../shared/widgets/game_card.dart';
import '../../../shared/widgets/game_popup.dart';
import '../../../shared/theme/game_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
void showVestidorDialog(BuildContext context) {
  final size = MediaQuery.of(context).size;
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Vestidor',
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
          child: const VestidorScreen(),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
class VestidorScreen extends ConsumerStatefulWidget {
  const VestidorScreen({super.key});

  @override
  ConsumerState<VestidorScreen> createState() => _VestidorScreenState();
}

class _VestidorScreenState extends ConsumerState<VestidorScreen> {
  CosmeticSlot _slot = CosmeticSlot.helmet;
  // null = mostrando un slot de cosmético; si no, pestaña especial activa
  String? _special;
  // Loadout temporal en memoria para el preview en tiempo real
  late Map<String, CosmeticDefinition?> _previewSlots;
  bool _initialized = false;
  bool _saving = false;
  final _blinkReaction = BlinkReactionController();

  @override
  void dispose() {
    _blinkReaction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loadoutAsync = ref.watch(equippedLoadoutProvider);
    final ownedAsync = ref.watch(ownedCosmeticsProvider);

    // Inicializar preview una vez con el loadout real
    if (!_initialized && loadoutAsync.valueOrNull != null) {
      _previewSlots = Map.from(loadoutAsync.value!.slots);
      _initialized = true;
    }

    final previewLoadout = EquippedLoadout(_initialized ? _previewSlots : {});
    final ownedAll = ownedAsync.valueOrNull ?? [];
    final slotItems = ownedAll.where((c) => c.slot == _slot).toList();

    return ScreenBackground(
      child: Row(
        children: [
          // ── Sidebar ──────────────────────────────────────────────────────
          _VestidorSidebar(
            selected: _slot,
            special: _special,
            onSelect: (s) => setState(() {
              _slot = s;
              _special = null;
            }),
            onSelectSpecial: (s) => setState(() => _special = s),
            onBack: () => Navigator.of(context).pop(),
          ),

          // ── Zona central: preview de Blink ───────────────────────────────
          _BlinkPreviewPanel(
            loadout: previewLoadout,
            saving: _saving,
            onSave: _saveLoadout,
            reaction: _blinkReaction,
          ),

          // ── Panel derecho ─────────────────────────────────────────────────
          Expanded(
            child: _special == 'inventory'
                ? const _InventoryPanel()
                : _special == 'badges'
                    ? const _BadgesPanel()
                    : _CosmeticsGrid(
                        slot: _slot,
                        items: slotItems,
                        previewLoadout: previewLoadout,
                        onEquip: _equip,
                        onUnequip: _unequip,
                      ),
          ),
        ],
      ),
    );
  }

  void _equip(CosmeticDefinition c) {
    setState(() => _previewSlots[c.slot.id] = c);
  }

  void _unequip(CosmeticSlot slot) {
    setState(() => _previewSlots[slot.id] = null);
  }

  Future<void> _saveLoadout() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final notifier = ref.read(cosmeticShopProvider.notifier);
      // Equipar los slots que cambiaron
      final liveLoadout = ref.read(equippedLoadoutProvider).valueOrNull ??
          EquippedLoadout.empty;
      var changed = false;
      for (final slot in CosmeticSlot.values) {
        final preview = _previewSlots[slot.id];
        final live = liveLoadout[slot];
        if (preview?.id != live?.id) {
          changed = true;
          if (preview != null) {
            await notifier.equip(preview.id);
          } else {
            await notifier.unequip(slot);
          }
        }
      }
      ref.invalidate(equippedLoadoutProvider);
      if (changed) ref.read(justChangedOutfitProvider.notifier).state = true;
      if (mounted) {
        _snack('¡Cambios guardados! ✨', const Color(0xFF2E7D32));
        _blinkReaction.react(BlinkMood.contento);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, Color bg) =>
      showGamePopup(context, msg, accentColor: bg);
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar
// ─────────────────────────────────────────────────────────────────────────────
class _VestidorSidebar extends StatelessWidget {
  const _VestidorSidebar({
    required this.selected,
    required this.special,
    required this.onSelect,
    required this.onSelectSpecial,
    required this.onBack,
  });
  final CosmeticSlot selected;
  final String? special;
  final ValueChanged<CosmeticSlot> onSelect;
  final ValueChanged<String> onSelectSpecial;
  final VoidCallback onBack;

  // Slots que se muestran en el vestidor
  static const _slots = [
    CosmeticSlot.helmet,
    CosmeticSlot.top,
    CosmeticSlot.bottom,
    CosmeticSlot.boots,
    CosmeticSlot.accesorios,
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
        border: Border(right: BorderSide(color: Color(0xFF2A1A5E), width: 1.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Color(0xFF2A1A5E), width: 1)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onBack,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 15),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Vestidor'.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Slots
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              children: [
                ..._slots.map((s) => _SidebarItem(
                      slot: s,
                      selected: special == null && selected == s,
                      onTap: () => onSelect(s),
                    )),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Divider(color: Color(0xFF2A1A5E), height: 1),
                ),
                _SidebarSpecialItem(
                  emoji: '🎒',
                  label: 'Inventario',
                  selected: special == 'inventory',
                  onTap: () => onSelectSpecial('inventory'),
                ),
                _SidebarSpecialItem(
                  emoji: '🏅',
                  label: 'Badges',
                  selected: special == 'badges',
                  onTap: () => onSelectSpecial('badges'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarSpecialItem extends StatelessWidget {
  const _SidebarSpecialItem({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF7B2FBE).withOpacity(0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(
              color: selected ? const Color(0xFF7B2FBE) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: selected ? Colors.white : GameTokens.textSecondary,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem(
      {required this.slot, required this.selected, required this.onTap});
  final CosmeticSlot slot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF7B2FBE).withOpacity(0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(
              color: selected ? const Color(0xFF7B2FBE) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(slot.defaultEmoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                slot.displayName.toUpperCase(),
                style: TextStyle(
                  color: selected ? Colors.white : GameTokens.textSecondary,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 13,
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
// Panel central: preview de Blink
// ─────────────────────────────────────────────────────────────────────────────
class _BlinkPreviewPanel extends StatelessWidget {
  const _BlinkPreviewPanel({
    required this.loadout,
    required this.saving,
    required this.onSave,
    required this.reaction,
  });
  final EquippedLoadout loadout;
  final bool saving;
  final VoidCallback onSave;
  final BlinkReactionController reaction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFF2A1A5E), width: 1.5)),
      ),
      child: Column(
        children: [
          // Título
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
            child: Text(
              'Preview'.toUpperCase(),
              style: TextStyle(
                color: GameTokens.textMuted,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
          ),
          // Blink
          Expanded(
            child: ClipRect(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: BlinkAvatar(
                    size: 160,
                    loadout: loadout,
                    bounce: true,
                    reaction: reaction,
                  ),
                ),
              ),
            ),
          ),
          // Botón guardar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: GestureDetector(
              onTap: saving ? null : onSave,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B2FBE), Color(0xFFAB47BC)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFAB47BC).withOpacity(0.40),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: saving
                    ? const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        '✨ Guardar look',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel de inventario
// ─────────────────────────────────────────────────────────────────────────────
class _InventoryPanel extends ConsumerWidget {
  const _InventoryPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(inventoryProvider);
    final stacks = inventoryAsync.valueOrNull ?? [];

    return Container(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Color(0xFF2A1A5E), width: 1)),
            ),
            child: Row(
              children: [
                const Text('🎒', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  'Mi inventario'.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: inventoryAsync.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF9575CD)))
                : stacks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🎒', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            Text(
                              'Tu inventario está vacío',
                              style: TextStyle(
                                  color: GameTokens.textMuted, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Compra o gana objetos en la tienda y misiones',
                              style: TextStyle(
                                  color: GameTokens.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: stacks.length,
                        itemBuilder: (_, i) => _InventoryCard(stack: stacks[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({required this.stack});
  final InventoryStack stack;

  @override
  Widget build(BuildContext context) {
    final item = stack.item;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1040), Color(0xFF110C30)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A1A5E)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 28),
            child: Center(
              child: item.imagePath != null
                  ? Image.asset(
                      'assets/items/${item.imagePath}',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Text(item.emoji,
                          style: const TextStyle(fontSize: 40)),
                    )
                  : Text(item.emoji, style: const TextStyle(fontSize: 40)),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 6,
            child: Text(
              item.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: GameTokens.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF7B2FBE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '×${stack.qty}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel de badges — catálogo completo, con estado bloqueado/desbloqueado
// ─────────────────────────────────────────────────────────────────────────────
class _BadgesPanel extends ConsumerWidget {
  const _BadgesPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defsAsync = ref.watch(badgeDefinitionsProvider);
    final earnedAsync = ref.watch(playerBadgesProvider);

    return Container(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Color(0xFF2A1A5E), width: 1)),
            ),
            child: Row(
              children: [
                const Text('🏅', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  'Badges'.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: defsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.white54),
              ),
              error: (_, __) => Center(
                child: Text(
                  'No se pudieron cargar las medallas',
                  style: TextStyle(color: GameTokens.textMuted, fontSize: 13),
                ),
              ),
              data: (defs) {
                if (defs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🏅', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(
                          'Próximamente',
                          style: TextStyle(
                              color: GameTokens.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }
                final earnedIds =
                    earnedAsync.asData?.value.map((b) => b.badgeId).toSet() ??
                        <String>{};
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: defs.length,
                  itemBuilder: (_, i) {
                    final def = defs[i];
                    final earned = earnedIds.contains(def.id);
                    return _BadgeCard(def: def, earned: earned);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.def, required this.earned});
  final BadgeDefinition def;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1A1140),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Opacity(
                opacity: earned ? 1.0 : 0.35,
                child: Text(def.emoji, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  def.name,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Text(
            def.description,
            style: TextStyle(color: GameTokens.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: earned ? const Color(0xFF241858) : const Color(0xFF150E33),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: earned
                ? const Color(0xFFFFC107).withOpacity(0.55)
                : const Color(0xFF2A1A5E),
            width: earned ? 1.4 : 1,
          ),
          boxShadow: earned
              ? [
                  BoxShadow(
                      color: const Color(0xFFFFC107).withOpacity(0.25),
                      blurRadius: 10)
                ]
              : null,
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: earned ? 1.0 : 0.25,
              child: Text(def.emoji, style: const TextStyle(fontSize: 32)),
            ),
            const SizedBox(height: 6),
            Text(
              def.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: earned ? Colors.white : GameTokens.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 10.5,
              ),
            ),
            if (!earned) ...[
              const SizedBox(height: 3),
              const Icon(Icons.lock, color: Colors.white24, size: 12),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grid de cosméticos
// ─────────────────────────────────────────────────────────────────────────────
class _CosmeticsGrid extends StatelessWidget {
  const _CosmeticsGrid({
    required this.slot,
    required this.items,
    required this.previewLoadout,
    required this.onEquip,
    required this.onUnequip,
  });
  final CosmeticSlot slot;
  final List<CosmeticDefinition> items;
  final EquippedLoadout previewLoadout;
  final ValueChanged<CosmeticDefinition> onEquip;
  final ValueChanged<CosmeticSlot> onUnequip;

  @override
  Widget build(BuildContext context) {
    final equipped = previewLoadout[slot];
    return Container(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Color(0xFF2A1A5E), width: 1)),
            ),
            child: Row(
              children: [
                Text(slot.defaultEmoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  slot.displayName.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                if (equipped != null)
                  GestureDetector(
                    onTap: () => onUnequip(slot),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.redAccent.withOpacity(0.60)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Quitar',
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Grid
          Expanded(
            child: items.isEmpty
                ? _EmptySlot(slot: slot)
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final c = items[i];
                      final isEquipped = equipped?.id == c.id;
                      return _CosmeticCard(
                        cosmetic: c,
                        isEquipped: isEquipped,
                        onTap: () =>
                            isEquipped ? onUnequip(c.slot) : onEquip(c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta de cosmético
// ─────────────────────────────────────────────────────────────────────────────
class _CosmeticCard extends StatelessWidget {
  const _CosmeticCard({
    required this.cosmetic,
    required this.isEquipped,
    required this.onTap,
  });
  final CosmeticDefinition cosmetic;
  final bool isEquipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GameCard(
        accentColor: GameTokens.purpleLight,
        backgroundColor:
            isEquipped ? const Color(0xFF4A1A8A) : const Color(0xFF1A1040),
        highlighted: isEquipped,
        borderRadius: 14,
        child: Stack(
          children: [
            // Imagen
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 28),
              child: Center(
                child: _CosmeticImage(cosmetic: cosmetic),
              ),
            ),
            // Nombre
            Positioned(
              left: 0,
              right: 0,
              bottom: 6,
              child: Text(
                cosmetic.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isEquipped ? Colors.white : GameTokens.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // Badge equipado
            if (isEquipped)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Color(0xFF7B2FBE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 11),
                ),
              ),
          ],
        ),
      ).animate(target: isEquipped ? 1 : 0).scale(
            begin: const Offset(1, 1),
            end: const Offset(1.03, 1.03),
            duration: 180.ms,
          ),
    );
  }
}

class _CosmeticImage extends StatelessWidget {
  const _CosmeticImage({required this.cosmetic});
  final CosmeticDefinition cosmetic;

  @override
  Widget build(BuildContext context) {
    // Prioridad: imagen de tienda > emoji
    if (cosmetic.assetPath != null) {
      return Image.asset(
        cosmetic.assetPath!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            Text(cosmetic.emoji, style: const TextStyle(fontSize: 40)),
      );
    }
    return Text(cosmetic.emoji, style: const TextStyle(fontSize: 40));
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.slot});
  final CosmeticSlot slot;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(slot.defaultEmoji, style: const TextStyle(fontSize: 48))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.08, 1.08),
                  duration: 1800.ms),
          const SizedBox(height: 12),
          Text(
            'No tienes ${slot.displayName.toLowerCase()} aún',
            style: TextStyle(color: GameTokens.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Visita la tienda o completa misiones',
            style: TextStyle(color: GameTokens.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
