import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/child_goal.dart';
import '../../data/repositories/child_goal_repository.dart';
import 'auth_provider.dart';

final childGoalRepositoryProvider = Provider<ChildGoalRepository>(
  (_) => ChildGoalRepository(),
);

final currentGoalProvider = FutureProvider<ChildGoal?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.read(childGoalRepositoryProvider).getCurrentGoal();
});
