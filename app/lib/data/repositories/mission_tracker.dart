import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/mission.dart' show Mission, MissionObjectiveType;
import '../../shared/providers/demo_progress_provider.dart';

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

  Future<void> recordQuiz() => _increment('quiz');
  Future<void> recordJob() => _increment('job');
  Future<void> recordPurchase() => _increment('purchase');

  Future<void> _increment(String type) async {
    if (DemoStore.isActive) {
      DemoStore.instance.recordMissionAction(type);
      return;
    }
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
    if (DemoStore.isActive) {
      final s = DemoStore.instance;
      return {
        MissionObjectiveType.completeQuizzes: s.progressFor('quiz'),
        MissionObjectiveType.completeJobs: s.progressFor('job'),
        MissionObjectiveType.buyFromShop: s.progressFor('purchase'),
      };
    }
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
        MissionObjectiveType.completeQuizzes: (row['quizzes'] as int?) ?? 0,
        MissionObjectiveType.completeJobs: (row['jobs'] as int?) ?? 0,
        MissionObjectiveType.buyFromShop: (row['purchases'] as int?) ?? 0,
      };
    } catch (_) {
      return _zero();
    }
  }

  Map<MissionObjectiveType, int> _zero() => {
        MissionObjectiveType.completeQuizzes: 0,
        MissionObjectiveType.completeJobs: 0,
        MissionObjectiveType.buyFromShop: 0,
      };

  // ── Reclamación de recompensas ────────────────────────────────────────────

  /// Devuelve true si la misión ya fue reclamada por el usuario actual.
  Future<bool> isClaimed(String missionId) async {
    if (DemoStore.isActive) {
      return DemoStore.instance.isMissionClaimed(missionId);
    }
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
    if (DemoStore.isActive) {
      DemoStore.instance.markMissionClaimed(missionId);
      return;
    }
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      await _client.from('mission_claims').upsert(
        {
          'user_id': userId,
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

  /// Todos los IDs de misión ya reclamados por el usuario actual, en UNA
  /// sola consulta — usar esto en vez de llamar [isClaimed] en un loop por
  /// cada misión (eso hacía una consulta de red por misión y era la causa
  /// de la carga lenta en Misiones/Trabajos).
  Future<Set<String>> claimedMissionIds() async {
    if (DemoStore.isActive) {
      return Set<String>.from(DemoStore.instance.claimedMissions);
    }
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return {};
      final rows = await _client
          .from('mission_claims')
          .select('mission_id')
          .eq('user_id', userId);
      return (rows as List).map((r) => r['mission_id'] as String).toSet();
    } catch (_) {
      return {};
    }
  }

  // ── Capítulos de historia ────────────────────────────────────────────────

  /// Capítulo desbloqueado (1 = siempre disponible). Un capítulo N>1 se
  /// desbloquea cuando ya se reclamó la última misión (order_in_chapter=4)
  /// del capítulo N-1. Usado por Misiones y Trabajos para mostrar el
  /// mismo estado de bloqueo en ambas pantallas. No hace red — recibe el
  /// conjunto de reclamados ya obtenido con [claimedMissionIds].
  // ── Foto de progreso al desbloquear un capítulo ──────────────────────────

  /// Devuelve la foto de progreso (saldo por categoría + contadores de
  /// trabajos/quizzes/compras) del capítulo indicado — si es la primera vez
  /// que se consulta, el servidor la crea con los valores de AHORA MISMO
  /// (ese momento pasa a ser el "desde que se desbloqueó" del capítulo).
  /// En demo siempre es cero: cada sesión demo ya arranca limpia.
  Future<Map<String, int>> ensureChapterSnapshot(int chapterNumber) async {
    const zero = {
      'guardar': 0,
      'invertir': 0,
      'donar': 0,
      'gastar': 0,
      'quizzes': 0,
      'jobs': 0,
      'purchases': 0,
    };
    if (DemoStore.isActive) return zero;
    try {
      final row = await _client.rpc('ensure_chapter_snapshot',
          params: {'p_chapter_number': chapterNumber}) as Map<String, dynamic>;
      return {
        'guardar': row['guardar_at_unlock'] as int? ?? 0,
        'invertir': row['invertir_at_unlock'] as int? ?? 0,
        'donar': row['donar_at_unlock'] as int? ?? 0,
        'gastar': row['gastar_at_unlock'] as int? ?? 0,
        'quizzes': row['quizzes_at_unlock'] as int? ?? 0,
        'jobs': row['jobs_at_unlock'] as int? ?? 0,
        'purchases': row['purchases_at_unlock'] as int? ?? 0,
      };
    } catch (_) {
      return zero;
    }
  }

  int unlockedChapterFrom(List<Mission> chapterMissions, Set<String> claimedIds) {
    final finales = chapterMissions
        .where((m) => m.chapterNumber != null && m.orderInChapter == 4)
        .toList()
      ..sort((a, b) => a.chapterNumber!.compareTo(b.chapterNumber!));

    var unlocked = 1;
    for (final finale in finales) {
      if (claimedIds.contains(finale.id)) {
        unlocked = finale.chapterNumber! + 1;
      } else {
        break;
      }
    }
    return unlocked;
  }
}
