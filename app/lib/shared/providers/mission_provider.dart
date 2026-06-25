import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/mission.dart';
import '../../data/repositories/mission_repository.dart';
import 'world_provider.dart';

final missionRepositoryProvider = Provider<MissionRepository>(
  (_) => MissionRepository(),
);

/// Misiones activas del mundo actual.
/// Se invalida automáticamente si el mundo cambia.
final activeMissionsProvider = FutureProvider<List<Mission>>((ref) async {
  final worldId = ref.watch(currentWorldProvider);
  return ref.read(missionRepositoryProvider).getActiveMissions(worldSlug: worldId);
});
