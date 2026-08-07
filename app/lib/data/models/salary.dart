// ─────────────────────────────────────────────────────────────────────────────
// WeeklySalary  — salario semanal asignado por el padre al hijo
// ─────────────────────────────────────────────────────────────────────────────

class WeeklySalary {
  final String id;
  final String parentId;
  final String childId;
  final int amount; // 20-35 monedas Blink
  final bool isActive;
  final DateTime? lastPaidAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WeeklySalary({
    required this.id,
    required this.parentId,
    required this.childId,
    required this.amount,
    required this.isActive,
    this.lastPaidAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WeeklySalary.fromJson(Map<String, dynamic> j) => WeeklySalary(
        id: j['id'] as String,
        parentId: j['parent_id'] as String,
        childId: j['child_id'] as String,
        amount: j['amount'] as int? ?? 25,
        isActive: j['is_active'] as bool? ?? true,
        lastPaidAt: j['last_paid_at'] != null
            ? DateTime.parse(j['last_paid_at'] as String)
            : null,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );

  /// ¿Ya se cobró esta semana?
  bool get claimedThisWeek {
    if (lastPaidAt == null) return false;
    final weekStart = _weekStart(DateTime.now());
    return lastPaidAt!.isAfter(weekStart) ||
        lastPaidAt!.isAtSameMomentAs(weekStart);
  }

  static DateTime _weekStart(DateTime d) {
    final monday = d.subtract(Duration(days: d.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }
}

// ─── Resultado del claim ─────────────────────────────────────────────────────
class SalaryClaimResult {
  final bool alreadyClaimed;
  final int amount;
  final int fuelAdded;
  final String? error;

  const SalaryClaimResult({
    required this.alreadyClaimed,
    required this.amount,
    required this.fuelAdded,
    this.error,
  });

  factory SalaryClaimResult.fromJson(Map<String, dynamic> j) {
    if (j.containsKey('error')) {
      return SalaryClaimResult(
        alreadyClaimed: false,
        amount: 0,
        fuelAdded: 0,
        error: j['error'] as String?,
      );
    }
    return SalaryClaimResult(
      alreadyClaimed: j['already_claimed'] as bool? ?? false,
      amount: j['amount'] as int? ?? 0,
      fuelAdded: j['fuel_added'] as int? ?? 0,
    );
  }
}
