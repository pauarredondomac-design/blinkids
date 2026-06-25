import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/item.dart';
import '../../data/repositories/item_repository.dart';

final itemRepositoryProvider = Provider<ItemRepository>(
  (_) => ItemRepository(),
);

/// Lista de stacks del inventario del jugador.
/// Se invalida manualmente tras comprar o usar ítems.
final inventoryProvider = FutureProvider<List<InventoryStack>>((ref) async {
  return ref.read(itemRepositoryProvider).getInventory();
});

/// Listings de la tienda personal del jugador.
final myListingsProvider = FutureProvider<List<PlayerListing>>((ref) async {
  return ref.read(itemRepositoryProvider).getMyListings();
});
