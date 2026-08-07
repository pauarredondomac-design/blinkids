/// Calcula el nivel basado en XP (cada 100 XP = 1 nivel).
int levelFromXp(int xp) => (xp / 100).floor() + 1;

/// XP que falta para el siguiente nivel.
int xpToNextLevel(int xp) => 100 - (xp % 100);

/// Progreso dentro del nivel actual (0.0 → 1.0).
double levelProgressFromXp(int xp) => (xp % 100) / 100.0;

class Character {
  final String id;
  final String userId;
  final int xp;
  final int level;
  final String? equippedAvatarId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Character({
    required this.id,
    required this.userId,
    required this.xp,
    required this.level,
    this.equippedAvatarId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Progreso dentro del nivel actual (0.0 → 1.0).
  double get levelProgress => levelProgressFromXp(xp);

  /// XP faltante para el siguiente nivel.
  int get xpToNext => xpToNextLevel(xp);

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      xp: json['xp'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      equippedAvatarId: json['equipped_avatar_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'xp': xp,
        'level': level,
        if (equippedAvatarId != null) 'equipped_avatar_id': equippedAvatarId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Character copyWith({
    int? xp,
    int? level,
    String? equippedAvatarId,
  }) {
    return Character(
      id: id,
      userId: userId,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      equippedAvatarId: equippedAvatarId ?? this.equippedAvatarId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
