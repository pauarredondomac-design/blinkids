import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/providers/demo_progress_provider.dart';

/// Cuántas veces completó el niño CADA TIPO de quiz (Elegir/Clasificar/
/// Relacionar/Ordenar/Trivia) con todas las respuestas correctas. Tope de 2
/// veces con recompensa — usado por QuizzesScreen + ActivityPlayer.
class QuizCompletionRepository {
  final _client = Supabase.instance.client;

  Future<int> timesCompleted(String quizType) async {
    if (DemoStore.isActive) {
      return DemoStore.instance.quizCompletions[quizType] ?? 0;
    }
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return 0;
      final row = await _client
          .from('quiz_completions')
          .select('times_completed')
          .eq('user_id', userId)
          .eq('quiz_type', quizType)
          .maybeSingle();
      return (row?['times_completed'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> recordCompletion(String quizType) async {
    if (DemoStore.isActive) {
      final store = DemoStore.instance;
      store.quizCompletions[quizType] =
          (store.quizCompletions[quizType] ?? 0) + 1;
      return;
    }
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;
      final current = await timesCompleted(quizType);
      await _client.from('quiz_completions').upsert({
        'user_id': userId,
        'quiz_type': quizType,
        'times_completed': current + 1,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  // ── Preguntas ya contestadas bien (rondas de 3) ────────────────────────────
  // Una vez que el niño acierta las 3 de una ronda, esas preguntas quedan
  // marcadas para siempre y no vuelven a salir en el sorteo de esa sección.

  Future<Set<String>> answeredQuestionIds() async {
    if (DemoStore.isActive) return DemoStore.instance.quizAnsweredQuestions;
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return {};
      final rows = await _client
          .from('quiz_answered_questions')
          .select('question_id')
          .eq('user_id', userId);
      return (rows as List).map((r) => r['question_id'] as String).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> markAnsweredQuestions(List<String> questionIds) async {
    if (questionIds.isEmpty) return;
    if (DemoStore.isActive) {
      DemoStore.instance.quizAnsweredQuestions.addAll(questionIds);
      return;
    }
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;
      await _client.from('quiz_answered_questions').upsert([
        for (final id in questionIds)
          {'user_id': userId, 'question_id': id},
      ]);
    } catch (_) {}
  }
}
