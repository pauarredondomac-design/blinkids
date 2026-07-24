import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/wallet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Estado del demo — solo en memoria, nunca toca Supabase.
//
// Las pantallas reales (Trabajos, Misiones, Mercado, Tienda, Banco) se
// reutilizan tal cual para el demo: los repositorios consultan
// `DemoStore.isActive` y, si es true (no hay sesión real), leen/escriben
// aquí en vez de llamar a Supabase.
// ─────────────────────────────────────────────────────────────────────────────

class DemoStore extends ChangeNotifier {
  DemoStore._();
  static final DemoStore instance = DemoStore._();

  /// true cuando no hay usuario real con sesión (modo demo).
  static bool get isActive => Supabase.instance.client.auth.currentUser == null;

  int stage = 0; // 0=solo banco, 1=trabajos, 2=misiones, 3=mercado, 4=tienda, 5=completo
  int coins = 500;
  int xp = 0;
  int fuel = 0;
  String? pendingMessage;

  final Map<String, int> inventory = {};
  final Map<String, int> missionProgress = {};
  final Set<String> claimedMissions = {};
  final List<Map<String, dynamic>> listings = [];
  int _listingSeq = 0;

  // Tutoriales ya vistos en esta sesión demo
  final Set<String> seenTutorials = {};

  // Balances de las categorías de la bolsa (Guardar / Banco Estelar / Gastar)
  final Map<WalletCategoryType, int> walletCategoryBalances = {
    WalletCategoryType.guardar:       0,
    WalletCategoryType.banco_estelar: 0,
    WalletCategoryType.gastar:        0,
  };

  bool isUnlocked(String buildingId) {
    switch (buildingId) {
      case 'banco':    return true;
      case 'alcancia': return stage >= 3;
      case 'trabajos': return stage >= 1;
      case 'misiones': return stage >= 2;
      case 'mercado':  return stage >= 5; // mercado oculto, reservado para futuro
      case 'tienda':   return stage >= 4;
      default:         return false;
    }
  }

  String? get nextUnlock {
    switch (stage) {
      case 0: return 'Trabajos';
      case 1: return 'Misiones';
      case 2: return 'Mi Bolsa';
      case 3: return 'Tienda';
      default: return null;
    }
  }

  bool get isComplete => stage >= 5;

  void advanceStage() {
    stage++;
    notifyListeners();
  }

  void setPendingMessage(String message) {
    pendingMessage = message;
    notifyListeners();
  }

  void clearPendingMessage() {
    pendingMessage = null;
    notifyListeners();
  }

  void addCoins(int amount) {
    coins += amount;
    notifyListeners();
  }

  bool spendCoins(int amount) {
    if (coins < amount) return false;
    coins -= amount;
    notifyListeners();
    return true;
  }

  void addXp(int amount) {
    xp += amount;
    fuel = (xp ~/ 100).clamp(0, 100);
    notifyListeners();
  }

  int countOf(String itemId) => inventory[itemId] ?? 0;

  void addItem(String itemId, int qty) {
    inventory[itemId] = (inventory[itemId] ?? 0) + qty;
    notifyListeners();
  }

  bool removeItem(String itemId, int qty) {
    final have = inventory[itemId] ?? 0;
    if (have < qty) return false;
    final left = have - qty;
    if (left <= 0) {
      inventory.remove(itemId);
    } else {
      inventory[itemId] = left;
    }
    notifyListeners();
    return true;
  }

  void recordMissionAction(String type) {
    missionProgress[type] = (missionProgress[type] ?? 0) + 1;
    notifyListeners();
  }

  int progressFor(String type) => missionProgress[type] ?? 0;

  bool isMissionClaimed(String missionId) => claimedMissions.contains(missionId);

  void markMissionClaimed(String missionId) {
    claimedMissions.add(missionId);
    notifyListeners();
  }

  void markTutorialSeen(String key) {
    seenTutorials.add(key);
    // No notifyListeners — no rebuild needed for tutorial state
  }

  bool isTutorialSeen(String key) => seenTutorials.contains(key);

  /// Distribuye monedas entre el pool libre y una categoría de la bolsa.
  /// [categoryId] — 'demo_guardar' | 'demo_banco_estelar' | 'demo_gastar'
  void distributeCoins(String categoryId, int newCategoryBalance, int newWalletTotal) {
    final type = _categoryTypeFromId(categoryId);
    if (type != null) walletCategoryBalances[type] = newCategoryBalance;
    coins = newWalletTotal;
    notifyListeners();
  }

  /// Añade combustible directamente (desde distribución de monedas).
  void addFuelDirect(int amount) {
    fuel = (fuel + amount).clamp(0, 100);
    notifyListeners();
  }

  static WalletCategoryType? _categoryTypeFromId(String id) {
    if (id.contains('guardar'))       return WalletCategoryType.guardar;
    if (id.contains('banco_estelar')) return WalletCategoryType.banco_estelar;
    if (id.contains('gastar'))        return WalletCategoryType.gastar;
    return null;
  }

  String addListing({
    required String itemId,
    required int qty,
    required int pricePerUnit,
    required String sellerName,
  }) {
    final id = 'demo_listing_${_listingSeq++}';
    listings.add({
      'id': id,
      'itemId': itemId,
      'qty': qty,
      'pricePerUnit': pricePerUnit,
      'sellerName': sellerName,
    });
    notifyListeners();
    return id;
  }

  Map<String, dynamic>? removeListing(String listingId) {
    final idx = listings.indexWhere((l) => l['id'] == listingId);
    if (idx == -1) return null;
    final removed = listings.removeAt(idx);
    notifyListeners();
    return removed;
  }

  void reset() {
    stage = 0;
    coins = 500;
    xp = 0;
    fuel = 0;
    pendingMessage = null;
    inventory.clear();
    missionProgress.clear();
    claimedMissions.clear();
    listings.clear();
    seenTutorials.clear();
    walletCategoryBalances.updateAll((_, __) => 0);
    notifyListeners();
  }
}

final demoProgressProvider = ChangeNotifierProvider<DemoStore>(
  (ref) => DemoStore.instance,
);
