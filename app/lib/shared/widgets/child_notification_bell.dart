import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/app_notification.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/parent_provider.dart';
import '../../shared/providers/profile_provider.dart';
import 'game_popup.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ChildNotificationBell
// Campana con badge rojo para el HUD del niño.
// Se puede soltar en cualquier Row — maneja su propio estado.
// ─────────────────────────────────────────────────────────────────────────────
class ChildNotificationBell extends ConsumerStatefulWidget {
  const ChildNotificationBell({super.key, this.accentColor});

  /// Color del borde y el ícono activo (verde bosque o cian espacio).
  final Color? accentColor;

  @override
  ConsumerState<ChildNotificationBell> createState() =>
      _ChildNotificationBellState();
}

class _ChildNotificationBellState extends ConsumerState<ChildNotificationBell> {
  void _openPanel() {
    // Marcar todas como leídas al abrir
    final userId = ref.read(currentUserProvider)?.id;
    if (userId != null) {
      ref.read(notificationRepositoryProvider).markAllRead(userId).then((_) {
        if (!mounted) return;
        ref.invalidate(unreadCountProvider);
        ref.invalidate(notificationsListProvider);
      });
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _NotifBottomSheet(accent: widget.accentColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    final accent = widget.accentColor ?? const Color(0xFF69F0AE);

    return GestureDetector(
      onTap: _openPanel,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Ícono con fondo semitransparente
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(100),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: count > 0 ? accent.withAlpha(150) : Colors.white24,
              ),
            ),
            child: Icon(
              Icons.notifications_rounded,
              color: count > 0 ? accent : Colors.white54,
              size: 20,
            ),
          ),
          // Badge rojo
          if (count > 0)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Color(0xFFEC4899),
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                  ),
                ),
              ).animate().scale(
                    begin: const Offset(0.6, 0.6),
                    end: const Offset(1.0, 1.0),
                    duration: 200.ms,
                    curve: Curves.elasticOut,
                  ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet de notificaciones del niño
// ─────────────────────────────────────────────────────────────────────────────
class _NotifBottomSheet extends ConsumerWidget {
  const _NotifBottomSheet({this.accent});
  final Color? accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificationsListProvider);
    final effectiveAccent = accent ?? const Color(0xFF69F0AE);

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Color(0xFF0D1230),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── Tirador ──────────────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(children: [
              Icon(
                Icons.notifications_rounded,
                color: effectiveAccent,
                size: 22,
              ),
              const SizedBox(width: 8),
              const Text(
                'Notificaciones',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cerrar',
                  style: TextStyle(
                    color: Colors.white38,
                    fontFamily: 'Nunito',
                    fontSize: 13,
                  ),
                ),
              ),
            ]),
          ),
          const Divider(color: Colors.white10, height: 1),

          // ── Lista ─────────────────────────────────────────────────────
          Expanded(
            child: notifsAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(color: effectiveAccent),
              ),
              error: (_, __) => const Center(
                child: Text(
                  'No se pudieron cargar las notificaciones.',
                  style: TextStyle(color: Colors.white38, fontFamily: 'Nunito'),
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const _EmptyNotifs();
                }
                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: list.length,
                  itemBuilder: (ctx, i) {
                    final n = list[i];
                    return _NotifTile(
                      notif: n,
                      accent: effectiveAccent,
                    ).animate(delay: (30 * i).ms).fadeIn(duration: 200.ms);
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

// ─────────────────────────────────────────────────────────────────────────────
// Tile individual de notificación
// ─────────────────────────────────────────────────────────────────────────────
class _NotifTile extends ConsumerStatefulWidget {
  const _NotifTile({required this.notif, required this.accent});
  final AppNotification notif;
  final Color accent;

  @override
  ConsumerState<_NotifTile> createState() => _NotifTileState();
}

class _NotifTileState extends ConsumerState<_NotifTile> {
  bool _acting = false;
  bool _handled = false; // se ocultó el tile de acción tras aceptar/rechazar

  Future<void> _accept() async {
    final parentId = widget.notif.data['parent_id'] as String?;
    if (parentId == null) return;

    final userId = ref.read(currentUserProvider)?.id;
    final profile = ref.read(currentProfileProvider).valueOrNull;
    if (userId == null || profile == null) return;

    setState(() => _acting = true);
    try {
      await ref.read(parentRepositoryProvider).acceptLinkRequest(
            parentId: parentId,
            childId: userId,
            childName: profile.displayName,
          );
      // Marcar notificación como leída
      await ref.read(notificationRepositoryProvider).markRead(widget.notif.id);
      ref.invalidate(notificationsListProvider);
      ref.invalidate(unreadCountProvider);
      setState(() => _handled = true);

      if (mounted) {
        showGamePopup(
          context,
          '¡Solicitud aceptada! Tu tutor puede verte ahora. 🎉',
          accentColor: const Color(0xFF10B981),
        );
      }
    } catch (e) {
      if (mounted) {
        showGamePopup(context, 'Error: $e', accentColor: Colors.red);
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _reject() async {
    final parentId = widget.notif.data['parent_id'] as String?;
    if (parentId == null) return;

    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    setState(() => _acting = true);
    try {
      // Actualizar estado de la solicitud
      await Supabase.instance.client
          .from('link_requests')
          .update({'status': 'rejected'})
          .eq('parent_id', parentId)
          .eq('child_id', userId);

      // Marcar notificación como leída
      await ref.read(notificationRepositoryProvider).markRead(widget.notif.id);
      ref.invalidate(notificationsListProvider);
      ref.invalidate(unreadCountProvider);
      setState(() => _handled = true);

      if (mounted) {
        showGamePopup(context, 'Solicitud rechazada.',
            accentColor: Colors.grey);
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLinkRequest = widget.notif.type == 'link_request' && !_handled;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.notif.isRead
            ? Colors.white.withAlpha(6)
            : widget.accent.withAlpha(20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.notif.isRead
              ? Colors.white10
              : widget.accent.withAlpha(80),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabecera ──────────────────────────────────────────────
          Row(children: [
            Text(
              widget.notif.typeIcon,
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.notif.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.notif.body,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  widget.notif.timeAgo,
                  style: const TextStyle(
                    color: Colors.white30,
                    fontFamily: 'Nunito',
                    fontSize: 10,
                  ),
                ),
                if (!widget.notif.isRead && !isLinkRequest)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEC4899),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ]),

          // ── Botones Aceptar / Rechazar (solo link_request) ────────
          if (isLinkRequest) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _acting ? null : _reject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text(
                    '✖ Rechazar',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _acting ? null : _accept,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: _acting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          '✔ Aceptar',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                ),
              ),
            ]),
          ],

          // ── Estado tras aceptar/rechazar ──────────────────────────
          if (_handled)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                widget.notif.type == 'link_request' ? '✅ Respondida' : '',
                style: const TextStyle(
                  color: Colors.white38,
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Estado vacío
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyNotifs extends StatelessWidget {
  const _EmptyNotifs();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🔔', style: TextStyle(fontSize: 44)),
          SizedBox(height: 12),
          Text(
            'Sin notificaciones',
            style: TextStyle(
              color: Colors.white54,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Aquí verás cuando un tutor\nquiera conectarse contigo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white30,
              fontFamily: 'Nunito',
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
