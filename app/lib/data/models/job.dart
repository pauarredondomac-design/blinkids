class JobLevel {
  final int price;
  final int paid;
  final int change;

  const JobLevel({
    required this.price,
    required this.paid,
    required this.change,
  });

  factory JobLevel.fromJson(Map<String, dynamic> json) => JobLevel(
        price: json['price'] as int,
        paid: json['paid'] as int,
        change: json['change'] as int,
      );
}

class Job {
  final String id;
  final String name;
  final String? description;
  final int coinReward;
  final int xpReward;
  final int durationSeconds;
  final int cooldownMinutes;
  final String? mechanics; // 'drag_coins' | 'income_expense_entry'
  final String? intro;
  final List<JobLevel> levels;
  final bool isActive;

  const Job({
    required this.id,
    required this.name,
    this.description,
    required this.coinReward,
    required this.xpReward,
    required this.durationSeconds,
    required this.cooldownMinutes,
    this.mechanics,
    this.intro,
    required this.levels,
    this.isActive = true,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    final instr = json['instructions'] as Map<String, dynamic>? ?? {};
    final rawLevels = instr['levels'] as List<dynamic>? ?? [];
    return Job(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      coinReward: json['coin_reward'] as int? ?? 0,
      xpReward: json['xp_reward'] as int? ?? 0,
      durationSeconds: json['duration_seconds'] as int? ?? 60,
      cooldownMinutes: json['cooldown_minutes'] as int? ?? 60,
      mechanics: instr['mechanics'] as String?,
      intro: instr['intro'] as String?,
      levels: rawLevels
          .map((l) => JobLevel.fromJson(l as Map<String, dynamic>))
          .toList(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
