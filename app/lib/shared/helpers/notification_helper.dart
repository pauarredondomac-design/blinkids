import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NotificationHelper
// Genera notificaciones de engagement (inactividad) para el niño.
// Se llama desde el initState de cada mundo (Forest / Space).
// Todas las operaciones son silenciosas — nunca interrumpen la UX.
// ─────────────────────────────────────────────────────────────────────────────
class NotificationHelper {
  NotificationHelper._();

  static SupabaseClient get _db => Supabase.instance.client;

  // ── Punto de entrada principal ────────────────────────────────────────────
  /// Comprueba si el niño lleva 3+ días inactivo y, si es así,
  /// inserta una notificación de recordatorio (máximo 1 por tipo cada 24h).
  static Future<void> checkEngagement() async {
    try {
      final user = _db.auth.currentUser;
      if (user == null) return;

      final now = DateTime.now().toUtc();

      // 1. Leer last_active y created_at del perfil ANTES de actualizar
      final profileRow = await _db
          .from('profiles')
          .select('last_active, created_at, role')
          .eq('id', user.id)
          .maybeSingle();

      if (profileRow == null) return;

      // Solo para niños
      if ((profileRow['role'] as String?) != 'child') return;

      final lastActiveStr = profileRow['last_active'] as String?;
      final createdAtStr = profileRow['created_at'] as String?;

      final lastActive = lastActiveStr != null
          ? DateTime.tryParse(lastActiveStr)?.toUtc()
          : null;
      final createdAt = createdAtStr != null
          ? DateTime.tryParse(createdAtStr)?.toUtc()
          : null;

      // No enviar notificaciones a usuarios registrados hace menos de 1 día
      if (createdAt != null && now.difference(createdAt).inDays < 1) {
        await _touchLastActive(user.id, now);
        return;
      }

      // 2. Calcular días de inactividad
      if (lastActive != null) {
        final daysSince = now.difference(lastActive).inDays;

        if (daysSince >= 3) {
          await _maybeInsertInactivityNotif(user.id, daysSince, now);
        }
      }

      // 3. Actualizar last_active a ahora
      await _touchLastActive(user.id, now);
    } catch (_) {
      // Silencioso — no interrumpir la experiencia del jugador
    }
  }

  // ── Actualizar last_active ─────────────────────────────────────────────────
  static Future<void> _touchLastActive(String userId, DateTime now) async {
    try {
      await _db
          .from('profiles')
          .update({'last_active': now.toIso8601String()}).eq('id', userId);
    } catch (_) {}
  }

  // ── Insertar notificación de inactividad (si no hay una reciente) ──────────
  static Future<void> _maybeInsertInactivityNotif(
    String userId,
    int daysSince,
    DateTime now,
  ) async {
    final type = daysSince >= 7 ? 'inactivity_7d' : 'inactivity_3d';

    // Evitar spam: comprobar si ya se envió esta notificación en las últimas 24h
    final cutoff = now.subtract(const Duration(hours: 24)).toIso8601String();
    final existing = await _db
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('type', type)
        .gte('created_at', cutoff)
        .maybeSingle();

    if (existing != null) return; // ya notificado recientemente

    final String title;
    final String body;

    if (daysSince >= 7) {
      title = '¡Hace una semana que no te vemos! 🌟';
      body =
          'Tu bolsa te extraña... entra a Blinkids y mira cuánto puede crecer tu dinero.';
    } else {
      final dias = daysSince == 1 ? 'día' : 'días';
      title = '¡Te extrañamos, aventurero! 👋';
      body = 'Llevas $daysSince $dias sin aventuras. '
          '¡Vuelve y revisa cómo va creciendo tu bolsa!';
    }

    await _db.from('notifications').insert({
      'user_id': userId,
      'type': type,
      'title': title,
      'body': body,
      'data': {'days_since': daysSince},
    });
  }
}
