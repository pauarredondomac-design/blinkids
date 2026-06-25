// ─────────────────────────────────────────────────────────────────────────────
// UserStreak  — racha de actividad diaria o semanal
// ─────────────────────────────────────────────────────────────────────────────

class UserStreak {
  final String userId;
  final String streakType;   // 'daily' | 'weekly'
  final int    currentStreak;
  final int    longestStreak;
  final DateTime lastActivityAt;
  final DateTime updatedAt;

  const UserStreak({
    required this.userId,
    required this.streakType,
    required this.currentStreak,
    required this.longestStreak,
    required this.lastActivityAt,
    required this.updatedAt,
  });

  factory UserStreak.fromJson(Map<String, dynamic> j) => UserStreak(
    userId:         j['user_id']          as String,
    streakType:     j['streak_type']      as String,
    currentStreak:  j['current_streak']   as int? ?? 0,
    longestStreak:  j['longest_streak']   as int? ?? 0,
    lastActivityAt: DateTime.parse(j['last_activity_at'] as String),
    updatedAt:      DateTime.parse(j['updated_at'] as String),
  );
}
