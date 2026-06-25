import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/job.dart';

class JobRepository {
  SupabaseClient get _db => Supabase.instance.client;

  Future<List<Job>> getActiveJobs({String worldSlug = 'forest'}) async {
    try {
      final worldRow = await _db
          .from('worlds')
          .select('id')
          .eq('slug', worldSlug)
          .maybeSingle();

      final worldId = worldRow?['id'] as String?;

      List<Map<String, dynamic>> rows;
      if (worldId != null) {
        rows = await _db
            .from('jobs')
            .select()
            .eq('is_active', true)
            .or('world_id.eq.$worldId,world_id.is.null')
            .order('created_at');
      } else {
        rows = await _db
            .from('jobs')
            .select()
            .eq('is_active', true)
            .order('created_at');
      }

      if (rows.isEmpty) return _fallbackJobs();
      return rows.map((r) => Job.fromJson(r)).toList();
    } catch (_) {
      return _fallbackJobs();
    }
  }

  /// Registra un trabajo completado y actualiza las monedas del jugador.
  Future<void> recordCompletion({
    required String userId,
    required String jobId,
    required int coinsEarned,
  }) async {
    try {
      await _db.from('job_completions').insert({
        'user_id':      userId,
        'job_id':       jobId,
        'coins_earned': coinsEarned,
      });
    } catch (_) {
      // No bloquea el flujo si falla el registro
    }
  }

  List<Job> _fallbackJobs() => [
        Job(
          id:   'job-local-1',
          name: 'Vendedor de Frutas',
          description:
              'Atiende tu puesto y da el cambio exacto a los clientes. ¡Rápido, hay fila!',
          coinReward:      25,
          xpReward:        15,
          durationSeconds: 60,
          cooldownMinutes: 60,
          mechanics: 'drag_coins',
          intro:
              'Los clientes llegan con billetes. Tu tarea es dar el cambio correcto.',
          levels: const [
            JobLevel(price: 15, paid: 20, change: 5),
            JobLevel(price: 32, paid: 50, change: 18),
            JobLevel(price: 67, paid: 100, change: 33),
          ],
        ),
        Job(
          id:   'job-local-2',
          name: 'Tiendita del Bosque',
          description:
              'Anota ingresos y gastos del día para saber si tuviste ganancia.',
          coinReward:      20,
          xpReward:        10,
          durationSeconds: 90,
          cooldownMinutes: 120,
          mechanics: 'income_expense_entry',
          intro:
              'Registra cuánto ganaste y cuánto gastaste para calcular tu ganancia.',
          levels: const [],
        ),
      ];
}
