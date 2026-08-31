import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/donation_cause.dart';

class DonationRepository {
  final _client = Supabase.instance.client;

  Future<Map<String, DonationCauseProgress>> getProgress(String userId) async {
    final rows = await _client
        .from('donation_cause_progress')
        .select()
        .eq('user_id', userId);
    final list = (rows as List)
        .map((r) => DonationCauseProgress.fromJson(r as Map<String, dynamic>))
        .toList();
    return {for (final p in list) p.causeId: p};
  }

  /// Suma [amount] al progreso de [causeId]. Si con esto llega o pasa la
  /// meta, guarda solo el sobrante (para que el excedente no se pierda) y
  /// suma 1 a `completions`. Devuelve true si esta donación completó la meta.
  Future<bool> donate({
    required String userId,
    required String causeId,
    required int amount,
    required int goal,
  }) async {
    final existing = await _client
        .from('donation_cause_progress')
        .select()
        .eq('user_id', userId)
        .eq('cause_id', causeId)
        .maybeSingle();

    final currentAmount = (existing?['amount'] as int?) ?? 0;
    final currentCompletions = (existing?['completions'] as int?) ?? 0;
    final newTotal = currentAmount + amount;
    final reachedGoal = newTotal >= goal;
    final finalAmount = reachedGoal ? newTotal - goal : newTotal;
    final finalCompletions =
        reachedGoal ? currentCompletions + 1 : currentCompletions;

    await _client.from('donation_cause_progress').upsert({
      'user_id': userId,
      'cause_id': causeId,
      'amount': finalAmount,
      'completions': finalCompletions,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,cause_id');

    return reachedGoal;
  }
}
