// ─────────────────────────────────────────────────────────────────────────────
// Catálogo visual de metas del Banco Estelar — el niño elige UNA, nunca
// escribe texto libre (ver documento maestro, sección "Catálogo visual de metas").
// ─────────────────────────────────────────────────────────────────────────────
class SavingsGoalOption {
  const SavingsGoalOption({
    required this.key,
    required this.name,
    required this.emoji,
    required this.cost,
  });

  final String key;
  final String name;
  final String emoji;
  final int cost;
}

const savingsGoalCatalog = <SavingsGoalOption>[
  SavingsGoalOption(key: 'bici', name: 'Bicicleta', emoji: '🚲', cost: 500),
  SavingsGoalOption(key: 'consola', name: 'Consola', emoji: '🎮', cost: 900),
  SavingsGoalOption(key: 'balon', name: 'Balón', emoji: '⚽', cost: 300),
  SavingsGoalOption(
      key: 'audifonos', name: 'Audífonos', emoji: '🎧', cost: 400),
  SavingsGoalOption(key: 'patin', name: 'Patín', emoji: '🛴', cost: 350),
  SavingsGoalOption(key: 'mascota', name: 'Mascota', emoji: '🐶', cost: 800),
  SavingsGoalOption(key: 'libros', name: 'Libros', emoji: '📚', cost: 250),
  SavingsGoalOption(key: 'mochila', name: 'Mochila', emoji: '🎒', cost: 300),
];

// ─────────────────────────────────────────────────────────────────────────────
// ChildGoal — la meta activa (o cumplida) de un niño.
// ─────────────────────────────────────────────────────────────────────────────
class ChildGoal {
  const ChildGoal({
    required this.goalKey,
    required this.goalName,
    required this.goalEmoji,
    required this.goalCost,
    required this.chosenAt,
    this.completedAt,
  });

  final String goalKey;
  final String goalName;
  final String goalEmoji;
  final int goalCost;
  final DateTime chosenAt;
  final DateTime? completedAt;

  bool get isCompleted => completedAt != null;

  factory ChildGoal.fromJson(Map<String, dynamic> json) {
    return ChildGoal(
      goalKey: json['goal_key'] as String,
      goalName: json['goal_name'] as String,
      goalEmoji: json['goal_emoji'] as String,
      goalCost: json['goal_cost'] as int,
      chosenAt: DateTime.parse(json['chosen_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }
}
