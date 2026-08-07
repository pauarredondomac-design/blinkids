import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/badge.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BadgeRepository
//
// Gestiona las medallas del jugador.
// • getBadges()           – devuelve todas las medallas del jugador actual
//                          con su info del catálogo (JOIN server-side).
// • checkAndAward()       – llama al RPC check_and_award_badges() y devuelve
//                          los IDs de las medallas recién ganadas.
// • getBadgesForChild()   – para la vista de padre: medallas del hijo.
// ─────────────────────────────────────────────────────────────────────────────
class BadgeRepository {
  SupabaseClient get _db => Supabase.instance.client;

  /// Devuelve las medallas ganadas por el usuario actual, ordenadas por fecha.
  Future<List<PlayerBadge>> getBadges() async {
    try {
      final rows = await _db
          .from('player_badges')
          .select(
              'badge_id, earned_at, badge_definitions(name, description, emoji)')
          .order('earned_at', ascending: false);

      return (rows as List).map((r) {
        final def = r['badge_definitions'] as Map<String, dynamic>?;
        return PlayerBadge(
          badgeId: r['badge_id'] as String,
          earnedAt: DateTime.parse(r['earned_at'] as String),
          name: def?['name'] as String?,
          description: def?['description'] as String?,
          emoji: def?['emoji'] as String?,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Devuelve las medallas ganadas por un hijo específico (para panel de padre).
  Future<List<PlayerBadge>> getBadgesForChild(String childId) async {
    try {
      final rows = await _db
          .from('player_badges')
          .select(
              'badge_id, earned_at, badge_definitions(name, description, emoji)')
          .eq('user_id', childId)
          .order('earned_at', ascending: false);

      return (rows as List).map((r) {
        final def = r['badge_definitions'] as Map<String, dynamic>?;
        return PlayerBadge(
          badgeId: r['badge_id'] as String,
          earnedAt: DateTime.parse(r['earned_at'] as String),
          name: def?['name'] as String?,
          description: def?['description'] as String?,
          emoji: def?['emoji'] as String?,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Llama al RPC check_and_award_badges() y devuelve los IDs de las
  /// medallas recién ganadas (lista vacía si no hubo novedades).
  Future<List<String>> checkAndAward() async {
    try {
      final result = await _db.rpc('check_and_award_badges');
      if (result == null) return [];
      return (result as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  /// Devuelve el catálogo completo de medallas disponibles, ordenado.
  Future<List<BadgeDefinition>> getAllDefinitions() async {
    try {
      final rows =
          await _db.from('badge_definitions').select().order('sort_order');
      return (rows as List)
          .map((r) => BadgeDefinition.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
