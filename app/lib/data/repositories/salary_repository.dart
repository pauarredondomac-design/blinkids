import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/salary.dart';

class SalaryRepository {
  SupabaseClient get _db => Supabase.instance.client;

  // ── Para el niño ─────────────────────────────────────────────────────────

  /// Estado del salario del niño actual.
  Future<Map<String, dynamic>> getMyStatus() async {
    try {
      final result = await _db.rpc('get_my_salary_status');
      return Map<String, dynamic>.from(result as Map);
    } catch (_) {
      return {'has_salary': false};
    }
  }

  /// Cobra el salario semanal. Devuelve SalaryClaimResult.
  Future<SalaryClaimResult> claimSalary() async {
    final result = await _db.rpc('claim_weekly_salary');
    return SalaryClaimResult.fromJson(
      Map<String, dynamic>.from(result as Map),
    );
  }

  // ── Para el padre ─────────────────────────────────────────────────────────

  /// Obtiene el salario que el padre asignó a un hijo específico.
  Future<WeeklySalary?> getSalaryForChild(String childId) async {
    try {
      final row = await _db
          .from('weekly_salaries')
          .select()
          .eq('child_id', childId)
          .eq('is_active', true)
          .maybeSingle();
      return row != null ? WeeklySalary.fromJson(row) : null;
    } catch (_) {
      return null;
    }
  }

  /// Lista todos los salarios asignados por el padre actual.
  Future<List<WeeklySalary>> getSalariesByParent() async {
    try {
      final rows = await _db
          .from('weekly_salaries')
          .select()
          .eq('parent_id', _db.auth.currentUser!.id)
          .eq('is_active', true)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) => WeeklySalary.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Asigna o actualiza el salario de un hijo (20-35).
  Future<void> upsertSalary({
    required String childId,
    required int amount,
  }) async {
    await _db.rpc(
      'upsert_weekly_salary',
      params: {'p_child_id': childId, 'p_amount': amount},
    );
  }
}
