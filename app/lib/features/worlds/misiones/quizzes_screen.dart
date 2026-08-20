import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/question.dart';
import '../../../data/repositories/quiz_completion_repository.dart';
import '../../../shared/providers/question_provider.dart';
import '../../../shared/widgets/activity_player.dart';
import '../../../shared/widgets/screen_background.dart';
import '../../../shared/widgets/game_card.dart';
import '../../../shared/widgets/game_popup.dart';
import '../../../shared/widgets/tab_icon.dart';
import '../../../shared/widgets/return_to_mission_banner.dart';
import 'misiones_screen.dart';

// Todas las preguntas de Quizzes dan 10 monedas fijas cada una (sin importar
// que el banco original de cada pregunta esté en 0 para su uso como
// pregunta diaria) — solo aplica dentro de Quizzes, no cambia esos bancos.
const int kCoinsPerQuizQuestion = 10;

// Quizzes ya no usa su propio banco de preguntas ("Desafío") — reutiliza
// TODAS las preguntas diarias de los 5 edificios (module_slug + grupo exacto
// que usa cada uno para su pregunta del día). No toca esos bancos: la
// pregunta diaria en cada edificio sigue funcionando igual, esto solo agrega
// una segunda pantalla que lee de las mismas preguntas.
const _kDailyQuestionSources = <String, String>{
  'mi_bolsa': 'Diario',
  'banco_estelar_diario': 'Diario',
  'trabajos': 'Diario',
  'tienda': 'Diario',
  'misiones': '🌞 Diaria',
};

// ─────────────────────────────────────────────────────────────────────────────
// Quizzes — el niño elige primero QUÉ TIPO de quiz quiere jugar (Elegir,
// Clasificar, Relacionar, Ordenar, Trivia) y luego juega solo las preguntas
// de ese tipo. El banco es la unión de las preguntas diarias de los 5
// edificios (Mi Bolsa, Banco Estelar, Trabajos, Tienda, Misiones).
// ─────────────────────────────────────────────────────────────────────────────
void showQuizzesDialog(BuildContext context) {
  final size = MediaQuery.of(context).size;
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Quizzes',
    barrierColor: Colors.black.withOpacity(0.65),
    transitionDuration: const Duration(milliseconds: 280),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
        child: FadeTransition(opacity: anim, child: child),
      );
    },
    pageBuilder: (ctx, _, __) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: size.width * 0.94,
          height: size.height * 0.90,
          child: const QuizzesScreen(),
        ),
      ),
    ),
  );
}

// Nombre, emoji, color y nombre de ícono de cada mecánica del catálogo.
const _mechanicInfo = <QuestionType, (String, String, Color, String)>{
  QuestionType.multipleChoice: ('Elegir', '🎯', Color(0xFF4FC3F7), 'quiz_elegir'),
  QuestionType.classify: (
    'Clasificar',
    '🗂️',
    Color(0xFF66BB6A),
    'quiz_clasificar'
  ),
  QuestionType.dragMatch: (
    'Relacionar',
    '🔗',
    Color(0xFFAB47BC),
    'quiz_relacionar'
  ),
  QuestionType.orderSteps: (
    'Ordenar',
    '🔢',
    Color(0xFFFFA726),
    'quiz_ordenar'
  ),
  QuestionType.trueFalse: ('Trivia', '✅', Color(0xFFEF5350), 'quiz_trivia'),
};

class QuizzesScreen extends ConsumerStatefulWidget {
  const QuizzesScreen({super.key});

  @override
  ConsumerState<QuizzesScreen> createState() => _QuizzesScreenState();
}

class _QuizzesScreenState extends ConsumerState<QuizzesScreen> {
  final _rng = Random();
  final _repo = QuizCompletionRepository();

  QuestionType? _selectedType;
  Set<String> _answeredIds = {};
  List<Question> _currentRound = [];
  int _roundKey = 0;
  bool _loadingProgress = false;

  // Rondas de 3 preguntas al azar por sección. Al acertar las 3, esas
  // preguntas quedan marcadas para siempre (no vuelven a salir) y se sortean
  // otras 3 del resto — hasta que ya no queden, y esa sección queda completa.
  Future<void> _selectType(QuestionType type, List<Question> pool) async {
    setState(() {
      _selectedType = type;
      _loadingProgress = true;
    });
    final answered = await _repo.answeredQuestionIds();
    if (!mounted) return;
    setState(() {
      _answeredIds = answered;
      _loadingProgress = false;
      _pickNewRound(pool.where((q) => q.type == type).toList());
    });
  }

  void _pickNewRound(List<Question> pool) {
    final remaining = pool.where((q) => !_answeredIds.contains(q.id)).toList()
      ..shuffle(_rng);
    _currentRound = remaining.take(3).toList();
    _roundKey++;
  }

