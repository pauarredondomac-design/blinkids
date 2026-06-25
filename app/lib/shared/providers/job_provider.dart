import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/job.dart';
import '../../data/repositories/job_repository.dart';

final jobRepositoryProvider = Provider<JobRepository>(
  (_) => JobRepository(),
);

final activeJobsProvider = FutureProvider<List<Job>>((ref) async {
  return ref.read(jobRepositoryProvider).getActiveJobs();
});
