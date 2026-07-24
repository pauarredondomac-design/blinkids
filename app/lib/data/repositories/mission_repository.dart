import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/mission.dart'; // also re-exports ItemReward via item.dart

class MissionRepository {
  SupabaseClient get _db => Supabase.instance.client;

  /// Trae las misiones activas (del bosque o globales).
  Future<List<Mission>> getActiveMissions({String worldSlug = 'forest'}) async {
    try {
      final worldRow = await _db
          .from('worlds')
          .select('id')
          .eq('slug', worldSlug)
          .maybeSingle();

      final worldId = worldRow?['id'] as String?;

      var query = _db
          .from('missions')
          .select()
          .eq('status', 'active')
          .order('created_at');

      if (worldId != null) {
        final rows = await _db
            .from('missions')
            .select()
            .eq('status', 'active')
            .or('world_id.eq.$worldId,world_id.is.null')
            .order('created_at');
        return rows.map((r) => Mission.fromJson(r)).toList();
      }

      final rows = await query;
      return rows.map((r) => Mission.fromJson(r)).toList();
    } catch (_) {
      return _fallbackMissions(worldSlug);
    }
  }

  /// Une al usuario a una misión.
  Future<void> joinMission(String missionId, String userId) async {
    await _db.from('mission_participants').upsert(
      {'mission_id': missionId, 'user_id': userId},
      onConflict: 'mission_id,user_id',
    );
    await _db.rpc('increment_mission_participants', params: {
      'p_mission_id': missionId,
    });
  }

  /// Comprueba si el usuario ya está en la misión.
  Future<bool> hasJoined(String missionId, String userId) async {
    try {
      final row = await _db
          .from('mission_participants')
          .select('id')
          .eq('mission_id', missionId)
          .eq('user_id', userId)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  // ── Misiones de ejemplo con sistema de objetivos ─────────────────────────
  List<Mission> _fallbackMissions(String worldSlug) {
    if (worldSlug == 'space') return _spaceMissions();
    return _forestMissions();
  }

  List<Mission> _forestMissions() => [
    Mission(
      id: 'forest-quiz-5',
      name: '¡Cerebro de Finanzas! 🧠',
      description: 'Responde 5 preguntas de finanzas correctamente.',
      storyText:
          'El viejo Búho Sabio del bosque quiere ver cuánto sabes de dinero. '
          '¡Demuestra que eres el más inteligente del bosque respondiendo sus preguntas!',
      coinReward: 80,
      xpReward: 50,
      status: MissionStatus.active,
      totalParticipantsNeeded: 1,
      currentParticipants: 0,
      createdAt: DateTime.now(),
      objectiveType:   MissionObjectiveType.completeQuizzes,
      objectiveTarget: 5,
    ),
    Mission(
      id: 'forest-jobs-3',
      name: '¡Trabajador del Bosque! 🔨',
      description: 'Completa 3 trabajos de crafting para los habitantes del bosque.',
      storyText:
          'Los animales del bosque necesitan tu ayuda. '
          'Repara cabañas, cura animales y recolecta provisiones. '
          '¡Juntos haremos del bosque un lugar mejor!',
      coinReward: 120,
      xpReward: 70,
      status: MissionStatus.active,
      totalParticipantsNeeded: 1,
      currentParticipants: 0,
      createdAt: DateTime.now(),
      objectiveType:   MissionObjectiveType.completeJobs,
      objectiveTarget: 3,
      itemReward: ItemReward(itemId: 'fuel_capsule', qty: 2),
    ),
    Mission(
      id: 'forest-shop-3',
      name: '¡Comprador del Bosque! 🛍️',
      description: 'Compra 3 productos en la tienda del bosque.',
      storyText:
          'La tiendita del bosque está teniendo poca clientela. '
          '¡Ayuda a la ardilla vendedora comprando algunos productos '
          'y aprende cómo funciona el comercio!',
      coinReward: 60,
      xpReward: 30,
      status: MissionStatus.active,
      totalParticipantsNeeded: 1,
      currentParticipants: 0,
      createdAt: DateTime.now(),
      objectiveType:   MissionObjectiveType.buyFromShop,
      objectiveTarget: 3,
    ),
  ];

  List<Mission> _spaceMissions() => [
    Mission(
      id: 'space-quiz-5',
      name: '¡Astronauta Inteligente! 🚀',
      description: 'Responde 5 preguntas de finanzas en el espacio.',
      storyText:
          'La Academia Galáctica pone a prueba a todos sus astronautas. '
          '¡Demuestra que sabes tanto de finanzas como de cohetes!',
      coinReward: 80,
      xpReward: 50,
      status: MissionStatus.active,
      totalParticipantsNeeded: 1,
      currentParticipants: 0,
      createdAt: DateTime.now(),
      objectiveType:   MissionObjectiveType.completeQuizzes,
      objectiveTarget: 5,
    ),
    Mission(
      id: 'space-jobs-3',
      name: '¡Mecánico Galáctico! 🔧',
      description: 'Completa 3 trabajos de reparación en la estación espacial.',
      storyText:
          'La estación espacial Alpha necesita mantenimiento urgente. '
          'Repara naves, activa estaciones y arregla robots. '
          '¡La misión depende de ti, astronauta!',
      coinReward: 120,
      xpReward: 70,
      status: MissionStatus.active,
      totalParticipantsNeeded: 1,
      currentParticipants: 0,
      createdAt: DateTime.now(),
      objectiveType:   MissionObjectiveType.completeJobs,
      objectiveTarget: 3,
      itemReward: ItemReward(itemId: 'fuel_capsule', qty: 2),
    ),
    Mission(
      id: 'space-shop-3',
      name: '¡Comerciante Espacial! 🛒',
      description: 'Compra 3 piezas en la tienda de la estación.',
      storyText:
          'La tienda de suministros de la estación necesita más clientes. '
          '¡Aprende cómo funciona el comercio intergaláctico comprando piezas '
          'para tus proyectos espaciales!',
      coinReward: 60,
      xpReward: 30,
      status: MissionStatus.active,
      totalParticipantsNeeded: 1,
      currentParticipants: 0,
      createdAt: DateTime.now(),
      objectiveType:   MissionObjectiveType.buyFromShop,
      objectiveTarget: 3,
    ),
  ];
}
