import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/crafting_job.dart';
import '../../data/models/mission.dart';
import '../../data/repositories/crafting_job_repository.dart';
import '../../data/repositories/mission_tracker.dart';
import 'demo_progress_provider.dart';
import 'item_provider.dart';
import 'mission_provider.dart';
import 'wallet_provider.dart';
import 'world_provider.dart';

/// Cuántos trabajos del Taller están desbloqueados, sin completar y con
/// todos los materiales listos ahora mismo — mismo criterio que "listos
/// para hacer" en la pantalla de Trabajos. Es el número que se muestra
/// como notificación sobre el edificio Trabajos en el mapa.
///
/// No reacciona solo a cambios (no observa otros providers): se recalcula
/// llamando `ref.invalidate` después de cerrar cualquier edificio, desde
/// `space_world_map.dart`.
final trabajosPendingCountProvider = FutureProvider<int>((ref) async {
  final worldId = ref.read(currentWorldProvider);
  final inventory = await ref.read(itemRepositoryProvider).getInventory();
  final have = {for (final s in inventory) s.item.id: s.qty};

  final jobs = await CraftingJobRepository.getJobsForWorld(worldId);
  final completedIds = await CraftingJobRepository.completedJobIds();

  final missions = await ref.read(activeMissionsProvider.future);
  final claimedMissions = await MissionTracker().claimedMissionIds();
  final unlockedChapter =
      MissionTracker().unlockedChapterFrom(missions, claimedMissions);

  bool hasAllMaterials(CraftingJob job) =>
      job.requirements.every((r) => (have[r.itemId] ?? 0) >= r.qty);

  var count = 0;

  final byChapter = <int, List<CraftingJob>>{};
  for (final j in jobs) {
    if (j.chapterNumber == null) continue;
    byChapter.putIfAbsent(j.chapterNumber!, () => []).add(j);
  }
  for (final entry in byChapter.entries) {
    if (entry.key > unlockedChapter) continue;
    final chJobs = entry.value
      ..sort(
          (a, b) => (a.orderInChapter ?? 0).compareTo(b.orderInChapter ?? 0));
    for (var i = 0; i < chJobs.length; i++) {
      final job = chJobs[i];
      final prevCompleted = i == 0 || completedIds.contains(chJobs[i - 1].id);
      if (!prevCompleted) continue;
      if (completedIds.contains(job.id)) continue;
      if (hasAllMaterials(job)) count++;
    }
  }

  for (final job in jobs.where((j) => j.chapterNumber == null)) {
    if (completedIds.contains(job.id)) continue;
    if (hasAllMaterials(job)) count++;
  }

  return count;
});

/// Cuántas misiones activas se pueden reclamar ahora mismo (desbloqueadas,
/// no reclamadas y con todo lo necesario) — el número sobre Misiones.
final misionesPendingCountProvider = FutureProvider<int>((ref) async {
  final missions = await ref.read(activeMissionsProvider.future);
  final inventory = await ref.read(itemRepositoryProvider).getInventory();
  final have = {for (final s in inventory) s.item.id: s.qty};
  final coins = DemoStore.isActive
      ? ref.read(demoProgressProvider).coins
      : (ref.read(currentWalletProvider).valueOrNull?.totalCoins ?? 0);

  final claimed = await MissionTracker().claimedMissionIds();
  final unlockedChapter =
      MissionTracker().unlockedChapterFrom(missions, claimed);

  bool canClaim(Mission m) {
    final itemsOk =
        m.requiredItems.every((r) => (have[r.itemId] ?? 0) >= r.qty);
    final coinsOk = coins >= m.requiredCoins;
    return itemsOk && coinsOk;
  }

  var count = 0;

  final byChapter = <int, List<Mission>>{};
  for (final m in missions) {
    if (m.chapterNumber == null) continue;
    byChapter.putIfAbsent(m.chapterNumber!, () => []).add(m);
  }
  for (final entry in byChapter.entries) {
    if (entry.key > unlockedChapter) continue;
    final chMissions = entry.value
      ..sort(
          (a, b) => (a.orderInChapter ?? 0).compareTo(b.orderInChapter ?? 0));
    for (var i = 0; i < chMissions.length; i++) {
      final m = chMissions[i];
      final prevClaimed = i == 0 || claimed.contains(chMissions[i - 1].id);
      if (!prevClaimed) continue;
      if (claimed.contains(m.id)) continue;
      if (canClaim(m)) count++;
    }
  }

  for (final m in missions.where((m) => m.chapterNumber == null)) {
    if (claimed.contains(m.id)) continue;
    if (canClaim(m)) count++;
  }

  return count;
});
