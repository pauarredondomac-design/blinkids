import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/providers/demo_progress_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BuildingQuestionRepository
// Controla la "pregunta del día" de cada edificio: se muestra una sola vez
// al día (primera entrada del día), y no vuelve a salir el resto del día
// sin importar si se contestó bien o mal.
// ─────────────────────────────────────────────────────────────────────────────
/// Todos los edificios que tienen (o tendrán) pregunta diaria.
const List<String> kDailyQuestionBuildings = [
  'mi_bolsa',
  'banco_estelar',
  'misiones',
  'trabajos',
  'tienda',
];

class BuildingQuestionRepository {
  SupabaseClient get _db => Supabase.instance.client;

  /// Fecha de calendario local en formato 'yyyy-MM-dd'.
  String get _today {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  /// true si ya se mostró/resolvió la pregunta diaria de este edificio hoy.
  Future<bool> shownToday(String buildingSlug) async {
    if (DemoStore.isActive) {
      return DemoStore.instance.dailyQuestionShownToday(buildingSlug);
    }
    try {
      final userId = _db.auth.currentUser?.id;
      if (userId == null) return false;
      final row = await _db
          .from('building_daily_questions')
          .select('shown_date')
          .eq('user_id', userId)
          .eq('building_slug', buildingSlug)
          .eq('shown_date', _today)
          .maybeSingle();
      return row != null;
    } catch (_) {
      // Si falla la red, no interrumpir la pantalla con una pregunta.
      return true;
    }
  }

  Future<void> markShown(
    String buildingSlug, {
    String? questionId,
    bool correct = false,
  }) async {
    if (DemoStore.isActive) {
      DemoStore.instance.markDailyQuestionShown(buildingSlug);
      return;
    }
    try {
      final userId = _db.auth.currentUser?.id;
      if (userId == null) return;
      await _db.from('building_daily_questions').upsert(
        {
          'user_id': userId,
          'building_slug': buildingSlug,
          'shown_date': _today,
          'question_id': questionId,
          'answered_correctly': correct,
        },
        onConflict: 'user_id,building_slug,shown_date',
      );
    } catch (_) {}
  }

  /// true una vez que el jugador terminó el recorrido guiado (map_guide).
  /// Mientras sea false, [maybeShowDailyBuildingQuestion] no debe mostrar
  /// nada — el primer día es solo intro + instrucciones, sin preguntas.
  Future<bool> isIntroComplete() async {
    final user = _db.auth.currentUser;
    if (user == null || user.isAnonymous) {
      return DemoStore.instance.introComplete;
    }
    try {
      final data = await _db
          .from('profiles')
          .select('tutorials_seen')
          .eq('id', user.id)
          .maybeSingle();
      final map = (data?['tutorials_seen'] as Map<String, dynamic>?) ?? {};
      return map['map_guide'] == true;
    } catch (_) {
      return true; // si falla la red, no bloquear la función indefinidamente
    }
  }

  /// Da por "mostrada hoy" la pregunta diaria de TODOS los edificios, sin
  /// registrar ninguna pregunta real. Se llama justo cuando termina el
  /// recorrido guiado, para que el día en que se completa el intro no
  /// tenga preguntas — empiezan al día siguiente.
  Future<void> markAllShownToday() async {
    for (final slug in kDailyQuestionBuildings) {
      await markShown(slug);
    }
  }
}
