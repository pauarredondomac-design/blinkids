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

  // ── Campos de capítulo de historia (nuevos) ──────────────────────────────
  /// Nombre del capítulo (ej. "1 - Marte"). Null = misión sin capítulo (legado).
  final String? chapter;
  final int? chapterNumber;
  final int? orderInChapter;
  final int? stars;
  final int fuelReward;

  /// Ítems que hay que tener (y se consumen) para poder reclamar la misión.
  final List<ItemRequirement> requiredItems;

  /// Monedas que hay que tener (y se descuentan) para poder reclamar la misión.
  final int requiredCoins;

  /// Si se reclama esta misión, desbloquea este número de capítulo.
  final int? unlocksChapter;

  /// Última misión de la temporada — dispara la celebración final.
  final bool isSeasonFinale;

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
    this.chapter,
    this.chapterNumber,
    this.orderInChapter,
    this.stars,
    this.fuelReward = 0,
    this.requiredItems = const [],
    this.requiredCoins = 0,
    this.unlocksChapter,
    this.isSeasonFinale = false,
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

    final requiredItems = (json['required_items'] as List? ?? [])
        .map((e) => ItemRequirement(
              itemId: e['item_id'] as String,
              qty: (e['qty'] as num).toInt(),
            ))
        .toList();

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
      chapter: json['chapter'] as String?,
      chapterNumber: json['chapter_number'] as int?,
      orderInChapter: json['order_in_chapter'] as int?,
      stars: json['stars'] as int?,
      fuelReward: json['fuel_reward'] as int? ?? 0,
      requiredItems: requiredItems,
      requiredCoins: json['required_coins'] as int? ?? 0,
      unlocksChapter: json['unlocks_chapter'] as int?,
      isSeasonFinale: json['is_season_finale'] as bool? ?? false,
    );
  }

  /// Progreso basado en participantes (sistema legado de Supabase).
  double get progressRatio => totalParticipantsNeeded == 0
      ? 1.0
      : (currentParticipants / totalParticipantsNeeded).clamp(0.0, 1.0);

  bool get isCompleted => status == MissionStatus.completed;

  /// ¿Tiene sistema de objetivo local (auto-tracking)?
  bool get hasObjective => objectiveType != null;

  /// ¿Es parte de la historia por capítulos?
  bool get isChapterMission => chapterNumber != null;

  /// ¿Necesita ítems y/o monedas para poder reclamarse?
  bool get hasClaimRequirements => requiredItems.isNotEmpty || requiredCoins > 0;
}
