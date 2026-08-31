enum QuestionType {
  multipleChoice,
  trueFalse,
  orderSteps,
  classify,
  dragMatch,
  fillBlank,

  /// Preguntas sin respuesta incorrecta — cualquier elección (o solo
  /// continuar) muestra el mensaje positivo. Usado para preguntas de
  /// reflexión ("¿Qué harías?", "no hay cantidad correcta", etc.).
  reflection,
}

QuestionType _typeFromString(String? raw) {
  switch (raw) {
    case 'true_false':
      return QuestionType.trueFalse;
    case 'order_steps':
      return QuestionType.orderSteps;
    case 'classify':
      return QuestionType.classify;
    case 'drag_match':
      return QuestionType.dragMatch;
    case 'fill_blank':
      return QuestionType.fillBlank;
    case 'reflection':
      return QuestionType.reflection;
    default:
      return QuestionType.multipleChoice;
  }
}

class QuestionOption {
  final String id;
  final String text;
  final String? icon;

  /// Solo para 'classify': a qué bolsa pertenece este ítem ('a' o 'b').
  final String? bucket;

  /// Solo para 'drag_match': lado derecho del par (si el ítem es un par ya formado).
  final String? right;

  const QuestionOption({
    required this.id,
    required this.text,
    this.icon,
    this.bucket,
    this.right,
  });

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      id: json['id'] as String,
      text: json['text'] as String,
      icon: json['icon'] as String?,
      bucket: json['bucket'] as String?,
      right: json['right'] as String?,
    );
  }
}

class Question {
  final String id;
  final QuestionType type;
  final String questionText;
  final List<QuestionOption> options;

  /// Para multipleChoice/trueFalse: id de la opción correcta.
  /// Para orderSteps: lista ordenada de ids (secuencia correcta).
  /// Para classify: mapa {'a': 'Etiqueta bolsa A', 'b': 'Etiqueta bolsa B'}.
  /// Para dragMatch: lista de ids de pares válidos (vacío si es reflexión sin respuesta única).
  final dynamic correctAnswer;
  final int coinReward;
  final int xpReward;
  final int fuelReward;
  final String? explanation;
  final String? retroWrong;
  final String? gancho;
  final String? groupName;
  final bool isHito;
  final String? badgeName;
  final String? catalogId;

  const Question({
    required this.id,
    required this.type,
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    required this.coinReward,
    required this.xpReward,
    this.fuelReward = 0,
    this.explanation,
    this.retroWrong,
    this.gancho,
    this.groupName,
    this.isHito = false,
    this.badgeName,
    this.catalogId,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    final qType = _typeFromString(json['type'] as String?);

    final rawOptions = json['options'];
    final List<dynamic> optList = rawOptions is List ? rawOptions : [];
    final options = optList
        .map((o) => QuestionOption.fromJson(o as Map<String, dynamic>))
        .toList();

    dynamic correct = json['correct_answer'];
    // correct_answer puede venir como string JSON serializado ('"b"') o ya decodificado.
    if (correct is String && correct.startsWith('"') && correct.endsWith('"')) {
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
      fuelReward: json['fuel_reward'] as int? ?? 0,
      explanation: json['explanation'] as String?,
      retroWrong: json['retro_wrong'] as String?,
      gancho: json['gancho'] as String?,
      groupName: json['group_name'] as String?,
      isHito: json['is_hito'] as bool? ?? false,
      badgeName: json['badge_name'] as String?,
      catalogId: json['catalog_id'] as String?,
    );
  }

  bool isCorrect(String answerId) => correctAnswer is List
      ? (correctAnswer as List).contains(answerId)
      : answerId == correctAnswer;
}
