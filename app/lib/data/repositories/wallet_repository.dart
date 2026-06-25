import '../models/wallet.dart';
import '../services/supabase_service.dart';

class WalletRepository {
  /// Crea la cartera y las 5 categorías del niño en una sola operación.
  Future<Wallet> createWallet(String userId) async {
    final data = await supabase
        .from('wallets')
        .insert({'user_id': userId})
        .select()
        .single();
    final wallet = Wallet.fromJson(data);

    // 3 categorías: guardar, banco_estelar, gastar
    await supabase.from('wallet_categories').insert(
          WalletCategoryType.values
              .map((cat) => {
                    'wallet_id': wallet.id,
                    'category': cat.name,
                    'balance': 0,
                  })
              .toList(),
        );

    return wallet;
  }

  Future<Wallet?> getWallet(String userId) async {
    final data = await supabase
        .from('wallets')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return data != null ? Wallet.fromJson(data) : null;
  }

  /// Devuelve el wallet existente o lo crea si aún no existe.
  /// Seguro llamarlo varias veces (no duplica por UNIQUE user_id).
  Future<Wallet> getOrCreateWallet(String userId) async {
    return await getWallet(userId) ?? await createWallet(userId);
  }

  Future<List<WalletCategory>> getCategories(String walletId) async {
    var data = await supabase
        .from('wallet_categories')
        .select()
        .eq('wallet_id', walletId)
        .order('category');

    // Auto-seed si las 3 categorías no existen aún (registro incompleto).
    if ((data as List).isEmpty) {
      await supabase.from('wallet_categories').insert(
            WalletCategoryType.values
                .map((cat) => {
                      'wallet_id': walletId,
                      'category': cat.name,
                      'balance': 0,
                    })
                .toList(),
          );
      data = await supabase
          .from('wallet_categories')
          .select()
          .eq('wallet_id', walletId)
          .order('category');
    }

    return (data as List).map((e) => WalletCategory.fromJson(e)).toList();
  }

  /// Mueve monedas entre el pool libre y una categoría.
  Future<void> distributeCoins({
    required String categoryId,
    required int newCategoryBalance,
    required String walletId,
    required int newWalletTotal,
  }) async {
    await supabase
        .from('wallet_categories')
        .update({'balance': newCategoryBalance})
        .eq('id', categoryId);
    await supabase
        .from('wallets')
        .update({'total_coins': newWalletTotal})
        .eq('id', walletId);
  }

  /// Suma monedas al wallet del usuario actual de forma atómica (recompensa).
  /// Llama al RPC award_coins (SECURITY DEFINER). El parámetro userId se
  /// mantiene por compatibilidad pero el RPC siempre usa auth.uid().
  Future<void> awardStarterCoins(String userId, int amount) async {
    await supabase.rpc('award_coins', params: {'p_amount': amount});
  }

  /// Descuenta monedas del wallet del usuario actual de forma atómica.
  /// Llama al RPC spend_coins (SECURITY DEFINER) que hace UPDATE atómico
  /// en una sola sentencia SQL: no hay race condition entre SELECT y UPDATE.
  /// Devuelve false si el saldo es insuficiente (sin modificar nada).
  Future<bool> spendCoins(String userId, int amount) async {
    // userId se ignora: el RPC usa auth.uid() internamente.
    // Se mantiene el parámetro para compatibilidad con llamadas existentes.
    final result = await supabase.rpc(
      'spend_coins',
      params: {'p_amount': amount},
    );
    return (result as int) >= 0; // -1 = saldo insuficiente
  }

  /// Transfiere monedas del padre (usuario actual) al hijo con validación
  /// server-side de que el vínculo padre-hijo existe.
  /// La operación es atómica: descuenta del padre, suma al hijo e inserta
  /// la notificación en una sola transacción PostgreSQL.
  /// Lanza excepción si el padre no está vinculado con el hijo o si
  /// no tiene suficiente saldo.
  Future<void> transferCoinsToChild(String childId, int amount) async {
    await supabase.rpc(
      'transfer_coins_to_child',
      params: {
        'p_child_id': childId,
        'p_amount':   amount,
      },
    );
  }

  /// Compra atómica de un mundo: descuenta el costo y registra world_progress
  /// en una sola transacción. No puede quedarse a medias.
  /// Lanza excepción si las monedas son insuficientes o el mundo no existe.
  Future<void> purchaseWorld(String worldSlug) async {
    await supabase.rpc(
      'purchase_world',
      params: {'p_world_slug': worldSlug},
    );
  }

  /// Mueve monedas entre categorías de la bolsa del niño.
  /// Llama a una Edge Function para que la transacción sea atómica.
  Future<void> moveCoins({
    required String userId,
    required String fromCategoryId,
    required String toCategoryId,
    required int amount,
  }) async {
    await supabase.functions.invoke('move-coins', body: {
      'user_id': userId,
      'from_category_id': fromCategoryId,
      'to_category_id': toCategoryId,
      'amount': amount,
    });
  }
}
