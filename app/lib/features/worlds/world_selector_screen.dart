import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/world.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../shared/providers/wallet_provider.dart';
import '../../shared/providers/world_provider.dart';
import '../../shared/widgets/coin_display.dart';
import '../../shared/widgets/game_popup.dart';
import '../../shared/widgets/modal_corners.dart';

void showWorldSelectorDialog(BuildContext context, String currentWorldId) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cambiar mundo',
    barrierColor: Colors.black.withOpacity(0.75),
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
        child: FadeTransition(opacity: anim, child: child),
      );
    },
    pageBuilder: (ctx, _, __) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: WorldSelectorScreen(currentWorldId: currentWorldId),
    ),
  );
}

class WorldSelectorScreen extends ConsumerStatefulWidget {
  const WorldSelectorScreen({super.key, this.currentWorldId = 'space'});
  final String currentWorldId;

  @override
  ConsumerState<WorldSelectorScreen> createState() =>
      _WorldSelectorScreenState();
}

const _kWorldsPerPage = 3;

List<List<World>> _chunkWorlds() {
  final groups = <List<World>>[];
  for (var i = 0; i < allWorlds.length; i += _kWorldsPerPage) {
    groups.add(
        allWorlds.sublist(i, (i + _kWorldsPerPage).clamp(0, allWorlds.length)));
  }
  return groups;
}

class _WorldSelectorScreenState extends ConsumerState<WorldSelectorScreen> {
  bool _busy = false;
  late final PageController _pageCtrl;
  late final List<List<World>> _groups;

