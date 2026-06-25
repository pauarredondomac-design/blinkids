import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/fuel.dart';
import '../../data/repositories/fuel_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FuelRepository singleton
// ─────────────────────────────────────────────────────────────────────────────
final fuelRepositoryProvider = Provider<FuelRepository>(
  (_) => FuelRepository(),
);

// ─────────────────────────────────────────────────────────────────────────────
// Fuel del mundo espacio (el que usa la barra de combustible en el HUD)
// ─────────────────────────────────────────────────────────────────────────────
final spaceFuelProvider = FutureProvider<WorldFuel?>((ref) async {
  return ref.read(fuelRepositoryProvider).getFuel('space');
});

// ─────────────────────────────────────────────────────────────────────────────
// FuelNotifier — gestiona acciones de combustible
// ─────────────────────────────────────────────────────────────────────────────
class FuelNotifier extends Notifier<AsyncValue<int>> {
  @override
  AsyncValue<int> build() => const AsyncValue.loading();

  Future<bool> addFuel(String worldSlug, int amount) async {
    final repo = ref.read(fuelRepositoryProvider);
    final reached100 = await repo.addFuel(worldSlug, amount);
    // Invalidar para refrescar la UI
    ref.invalidate(spaceFuelProvider);
    return reached100;
  }

  Future<void> resetFuel(String worldSlug) async {
    await ref.read(fuelRepositoryProvider).resetFuel(worldSlug);
    ref.invalidate(spaceFuelProvider);
  }

  /// Registra actividad diaria (llamar al arrancar la app o al entrar al mapa).
  /// Devuelve el JSON con streak, milestone_coins, fuel_added.
  Future<Map<String, dynamic>> recordDailyActivity() async {
    final result = await ref.read(fuelRepositoryProvider).recordDailyActivity();
    ref.invalidate(spaceFuelProvider);
    return result;
  }
}

final fuelNotifierProvider = NotifierProvider<FuelNotifier, AsyncValue<int>>(
  FuelNotifier.new,
);
