import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/job.dart';
import '../../data/repositories/job_repository.dart';
import 'auth_provider.dart';

final jobRepositoryProvider = Provider<JobRepository>(
  (_) => JobRepository(),
);

final activeJobsProvider = FutureProvider<List<Job>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.read(jobRepositoryProvider).getActiveJobs();
});
