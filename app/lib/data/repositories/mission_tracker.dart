import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/mission.dart' show MissionObjectiveType;

// ─────────────────────────────────────────────────────────────────────────────
// MissionTracker
// Lleva el conteo de acciones del jugador que sirven para completar misiones.
//
// SEGURIDAD: el progreso se almacena en Supabase (tablas mission_progress y
// mission_claims, migración 017) con RLS activo.
// El RPC increment_mission_action usa SECURITY DEFINER + ON CONFLICT DO UPDATE,
// lo que garantiza atomicidad y evita que un cliente malicioso infle los
// contadores escribiendo directamente en la tabla.
// ─────────────────────────────────────────────────────────────────────────────

class MissionTracker {
  final _client = Supabase.instance.client;

  // ── Registro de acciones ─────────────────────────────────────────────────

  Future<void> recordQuiz()     => _increment('quiz');
  Future<void> recordJob()      => _increment('job');
  Future<void> recordPurchase() => _increment('purchase');

  Future<void> _increment(String type) async {
    try {
      await _client.rpc(
        'increment_mission_action',
        params: {'p_type': type},
      );
    } catch (_) {
      // Fallo de red → ignorar silenciosamente.
      // El RPC volverá a funcionar cuando haya conexión.
    }
  }

  // ── Consultas ────────────────────────────────────────────────────────────

  Future<int> progressFor(MissionObjectiveType type) async {
    final all = await allProgress();
    return all[type] ?? 0;
  }

  /// Devuelve el progreso actual para todos los tipos.
  Future<Map<MissionObjectiveType, int>> allProgress() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return _zero();

      final row = await _client
          .from('mission_progress')
          .select('quizzes, jobs, purchases')
          .eq('user_id', userId)
          .maybeSingle();

      if (row == null) return _zero();

      return {
        MissionObjectiveType.completeQuizzes: (row['quizzes']   as int?) ?? 0,
        MissionObjectiveType.completeJobs:    (row['jobs']      as int?) ?? 0,
        MissionObjectiveType.buyFromShop:     (row['purchases'] as int?) ?? 0,
      };
    } catch (_) {
      return _zero();
    }
  }

  Map<MissionObjectiveType, int> _zero() => {
    MissionObjectiveType.completeQuizzes: 0,
    MissionObjectiveType.completeJobs:    0,
    MissionObjectiveType.buyFromShop:     0,
  };

  // ── Reclamación de recompensas ────────────────────────────────────────────

  /// Devuelve true si la misión ya fue reclamada por el usuario actual.
  Future<bool> isClaimed(String missionId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      final row = await _client
          .from('mission_claims')
          .select('mission_id')
          .eq('user_id', userId)
          .eq('mission_id', missionId)
          .maybeSingle();

      return row != null;
    } catch (_) {
      return false; // En caso de error de red, no bloquear al jugador
    }
  }

  /// Marca una misión como reclamada. La PK (user_id, mission_id) en la tabla
  /// garantiza que no se puede reclamar dos veces aunque el cliente lo intente.
  Future<void> markClaimed(String missionId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      await _client.from('mission_claims').upsert(
        {
          'user_id':    userId,
          'mission_id': missionId,
          'claimed_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,mission_id',
      );
    } catch (_) {
      // Si falla, el jugador no podrá reclamar el premio en esta sesión
      // pero tampoco podrá reclamarlo dos veces si la DB lo bloqueó antes.
    }
  }
}
