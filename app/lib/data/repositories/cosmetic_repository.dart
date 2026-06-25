import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cosmetic.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CosmeticRepository
// ─────────────────────────────────────────────────────────────────────────────
class CosmeticRepository {
  SupabaseClient get _db => Supabase.instance.client;

  // ── Catálogo ────────────────────────────────────────────────────────────────

  Future<List<CosmeticDefinition>> getAll() async {
    try {
      final rows = await _db
          .from('cosmetic_definitions')
          .select()
          .order('slot')
          .order('price');
      return (rows as List)
          .map((r) => CosmeticDefinition.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<CosmeticDefinition>> getForSlot(CosmeticSlot slot) async {
    try {
      final rows = await _db
          .from('cosmetic_definitions')
          .select()
          .eq('slot', slot.id)
          .order('price');
      return (rows as List)
          .map((r) => CosmeticDefinition.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Inventario del jugador ──────────────────────────────────────────────────

  Future<List<CosmeticDefinition>> getOwned() async {
    try {
      final rows = await _db
          .from('player_cosmetics')
          .select('cosmetic_id, obtained_at, cosmetic_definitions(*)')
          .order('obtained_at', ascending: false);
      return (rows as List).map((r) {
        final def = r['cosmetic_definitions'] as Map<String, dynamic>?;
        if (def == null) return null;
        return CosmeticDefinition.fromJson(def);
      }).whereType<CosmeticDefinition>().toList();
    } catch (_) {
      return [];
    }
  }

  Future<Set<String>> getOwnedIds() async {
    try {
      final rows = await _db
          .from('player_cosmetics')
          .select('cosmetic_id');
      return (rows as List).map((r) => r['cosmetic_id'] as String).toSet();
    } catch (_) {
      return {};
    }
  }

  // ── Equipamiento actual ─────────────────────────────────────────────────────

  Future<EquippedLoadout> getEquipped() async {
    try {
      final rows = await _db
          .from('character_equipped')
          .select('slot, cosmetic_id, cosmetic_definitions(*)');

      final map = <String, CosmeticDefinition?>{};
      for (final r in rows as List) {
        final slot = r['slot'] as String;
        final def  = r['cosmetic_definitions'] as Map<String, dynamic>?;
        map[slot]  = def != null ? CosmeticDefinition.fromJson(def) : null;
      }
      return EquippedLoadout(map);
    } catch (_) {
      return EquippedLoadout.empty;
    }
  }

  // ── Acciones ────────────────────────────────────────────────────────────────

  /// Compra un cosmético: descuenta monedas y registra propiedad.
  Future<int> buy(String cosmeticId) async {
    final result = await _db.rpc('buy_cosmetic', params: {'p_cosmetic_id': cosmeticId});
    return (result as Map<String, dynamic>?)?['balance'] as int? ?? 0;
  }

  /// Equipa un cosmético que el jugador ya posee.
  Future<void> equip(String cosmeticId) async {
    await _db.rpc('equip_cosmetic', params: {'p_cosmetic_id': cosmeticId});
  }

  /// Desequipa el cosmético del slot indicado.
  Future<void> unequip(CosmeticSlot slot) async {
    await _db.rpc('unequip_cosmetic', params: {'p_slot': slot.id});
  }
}
