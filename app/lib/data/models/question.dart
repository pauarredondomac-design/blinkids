enum QuestionType { multipleChoice, trueFalse }

class QuestionOption {
  final String id;
  final String text;
  final String? icon;

  const QuestionOption({
    required this.id,
    required this.text,
    this.icon,
  });

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      id: json['id'] as String,
      text: json['text'] as String,
      icon: json['icon'] as String?,
    );
  }
}

class Question {
  final String id;
  final QuestionType type;
  final String questionText;
  final List<QuestionOption> options;
  final String correctAnswer;
  final int coinReward;
  final int xpReward;
  final String? explanation;

  const Question({
    required this.id,
    required this.type,
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    required this.coinReward,
    required this.xpReward,
    this.explanation,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as String? ?? 'multiple_choice';
    final qType = rawType == 'true_false'
        ? QuestionType.trueFalse
        : QuestionType.multipleChoice;

    final rawOptions = json['options'];
    final List<dynamic> optList =
        rawOptions is List ? rawOptions : [];
    final options =
        optList.map((o) => QuestionOption.fromJson(o as Map<String, dynamic>)).toList();

    // correct_answer viene como '"b"' (string JSON) o 'b'
    String correct = json['correct_answer']?.toString() ?? '';
    if (correct.startsWith('"') && correct.endsWith('"')) {
      correct = correct.substring(1, correct.length - 1);
    }

    return Question(
      id: json['id'] as String,
      type: qType,
      questionText: json['question_text'] as String,
      options: options,
      correctAnswer: correct,
      coinReward: json['coin_reward'] as int? ?? 10,
      xpReward: json['xp_reward'] as int? ?? 5,
      explanation: json['explanation'] as String?,
    );
  }

  bool isCorrect(String answerId) => answerId == correctAnswer;
}
