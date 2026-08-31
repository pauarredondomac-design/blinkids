import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/cosmetic.dart';
import '../../../data/services/analytics_service.dart';
import '../../../shared/providers/cosmetic_provider.dart';
import '../../../shared/providers/blink_ambient_provider.dart';
import '../../../shared/widgets/blink_avatar.dart';
import '../../../shared/widgets/blink_reaction.dart';
import '../../../shared/widgets/blink_face_popup.dart';
import '../../../shared/widgets/tab_icon.dart';
import '../../../shared/widgets/game_popup.dart';
import '../../../shared/theme/game_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Vestidor a pantalla completa — diseño nuevo (Blink centrado, categorías en
// una fila inferior, objetos en una franja horizontal debajo). Reusa los
// mismos providers y la misma lógica de equipar/guardar que el Vestidor
// original (diálogo con sidebar), que sigue existiendo sin cambios para
// quien lo abra desde otras partes de la app.
// ─────────────────────────────────────────────────────────────────────────────
class WardrobeScreen extends ConsumerStatefulWidget {
  const WardrobeScreen({super.key});

  @override
  ConsumerState<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends ConsumerState<WardrobeScreen> {
  CosmeticSlot _slot = CosmeticSlot.helmet;
  late Map<String, CosmeticDefinition?> _previewSlots;
  bool _initialized = false;
  bool _saving = false;
  final _blinkReaction = BlinkReactionController();

  static const _slots = [
    CosmeticSlot.helmet,
    CosmeticSlot.top,
    CosmeticSlot.bottom,
    CosmeticSlot.boots,
    CosmeticSlot.accesorios,
  ];

  @override
  void dispose() {
    _blinkReaction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loadoutAsync = ref.watch(equippedLoadoutProvider);
    final ownedAsync = ref.watch(ownedCosmeticsProvider);

    if (!_initialized && loadoutAsync.valueOrNull != null) {
      _previewSlots = Map.from(loadoutAsync.value!.slots);
      _initialized = true;
    }

    final previewLoadout = EquippedLoadout(_initialized ? _previewSlots : {});
    final ownedAll = ownedAsync.valueOrNull ?? [];
    final slotItems = ownedAll.where((c) => c.slot == _slot).toList();
    final equippedInSlot = previewLoadout[_slot];

    return Scaffold(
      backgroundColor: GameTokens.bgDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/worlds/space/mi_nave_fondo.png',
              fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.45)),
          SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 12),
                  Text('VESTIDOR', style: GameText.title(size: 22)),
                ],
              ),
            ),
            // Diseño de 3 columnas: sidebar de categorías / Blink / grid de
            // objetos. La grid usa MaxCrossAxisExtent (no un número fijo de
            // columnas) para que quepan solas las columnas que alcancen en
            // cualquier tamaño de pantalla.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 76,
                      child: ListView(
                        children: _slots
                            .map((s) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _CategoryButton(
                                    slot: s,
                                    selected: s == _slot,
                                    onTap: () => setState(() => _slot = s),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: LayoutBuilder(builder: (context, c) {
                        // Blink parado es ~1.8x más alto que ancho (ver
                        // _AssembledBlink) — el `size` que le pasamos a
                        // BlinkAvatar es su ANCHO, así que lo calculamos a
                        // partir del alto real disponible (menos el botón
                        // de abajo) para que el cuerpo completo quepa sin
                        // overflow, en vez de un número fijo.
                        const blinkAspect = 1.8;
                        const buttonSpace = 66.0;
                        final availableForBlink = c.maxHeight - buttonSpace;
                        final blinkSize =
                            (availableForBlink / blinkAspect).clamp(80.0, 260.0);
                        return Column(
                          children: [
                            Expanded(
                              child: Center(
                                child: BlinkAvatar(
                                  size: blinkSize,
                                  loadout: previewLoadout,
                                  bounce: true,
                                  reaction: _blinkReaction,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _SaveButton(saving: _saving, onTap: _saveLoadout),
                          ],
                        );
                      }),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: slotItems.isEmpty
                          ? Center(
                              child: Text(
                                'Sin objetos de este tipo todavía',
                                style: GameText.body(
                                    color: GameTokens.textMuted, size: 13),
                              ),
                            )
                          : GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 110,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.85,
                              ),
                              itemCount: slotItems.length,
                              itemBuilder: (_, i) {
                                final c = slotItems[i];
                                final isEquipped = equippedInSlot?.id == c.id;
                                return _WardrobeItemCard(
                                  cosmetic: c,
                                  isEquipped: isEquipped,
                                  onTap: () => isEquipped
                                      ? _unequip(c.slot)
                                      : _equip(c),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
          ),
        ],
      ),
    );
  }

  void _equip(CosmeticDefinition c) =>
      setState(() => _previewSlots[c.slot.id] = c);

  void _unequip(CosmeticSlot slot) =>
      setState(() => _previewSlots[slot.id] = null);

  Future<void> _saveLoadout() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final notifier = ref.read(cosmeticShopProvider.notifier);
      final liveLoadout =
          ref.read(equippedLoadoutProvider).valueOrNull ?? EquippedLoadout.empty;
      var changed = false;
      for (final slot in CosmeticSlot.values) {
        final preview = _previewSlots[slot.id];
        final live = liveLoadout[slot];
        if (preview?.id != live?.id) {
          changed = true;
          if (preview != null) {
            await notifier.equip(preview.id);
            AnalyticsService.instance.cosmeticEquipped(preview.id, slot.id);
          } else {
            await notifier.unequip(slot);
          }
        }
      }
      ref.invalidate(equippedLoadoutProvider);
      if (changed) ref.read(justChangedOutfitProvider.notifier).state = true;
      if (mounted) {
        if (changed) {
          await showBlinkFacePopup(
            context,
            helmetAssetPath:
                _previewSlots[CosmeticSlot.helmet.id]?.equippedAssetPath,
            mood: BlinkMood.contento,
          );
        } else {
          showGamePopup(context, 'Sin cambios que guardar.',
              accentColor: const Color(0xFF2E7D32));
        }
      }
    } catch (e) {
      if (mounted) {
        showGamePopup(context, 'Error: $e', accentColor: Colors.red.shade700);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    required this.slot,
    required this.selected,
    required this.onTap,
  });
  final CosmeticSlot slot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 64,
          decoration: BoxDecoration(
            color: selected
                ? GameTokens.purple.withOpacity(0.30)
                : GameTokens.bgPanel.withOpacity(0.70),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? GameTokens.purple : Colors.white24,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TabIcon(
                  name: 'slot_${slot.name}', emoji: slot.defaultEmoji, size: 30),
              const SizedBox(height: 4),
              Text(
                slot.displayName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GameText.label(
                  color: selected ? Colors.white : GameTokens.textMuted,
                  size: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WardrobeItemCard extends StatelessWidget {
  const _WardrobeItemCard({
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
      child: Container(
        width: 92,
        decoration: BoxDecoration(
          color: isEquipped
              ? GameTokens.purple.withOpacity(0.35)
              : GameTokens.bgPanel.withOpacity(0.75),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isEquipped ? GameTokens.purpleLight : Colors.white24,
            width: isEquipped ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 22),
              child: Center(
                child: cosmetic.assetPath != null
                    ? Image.asset(
                        cosmetic.assetPath!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Text(cosmetic.emoji,
                            style: const TextStyle(fontSize: 34)),
                      )
                    : Text(cosmetic.emoji,
                        style: const TextStyle(fontSize: 34)),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 5,
              child: Text(
                isEquipped ? 'Puesto' : cosmetic.name,
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
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.saving, required this.onTap});
  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: saving ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7B2FBE), Color(0xFFAB47BC)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: GameTokens.glow(GameTokens.purpleLight),
        ),
        child: saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text('✨ Guardar look', style: GameText.button(size: 14)),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: GameTokens.bgPanel.withOpacity(0.85),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