  @override
  void initState() {
    super.initState();
    _groups = _chunkWorlds();
    final worldIndex =
        allWorlds.indexWhere((w) => w.id == widget.currentWorldId);
    final initialPage = worldIndex < 0 ? 0 : worldIndex ~/ _kWorldsPerPage;
    _pageCtrl = PageController(initialPage: initialPage);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _handlePurchase(World world) async {
    final coins = ref.read(currentWalletProvider).valueOrNull?.totalCoins ?? 0;
    if (coins < world.unlockCost) {
      _showSnack('Necesitas ${world.unlockCost} monedas. Solo tienes $coins.',
          Colors.red.shade700);
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _PurchaseDialog(world: world, currentCoins: coins),
    );
    if (confirm != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await WalletRepository().purchaseWorld(world.id);
      ref.invalidate(unlockedWorldsProvider);
      ref.invalidate(currentWalletProvider);
      if (mounted) _showSnack('${world.name} desbloqueado', world.accentColor);
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        _showSnack(
          msg.contains('insuficiente')
              ? 'No tienes suficientes monedas'
              : msg.contains('ya está desbloqueado')
                  ? 'Ya tienes este mundo'
                  : 'Error al comprar. Intenta de nuevo.',
          Colors.red.shade700,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String msg, Color bg) =>
      showGamePopup(context, msg, accentColor: bg);

  @override
  Widget build(BuildContext context) {
    final unlockedAsync = ref.watch(unlockedWorldsProvider);
    final walletAsync = ref.watch(currentWalletProvider);
    final coins = walletAsync.valueOrNull?.totalCoins ?? 0;
    final unlocked = unlockedAsync.valueOrNull ?? ['space'];
    final unlockedCount =
        allWorlds.where((w) => w.isFree || unlocked.contains(w.id)).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 60, 12, 12),
        child: ModalCorners(
        onClose: () => context.pop(),
        title: 'Selector de Mundos',
        child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0A20), Color(0xFF12124A), Color(0xFF080E1F)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$unlockedCount / ${allWorlds.length} desbloqueados',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ),
                    CoinDisplay(coins: coins),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                height: 1,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white24,
                      Colors.transparent
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // ── PageView deslizable (3 tarjetas por página) ──────────
              Expanded(
                child: PageView.builder(
                  controller: _pageCtrl,
                  itemCount: _groups.length,
                  itemBuilder: (ctx, pageIndex) {
                    final group = _groups[pageIndex];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: ClipRect(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final world in group) ...[
                            if (world != group.first) const SizedBox(width: 8),
                            Expanded(
                              child: _WorldCard(
                                world: world,
                                isUnlocked:
                                    world.isFree || unlocked.contains(world.id),
                                isCurrent: world.id == widget.currentWorldId,
                                canAfford: coins >= world.unlockCost,
                                busy: _busy,
                                onEnter: () => context.go(world.route),
                                onBuy: () => _handlePurchase(world),
                              ),
                            ),
                          ],
                        ],
                      ),
                      ),
                    );
                  },
                ),
              ),

              // ── Dots de página ───────────────────────────────────────
              if (_groups.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14, top: 6),
                  child: _PageDots(
                    count: _groups.length,
                    controller: _pageCtrl,
                  ),
                ),
            ],
          ),
        ),
        ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta de mundo
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

  final World world;
  final bool isUnlocked;
  final bool isCurrent;
  final bool canAfford;
  final bool busy;
  final VoidCallback onEnter;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCurrent ? Colors.white : world.accentColor.withAlpha(140),
          width: isCurrent ? 3 : 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Fondo del mapa del mundo ──────────────────────
            if (world.backgroundImagePath != null)
              Image.asset(
                world.backgroundImagePath!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: world.accentColor.withAlpha(60)),
              )
            else
              Container(color: world.accentColor.withAlpha(60)),

            // ── Velo oscuro para legibilidad ──────────────────
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(80),
                    Colors.black.withAlpha(160)
                  ],
                ),
              ),
            ),

            // ── Contenido ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final side =
                            constraints.maxWidth < constraints.maxHeight
                                ? constraints.maxWidth
                                : constraints.maxHeight;
                        return Center(
                          child: SizedBox(
                            width: side,
                            height: side,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: _WorldImage(
                                  world: world, isUnlocked: isUnlocked),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildStatus(),
                  const SizedBox(height: 6),
                  Text(
                    world.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: world.comingSoon ? Colors.white54 : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
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

  Widget _buildStatus() {
    if (world.comingSoon) {
      return const _Pill(
          label: 'Próximamente', bg: Colors.white24, fg: Colors.white70);
    }
    if (isUnlocked) {
      if (isCurrent) {
        return _Pill(label: 'Aquí', bg: Colors.white, fg: world.accentColor);
      }
      return _Pill(
        label: 'Entrar',
        bg: Colors.white,
        fg: world.accentColor,
        onTap: busy ? null : onEnter,
      );
    }
    return _Pill(
      label: '${world.unlockCost} monedas',
      bg: canAfford ? Colors.white : Colors.white24,
      fg: canAfford ? world.accentColor : Colors.white38,
      onTap: (busy || !canAfford) ? null : onBuy,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Imagen del mundo con fallback
// ─────────────────────────────────────────────────────────────────────────────
class _WorldImage extends StatelessWidget {
  const _WorldImage({required this.world, required this.isUnlocked});
  final World world;
  final bool isUnlocked;

  @override
  Widget build(BuildContext context) {
    final path = isUnlocked
        ? (world.unlockedImagePath ?? world.lockedImagePath)
        : world.lockedImagePath;

    if (path != null) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() => Container(
        color: world.accentColor.withAlpha(40),
        child: Center(
          child: Text(
            isUnlocked ? world.emoji : '🔒',
            style: const TextStyle(fontSize: 52),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Botón pill
// ─────────────────────────────────────────────────────────────────────────────
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.bg,
    required this.fg,
    this.onTap,
  });
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dots de paginación
// ─────────────────────────────────────────────────────────────────────────────
class _PageDots extends StatefulWidget {
  const _PageDots({required this.count, required this.controller});
  final int count;
  final PageController controller;

  @override
  State<_PageDots> createState() => _PageDotsState();
}

class _PageDotsState extends State<_PageDots> {
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _page = widget.controller.initialPage.toDouble();
    widget.controller.addListener(_onScroll);
  }

  void _onScroll() {
    if (mounted) setState(() => _page = widget.controller.page ?? _page);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.count, (i) {
        final active = ((_page - i).abs() < 0.5);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white30,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Diálogo de confirmación de compra
// ─────────────────────────────────────────────────────────────────────────────
class _PurchaseDialog extends StatelessWidget {
  const _PurchaseDialog({required this.world, required this.currentCoins});
  final World world;
  final int currentCoins;

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
        'Desbloquear ${world.name}',
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
            'Gastar ${world.unlockCost} monedas para acceder a este mundo para siempre.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white70, fontFamily: 'Nunito', fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$currentCoins monedas',
                style: const TextStyle(
                  color: Color(0xFFFFD600),
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded,
                    color: Colors.white38, size: 16),
              ),
              Text(
                '$after monedas',
                style: TextStyle(
                  color: after >= 0 ? Colors.greenAccent : Colors.redAccent,
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
          child: const Text('Cancelar',
              style: TextStyle(color: Colors.white54, fontFamily: 'Nunito')),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: world.accentColor,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Comprar',
              style:
                  TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}
