import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/salary.dart';
import '../../data/repositories/salary_repository.dart';

final salaryRepositoryProvider = Provider<SalaryRepository>(
  (_) => SalaryRepository(),
);

// ─── Estado del salario para el niño ─────────────────────────────────────────
final mySalaryStatusProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(salaryRepositoryProvider).getMyStatus();
});

// ─── Lista de salarios asignados por el padre ─────────────────────────────────
final parentSalariesProvider = FutureProvider<List<WeeklySalary>>((ref) async {
  return ref.read(salaryRepositoryProvider).getSalariesByParent();
});

// ─── Notifier para cobrar salario ────────────────────────────────────────────
class SalaryNotifier extends AsyncNotifier<SalaryClaimResult?> {
  @override
  Future<SalaryClaimResult?> build() async => null;

  Future<SalaryClaimResult> claim() async {
    state = const AsyncValue.loading();
    final result =
        await ref.read(salaryRepositoryProvider).claimSalary();
    state = AsyncValue.data(result);
    ref.invalidate(mySalaryStatusProvider);
    return result;
  }
}

final salaryNotifierProvider =
    AsyncNotifierProvider<SalaryNotifier, SalaryClaimResult?>(
  SalaryNotifier.new,
);
