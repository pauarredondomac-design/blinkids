import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/cosmetic.dart';
import '../../data/repositories/cosmetic_repository.dart';
import 'auth_provider.dart';

final _repo = CosmeticRepository();

// ── Catálogo de cosméticos ─────────────────────────────────────────────────────
final cosmeticCatalogProvider = FutureProvider<List<CosmeticDefinition>>((ref) async {
  return _repo.getAll();
});

// ── Solo cosméticos vendibles en la tienda ────────────────────────────────────
final cosmeticsInShopProvider = FutureProvider<List<CosmeticDefinition>>((ref) async {
  ref.keepAlive();
  return _repo.getInShop();
});

// ── Cosméticos que el jugador posee ───────────────────────────────────────────
final ownedCosmeticsProvider = FutureProvider<List<CosmeticDefinition>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return _repo.getOwned();
});

// ── IDs de cosméticos poseídos (para chequeo rápido) ──────────────────────────
final ownedCosmeticIdsProvider = FutureProvider<Set<String>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {};
  return _repo.getOwnedIds();
});

// ── Equipamiento actual del jugador ───────────────────────────────────────────
final equippedLoadoutProvider = FutureProvider<EquippedLoadout>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return EquippedLoadout.empty;
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
