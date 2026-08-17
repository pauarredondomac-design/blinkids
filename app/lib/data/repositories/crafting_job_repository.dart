import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/crafting_job.dart';
import '../models/item.dart';
import '../../shared/providers/demo_progress_provider.dart';

class CraftingJobRepository {
  static final _client = Supabase.instance.client;

  // ── Catálogo ──────────────────────────────────────────────────────────────

  /// Carga los trabajos de crafting para un mundo desde Supabase.
  /// Si falla (offline / demo / RLS), devuelve el catálogo hardcodeado.
  static Future<List<CraftingJob>> getJobsForWorld(String worldSlug) async {
    try {
      final worldRow = await _client
          .from('worlds')
          .select('id')
          .eq('slug', worldSlug)
          .maybeSingle();

      final worldId = worldRow?['id'] as String?;
      if (worldId == null) return craftingJobsForWorld(worldSlug);

      final rows = await _client
          .from('jobs')
          .select(
              'id, emoji, name, npc_name, npc_emoji, story, requirements, coin_reward, xp_reward, fuel_reward, item_reward, chapter, chapter_number, order_in_chapter')
          .eq('type', 'crafting')
          .eq('world_id', worldId)
          .eq('is_active', true)
          .order('created_at');

      final list = rows as List;
      if (list.isEmpty) return craftingJobsForWorld(worldSlug);

      return list.map((r) => _fromRow(r, worldSlug)).toList();
    } catch (_) {
      return craftingJobsForWorld(worldSlug);
    }
  }

  static CraftingJob _fromRow(Map<String, dynamic> r, String worldSlug) {
    final reqs = (r['requirements'] as List? ?? [])
        .map((e) => ItemRequirement(
              itemId: e['item_id'] as String,
              qty: (e['qty'] as num).toInt(),
            ))
        .toList();

    final rewardJson = r['item_reward'] as Map<String, dynamic>?;
    final itemReward = rewardJson != null
        ? ItemReward(
            itemId: rewardJson['item_id'] as String,
            qty: (rewardJson['qty'] as num).toInt(),
          )
        : null;

    return CraftingJob(
      id: r['id'] as String,
      emoji: (r['emoji'] as String?) ?? '🔨',
      name: r['name'] as String,
      npcName: (r['npc_name'] as String?) ?? '',
      npcEmoji: (r['npc_emoji'] as String?) ?? '👤',
      story: (r['story'] as String?) ?? '',
      world: worldSlug,
      requirements: reqs,
      coinReward: (r['coin_reward'] as num).toInt(),
      xpReward: (r['xp_reward'] as num).toInt(),
      fuelReward: (r['fuel_reward'] as num? ?? 0).toInt(),
      itemReward: itemReward,
      chapter: r['chapter'] as String?,
      chapterNumber: r['chapter_number'] as int?,
      orderInChapter: r['order_in_chapter'] as int?,
    );
  }

  // ── Completar trabajo ─────────────────────────────────────────────────────

  /// Registra el trabajo completado en job_completions.
  /// No hace nada en demo (nunca escribe a Supabase en demo).
  static Future<void> recordCompletion({
    required String jobId,
    required int coinsEarned,
  }) async {
    if (DemoStore.isActive) return;
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;
      await _client.from('job_completions').insert({
        'user_id': userId,
        'job_id': jobId,
        'coins_earned': coinsEarned,
      });
    } catch (_) {}
  }
}
