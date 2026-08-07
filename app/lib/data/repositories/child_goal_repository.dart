import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/child_goal.dart';

class ChildGoalRepository {
  SupabaseClient get _db => Supabase.instance.client;

  Future<ChildGoal?> getCurrentGoal() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final row = await _db
          .from('child_goals')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return row != null ? ChildGoal.fromJson(row) : null;
    } catch (_) {
      return null;
    }
  }

  /// Elige (o cambia a) una meta nueva. Reinicia el estado de "cumplida".
  Future<void> chooseGoal(SavingsGoalOption goal) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return;
    await _db.from('child_goals').upsert({
      'user_id': userId,
      'goal_key': goal.key,
      'goal_name': goal.name,
      'goal_emoji': goal.emoji,
      'goal_cost': goal.cost,
      'chosen_at': DateTime.now().toIso8601String(),
      'completed_at': null,
    }, onConflict: 'user_id');
  }

  Future<void> markCompleted() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return;
    await _db
        .from('child_goals')
        .update({'completed_at': DateTime.now().toIso8601String()}).eq(
            'user_id', userId);
  }
}
