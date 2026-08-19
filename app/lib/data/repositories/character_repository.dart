import '../models/character.dart';
import '../services/supabase_service.dart';

class CharacterRepository {
  Future<Character?> getCharacter(String userId) async {
    final data = await supabase
        .from('characters')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return data != null ? Character.fromJson(data) : null;
  }

  Future<Character> createCharacter(String userId) async {
    final data = await supabase
        .from('characters')
        .insert({
          'user_id': userId,
          'xp': 0,
          'level': 1,
        })
        .select()
        .single();
    return Character.fromJson(data);
  }

  Future<Character> addXp(String userId, int xpToAdd) async {
    // Autoreparación: si por algún motivo la cuenta no tiene fila en
    // `characters` (ej. se creó antes de que el signup empezara a crearla),
    // no perder el XP en silencio — crearla ahora mismo con xp=0.
    final current = await getCharacter(userId) ?? await createCharacter(userId);

    final newXp = current.xp + xpToAdd;
    final newLevel = levelFromXp(newXp);

    final data = await supabase
        .from('characters')
        .update({
          'xp': newXp,
          'level': newLevel,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', userId)
        .select()
        .single();
    return Character.fromJson(data);
  }

  Future<Character> equipAvatar(String userId, String avatarId) async {
    final data = await supabase
        .from('characters')
        .update({
          'equipped_avatar_id': avatarId,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', userId)
        .select()
        .single();
    return Character.fromJson(data);
  }
}
