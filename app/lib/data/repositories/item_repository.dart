import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/item.dart';
import '../../shared/providers/demo_progress_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ItemRepository
// Gestiona el inventario del jugador y su tienda personal.
//
// SEGURIDAD: los ítems se almacenan en Supabase (tablas player_items y
// player_market_listings, migración 018) con RLS activo.
// Las operaciones de agregar/quitar usan los RPCs add_player_item y
// remove_player_item (SECURITY DEFINER) para garantizar atomicidad y evitar
// inconsistencias por acceso concurrente o manipulación desde clientes externos.
// ─────────────────────────────────────────────────────────────────────────────
class ItemRepository {
  final _client = Supabase.instance.client;

  // ── Inventario ──────────────────────────────────────────────────────────

  Future<int> countOf(String itemId) async {
    if (DemoStore.isActive) return DemoStore.instance.countOf(itemId);
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return 0;

      final row = await _client
          .from('player_items')
          .select('qty')
          .eq('user_id', userId)
          .eq('item_id', itemId)
          .maybeSingle();

      return (row?['qty'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<List<InventoryStack>> getInventory() async {
    if (DemoStore.isActive) {
      return DemoStore.instance.inventory.entries
          .map((e) {
            final item = itemById(e.key);
            if (item == null) return null;
            return InventoryStack(item: item, qty: e.value);
          })
          .whereType<InventoryStack>()
          .toList();
    }
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      final rows = await _client
          .from('player_items')
          .select('item_id, qty')
          .eq('user_id', userId)
          .gt('qty', 0);

      return (rows as List)
          .map((r) {
            final item = itemById(r['item_id'] as String);
            if (item == null) return null;
            return InventoryStack(item: item, qty: r['qty'] as int);
          })
          .whereType<InventoryStack>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Agrega qty unidades al inventario usando el RPC add_player_item (atómico).
  Future<void> addToInventory(String itemId, int qty) async {
    if (DemoStore.isActive) {
      DemoStore.instance.addItem(itemId, qty);
      return;
    }
    await _client.rpc(
      'add_player_item',
      params: {'p_item_id': itemId, 'p_qty': qty},
    );
  }

  /// Quita qty unidades del inventario usando el RPC remove_player_item (atómico).
  /// Lanza excepción si no hay suficiente.
  Future<void> removeFromInventory(String itemId, int qty) async {
    if (DemoStore.isActive) {
      final ok = DemoStore.instance.removeItem(itemId, qty);
      if (!ok) throw Exception('No hay suficientes materiales');
      return;
    }
    await _client.rpc(
      'remove_player_item',
      params: {'p_item_id': itemId, 'p_qty': qty},
    );
  }

  /// Devuelve true si el jugador tiene todos los materiales requeridos.
  Future<bool> hasRequirements(List<ItemRequirement> requirements) async {
    for (final req in requirements) {
      if (await countOf(req.itemId) < req.qty) return false;
    }
    return true;
  }

  /// Consume todos los materiales de la lista (llama [hasRequirements] antes).
  Future<void> consumeRequirements(List<ItemRequirement> requirements) async {
    for (final req in requirements) {
      await removeFromInventory(req.itemId, req.qty);
    }
  }

  // ── Tienda personal del jugador (hasta 10 listings) ────────────────────

  static const int maxListings = 10;

  Future<List<PlayerListing>> getMyListings() async {
    if (DemoStore.isActive) {
      return DemoStore.instance.listings
          .map((l) => PlayerListing(
                id: l['id'] as String,
                itemId: l['itemId'] as String,
                qty: l['qty'] as int,
                pricePerUnit: l['pricePerUnit'] as int,
                sellerName: l['sellerName'] as String,
              ))
          .toList();
    }
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      final rows = await _client
          .from('player_market_listings')
          .select('id, item_id, qty, price_per_unit, seller_name')
          .eq('seller_id', userId)
          .order('created_at', ascending: false);

      return (rows as List)
          .map((r) => PlayerListing(
                id: r['id'] as String,
                itemId: r['item_id'] as String,
                qty: r['qty'] as int,
                pricePerUnit: r['price_per_unit'] as int,
                sellerName: r['seller_name'] as String,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> addListing({
    required String itemId,
    required int qty,
    required int pricePerUnit,
    required String sellerName,
  }) async {
    if (DemoStore.isActive) {
      final existing = DemoStore.instance.listings;
      if (existing.length >= maxListings) return false;
      final ok = DemoStore.instance.removeItem(itemId, qty);
      if (!ok) throw Exception('No hay suficientes materiales');
      DemoStore.instance.addListing(
        itemId: itemId,
        qty: qty,
        pricePerUnit: pricePerUnit,
        sellerName: sellerName,
      );
      return true;
    }
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    final existing = await getMyListings();
    if (existing.length >= maxListings) return false;

    // Descuenta del inventario (atómico; lanza si no hay suficiente)
    await removeFromInventory(itemId, qty);

    await _client.from('player_market_listings').insert({
      'seller_id': userId,
      'seller_name': sellerName,
      'item_id': itemId,
      'qty': qty,
      'price_per_unit': pricePerUnit,
    });

    return true;
  }

  Future<void> removeListing(String listingId) async {
    if (DemoStore.isActive) {
      final removed = DemoStore.instance.removeListing(listingId);
      if (removed != null) {
        DemoStore.instance
            .addItem(removed['itemId'] as String, removed['qty'] as int);
      }
      return;
    }
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    // Recuperar el listing antes de borrarlo para devolver ítems al inventario
    final row = await _client
        .from('player_market_listings')
        .select('item_id, qty')
        .eq('id', listingId)
        .eq('seller_id', userId) // solo puede borrar el propio vendedor
        .maybeSingle();

    if (row != null) {
      await addToInventory(row['item_id'] as String, row['qty'] as int);
    }

    await _client
        .from('player_market_listings')
        .delete()
        .eq('id', listingId)
        .eq('seller_id', userId);
  }

  // ── Tienda de exploración (datos de otros jugadores del mercado) ────────

  Future<List<PlayerListing>> getMarketListings(String worldId) async {
    try {
      final userId = _client.auth.currentUser?.id;

      final worldItems = shopItemsForWorld(worldId).map((i) => i.id).toList();
      if (worldItems.isEmpty) return [];

      // Los filtros deben aplicarse ANTES de order/limit
      var base = _client
          .from('player_market_listings')
          .select('id, item_id, qty, price_per_unit, seller_name')
          .inFilter('item_id', worldItems);

      // Excluir los propios listings del jugador si está autenticado
      if (userId != null) {
        base = base.neq('seller_id', userId);
      }

      final rows = await base.order('created_at', ascending: false).limit(20);
      return (rows as List)
          .map((r) => PlayerListing(
                id: r['id'] as String,
                itemId: r['item_id'] as String,
                qty: r['qty'] as int,
                pricePerUnit: r['price_per_unit'] as int,
                sellerName: r['seller_name'] as String,
              ))
          .toList();
    } catch (_) {
      // Si la tabla está vacía o hay error de red, mostrar listings de muestra
      return _sampleListings(worldId);
    }
  }

  /// Listings de muestra para cuando el mercado está vacío.
  List<PlayerListing> _sampleListings(String worldId) {
    final worldItems = shopItemsForWorld(worldId);
    if (worldItems.isEmpty) return [];

    final sellers = [
      'Zorro Astuto',
      'Ardilla Pro',
      'Oso Trader',
      'Búho Rico',
      'Conejo Veloz',
      'Lobo Mercante',
      'Ciervo Sabio',
      'Mapache Listo',
    ];
    final result = <PlayerListing>[];
    for (var i = 0; i < worldItems.length && i < sellers.length; i++) {
      final item = worldItems[i % worldItems.length];
      final mult = 0.9 + (i % 4) * 0.15;
      result.add(PlayerListing(
        id: 'sample_$i',
        itemId: item.id,
        qty: (i % 3) + 1,
        pricePerUnit: (item.shopPrice * mult).round(),
        sellerName: sellers[i],
      ));
    }
    return result;
  }
}
