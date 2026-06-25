import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/character.dart';
import '../../data/repositories/character_repository.dart';
import 'auth_provider.dart';
import 'badge_provider.dart';

final characterRepositoryProvider = Provider<CharacterRepository>(
  (_) => CharacterRepository(),
);

/// Personaje (Juan) del usuario actual.
final currentCharacterProvider = FutureProvider<Character?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.read(characterRepositoryProvider).getCharacter(user.id);
});

/// Otorga XP al personaje, refresca el provider y comprueba medallas.
/// Silencia errores para no bloquear el flujo de juego.
/// Devuelve los IDs de las medallas recién ganadas (lista vacía si ninguna).
Future<List<String>> awardXp(WidgetRef ref, int amount) async {
  if (amount <= 0) return [];
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];
  try {
    await CharacterRepository().addXp(userId, amount);
    ref.invalidate(currentCharacterProvider);
    // Comprobar si se ganaron nuevas medallas tras el XP
    return await ref.read(badgeCheckerProvider.notifier).check();
  } catch (_) {
    return [];
  }
}
