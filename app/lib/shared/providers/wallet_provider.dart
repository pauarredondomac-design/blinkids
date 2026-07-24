import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/wallet.dart';
import '../../data/repositories/wallet_repository.dart';
import 'auth_provider.dart';
import 'demo_progress_provider.dart';

final walletRepositoryProvider = Provider<WalletRepository>(
  (_) => WalletRepository(),
);

/// Cartera del usuario autenticado (o stub en demo).
final currentWalletProvider = FutureProvider<Wallet?>((ref) async {
  if (DemoStore.isActive) {
    // Rebuild reactivamente cuando cambien las monedas demo.
    final coins = ref.watch(demoProgressProvider).coins;
    return Wallet(
      id: 'demo',
      userId: 'demo',
      totalCoins: coins,
      realBalanceCents: 0,
      createdAt: DateTime(2024),
      updatedAt: DateTime.now(),
    );
  }
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.read(walletRepositoryProvider).getWallet(user.id);
});

/// Categorías de la bolsa del niño (o categorías demo en memoria).
final walletCategoriesProvider = FutureProvider<List<WalletCategory>>((ref) async {
  if (DemoStore.isActive) {
    ref.watch(demoProgressProvider); // rebuild cuando cambien balances
    final balances = DemoStore.instance.walletCategoryBalances;
    final now = DateTime.now();
    return [
      WalletCategory(id: 'demo_guardar',       walletId: 'demo', category: WalletCategoryType.guardar,       balance: balances[WalletCategoryType.guardar]       ?? 0, updatedAt: now),
      WalletCategory(id: 'demo_banco_estelar',  walletId: 'demo', category: WalletCategoryType.banco_estelar, balance: balances[WalletCategoryType.banco_estelar] ?? 0, updatedAt: now),
      WalletCategory(id: 'demo_gastar',         walletId: 'demo', category: WalletCategoryType.gastar,        balance: balances[WalletCategoryType.gastar]        ?? 0, updatedAt: now),
    ];
  }

  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final repo = ref.read(walletRepositoryProvider);
  final wallet = await repo.getOrCreateWallet(user.id);
  return repo.getCategories(wallet.id);
});
