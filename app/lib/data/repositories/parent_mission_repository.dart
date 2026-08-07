import '../models/parent_mission.dart';
import '../services/supabase_service.dart';

class ParentMissionRepository {
  /// Misiones asignadas al hijo actual (auth.uid() = child_id), sin importar estado.
  Future<List<ParentMission>> getMissionsForCurrentChild() async {
    final data = await supabase
        .from('parent_missions')
        .select()
        .eq('child_id', currentUserId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => ParentMission.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Misiones que el padre actual creó para un hijo específico.
  Future<List<ParentMission>> getMissionsCreatedForChild(String childId) async {
    final data = await supabase
        .from('parent_missions')
        .select()
        .eq('parent_id', currentUserId)
        .eq('child_id', childId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => ParentMission.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Crea una misión para un hijo vinculado. Lanza excepción si no está
  /// vinculado o la recompensa es inválida.
  Future<void> createMission({
    required String childId,
    required String title,
    String? description,
    required int coinReward,
  }) async {
    await supabase.rpc('create_parent_mission', params: {
      'p_child_id': childId,
      'p_title': title,
      'p_description': description,
      'p_coin_reward': coinReward,
    });
  }

  /// El hijo marca la misión como hecha — queda "awaiting_approval" hasta
  /// que el padre la confirme. No paga recompensa todavía.
  Future<void> markMissionDone(String missionId) async {
    await supabase.rpc('mark_parent_mission_done', params: {
      'p_mission_id': missionId,
    });
  }

  /// El padre confirma que la misión se hizo de verdad. Recién aquí se paga
  /// la recompensa desde su billetera de forma atómica. Lanza excepción si
  /// ya no tiene saldo suficiente.
  Future<void> approveMission(String missionId) async {
    await supabase.rpc('complete_parent_mission', params: {
      'p_mission_id': missionId,
    });
  }

  /// Otorga la recarga semanal al padre actual si ya toca.
  /// Devuelve cuántas monedas se otorgaron (0 si aún no toca).
  Future<int> grantWeeklyAllowanceIfDue() async {
    final result = await supabase.rpc('grant_weekly_allowance_if_due');
    return result as int? ?? 0;
  }
}
