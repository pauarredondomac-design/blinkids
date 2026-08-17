import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Bandera global: true cuando el backend (Supabase) está fallando —
/// error 5xx o la petición ni siquiera pudo completarse (sin red, timeout).
/// No usa Riverpod porque se necesita ANTES de que exista el ProviderScope
/// (se conecta al inicializar Supabase, en main()).
class BackendStatus {
  BackendStatus._();
  static final ValueNotifier<bool> isDown = ValueNotifier<bool>(false);
}

/// Envuelve el http.Client que usa Supabase para detectar cuándo el
/// backend está caído, sin tener que tocar cada pantalla/repositorio.
class MonitoredHttpClient extends http.BaseClient {
  MonitoredHttpClient([http.Client? inner]) : _inner = inner ?? http.Client();
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      final response = await _inner.send(request);
      BackendStatus.isDown.value = response.statusCode >= 500;
      return response;
    } catch (_) {
      BackendStatus.isDown.value = true;
      rethrow;
    }
  }

  @override
  void close() => _inner.close();
}
