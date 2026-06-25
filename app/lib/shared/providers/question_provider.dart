import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/question.dart';
import '../../data/repositories/question_repository.dart';

final questionRepositoryProvider = Provider<QuestionRepository>(
  (_) => QuestionRepository(),
);

final forestQuestionsProvider = FutureProvider<List<Question>>((ref) async {
  return ref.read(questionRepositoryProvider).getQuestionsForWorld();
});
