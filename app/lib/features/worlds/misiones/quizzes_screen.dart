import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/question.dart';
import '../../../shared/providers/question_provider.dart';
import '../../../shared/widgets/activity_player.dart';
import '../../../shared/widgets/screen_background.dart';
import '../../../shared/widgets/game_card.dart';
import '../../../shared/widgets/tab_icon.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Quizzes — el niño elige primero QUÉ TIPO de quiz quiere jugar (Elegir,
// Clasificar, Relacionar, Ordenar, Trivia) y luego juega solo las preguntas
// de ese tipo. Usa el mismo catálogo que antes ("Desafíos", MS-016..020).
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
  QuestionType? _selectedType;

  @override
  Widget build(BuildContext context) {
    final activitiesAsync = ref.watch(questionsForModuleProvider('misiones'));
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
      body: ScreenBackground(
          child: activitiesAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (_, __) => const Center(
          child: Text('No se pudieron cargar los quizzes.',
              style: TextStyle(color: Colors.white70, fontFamily: 'Nunito')),
        ),
        data: (all) {
          final pool =
              all.where((q) => q.groupName?.contains('Desafío') == true).toList();

          if (_selectedType == null) {
            return _QuizTypeGrid(
              pool: pool,
              onSelect: (t) => setState(() => _selectedType = t),
            );
          }

          final filtered =
              pool.where((q) => q.type == _selectedType).toList();
          return ActivityPlayer(
            key: ValueKey(_selectedType),
            activities: filtered,
            accentColor: info!.$3,
          );
        },
      )),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cuadrícula de tipos de quiz
// ─────────────────────────────────────────────────────────────────────────────
class _QuizTypeGrid extends StatelessWidget {
  const _QuizTypeGrid({required this.pool, required this.onSelect});
  final List<Question> pool;
  final ValueChanged<QuestionType> onSelect;

  @override
  Widget build(BuildContext context) {
    final counts = <QuestionType, int>{};
    for (final q in pool) {
      counts[q.type] = (counts[q.type] ?? 0) + 1;
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
          return _QuizTypeCard(
            emoji: e.value.$2,
            label: e.value.$1,
            color: e.value.$3,
            iconName: e.value.$4,
            count: count,
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
    required this.onTap,
  });
  final String emoji;
  final String label;
  final Color color;
  final String iconName;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final locked = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: locked ? 0.40 : 1.0,
        child: GameCard(
          accentColor: color,
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
                locked ? 'Próximamente' : '$count pregunta${count == 1 ? '' : 's'}',
                style: TextStyle(
                  color: locked ? Colors.white38 : Colors.white60,
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
