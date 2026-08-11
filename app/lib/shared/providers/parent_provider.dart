import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/app_notification.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/parent_repository.dart';
import 'auth_provider.dart';

// ── Repositorios ──────────────────────────────────────────────────────────────
final parentRepositoryProvider =
    Provider<ParentRepository>((_) => ParentRepository());

final notificationRepositoryProvider =
    Provider<NotificationRepository>((_) => NotificationRepository());

// ── Hijos vinculados al padre actual ─────────────────────────────────────────
final linkedChildrenProvider = FutureProvider<List<Profile>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return [];
  return ref.read(parentRepositoryProvider).getLinkedChildren(userId);
});

// ── Estadísticas de un hijo específico ───────────────────────────────────────
final childStatsProvider =
    FutureProvider.family<ChildStats, Profile>((ref, child) async {
  return ref
      .read(parentRepositoryProvider)
      .getChildStats(child.id, child.displayName, child.avatarUrl);
});

// ── Notificaciones (en vivo, vía Supabase Realtime) ─────────────────────────
final unreadCountProvider = StreamProvider<int>((ref) {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return Stream.value(0);
  return ref.read(notificationRepositoryProvider).watchUnreadCount(userId);
});

final notificationsListProvider = StreamProvider<List<AppNotification>>((ref) {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return Stream.value(<AppNotification>[]);
  return ref.read(notificationRepositoryProvider).watchNotifications(userId);
});
