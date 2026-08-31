import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/donation_cause.dart';
import '../../data/repositories/donation_repository.dart';
import 'auth_provider.dart';

final donationRepositoryProvider =
    Provider<DonationRepository>((_) => DonationRepository());

/// Progreso del jugador actual en cada causa, por `causeId`. Vacío si no
/// hay sesión real (demo) — Donar sigue sumando a la bolsa igual, solo no
/// se rastrea el progreso por causa.
final donationProgressProvider =
    FutureProvider<Map<String, DonationCauseProgress>>((ref) async {
  final user = ref.watch(currentRealUserProvider);
  if (user == null) return {};
  return ref.read(donationRepositoryProvider).getProgress(user.id);
});
