import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/wallet.dart';
import '../../data/repositories/wallet_repository.dart';
import 'auth_provider.dart';

final walletRepositoryProvider = Provider<WalletRepository>(
  (_) => WalletRepository(),
);

/// Cartera del usuario autenticado.
final currentWalletProvider = FutureProvider<Wallet?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.read(walletRepositoryProvider).getWallet(user.id);
});

/// Categorías de la bolsa del niño.
/// Auto-crea wallet + categorías si el usuario no las tiene aún.
final walletCategoriesProvider = FutureProvider<List<WalletCategory>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final repo = ref.read(walletRepositoryProvider);

  // getOrCreateWallet garantiza que siempre haya un wallet para el usuario.
  final wallet = await repo.getOrCreateWallet(user.id);

  // getCategories auto-seed las 3 categorías si aún no existen.
  return repo.getCategories(wallet.id);
});
