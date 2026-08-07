import 'item.dart';

export 'item.dart' show ItemReward;

enum MissionStatus { active, completed, cancelled }

/// Tipo de objetivo de la misión (para auto-tracking)
enum MissionObjectiveType { completeQuizzes, completeJobs, buyFromShop }

class Mission {
  final String id;
  final String name;
  final String? description;
  final String? storyText;
  final int coinReward;
  final int xpReward;
  final MissionStatus status;
  final int totalParticipantsNeeded;
  final int currentParticipants;
  final DateTime? endsAt;
  final DateTime createdAt;

  // ── Campos de objetivo (nuevos) ──────────────────────────────────────────
  /// Tipo de objetivo a completar. Null = misión sin auto-tracking (legado).
  final MissionObjectiveType? objectiveType;

  /// Cantidad objetivo (e.g. 5 quizzes, 3 trabajos).
  final int objectiveTarget;

  /// Ítem de recompensa opcional (además de monedas).
  final ItemReward? itemReward;

  const Mission({
    required this.id,
    required this.name,
    this.description,
    this.storyText,
    required this.coinReward,
    required this.xpReward,
    required this.status,
    required this.totalParticipantsNeeded,
    required this.currentParticipants,
    this.endsAt,
    required this.createdAt,
    this.objectiveType,
    this.objectiveTarget = 1,
    this.itemReward,
  });

  factory Mission.fromJson(Map<String, dynamic> json) {
    MissionObjectiveType? objType;
    final objTypeStr = json['objective_type'] as String?;
    if (objTypeStr != null) {
      objType = MissionObjectiveType.values.firstWhere(
        (t) => t.name == objTypeStr,
        orElse: () => MissionObjectiveType.completeQuizzes,
      );
    }

    ItemReward? reward;
    final rewardItemId = json['item_reward_id'] as String?;
    final rewardQty = json['item_reward_qty'] as int? ?? 1;
    if (rewardItemId != null) {
      reward = ItemReward(itemId: rewardItemId, qty: rewardQty);
    }

    return Mission(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      storyText: json['story_text'] as String?,
      coinReward: json['coin_reward'] as int? ?? 0,
      xpReward: json['xp_reward'] as int? ?? 0,
      status: MissionStatus.values.firstWhere(
        (s) => s.name == (json['status'] as String? ?? 'active'),
        orElse: () => MissionStatus.active,
      ),
      totalParticipantsNeeded: json['total_participants_needed'] as int? ?? 1,
      currentParticipants: json['current_participants'] as int? ?? 0,
      endsAt: json['ends_at'] != null
          ? DateTime.parse(json['ends_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      objectiveType: objType,
      objectiveTarget: json['objective_target'] as int? ?? 1,
      itemReward: reward,
    );
  }

  /// Progreso basado en participantes (sistema legado de Supabase).
  double get progressRatio => totalParticipantsNeeded == 0
      ? 1.0
      : (currentParticipants / totalParticipantsNeeded).clamp(0.0, 1.0);

  bool get isCompleted => status == MissionStatus.completed;

  /// ¿Tiene sistema de objetivo local (auto-tracking)?
  bool get hasObjective => objectiveType != null;
}
