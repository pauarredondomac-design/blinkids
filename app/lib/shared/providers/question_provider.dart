import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/question.dart';
import '../../data/repositories/question_repository.dart';

final questionRepositoryProvider = Provider<QuestionRepository>(
  (_) => QuestionRepository(),
);

final questionsForWorldProvider =
    FutureProvider.family<List<Question>, String>((ref, worldSlug) async {
  return ref.read(questionRepositoryProvider).getQuestionsForWorld(worldSlug: worldSlug);
});

/// Actividades narrativas de un módulo (trabajos, mi_bolsa, banco_estelar, misiones).
final questionsForModuleProvider =
    FutureProvider.family<List<Question>, String>((ref, moduleSlug) async {
  return ref.read(questionRepositoryProvider).getQuestionsForModule(moduleSlug);
});
