import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Resultado de búsqueda de niños
// ─────────────────────────────────────────────────────────────────────────────
class ChildSearchResult {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? email;

  const ChildSearchResult({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.email,
  });

  factory ChildSearchResult.fromJson(Map<String, dynamic> j) =>
      ChildSearchResult(
        id: j['id'] as String,
        displayName: j['display_name'] as String,
        avatarUrl: j['avatar_url'] as String?,
        email: j['email'] as String?,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Estadísticas del hijo para mostrar en la tarjeta del panel de padre
// ─────────────────────────────────────────────────────────────────────────────
class ChildStats {
  final String childId;
  final String displayName;
  final String? avatarUrl;
  final int xp;
  final int level;
  final int totalCoins;
  final int missionsJoined;

  const ChildStats({
    required this.childId,
    required this.displayName,
    this.avatarUrl,
    required this.xp,
    required this.level,
    required this.totalCoins,
    required this.missionsJoined,
  });

  // ── Progreso dentro del nivel actual (0-100 XP por nivel) ─────────────────
  double get levelProgress => (xp % 100) / 100.0;
  int get xpInLevel => xp % 100;
  int get xpToNext => 100 - (xp % 100);

  // Emoji fijo del personaje (cosmética aún no implementada → siempre 🦊)
  static const String characterEmoji = '🦊';
}

// ─────────────────────────────────────────────────────────────────────────────
// Resumen semanal del panel de padre (todos los hijos vinculados)
// ─────────────────────────────────────────────────────────────────────────────
class ParentWeeklySummary {
  final int coinsEarned;
  final int missionsCompleted;
  final int jobsCompleted;

  const ParentWeeklySummary({
    required this.coinsEarned,
    required this.missionsCompleted,
    required this.jobsCompleted,
  });

  factory ParentWeeklySummary.fromJson(Map<String, dynamic> j) =>
      ParentWeeklySummary(
        coinsEarned: (j['coins_earned'] as num?)?.toInt() ?? 0,
        missionsCompleted: (j['missions_completed'] as num?)?.toInt() ?? 0,
        jobsCompleted: (j['jobs_completed'] as num?)?.toInt() ?? 0,
      );

  static const empty =
      ParentWeeklySummary(coinsEarned: 0, missionsCompleted: 0, jobsCompleted: 0);
}

// ─────────────────────────────────────────────────────────────────────────────
// Ítem de actividad reciente (trabajo o tarea de papá completados)
// ─────────────────────────────────────────────────────────────────────────────
class ParentActivityItem {
  final String childName;
  final String activityType; // 'trabajo' | 'mision_papa'
  final String title;
  final int coinAmount;
  final DateTime occurredAt;

  const ParentActivityItem({
    required this.childName,
    required this.activityType,
    required this.title,
    required this.coinAmount,
    required this.occurredAt,
  });

  factory ParentActivityItem.fromJson(Map<String, dynamic> j) =>
      ParentActivityItem(
        childName: j['child_name'] as String? ?? '',
        activityType: j['activity_type'] as String? ?? 'trabajo',
        title: j['title'] as String? ?? '',
        coinAmount: (j['coin_amount'] as num?)?.toInt() ?? 0,
        occurredAt: DateTime.parse(j['occurred_at'] as String),
      );

  String get icon => activityType == 'mision_papa' ? '📋' : '🔨';

  String get timeAgo {
    final diff = DateTime.now().difference(occurredAt);
    if (diff.inMinutes < 1) return 'ahora mismo';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} días';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ParentRepository
// ─────────────────────────────────────────────────────────────────────────────
class ParentRepository {
  SupabaseClient get _db => Supabase.instance.client;

  // ── Busca niños por apodo o email (usa RPC en Supabase) ───────────────────
  Future<List<ChildSearchResult>> searchChild(String query) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim();

    // Intenta con la función RPC que accede a auth.users
    try {
      final rows = await _db.rpc('search_child', params: {'p_query': q});
      return (rows as List)
          .map((r) => ChildSearchResult.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // RPC no disponible → fallback a búsqueda directa por display_name
    }

    // Fallback: busca en profiles (requiere migración 011 para RLS)
    final rows = await _db
        .from('profiles')
        .select('id, display_name, avatar_url')
        .eq('role', 'child')
        .ilike('display_name', '%$q%')
        .limit(10);
    return (rows as List).map((r) {
      final m = r as Map<String, dynamic>;
      return ChildSearchResult.fromJson({...m, 'email': null});
    }).toList();
    // Si esto también falla, la excepción sube al llamador (_search en UI)
  }

  // ── Envía solicitud de vinculación padre → hijo ───────────────────────────
  Future<void> sendLinkRequest({
    required String parentId,
    required String childId,
    required String parentName,
  }) async {
    // Upsert en link_requests
    await _db.from('link_requests').upsert(
      {'parent_id': parentId, 'child_id': childId, 'status': 'pending'},
      onConflict: 'parent_id,child_id',
    );
    // Notificación para el niño
    await _db.from('notifications').insert({
      'user_id': childId,
      'type': 'link_request',
      'title': '¡Tu papá/mamá quiere conectarse! 👨‍👩‍👧',
      'body': '$parentName quiere ser tu tutor en Blinkids. '
          'Dile que abra sus notificaciones para aceptar.',
      'data': {'parent_id': parentId},
    });
  }

  // ── Acepta una solicitud de vinculación (lo llama el niño) ────────────────
  Future<void> acceptLinkRequest({
    required String parentId,
    required String childId,
    required String childName,
  }) async {
    // Actualizar status en link_requests
    await _db
        .from('link_requests')
        .update({'status': 'accepted'})
        .eq('parent_id', parentId)
        .eq('child_id', childId);

    // Crear vínculo en parent_child (si no existe)
    await _db.from('parent_child').upsert(
      {'parent_id': parentId, 'child_id': childId},
      onConflict: 'parent_id,child_id',
    );

    // Notificación para el padre
    await _db.from('notifications').insert({
      'user_id': parentId,
      'type': 'link_accepted',
      'title': '¡$childName aceptó tu solicitud! ✅',
      'body': 'Ya puedes ver la actividad de $childName en tu panel.',
      'data': {'child_id': childId},
    });
  }

  // ── Obtiene el estado de la solicitud entre padre e hijo ──────────────────
  Future<String?> getLinkRequestStatus(String parentId, String childId) async {
    try {
      final row = await _db
          .from('link_requests')
          .select('status')
          .eq('parent_id', parentId)
          .eq('child_id', childId)
          .maybeSingle();
      return row?['status'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ── Lista de hijos vinculados al padre ────────────────────────────────────
  Future<List<Profile>> getLinkedChildren(String parentId) async {
    try {
      final rows = await _db
          .from('parent_child')
          .select(
              'profiles!child_id(id, display_name, avatar_url, role, created_at, updated_at)')
          .eq('parent_id', parentId);
      return (rows as List)
          .map((e) => Profile.fromJson(e['profiles'] as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Solicitudes pendientes recibidas por el niño ──────────────────────────
  Future<List<Map<String, dynamic>>> getPendingRequestsForChild(
      String childId) async {
    try {
      final rows = await _db
          .from('link_requests')
          .select(
              'id, parent_id, created_at, profiles!parent_id(display_name, avatar_url)')
          .eq('child_id', childId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ── Estadísticas del hijo para el panel del padre ─────────────────────────
  Future<ChildStats> getChildStats(
    String childId,
    String displayName,
    String? avatarUrl,
  ) async {
    int xp = 0, level = 1, totalCoins = 0, missionsJoined = 0;

    try {
      final charRow = await _db
          .from('characters')
          .select('xp, level')
          .eq('user_id', childId)
          .maybeSingle();
      xp = charRow?['xp'] as int? ?? 0;
      level = charRow?['level'] as int? ?? 1;
    } catch (_) {}

    try {
      final walletRow = await _db
          .from('wallets')
          .select('total_coins')
          .eq('user_id', childId)
          .maybeSingle();
      totalCoins = walletRow?['total_coins'] as int? ?? 0;
    } catch (_) {}

    try {
      final mRows = await _db
          .from('mission_participants')
          .select('id')
          .eq('user_id', childId);
      missionsJoined = (mRows as List).length;
    } catch (_) {}

    return ChildStats(
      childId: childId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      xp: xp,
      level: level,
      totalCoins: totalCoins,
      missionsJoined: missionsJoined,
    );
  }

  // ── Resumen semanal (monedas/misiones/trabajos) de todos los hijos ───────
  Future<ParentWeeklySummary> getWeeklySummary() async {
    try {
      final rows = await _db.rpc('get_parent_weekly_summary');
      final row = (rows as List).isNotEmpty
          ? rows.first as Map<String, dynamic>
          : null;
      return row != null
          ? ParentWeeklySummary.fromJson(row)
          : ParentWeeklySummary.empty;
    } catch (_) {
      return ParentWeeklySummary.empty;
    }
  }

  // ── Actividad reciente (trabajos y tareas de papá) de todos los hijos ────
  Future<List<ParentActivityItem>> getRecentActivity({int limit = 8}) async {
    try {
      final rows = await _db
          .rpc('get_parent_recent_activity', params: {'p_limit': limit});
      return (rows as List)
          .map((e) => ParentActivityItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Genera un código de invitación para que el niño vincule su cuenta ────────
  Future<String> generateInviteCode() async {
    final result = await _db.rpc('generate_invite_code');
    return result as String;
  }

  // ── Canjea un código de invitación (lo llama el niño) ────────────────────────
  Future<void> redeemInviteCode(String code) async {
    await _db.rpc('redeem_invite_code', params: {'p_code': code.toUpperCase()});
  }
}
