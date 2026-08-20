import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/crafting_job.dart';
import '../../data/models/mission.dart';
import '../../data/models/wallet.dart';
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

  final tracker = MissionTracker();
  final claimed = await tracker.claimedMissionIds();
  final unlockedChapter = tracker.unlockedChapterFrom(missions, claimed);
  final categories = await ref.read(walletCategoriesProvider.future);
  final categoryBalance = {
    for (final c in categories) c.category.name: c.balance,
  };
  final objectiveProgress = await tracker.allProgress();

  // Fotos de progreso al desbloquear cada capítulo — mismo criterio "desde
  // que se desbloqueó" que usa la pantalla de Misiones, para que el número
  // del mapa coincida con lo que el niño ve al entrar.
  final chapterNumbers = List.generate(unlockedChapter, (i) => i + 1);
  final snapshotResults = await Future.wait(
    chapterNumbers.map((c) => tracker.ensureChapterSnapshot(c)),
  );
  final snapshots = {
    for (var i = 0; i < chapterNumbers.length; i++)
      chapterNumbers[i]: snapshotResults[i],
  };

  bool canClaim(Mission m) {
    final baseline = m.chapterNumber != null
        ? (snapshots[m.chapterNumber] ?? const {})
        : const <String, int>{};
    int deltaFor(String category) {
      final delta =
          (categoryBalance[category] ?? 0) - (baseline[category] ?? 0);
      return delta < 0 ? 0 : delta;
    }

    final itemsOk =
        m.requiredItems.every((r) => (have[r.itemId] ?? 0) >= r.qty);
    final coinsOk = coins >= m.requiredCoins;
    final categoriesTouched =
        assignableWalletCategories.where((t) => deltaFor(t.name) > 0).length;
    final categoriesSum =
        assignableWalletCategories.fold<int>(0, (s, t) => s + deltaFor(t.name));
    final categoryOk = !m.hasCategoryRequirement ||
        switch (m.requiredCategory) {
          'all' => assignableWalletCategories
              .every((t) => deltaFor(t.name) >= m.requiredCategoryAmount),
          'multi' => categoriesSum >= m.requiredCategoryAmount &&
              categoriesTouched >= m.requiredCategoryMinSpread,
          _ => deltaFor(m.requiredCategory!) >= m.requiredCategoryAmount,
        };
    final anyItemsCount =
        m.requiredAnyItems.fold<int>(0, (s, id) => s + (have[id] ?? 0));
    final anyItemsOk =
        !m.hasAnyItemsRequirement || anyItemsCount >= m.requiredAnyCount;
    final objectiveKey = switch (m.objectiveType) {
      MissionObjectiveType.completeQuizzes => 'quizzes',
      MissionObjectiveType.completeJobs => 'jobs',
      MissionObjectiveType.buyFromShop => 'purchases',
      null => null,
    };
    final objectiveBaseline =
        objectiveKey != null ? (baseline[objectiveKey] ?? 0) : 0;
    final objectiveDelta =
        (objectiveProgress[m.objectiveType] ?? 0) - objectiveBaseline;
    final objectiveOk = !m.hasObjective || objectiveDelta >= m.objectiveTarget;
    return itemsOk && coinsOk && categoryOk && anyItemsOk && objectiveOk;
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