  void _onSessionComplete(bool allCorrect) {
    if (!allCorrect) {
      showGamePopup(
        context,
        'Fallaste una — vamos de nuevo con las mismas 3. ¡Tú puedes! 💪',
        accentColor: Colors.orange.shade700,
      );
      setState(() => _roundKey++); // mismas 3, solo reinicia el reproductor
      return;
    }

    // Al terminar una ronda completa (las 3 correctas), regresa a Quizzes en
    // vez de encadenar otra ronda en la misma pantalla — el niño ve su
    // progreso actualizado en la cuadrícula y decide si sigue o cambia de
    // sección. La actualización de estado es inmediata (no espera la red)
    // para que el regreso se sienta instantáneo; guardar en la base de datos
    // pasa en segundo plano.
    final ids = _currentRound.map((q) => q.id).toList();
    final coinsEarned = _currentRound.length * kCoinsPerQuizQuestion;
    final xpEarned = _currentRound.fold<int>(0, (s, q) => s + q.xpReward);
    setState(() {
      _answeredIds.addAll(ids);
      _selectedType = null;
    });
    _repo.markAnsweredQuestions(ids);

    showGamePopup(
      context,
      '¡Ronda completa! 🎉\n+$coinsEarned monedas 🪙  +$xpEarned XP ⭐',
      accentColor: const Color(0xFF4ADE80),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sourceAsyncs = {
      for (final moduleSlug in _kDailyQuestionSources.keys)
        moduleSlug: ref.watch(questionsForModuleProvider(moduleSlug)),
    };
    final info = _selectedType == null ? null : _mechanicInfo[_selectedType!];

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_selectedType != null) {
              setState(() => _selectedType = null);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          info == null ? '🧠 Quizzes' : '${info.$2} ${info.$1}',
          style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 20),
        ),
      ),
      body: Stack(children: [
        ScreenBackground(
        child: Builder(builder: (context) {
          if (sourceAsyncs.values.any((a) => a.isLoading)) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          }
          if (sourceAsyncs.values.any((a) => a.hasError)) {
            return const Center(
              child: Text('No se pudieron cargar los quizzes.',
                  style:
                      TextStyle(color: Colors.white70, fontFamily: 'Nunito')),
            );
          }

          final pool = <Question>[];
          for (final entry in _kDailyQuestionSources.entries) {
            final questions = sourceAsyncs[entry.key]?.valueOrNull ?? [];
            pool.addAll(questions.where((q) => q.groupName == entry.value));
          }

          if (_selectedType == null) {
            return _QuizTypeGrid(
              pool: pool,
              answeredIds: _answeredIds,
              onSelect: (type) => _selectType(type, pool),
            );
          }
          if (_loadingProgress) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          }

          if (_currentRound.isEmpty) {
            return _SectionCompleteView(info: info!);
          }

          return Column(
            children: [
              Expanded(
                child: ActivityPlayer(
                  key: ValueKey('$_selectedType-$_roundKey'),
                  activities: _currentRound,
                  accentColor: info!.$3,
                  coinOverride: kCoinsPerQuizQuestion,
                  allOrNothing: true,
                  onSessionComplete: _onSessionComplete,
                ),
              ),
            ],
          );
        },
      )),
        ReturnToMissionBanner(
          onReturn: () {
            Navigator.of(context).pop();
            showMisionesDialog(context);
          },
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cuadrícula de tipos de quiz
// ─────────────────────────────────────────────────────────────────────────────
class _QuizTypeGrid extends StatelessWidget {
  const _QuizTypeGrid(
      {required this.pool, required this.answeredIds, required this.onSelect});
  final List<Question> pool;
  final Set<String> answeredIds;
  final ValueChanged<QuestionType> onSelect;

  @override
  Widget build(BuildContext context) {
    final counts = <QuestionType, int>{};
    final remaining = <QuestionType, int>{};
    for (final q in pool) {
      counts[q.type] = (counts[q.type] ?? 0) + 1;
      if (!answeredIds.contains(q.id)) {
        remaining[q.type] = (remaining[q.type] ?? 0) + 1;
      }
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
        children: _mechanicInfo.entries.map((e) {
          final count = counts[e.key] ?? 0;
          final left = remaining[e.key] ?? 0;
          return _QuizTypeCard(
            emoji: e.value.$2,
            label: e.value.$1,
            color: e.value.$3,
            iconName: e.value.$4,
            count: count,
            remaining: left,
            onTap: count > 0 ? () => onSelect(e.key) : null,
          );
        }).toList(),
      ),
    );
  }
}

class _QuizTypeCard extends StatelessWidget {
  const _QuizTypeCard({
    required this.emoji,
    required this.label,
    required this.color,
    required this.iconName,
    required this.count,
    required this.remaining,
    required this.onTap,
  });
  final String emoji;
  final String label;
  final Color color;
  final String iconName;
  final int count;
  final int remaining;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final locked = onTap == null;
    final completed = count > 0 && remaining == 0;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: locked ? 0.40 : 1.0,
        child: GameCard(
          accentColor: completed ? const Color(0xFF4ADE80) : color,
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TabIcon(name: iconName, emoji: emoji, size: 88),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  fontFamily: 'Nunito',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                locked
                    ? 'Próximamente'
                    : completed
                        ? '✅ Completado'
                        : '$remaining de $count',
                style: TextStyle(
                  color: locked
                      ? Colors.white38
                      : completed
                          ? const Color(0xFF4ADE80)
                          : Colors.white60,
                  fontWeight: completed ? FontWeight.w700 : FontWeight.normal,
                  fontSize: 11,
                  fontFamily: 'Nunito',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vista de sección completada — el niño ya contestó bien todas las preguntas
// disponibles de este tipo.
// ─────────────────────────────────────────────────────────────────────────────
class _SectionCompleteView extends StatelessWidget {
  const _SectionCompleteView({required this.info});
  final (String, String, Color, String) info;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(info.$2, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text(
              '¡Completaste ${info.$1}! 🎉',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ya contestaste bien todas las preguntas de esta sección.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
                fontFamily: 'Nunito',
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
