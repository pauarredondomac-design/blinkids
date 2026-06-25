// ─────────────────────────────────────────────────────────────────────────────
// Badge model
// ─────────────────────────────────────────────────────────────────────────────

class BadgeDefinition {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final int    sortOrder;

  const BadgeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.sortOrder,
  });

  factory BadgeDefinition.fromJson(Map<String, dynamic> j) => BadgeDefinition(
    id:          j['id']          as String,
    name:        j['name']        as String,
    description: j['description'] as String,
    emoji:       j['emoji']       as String? ?? '🏆',
    sortOrder:   j['sort_order']  as int?    ?? 0,
  );
}

class PlayerBadge {
  final String   badgeId;
  final DateTime earnedAt;

  // Denormalized from badge_definitions (populated after join)
  final String? name;
  final String? description;
  final String? emoji;

  const PlayerBadge({
    required this.badgeId,
    required this.earnedAt,
    this.name,
    this.description,
    this.emoji,
  });

  factory PlayerBadge.fromJson(Map<String, dynamic> j) => PlayerBadge(
    badgeId:     j['badge_id']   as String,
    earnedAt:    DateTime.parse(j['earned_at'] as String),
    name:        j['name']        as String?,
    description: j['description'] as String?,
    emoji:       j['emoji']       as String?,
  );

  String get displayEmoji => emoji ?? '🏆';
  String get displayName  => name  ?? badgeId;
}
