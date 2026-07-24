import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/blink_dialogues_repository.dart';
import '../providers/blink_ambient_provider.dart';
import '../providers/job_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BlinkAmbientHelper
// Decide qué dice Blink en la burbuja ambiental del mapa principal:
// reacción a vestuario > ausencia de varios días > trabajos pendientes > saludo.
// Silencioso — nunca interrumpe la UX si algo falla (ni en demo ni con sesión).
// ─────────────────────────────────────────────────────────────────────────────
class BlinkAmbientHelper {
  BlinkAmbientHelper._();

  static const _showDuration = Duration(seconds: 6);

  static Future<void> maybeGreet(WidgetRef ref) async {
    try {
      final screenKey = await _pickScreenKey(ref);
      final options = await BlinkDialoguesRepository.getSteps(screenKey);
      if (options.isEmpty) return;

      final pick = options[Random().nextInt(options.length)];
      final text = pick.body.isNotEmpty ? pick.body : pick.title;
      if (text.isEmpty) return;

      ref.read(blinkAmbientMessageProvider.notifier).state = text;

      Future.delayed(_showDuration, () {
        if (ref.read(blinkAmbientMessageProvider) == text) {
          ref.read(blinkAmbientMessageProvider.notifier).state = null;
        }
      });
    } catch (_) {
      // Silencioso
    }
  }

  static Future<String> _pickScreenKey(WidgetRef ref) async {
    if (ref.read(justChangedOutfitProvider)) {
      ref.read(justChangedOutfitProvider.notifier).state = false;
      return 'ambient_outfit';
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final row = await Supabase.instance.client
            .from('profiles')
            .select('last_active')
            .eq('id', user.id)
            .maybeSingle();
        final lastActiveStr = row?['last_active'] as String?;
        final lastActive =
            lastActiveStr != null ? DateTime.tryParse(lastActiveStr) : null;
        if (lastActive != null) {
          final daysSince =
              DateTime.now().toUtc().difference(lastActive.toUtc()).inDays;
          if (daysSince >= 2) return 'ambient_absence';
        }
      } catch (_) {}
    }

    try {
      final jobs = await ref.read(activeJobsProvider.future);
      if (jobs.isNotEmpty) return 'ambient_jobs';
    } catch (_) {}

    return 'ambient_idle';
  }
}
