import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_notification.dart';

class NotificationRepository {
  SupabaseClient get _db => Supabase.instance.client;

  /// Obtiene las últimas 25 notificaciones del usuario.
  Future<List<AppNotification>> getNotifications(String userId) async {
    try {
      final rows = await _db
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(25);
      return (rows as List)
          .map((r) => AppNotification.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Número de notificaciones no leídas.
  Future<int> getUnreadCount(String userId) async {
    try {
      final rows = await _db
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  /// Marca todas las notificaciones del usuario como leídas.
  Future<void> markAllRead(String userId) async {
    try {
      await _db
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (_) {}
  }

  /// Marca una notificación individual como leída.
  Future<void> markRead(String notificationId) async {
    try {
      await _db
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (_) {}
  }

  /// Crea una notificación (uso interno / admin).
  Future<void> createNotification({
    required String userId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _db.from('notifications').insert({
      'user_id': userId,
      'type':    type,
      'title':   title,
      'body':    body,
      'data':    data ?? {},
    });
  }
}
