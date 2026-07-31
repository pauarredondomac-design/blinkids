import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/question.dart';

class QuestionRepository {
  SupabaseClient get _db => Supabase.instance.client;

  /// Trae preguntas del bosque (y las globales).
  Future<List<Question>> getQuestionsForWorld({
    String worldSlug = 'forest',
    int limit = 10,
  }) async {
    try {
      final worldRow = await _db
          .from('worlds')
          .select('id')
          .eq('slug', worldSlug)
          .maybeSingle();

      final worldId = worldRow?['id'] as String?;

      List<Map<String, dynamic>> rows;
      if (worldId != null) {
        rows = await _db
            .from('questions')
            .select()
            .eq('is_active', true)
            .or('world_id.eq.$worldId,world_id.is.null')
            .order('created_at')
            .limit(limit);
      } else {
        rows = await _db
            .from('questions')
            .select()
            .eq('is_active', true)
            .order('created_at')
            .limit(limit);
      }

      if (rows.isEmpty) return _fallbackQuestions();
      return rows.map((r) => Question.fromJson(r)).toList();
    } catch (_) {
      return _fallbackQuestions();
    }
  }

  /// Trae actividades de un módulo (trabajos, mi_bolsa, banco_estelar, misiones...)
  /// ordenadas por sort_order. Usado por el catálogo nuevo de actividades narrativas.
  Future<List<Question>> getQuestionsForModule(
    String moduleSlug, {
    int? limit,
  }) async {
    try {
      var query = _db
          .from('questions')
          .select()
          .eq('is_active', true)
          .eq('module_slug', moduleSlug)
          .order('sort_order');

      final rows = limit != null ? await query.limit(limit) : await query;
      return (rows as List)
          .map((r) => Question.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Registra la respuesta del jugador en historial.
  Future<void> recordAnswer({
    required String userId,
    required String questionId,
    required bool isCorrect,
  }) async {
    try {
      await _db.from('player_answers').insert({
        'user_id': userId,
        'question_id': questionId,
        'is_correct': isCorrect,
      });
    } catch (_) {
      // No bloquear el juego si falla el registro
    }
  }

  List<Question> _fallbackQuestions() => [
        const Question(
          id: 'q-local-1',
          type: QuestionType.multipleChoice,
          questionText: '¿Qué es el ahorro?',
          options: [
            QuestionOption(id: 'a', text: 'Gastar todo tu dinero', icon: '🛒'),
            QuestionOption(
                id: 'b',
                text: 'Guardar parte del dinero para el futuro',
                icon: '🐷'),
            QuestionOption(id: 'c', text: 'Pedir dinero prestado', icon: '🤝'),
            QuestionOption(id: 'd', text: 'Perder dinero jugando', icon: '🎲'),
          ],
          correctAnswer: 'b',
          coinReward: 10,
          xpReward: 5,
          explanation:
              'El ahorro es guardar una parte de tu dinero para usarlo después, '
              'ya sea para una emergencia o para una meta importante.',
        ),
        const Question(
          id: 'q-local-2',
          type: QuestionType.trueFalse,
          questionText:
              '¿Es buena idea gastar todo tu dinero apenas lo recibes?',
          options: [
            QuestionOption(id: 'true', text: 'Verdadero'),
            QuestionOption(id: 'false', text: 'Falso'),
          ],
          correctAnswer: 'false',
          coinReward: 8,
          xpReward: 4,
          explanation:
              'No es buena idea. Es mejor guardar una parte para el futuro '
              'y otra para emergencias antes de gastar.',
        ),
        const Question(
          id: 'q-local-3',
          type: QuestionType.multipleChoice,
          questionText: '¿Cuántas categorías tiene la bolsa de Blinkids?',
          options: [
            QuestionOption(id: 'a', text: '3', icon: '3️⃣'),
            QuestionOption(id: 'b', text: '4', icon: '4️⃣'),
            QuestionOption(id: 'c', text: '5', icon: '5️⃣'),
            QuestionOption(id: 'd', text: '10', icon: '🔟'),
          ],
          correctAnswer: 'c',
          coinReward: 10,
          xpReward: 5,
          explanation: 'La bolsa tiene 5 categorías: Ahorro 🐷, Inversión 📈, '
              'Emergencia 🚨, Gastos 🛒 y Metas 🎯.',
        ),
        const Question(
          id: 'q-local-4',
          type: QuestionType.multipleChoice,
          questionText: '¿Qué es un presupuesto?',
          options: [
            QuestionOption(
                id: 'a',
                text: 'Un plan para gastar e invertir tu dinero',
                icon: '📋'),
            QuestionOption(
                id: 'b', text: 'Una lista de juguetes que quieres', icon: '🎮'),
            QuestionOption(
                id: 'c', text: 'El dinero que tienes en el banco', icon: '🏦'),
            QuestionOption(
                id: 'd', text: 'Un tipo de moneda especial', icon: '💰'),
          ],
          correctAnswer: 'a',
          coinReward: 12,
          xpReward: 6,
          explanation:
              'Un presupuesto es un plan que te ayuda a decidir cuánto dinero vas a '
              'gastar, ahorrar e invertir. ¡Es como un mapa para tu dinero!',
        ),
        const Question(
          id: 'q-local-5',
          type: QuestionType.trueFalse,
          questionText:
              '¿La inversión es cuando usas tu dinero para que crezca con el tiempo?',
          options: [
            QuestionOption(id: 'true', text: 'Verdadero'),
            QuestionOption(id: 'false', text: 'Falso'),
          ],
          correctAnswer: 'true',
          coinReward: 8,
          xpReward: 4,
          explanation:
              '¡Exacto! Invertir es poner tu dinero a trabajar para que genere más dinero '
              'con el tiempo, como en acciones, negocios o fondos de inversión.',
        ),
      ];
}
