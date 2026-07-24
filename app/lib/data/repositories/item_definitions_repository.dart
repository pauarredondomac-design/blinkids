import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/item.dart';

class ItemDefinitionsRepository {
  static final _client = Supabase.instance.client;

  /// Devuelve todos los ítems activos desde Supabase.
  /// Si falla (offline / demo / RLS), devuelve el catálogo hardcodeado.
  static Future<List<Item>> getAll() async {
    try {
      final rows = await _client
          .from('item_definitions')
          .select()
          .eq('active', true)
          .order('world')
          .order('shop_price');
      final list = rows as List;
      if (list.isEmpty) return allItems;
      return list.map((r) => Item.fromJson(r as Map<String, dynamic>)).toList();
    } catch (_) {
      return allItems;
    }
  }

  /// Filtra por mundo (incluye ítems 'any').
  static Future<List<Item>> getForWorld(String worldId) async {
    final all = await getAll();
    return all.where((i) => i.world == worldId || i.world == 'any').toList();
  }

  /// Solo los que tienen precio > 0 (vendibles en tienda).
  static Future<List<Item>> getShopItemsForWorld(String worldId) async {
    final items = await getForWorld(worldId);
    return items.where((i) => i.availableInShop).toList();
  }
}
