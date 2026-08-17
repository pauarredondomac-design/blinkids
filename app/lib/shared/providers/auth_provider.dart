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
/// Incluye sesiones anónimas (demo) — necesario para flujos como el registro
/// de un niño, que arranca en sesión anónima y luego se "sube" a cuenta real.
final currentUserProvider = Provider<User?>((ref) {
  final state = ref.watch(authStateProvider);
  return state.whenOrNull(data: (s) => s.session?.user) ??
      Supabase.instance.client.auth.currentUser;
});

/// Usuario real actual (null si no hay sesión O si es una sesión anónima/demo).
/// Usar en providers que consultan Supabase con datos del jugador: así el modo
/// demo nunca dispara llamadas reales a la base de datos (cero conexión).
final currentRealUserProvider = Provider<User?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.isAnonymous) return null;
  return user;
});
