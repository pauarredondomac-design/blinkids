import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/app_notification.dart';
import '../../data/models/parent_mission.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/parent_repository.dart';
import 'auth_provider.dart';
import 'parent_mission_provider.dart';

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

// ── Resumen semanal (todos los hijos) ────────────────────────────────────────
final parentWeeklySummaryProvider =
    FutureProvider<ParentWeeklySummary>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return ParentWeeklySummary.empty;
  return ref.read(parentRepositoryProvider).getWeeklySummary();
});

// ── Actividad reciente (todos los hijos) ─────────────────────────────────────
final parentRecentActivityProvider =
    FutureProvider<List<ParentActivityItem>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return [];
  return ref.read(parentRepositoryProvider).getRecentActivity();
});

// Pareja misión + nombre del hijo (el modelo solo trae childId).
typedef HomeChoreEntry = (ParentMission mission, String childName);

// ── Trabajos en casa activos (creados por el padre, de todos los hijos) ─────
final activeHomeChoresProvider =
    FutureProvider<List<HomeChoreEntry>>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return [];
  final children = await ref.watch(linkedChildrenProvider.future);
  final namesById = {for (final c in children) c.id: c.displayName};
  final repo = ref.read(parentMissionRepositoryProvider);
  final lists = await Future.wait(
    children.map((c) => repo.getMissionsCreatedForChild(c.id)),
  );
  final all = lists
      .expand((l) => l)
      .where((m) => m.isPending)
      .map((m) => (m, namesById[m.childId] ?? '···'))
      .toList()
    ..sort((a, b) => b.$1.createdAt.compareTo(a.$1.createdAt));
  return all;
});

// ── Notificaciones (en vivo, vía Supabase Realtime) ─────────────────────────
// Usan currentRealUserProvider (no currentUserProvider): la campana de
// notificaciones también se muestra en el mapa del niño en modo demo, y una
// sesión demo (anónima) no debe abrir un stream de Realtime ni escribir nada.
final unreadCountProvider = StreamProvider<int>((ref) {
  final userId = ref.watch(currentRealUserProvider)?.id;
  if (userId == null) return Stream.value(0);
  return ref.read(notificationRepositoryProvider).watchUnreadCount(userId);
});

final notificationsListProvider = StreamProvider<List<AppNotification>>((ref) {
  final userId = ref.watch(currentRealUserProvider)?.id;
  if (userId == null) return Stream.value(<AppNotification>[]);
  return ref.read(notificationRepositoryProvider).watchNotifications(userId);
});
