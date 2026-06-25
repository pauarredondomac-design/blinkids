import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/cosmetic.dart';
import '../../data/repositories/cosmetic_repository.dart';

final _repo = CosmeticRepository();

// ── Catálogo de cosméticos ─────────────────────────────────────────────────────
final cosmeticCatalogProvider = FutureProvider<List<CosmeticDefinition>>((ref) async {
  return _repo.getAll();
});

// ── Cosméticos que el jugador posee ───────────────────────────────────────────
final ownedCosmeticsProvider = FutureProvider<List<CosmeticDefinition>>((ref) async {
  return _repo.getOwned();
});

// ── IDs de cosméticos poseídos (para chequeo rápido) ──────────────────────────
final ownedCosmeticIdsProvider = FutureProvider<Set<String>>((ref) async {
  return _repo.getOwnedIds();
});

// ── Equipamiento actual del jugador ───────────────────────────────────────────
final equippedLoadoutProvider = FutureProvider<EquippedLoadout>((ref) async {
  return _repo.getEquipped();
});

// ── Notifier para comprar cosméticos ──────────────────────────────────────────
class CosmeticShopNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Compra el cosmético y refresca los providers relevantes.
  /// Lanza excepción si no hay monedas o ya lo tiene.
  Future<void> buy(String cosmeticId) async {
    state = const AsyncLoading();
    try {
      await _repo.buy(cosmeticId);
      ref.invalidate(ownedCosmeticsProvider);
      ref.invalidate(ownedCosmeticIdsProvider);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Equipa el cosmético y refresca el equipamiento.
  Future<void> equip(String cosmeticId) async {
    state = const AsyncLoading();
    try {
      await _repo.equip(cosmeticId);
      ref.invalidate(equippedLoadoutProvider);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Desequipa el slot y refresca el equipamiento.
  Future<void> unequip(CosmeticSlot slot) async {
    state = const AsyncLoading();
    try {
      await _repo.unequip(slot);
      ref.invalidate(equippedLoadoutProvider);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final cosmeticShopProvider =
    AsyncNotifierProvider<CosmeticShopNotifier, void>(CosmeticShopNotifier.new);
