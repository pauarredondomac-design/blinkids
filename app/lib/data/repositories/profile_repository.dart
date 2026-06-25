import '../models/profile.dart';
import '../services/supabase_service.dart';

class ProfileRepository {
  Future<Profile?> getProfile(String userId) async {
    final data = await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return data != null ? Profile.fromJson(data) : null;
  }

  /// Crea el perfil inicial del usuario al registrarse.
  Future<Profile> createProfile({
    required String userId,
    required UserRole role,
    required String displayName,
  }) async {
    final data = await supabase
        .from('profiles')
        .insert({
          'id': userId,
          'role': role.name,
          'display_name': displayName,
        })
        .select()
        .single();
    return Profile.fromJson(data);
  }

  Future<Profile> updateProfile(
    String userId, {
    String? displayName,
    String? avatarUrl,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
      if (displayName != null) 'display_name': displayName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };
    final data = await supabase
        .from('profiles')
        .update(updates)
        .eq('id', userId)
        .select()
        .single();
    return Profile.fromJson(data);
  }

  /// Devuelve los hijos vinculados a un padre.
  Future<List<Profile>> getChildren(String parentId) async {
    final data = await supabase
        .from('parent_child')
        .select('profiles!child_id(*)')
        .eq('parent_id', parentId);
    return (data as List)
        .map((e) => Profile.fromJson(e['profiles'] as Map<String, dynamic>))
        .toList();
  }

  Future<bool> profileExists(String userId) async {
    final data = await supabase
        .from('profiles')
        .select('id')
        .eq('id', userId)
        .maybeSingle();
    return data != null;
  }

  /// Devuelve true si el apodo ya está en uso (case-insensitive).
  /// Usa el RPC is_display_name_available (migración 011).
  Future<bool> isDisplayNameTaken(String displayName) async {
    final name = displayName.trim();
    if (name.isEmpty) return false;
    try {
      final available = await supabase.rpc(
        'is_display_name_available',
        params: {'p_name': name},
      );
      return !(available as bool);
    } catch (_) {
      // Fallback: búsqueda directa (RPC no disponible aún)
      final row = await supabase
          .from('profiles')
          .select('id')
          .ilike('display_name', name)
          .maybeSingle();
      return row != null;
    }
  }
}
