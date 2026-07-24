import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/badge.dart';
import '../../data/repositories/badge_repository.dart';
import 'auth_provider.dart';

final _repo = BadgeRepository();

// ── Medallas del jugador actual ───────────────────────────────────────────────
final playerBadgesProvider = FutureProvider<List<PlayerBadge>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return _repo.getBadges();
});

// ── Catálogo completo de medallas ─────────────────────────────────────────────
final badgeDefinitionsProvider = FutureProvider<List<BadgeDefinition>>((ref) async {
  return _repo.getAllDefinitions();
});

// ── Notifier que comprueba y otorga medallas ──────────────────────────────────
// Se llama con ref.read(badgeCheckerProvider.notifier).check() después de
// cualquier acción relevante (subir XP, completar misión, etc.).
// Devuelve los IDs de las medallas recién ganadas.
class BadgeCheckerNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async => [];

  Future<List<String>> check() async {
    state = const AsyncLoading();
    final newBadges = await _repo.checkAndAward();
    state = AsyncData(newBadges);
    if (newBadges.isNotEmpty) {
      // Refrescar la lista de medallas del jugador
      ref.invalidate(playerBadgesProvider);
    }
    return newBadges;
  }
}

final badgeCheckerProvider =
    AsyncNotifierProvider<BadgeCheckerNotifier, List<String>>(
      BadgeCheckerNotifier.new,
    );
