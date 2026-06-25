import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/profile_repository.dart';
import 'auth_provider.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (_) => ProfileRepository(),
);

/// Perfil del usuario autenticado actualmente.
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.read(profileRepositoryProvider).getProfile(user.id);
});
