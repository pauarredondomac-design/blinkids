import 'package:supabase_flutter/supabase_flutter.dart';

/// Persiste los mundos desbloqueados en Supabase (tabla world_progress).
/// Sobrevive reinstalaciones y cambios de dispositivo.
/// 'forest' siempre está desbloqueado por defecto (unlock_cost = 0).
class WorldRepository {
  final _client = Supabase.instance.client;

  // ── Consulta ──────────────────────────────────────────────────────────────
  /// Devuelve la lista de slugs de mundos desbloqueados por el usuario actual.
  Future<List<String>> getUnlockedWorldIds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return ['forest'];

    try {
      // 1. Obtener los UUIDs de mundos desbloqueados del usuario
      final progressRows = await _client
          .from('world_progress')
          .select('world_id')
          .eq('user_id', userId)
          .eq('is_unlocked', true);

      final worldIds = (progressRows as List)
          .map((r) => r['world_id'] as String)
          .toList();

      if (worldIds.isEmpty) return ['forest'];

      // 2. Convertir UUIDs → slugs consultando la tabla worlds
      final worldRows = await _client
          .from('worlds')
          .select('slug')
          .inFilter('id', worldIds);

      final slugs = (worldRows as List)
          .map((r) => r['slug'] as String)
          .toList();

      if (!slugs.contains('forest')) slugs.insert(0, 'forest');
      return slugs;
    } catch (_) {
      // Si falla la red → degradación segura (solo el bosque gratis)
      return ['forest'];
    }
  }

  // ── Desbloqueo ────────────────────────────────────────────────────────────
  /// Marca un mundo como desbloqueado en Supabase.
  /// Primero busca el UUID del mundo por su slug, luego hace upsert en
  /// world_progress (INSERT si no existe, UPDATE si ya existe).
  Future<void> unlockWorld(String worldSlug) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    // 1. Obtener el UUID del mundo a partir del slug
    final worldRow = await _client
        .from('worlds')
        .select('id')
        .eq('slug', worldSlug)
        .maybeSingle();

    if (worldRow == null) return; // slug desconocido → ignorar

    final worldId = worldRow['id'] as String;

    // 2. Upsert en world_progress
    await _client.from('world_progress').upsert(
      {
        'user_id':      userId,
        'world_id':     worldId,
        'is_unlocked':  true,
        'unlocked_at':  DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,world_id',
    );
  }

  // ── Helper ────────────────────────────────────────────────────────────────
  bool isUnlocked(String worldSlug, List<String> unlockedSlugs) =>
      worldSlug == 'forest' || unlockedSlugs.contains(worldSlug);
}
