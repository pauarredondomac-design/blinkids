import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/world_repository.dart';

final worldRepositoryProvider = Provider<WorldRepository>(
  (_) => WorldRepository(),
);

/// Lista de slugs de mundos desbloqueados por el jugador.
/// Se persiste en Supabase (world_progress). 'forest' siempre incluido.
final unlockedWorldsProvider = FutureProvider<List<String>>((ref) async {
  return ref.read(worldRepositoryProvider).getUnlockedWorldIds();
});

/// Mundo activo en este momento.
/// Cada WorldMap lo establece en su initState.
/// Las sub-pantallas (Misiones, Preguntas, etc.) lo leen para adaptar su tema.
final currentWorldProvider = StateProvider<String>((ref) => 'space');
