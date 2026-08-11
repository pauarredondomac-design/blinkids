import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/wallet.dart';
import '../../data/repositories/wallet_repository.dart';
import 'auth_provider.dart';
import 'demo_progress_provider.dart';

final walletRepositoryProvider = Provider<WalletRepository>(
  (_) => WalletRepository(),
);

/// Cartera del usuario autenticado (o stub en demo).
///
/// IMPORTANTE: `ref.watch(currentUserProvider)` se llama SIEMPRE primero,
/// sin importar la rama. Si se condiciona antes con `DemoStore.isActive`
/// (un getter plano, no reactivo), Riverpod nunca registra la dependencia
/// de auth cuando arranca en modo demo — y el provider se queda pegado
/// mostrando el wallet demo para siempre, incluso después de iniciar
/// sesión de verdad (bug real que causaba "monedas siempre en 500").
final currentWalletProvider = StreamProvider<Wallet?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    // Rebuild reactivamente cuando cambien las monedas demo.
    final coins = ref.watch(demoProgressProvider).coins;
    return Stream.value(Wallet(
      id: 'demo',
      userId: 'demo',
      totalCoins: coins,
      realBalanceCents: 0,
      createdAt: DateTime(2024),
      updatedAt: DateTime.now(),
    ));
  }
  // Stream en vivo (Supabase Realtime): si el papá manda monedas, o se
  // aprueba una misión, o cae el interés semanal, el saldo se actualiza
  // solo en pantalla, sin que el niño tenga que salir y volver a entrar.
  return ref.read(walletRepositoryProvider).watchWallet(user.id);
});

/// Categorías de la bolsa del niño (o categorías demo en memoria).
/// Mismo cuidado que arriba: `currentUserProvider` se observa primero.
final walletCategoriesProvider =
    FutureProvider<List<WalletCategory>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    ref.watch(demoProgressProvider); // rebuild cuando cambien balances
    final balances = DemoStore.instance.walletCategoryBalances;
    final now = DateTime.now();
    return [
      WalletCategory(
          id: 'demo_guardar',
          walletId: 'demo',
          category: WalletCategoryType.guardar,
          balance: balances[WalletCategoryType.guardar] ?? 0,
          updatedAt: now),
      WalletCategory(
          id: 'demo_invertir',
          walletId: 'demo',
          category: WalletCategoryType.invertir,
          balance: balances[WalletCategoryType.invertir] ?? 0,
          updatedAt: now),
      WalletCategory(
          id: 'demo_donar',
          walletId: 'demo',
          category: WalletCategoryType.donar,
          balance: balances[WalletCategoryType.donar] ?? 0,
          updatedAt: now),
      WalletCategory(
          id: 'demo_gastar',
          walletId: 'demo',
          category: WalletCategoryType.gastar,
          balance: balances[WalletCategoryType.gastar] ?? 0,
          updatedAt: now),
    ];
  }

  final repo = ref.read(walletRepositoryProvider);
  final wallet = await repo.getOrCreateWallet(user.id);
  return repo.getCategories(wallet.id);
});
