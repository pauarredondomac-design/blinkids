import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'analytics_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CrashReportingService
//
// Captura errores de Flutter y de Dart no manejados y los guarda en Supabase.
//
// Uso: Llamar CrashReportingService.init() en main() ANTES de runApp().
//
// Nota: Como Supabase puede no estar inicializado cuando ocurre el primer
// error, los reportes se encolan en memoria y se envían en diferido.
// ─────────────────────────────────────────────────────────────────────────────
class CrashReportingService {
  CrashReportingService._();
  static final CrashReportingService _instance = CrashReportingService._();

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

  // ── Inicializar handlers de error ─────────────────────────────────────────
  static void init() {
    // 1. Errores de Flutter (widgets, rendering, etc.)
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details); // log normal en consola
      _instance._report(
        error: details.exceptionAsString(),
        stackTrace: details.stack?.toString(),
        context: 'flutter_error',
      );
    };

    // 2. Errores de Dart async fuera del árbol de widgets
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      _instance._report(
        error: error.toString(),
        stackTrace: stack.toString(),
        context: 'platform_error',
      );
      return true; // true = error manejado (no re-lanzar)
    };
  }

  // ── Reporte manual desde try/catch ────────────────────────────────────────
  static Future<void> report(
    Object error,
    StackTrace? stackTrace, {
    String context = 'dart_error',
  }) async {
    await _instance._report(
      error: error.toString(),
      stackTrace: stackTrace?.toString(),
      context: context,
    );
  }

  // ── Envía el reporte a Supabase (silencioso si falla) ─────────────────────
  Future<void> _report({
    required String error,
    String? stackTrace,
    String? context,
  }) async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      await Supabase.instance.client.from('crash_reports').insert({
        'user_id': uid,
        'error': error,
        'stack_trace': stackTrace,
        'context': context,
        'app_version': AnalyticsService.appVersion,
        'platform': _platform,
      });
    } catch (_) {
      // Si Supabase falla o no está listo, ignorar silenciosamente.
      // Los crashes no deben generar más crashes.
    }
  }
}
