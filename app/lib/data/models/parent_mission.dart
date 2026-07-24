enum ParentMissionStatus { pending, completed, cancelled }

/// Misión que un padre/madre crea para un hijo vinculado, con recompensa
/// en monedas pagada desde la billetera del propio padre.
class ParentMission {
  const ParentMission({
    required this.id,
    required this.parentId,
    required this.childId,
    required this.title,
    this.description,
    required this.coinReward,
    required this.status,
    required this.createdAt,
    this.completedAt,
  });

  final String              id;
  final String              parentId;
  final String              childId;
  final String              title;
  final String?             description;
  final int                 coinReward;
  final ParentMissionStatus status;
  final DateTime            createdAt;
  final DateTime?           completedAt;

  bool get isPending   => status == ParentMissionStatus.pending;
  bool get isCompleted => status == ParentMissionStatus.completed;

  factory ParentMission.fromJson(Map<String, dynamic> json) {
    return ParentMission(
      id:          json['id'] as String,
      parentId:    json['parent_id'] as String,
      childId:     json['child_id'] as String,
      title:       json['title'] as String,
      description: json['description'] as String?,
      coinReward:  json['coin_reward'] as int,
      status: ParentMissionStatus.values.firstWhere(
        (s) => s.name == (json['status'] as String? ?? 'pending'),
        orElse: () => ParentMissionStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }
}
