import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/badge.dart';
import '../../data/repositories/badge_repository.dart';
import '../providers/badge_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BadgesRow
// Fila horizontal de medallas del jugador actual.
// Se puede mostrar en el perfil del jugador o en la pantalla del padre.
// ─────────────────────────────────────────────────────────────────────────────
class BadgesRow extends ConsumerWidget {
  const BadgesRow({super.key, this.maxVisible = 6});

  /// Máximo de medallas a mostrar antes de mostrar el botón "ver más".
  final int maxVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(playerBadgesProvider);

    return badgesAsync.when(
      loading: () => const SizedBox(height: 40),
      error: (_, __) => const SizedBox.shrink(),
      data: (badges) => _BadgesContent(badges: badges, maxVisible: maxVisible),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BadgesRowForChild — para la vista del padre pasando badgeId externos
// ─────────────────────────────────────────────────────────────────────────────
class BadgesRowForChild extends StatefulWidget {
  const BadgesRowForChild(
      {super.key, required this.childId, this.maxVisible = 6});

  final String childId;
  final int maxVisible;

  @override
  State<BadgesRowForChild> createState() => _BadgesRowForChildState();
}

class _BadgesRowForChildState extends State<BadgesRowForChild> {
  List<PlayerBadge>? _badges;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await BadgeRepository().getBadgesForChild(widget.childId);
    if (mounted) setState(() => _badges = result);
  }

  @override
  Widget build(BuildContext context) {
    if (_badges == null) return const SizedBox(height: 40);
    return _BadgesContent(badges: _badges!, maxVisible: widget.maxVisible);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Contenido compartido
// ─────────────────────────────────────────────────────────────────────────────
class _BadgesContent extends StatelessWidget {
  const _BadgesContent({required this.badges, required this.maxVisible});

  final List<PlayerBadge> badges;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Text('🔒', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'Aún no tienes medallas. ¡Sigue jugando!',
              style: TextStyle(
                color: Colors.white38,
                fontFamily: 'Nunito',
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    final visible = badges.take(maxVisible).toList();
    final extra = badges.length - maxVisible;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...visible.map((b) => _BadgeChip(badge: b)),
        if (extra > 0) _MoreChip(count: extra, allBadges: badges),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chip individual de medalla
// ─────────────────────────────────────────────────────────────────────────────
class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge});
  final PlayerBadge badge;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: badge.description ?? badge.displayName,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F3C),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF7C3AED).withAlpha(100)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(badge.displayEmoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            Text(
              badge.displayName,
              style: const TextStyle(
                color: Colors.white70,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chip "+N más"
// ─────────────────────────────────────────────────────────────────────────────
class _MoreChip extends StatelessWidget {
  const _MoreChip({required this.count, required this.allBadges});
  final int count;
  final List<PlayerBadge> allBadges;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => _AllBadgesDialog(badges: allBadges),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '+$count más',
          style: const TextStyle(
            color: Colors.white54,
            fontFamily: 'Nunito',
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Diálogo con todas las medallas
// ─────────────────────────────────────────────────────────────────────────────
class _AllBadgesDialog extends StatelessWidget {
  const _AllBadgesDialog({required this.badges});
  final List<PlayerBadge> badges;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0D1230),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🏅 Mis Medallas',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: badges.map((b) => _BadgeChip(badge: b)).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                  ),
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(
                        fontFamily: 'Nunito', fontWeight: FontWeight.w700),
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
// BadgeUnlockToast — muestra un toast cuando se gana una nueva medalla
// ─────────────────────────────────────────────────────────────────────────────
class BadgeUnlockToast extends StatelessWidget {
  const BadgeUnlockToast({super.key, required this.badgeId});
  final String badgeId;

  static void show(BuildContext context, String badgeId,
      {String? name, String? emoji}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
        builder: (_) => _ToastEntry(
              badgeId: badgeId,
              name: name,
              emoji: emoji,
              onDone: () => entry.remove(),
            ));
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Muestra un toast por cada medalla nueva (con nombre/emoji reales) en
/// secuencia, para usar tras `awardXp()` u otra acción que pueda otorgar
/// medallas. Seguro de llamar con una lista vacía.
Future<void> showBadgeUnlockToasts(
  BuildContext context,
  WidgetRef ref,
  List<String> newBadgeIds,
) async {
  if (newBadgeIds.isEmpty) return;
  final defs = await ref.read(badgeDefinitionsProvider.future);
  for (final id in newBadgeIds) {
    if (!context.mounted) return;
    BadgeDefinition? def;
    for (final d in defs) {
      if (d.id == id) {
        def = d;
        break;
      }
    }
    BadgeUnlockToast.show(context, id, name: def?.name, emoji: def?.emoji);
    await Future.delayed(const Duration(milliseconds: 3500));
  }
}

class _ToastEntry extends StatefulWidget {
  const _ToastEntry(
      {required this.badgeId, required this.onDone, this.name, this.emoji});
  final String badgeId;
  final String? name;
  final String? emoji;
  final VoidCallback onDone;

  @override
  State<_ToastEntry> createState() => _ToastEntryState();
}

class _ToastEntryState extends State<_ToastEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 3), () async {
      if (mounted) {
        await _ctrl.reverse();
        widget.onDone();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 60,
      left: 0,
      right: 0,
      child: Center(
        child: ScaleTransition(
          scale: _anim,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black54,
                    blurRadius: 16,
                    offset: Offset(0, 4)),
              ],
            ),
            child: Text(
              widget.name != null
                  ? '${widget.emoji ?? '🏅'} ¡Medalla: ${widget.name}!'
                  : '🏅 ¡Nueva medalla desbloqueada!',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
