import 'package:supabase_flutter/supabase_flutter.dart';

/// Acceso rápido al cliente de Supabase desde cualquier parte de la app.
SupabaseClient get supabase => Supabase.instance.client;

/// Acceso al usuario autenticado actualmente (puede ser null).
User? get currentUser => supabase.auth.currentUser;

/// Acceso al ID del usuario actual (lanza si no hay sesión).
String get currentUserId {
  final user = currentUser;
  if (user == null) throw Exception('No hay sesión activa');
  return user.id;
}
