import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AnalyticsService
// Singleton para registrar eventos de analíticas en Supabase.
//
// Uso:
//   AnalyticsService.instance.track('mission_completed', {'world': 'forest'});
//
// Todos los errores se silencian para no interrumpir el flujo del juego.
// ─────────────────────────────────────────────────────────────────────────────
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  // ── Nombre de la plataforma ─────────────────────────────────────────────────
  static String get _platform {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isWindows) return 'windows';
    } catch (_) {}
    return 'unknown';
  }

  // ── Versión de la app (puede actualizarse en initState del main) ────────────
  static String appVersion = '1.0.0';

  // ── Registra un evento ──────────────────────────────────────────────────────
  Future<void> track(
    String eventName, {
    Map<String, dynamic> properties = const {},
  }) async {
    if (kIsWeb) return; // Analytics no disponible en web
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      await Supabase.instance.client.from('analytics_events').insert({
        'user_id': uid,
        'event_name': eventName,
        'properties': properties,
        'app_version': appVersion,
        'platform': _platform,
      });
    } catch (_) {
      // Silencioso: las analíticas nunca deben bloquear el flujo del juego
    }
  }

  // ── Eventos predefinidos ────────────────────────────────────────────────────

  /// [voluntaryOpen] = true  → usuario abrió la app por su cuenta
  /// [voluntaryOpen] = false → usuario tocó una notificación push
  /// [voluntaryOpen] = null  → piloto sin push (no contaminado)
  Future<void> appOpen({bool? voluntaryOpen}) => track(
        'app_open',
        properties: {
          if (voluntaryOpen != null) 'voluntary_open': voluntaryOpen,
        },
      );

  Future<void> login(String method) =>
      track('login', properties: {'method': method});

  Future<void> register(String role) =>
      track('register', properties: {'role': role});

  Future<void> tutorialCompleted() => track('tutorial_completed');

  Future<void> worldEntered(String worldId) =>
      track('world_entered', properties: {'world_id': worldId});

  Future<void> worldUnlocked(String worldId, int cost) =>
      track('world_unlocked', properties: {'world_id': worldId, 'cost': cost});

  Future<void> missionCompleted(String missionId, int xpGained) =>
      track('mission_completed', properties: {
        'mission_id': missionId,
        'xp_gained': xpGained,
      });

  Future<void> quizCompleted(String questionId, bool correct, int xpGained) =>
      track('quiz_completed', properties: {
        'question_id': questionId,
        'correct': correct,
        'xp_gained': xpGained,
      });

  Future<void> jobCompleted(String jobId, int coinsEarned) =>
      track('job_completed', properties: {
        'job_id': jobId,
        'coins_earned': coinsEarned,
      });

  Future<void> itemPurchased(String itemId, int price) =>
      track('item_purchased', properties: {
        'item_id': itemId,
        'price': price,
      });

  Future<void> cosmeticPurchased(String cosmeticId, int price) =>
      track('cosmetic_purchased', properties: {
        'cosmetic_id': cosmeticId,
        'price': price,
      });

  Future<void> cosmeticEquipped(String cosmeticId, String slot) =>
      track('cosmetic_equipped', properties: {
        'cosmetic_id': cosmeticId,
        'slot': slot,
      });

  Future<void> badgeEarned(String badgeId) =>
      track('badge_earned', properties: {'badge_id': badgeId});

  Future<void> coinsReceived(int amount, String from) =>
      track('coins_received', properties: {
        'amount': amount,
        'from': from,
      });

  Future<void> onboardingStep(String step) =>
      track('onboarding_step', properties: {'step': step});
}
