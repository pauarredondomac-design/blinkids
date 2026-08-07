import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/parent_mission.dart';
import '../../data/repositories/parent_mission_repository.dart';
import 'auth_provider.dart';

final parentMissionRepositoryProvider = Provider<ParentMissionRepository>(
  (_) => ParentMissionRepository(),
);

/// Misiones de papá del hijo actual. Vacío en demo (sin sesión real).
final childParentMissionsProvider =
    FutureProvider<List<ParentMission>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.read(parentMissionRepositoryProvider).getMissionsForCurrentChild();
});

/// Misiones que el padre actual creó para un hijo específico.
final missionsCreatedForChildProvider =
    FutureProvider.family<List<ParentMission>, String>((ref, childId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref
      .read(parentMissionRepositoryProvider)
      .getMissionsCreatedForChild(childId);
});
