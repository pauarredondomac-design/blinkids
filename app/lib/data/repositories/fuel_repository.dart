import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/fuel.dart';

class FuelRepository {
  SupabaseClient get _db => Supabase.instance.client;

  /// Lee el fuel actual para el mundo dado.
  Future<WorldFuel?> getFuel(String worldSlug) async {
    try {
      final row = await _db
          .from('world_fuel')
          .select()
          .eq('user_id', _db.auth.currentUser!.id)
          .eq('world_slug', worldSlug)
          .maybeSingle();
      return row != null ? WorldFuel.fromJson(row) : null;
    } catch (_) {
      return null;
    }
  }

  /// Suma [amount] al combustible del mundo y devuelve si llegó a 100.
  Future<bool> addFuel(String worldSlug, int amount) async {
    try {
      final result = await _db.rpc(
        'add_fuel',
        params: {'p_world_slug': worldSlug, 'p_amount': amount},
      );
      return result as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Reinicia el fuel a 0 e incrementa el cycle (post-Hangar de Despegue).
  Future<void> resetFuel(String worldSlug) async {
    try {
      await _db.rpc('reset_fuel', params: {'p_world_slug': worldSlug});
    } catch (_) {}
  }

  /// Registra actividad diaria y devuelve streak + coins ganadas + fuel dado.
  Future<Map<String, dynamic>> recordDailyActivity() async {
    try {
      final result = await _db.rpc('record_daily_activity');
      return Map<String, dynamic>.from(result as Map);
    } catch (_) {
      return {};
    }
  }
}
