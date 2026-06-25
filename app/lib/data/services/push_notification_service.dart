import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'analytics_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PushNotificationService
//
// Uso desde cualquier parte del código Flutter:
//
//   await PushService.send('new_mission');
//   await PushService.send('bolsa_earnings');
//   await PushService.send('inactivity_reminder');
//   await PushService.send('sunday_allowance');
//
// Los títulos, cuerpos y cooldowns se gestionan en la tabla
// push_notification_templates de Supabase — sin tocar el código Flutter.
// ─────────────────────────────────────────────────────────────────────────────

// Alias corto para uso rápido en el código
typedef PushService = PushNotificationService;

// Tipos de notificación disponibles (coinciden con la tabla en DB)
abstract class PushType {
  static const inactivityReminder = 'inactivity_reminder'; // niño 4-5 días sin entrar
  static const sundayAllowance    = 'sunday_allowance';    // recordar al papá cada domingo
  static const newMission         = 'new_mission';          // nueva misión creada
  static const bolsaEarnings      = 'bolsa_earnings';       // ganancias en la bolsa
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static const String _oneSignalAppId = '34dd4e8c-d60d-4ee8-8251-c0179f6a87c5';

  // Flag: true si el último app_open fue provocado por tap en una notificación
  // null = piloto sin push (no contaminado)
  static bool? _openedFromNotification;

  /// Devuelve el flag y lo limpia para el próximo open
  static bool? consumeOpenedFromNotification() {
    final val = _openedFromNotification;
    _openedFromNotification = null;
    return val;
  }

  // ── Inicializar (llamar en main antes de runApp) ───────────────────────────
  Future<void> init() async {
    if (kIsWeb) return;

    OneSignal.Debug.setLogLevel(OSLogLevel.none);
    OneSignal.initialize(_oneSignalAppId);

    // Detectar si el usuario abre la app tocando una notificación push
    // → voluntary_open = false
    OneSignal.Notifications.addClickListener((event) {
      _openedFromNotification = true;
      // Registrar el open como no-voluntario
      AnalyticsService.instance.appOpen(voluntaryOpen: false);
      debugPrint('[Push] App abierta desde notificación: ${event.notification.title}');
    });

    // Solicitar permiso de notificaciones al usuario
    await OneSignal.Notifications.requestPermission(true);

    // Vincular el dispositivo con el usuario de Supabase
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) await OneSignal.login(uid);
  }

  // ── Llamar al hacer login (vincula el dispositivo) ────────────────────────
  Future<void> onLogin(String userId) async {
    await OneSignal.login(userId);
  }

  // ── Llamar al hacer logout (desvincula el dispositivo) ────────────────────
  Future<void> onLogout() async {
    await OneSignal.logout();
  }

  // ── Método principal: enviar notificación por tipo ────────────────────────
  // El título, cuerpo y cooldown se leen de la tabla push_notification_templates
  // en Supabase. Solo necesitas pasar el type.
  //
  // Ejemplo:
  //   await PushService.send('new_mission');
  //   await PushService.send('bolsa_earnings', data: {'amount': 150});
  //
  static Future<void> send(
    String type, {
    Map<String, dynamic> data = const {},
  }) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'send-push',
        body: {
          'type': type,
          if (data.isNotEmpty) 'data': data,
        },
      );
    } catch (e) {
      debugPrint('[Push] Error enviando "$type": $e');
    }
  }

  // ── Acceso por instancia (por compatibilidad) ─────────────────────────────
  Future<void> sendPush(String type, {Map<String, dynamic> data = const {}}) =>
      PushService.send(type, data: data);

  // ── Atajos semánticos para las 4 notificaciones ───────────────────────────

  /// Niño no se ha conectado en 4-5 días
  static Future<void> sendInactivityReminder() =>
      send(PushType.inactivityReminder);

  /// Recordar al papá dar el domingo (llamar cada domingo desde un cron o trigger)
  static Future<void> sendSundayAllowance() =>
      send(PushType.sundayAllowance);

  /// Se creó una nueva misión
  static Future<void> sendNewMission() =>
      send(PushType.newMission);

  /// El niño generó ganancias en la bolsa
  static Future<void> sendBolsaEarnings({int? amount}) =>
      send(PushType.bolsaEarnings, data: {
        if (amount != null) 'amount': amount,
      });
}
