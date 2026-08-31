import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/item.dart';
import '../../../shared/providers/item_provider.dart';
import '../../../shared/widgets/item_icon.dart';
import '../../../shared/theme/game_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Inventario a pantalla completa — diseño nuevo (cuadrícula grande de todos
// los objetos). Misma fuente de datos (inventoryProvider) que la pestaña de
// inventario dentro del Vestidor original, que sigue existiendo sin cambios.
// ─────────────────────────────────────────────────────────────────────────────
class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(inventoryProvider);
    final stacks = inventoryAsync.valueOrNull ?? [];

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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  _RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 12),
                  Text('INVENTARIO', style: GameText.title(size: 22)),
                ],
              ),
            ),
            Expanded(
              child: inventoryAsync.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: GameTokens.purpleLight))
                  : stacks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🎒', style: TextStyle(fontSize: 64)),
                              const SizedBox(height: 12),
                              Text('Tu inventario está vacío',
                                  style:
                                      GameText.body(color: GameTokens.textMuted)),
                              const SizedBox(height: 4),
                              Text(
                                'Compra o gana objetos en la tienda y misiones',
                                style: GameText.body(
                                    color: GameTokens.textMuted, size: 12),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(20),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: stacks.length,
                          itemBuilder: (_, i) => _InventoryCard(stack: stacks[i]),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A1A5E)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 32),
            child: Center(
              child: ItemIcon(item: item, size: 64),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: Text(
              item.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GameText.label(color: GameTokens.textSecondary, size: 11),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: GameTokens.purple,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('×${stack.qty}',
                  style: GameText.label(size: 11)),
            ),
          ),
        ],
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
