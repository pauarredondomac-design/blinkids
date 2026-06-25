import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (_) => AuthRepository(),
);

/// Stream de cambios de estado de autenticación.
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges,
);

/// Usuario actual (null si no hay sesión).
final currentUserProvider = Provider<User?>((ref) {
  final state = ref.watch(authStateProvider);
  return state.whenOrNull(data: (s) => s.session?.user) ??
      Supabase.instance.client.auth.currentUser;
});
