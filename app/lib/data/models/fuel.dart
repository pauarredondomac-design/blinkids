// ─────────────────────────────────────────────────────────────────────────────
// WorldFuel  — progreso de la barra de combustible por mundo
// ─────────────────────────────────────────────────────────────────────────────

class WorldFuel {
  final String userId;
  final String worldSlug;
  final int fuel; // 0-100
  final int cycle; // se incrementa al completar 100%
  final DateTime updatedAt;

  const WorldFuel({
    required this.userId,
    required this.worldSlug,
    required this.fuel,
    required this.cycle,
    required this.updatedAt,
  });

  factory WorldFuel.fromJson(Map<String, dynamic> j) => WorldFuel(
        userId: j['user_id'] as String,
        worldSlug: j['world_slug'] as String,
        fuel: j['fuel'] as int? ?? 0,
        cycle: j['cycle'] as int? ?? 1,
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );

  /// Progreso normalizado 0.0 – 1.0
  double get progress => fuel / 100.0;

  /// ¿El combustible llegó al 100%?
  bool get isFull => fuel >= 100;
}
