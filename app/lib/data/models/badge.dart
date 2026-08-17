// ─────────────────────────────────────────────────────────────────────────────
// Badge model
// ─────────────────────────────────────────────────────────────────────────────

class BadgeDefinition {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final int sortOrder;
  final String? imageAsset;

  const BadgeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.sortOrder,
    this.imageAsset,
  });

  factory BadgeDefinition.fromJson(Map<String, dynamic> j) => BadgeDefinition(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String,
        emoji: j['emoji'] as String? ?? '🏆',
        sortOrder: j['sort_order'] as int? ?? 0,
        imageAsset: j['image_asset'] as String?,
      );
}

class PlayerBadge {
  final String badgeId;
  final DateTime earnedAt;

  // Denormalized from badge_definitions (populated after join)
  final String? name;
  final String? description;
  final String? emoji;
  final String? imageAsset;

  const PlayerBadge({
    required this.badgeId,
    required this.earnedAt,
    this.name,
    this.description,
    this.emoji,
    this.imageAsset,
  });

  factory PlayerBadge.fromJson(Map<String, dynamic> j) => PlayerBadge(
        badgeId: j['badge_id'] as String,
        earnedAt: DateTime.parse(j['earned_at'] as String),
        name: j['name'] as String?,
        description: j['description'] as String?,
        emoji: j['emoji'] as String?,
        imageAsset: j['image_asset'] as String?,
      );

  String get displayEmoji => emoji ?? '🏆';
  String get displayName => name ?? badgeId;
}
