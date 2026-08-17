import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/question.dart';
import '../../../data/models/world.dart';
import '../../../data/repositories/question_repository.dart';
import '../../../data/repositories/wallet_repository.dart';
import '../../../data/repositories/mission_tracker.dart';
import '../../../shared/providers/question_provider.dart';
import '../../../shared/providers/wallet_provider.dart';
import '../../../shared/providers/character_provider.dart';
import '../../../shared/providers/world_provider.dart';
import '../../../shared/widgets/screen_tutorial.dart';
import '../../../shared/widgets/coin_display.dart';
import '../../../shared/widgets/badge_unlock_celebration.dart';
import '../../../core/constants/app_sizes.dart';

// ─────────────────────────────────────────────────────────────────────────────
void showPreguntasDialog(BuildContext context) {
  final size = MediaQuery.of(context).size;
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Preguntas',
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
          child: const PreguntasScreen(),
        ),
      ),
    ),
  );
}

// Estado de cada pregunta individual
enum _AnswerState { unanswered, correct, wrong }

class PreguntasScreen extends ConsumerStatefulWidget {
  const PreguntasScreen({super.key});

  @override
  ConsumerState<PreguntasScreen> createState() => _PreguntasScreenState();
}

class _PreguntasScreenState extends ConsumerState<PreguntasScreen> {
  int _currentIndex = 0;
  _AnswerState _answerState = _AnswerState.unanswered;
  String? _selectedId;
  int _coinsEarned = 0;
  int _correctCount = 0;
  bool _showSummary = false;
  bool _showExplain = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final worldId = ref.watch(currentWorldProvider);
    final questionsAsync = ref.watch(questionsForWorldProvider(worldId));
    final worldName = allWorlds
        .firstWhere((w) => w.id == worldId, orElse: () => allWorlds.first)
        .shortName;

    return ScreenTutorial(
      tutorialKey: 'preguntas',
      steps: const [
        TutorialStep(
          title: '¡Hora de Preguntas! ❓',
          body: 'Responde preguntas de finanzas para ganar monedas. '
              'Cada respuesta correcta te da monedas y experiencia.',
        ),
        TutorialStep(
          title: 'Lee con calma 📖',
          body: 'Lee bien la pregunta antes de elegir. Después de responder '
              'verás la explicación correcta con Juan.',
        ),
      ],
      child: Scaffold(
        backgroundColor: const Color(0xFF0D47A1),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop(),
          ),
          title: Text(
            '❓ Preguntas: $worldName',
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          actions: [
            // Monedas en AppBar
            Consumer(builder: (_, ref, __) {
              final coins =
                  ref.watch(currentWalletProvider).valueOrNull?.totalCoins ?? 0;
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  children: [
                    const AnimatedCoin(size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '$coins',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFFFFD600),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
        body: questionsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          error: (e, _) => _ErrorView(
            onRetry: () => ref.invalidate(questionsForWorldProvider(worldId)),
          ),
          data: (questions) {
            if (questions.isEmpty) {
              return const _EmptyView();
            }
            if (_showSummary) {
              return _SummaryView(
                correctCount: _correctCount,
                totalCount: questions.length,
                coinsEarned: _coinsEarned,
                onFinish: () => context.pop(),
              );
            }
            final q = questions[_currentIndex];
            return _QuizBody(
              question: q,
              questionNum: _currentIndex + 1,
              totalQuestions: questions.length,
              answerState: _answerState,
              selectedId: _selectedId,
              showExplain: _showExplain,
              onAnswer: (id) => _handleAnswer(q, id),
              onNext: () => _handleNext(questions.length),
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleAnswer(Question q, String optionId) async {
    if (_answerState != _AnswerState.unanswered) return;

    final isCorrect = q.isCorrect(optionId);
    setState(() {
      _selectedId = optionId;
      _answerState = isCorrect ? _AnswerState.correct : _AnswerState.wrong;
      _showExplain = true;
    });

    if (isCorrect) {
      _correctCount++;
      _coinsEarned += q.coinReward;

      // Otorgar monedas y XP en paralelo + registrar para misiones
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final xpFuture = awardXp(ref, q.xpReward);
      await Future.wait<void>([
        if (userId != null)
          WalletRepository()
              .awardStarterCoins(userId, q.coinReward)
              .catchError((_) => null),
        MissionTracker().recordQuiz(), // ← conteo para misiones
      ]);
      final newBadges = await xpFuture;
      if (userId != null) ref.invalidate(currentWalletProvider);
      if (mounted) showBadgeUnlockCelebrations(context, ref, newBadges);
    }

    // Registrar en historial
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      QuestionRepository().recordAnswer(
        userId: userId,
        questionId: q.id,
        isCorrect: isCorrect,
      );
    }
  }

  void _handleNext(int totalQuestions) {
    if (_currentIndex < totalQuestions - 1) {
      setState(() {
        _currentIndex++;
        _answerState = _AnswerState.unanswered;
        _selectedId = null;
        _showExplain = false;
      });
    } else {
      setState(() => _showSummary = true);
    }
  }
}

// ─── Cuerpo principal del quiz ────────────────────────────────────────────────
class _QuizBody extends StatelessWidget {
  const _QuizBody({
    required this.question,
    required this.questionNum,
    required this.totalQuestions,
    required this.answerState,
    required this.selectedId,
    required this.showExplain,
    required this.onAnswer,
    required this.onNext,
  });

  final Question question;
  final int questionNum;
  final int totalQuestions;
  final _AnswerState answerState;
  final String? selectedId;
  final bool showExplain;
  final void Function(String) onAnswer;
  final VoidCallback onNext;

  bool get _answered => answerState != _AnswerState.unanswered;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Juan (izquierda) ──────────────────────────────────────────────
        Expanded(
          flex: 2,
          child: _JuanPanel(answerState: answerState),
        ),

        // ── Pregunta + opciones (derecha) ─────────────────────────────────
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md,
              vertical: AppSizes.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Progreso
                _ProgressBar(
                  current: questionNum,
                  total: totalQuestions,
                ),
                const SizedBox(height: AppSizes.md),

                // Tarjeta de pregunta
                _QuestionCard(question: question),
                const SizedBox(height: AppSizes.md),

                // Opciones
                ...question.options.map(
                  (opt) => _OptionTile(
                    option: opt,
                    isSelected: selectedId == opt.id,
                    isCorrect: question.correctAnswer == opt.id,
                    isAnswered: _answered,
                    answerState: answerState,
                    onTap: () => onAnswer(opt.id),
                  ),
                ),

                // Explicación post-respuesta
                if (showExplain && question.explanation != null) ...[
                  const SizedBox(height: AppSizes.sm),
                  _ExplanationCard(
                    explanation: question.explanation!,
                    isCorrect: answerState == _AnswerState.correct,
                  ),
                ],

                // Botón siguiente
                if (_answered) ...[
                  const SizedBox(height: AppSizes.md),
                  FilledButton(
                    onPressed: onNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD600),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      questionNum < totalQuestions
                          ? 'Siguiente pregunta →'
                          : '¡Ver resultados! 🏆',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Juan animado ─────────────────────────────────────────────────────────────
class _JuanPanel extends StatelessWidget {
  const _JuanPanel({required this.answerState});
  final _AnswerState answerState;

  String get _emoji {
    switch (answerState) {
      case _AnswerState.correct:
        return '🦊';
      case _AnswerState.wrong:
        return '😔';
      case _AnswerState.unanswered:
        return '🦊';
    }
  }

  String get _bubble {
    switch (answerState) {
      case _AnswerState.correct:
        return '¡Correcto! 🎉';
      case _AnswerState.wrong:
        return 'Casi... 😅\n¡Sigue intentando!';
      case _AnswerState.unanswered:
        return '¡Piénsalo bien!';
    }
  }

  Color get _bubbleColor {
    switch (answerState) {
      case _AnswerState.correct:
        return const Color(0xFF2E7D32);
      case _AnswerState.wrong:
        return const Color(0xFFC62828);
      case _AnswerState.unanswered:
        return const Color(0xFF1565C0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Burbuja de diálogo
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _bubbleColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 6),
              ],
            ),
            child: Text(
              _bubble,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          )
              .animate(key: ValueKey(_answerState))
              .fadeIn(duration: 250.ms)
              .slideY(begin: 0.1, end: 0),

          // Juan
          Text(_emoji, style: const TextStyle(fontSize: 72))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(
                begin: 0,
                end: answerState == _AnswerState.correct ? -10 : -4,
                duration: 800.ms,
                curve: Curves.easeInOut,
              ),
        ],
      ),
    );
  }

  String get _answerState => answerState.name;
}

// ─── Barra de progreso ────────────────────────────────────────────────────────
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Pregunta $current de $total',
          style: const TextStyle(
            color: Colors.white70,
            fontFamily: 'Nunito',
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: current / total,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFFFD600),
              ),
              minHeight: 8,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Tarjeta de pregunta ──────────────────────────────────────────────────────
class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question});
  final Question question;

  @override
  Widget build(BuildContext context) {
    final isTF = question.type == QuestionType.trueFalse;
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Text(
            isTF ? '🔀' : '❓',
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              question.questionText,
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD600).withAlpha(30),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFD600)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '+${question.coinReward}',
                  style: const TextStyle(
                    color: Color(0xFFE65100),
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
                const AnimatedCoin(size: 14),
              ],
            ),
          ),
        ],
      ),
    )
        .animate(key: ValueKey(question.id))
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.05, end: 0);
  }
}

// ─── Opción de respuesta ──────────────────────────────────────────────────────
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.isSelected,
    required this.isCorrect,
    required this.isAnswered,
    required this.answerState,
    required this.onTap,
  });

  final QuestionOption option;
  final bool isSelected;
  final bool isCorrect;
  final bool isAnswered;
  final _AnswerState answerState;
  final VoidCallback onTap;

  Color get _bgColor {
    if (!isAnswered) return Colors.white;
    if (isCorrect) return const Color(0xFFE8F5E9);
    if (isSelected) return const Color(0xFFFFEBEE);
    return Colors.white.withAlpha(180);
  }

  Color get _borderColor {
    if (!isAnswered) return Colors.transparent;
    if (isCorrect) return const Color(0xFF2E7D32);
    if (isSelected) return const Color(0xFFC62828);
    return Colors.transparent;
  }

  String get _trailingIcon {
    if (!isAnswered) return '';
    if (isCorrect) return '✅';
    if (isSelected) return '❌';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: _borderColor, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4),
          ],
        ),
        child: ListTile(
          onTap: isAnswered ? null : onTap,
          leading: option.icon != null
              ? Text(option.icon!, style: const TextStyle(fontSize: 24))
              : null,
          title: Text(
            option.text,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: isAnswered && !isCorrect && !isSelected
                  ? Colors.black38
                  : Colors.black87,
            ),
          ),
          trailing: _trailingIcon.isNotEmpty
              ? Text(_trailingIcon, style: const TextStyle(fontSize: 20))
              : null,
        ),
      ),
    );
  }
}

// ─── Explicación post-respuesta ───────────────────────────────────────────────
class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard({
    required this.explanation,
    required this.isCorrect,
  });
  final String explanation;
  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: isCorrect ? const Color(0xFF1B5E20) : const Color(0xFF7F0000),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCorrect ? '💡' : '📚',
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              explanation,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Nunito',
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }
}

// ─── Pantalla de resumen final ────────────────────────────────────────────────
class _SummaryView extends StatelessWidget {
  const _SummaryView({
    required this.correctCount,
    required this.totalCount,
    required this.coinsEarned,
    required this.onFinish,
  });

  final int correctCount;
  final int totalCount;
  final int coinsEarned;
  final VoidCallback onFinish;

  String get _medal {
    final pct = totalCount == 0 ? 0 : correctCount / totalCount;
    if (pct == 1.0) return '🥇';
    if (pct >= 0.75) return '🥈';
    if (pct >= 0.5) return '🥉';
    return '📚';
  }

  String get _message {
    final pct = totalCount == 0 ? 0 : correctCount / totalCount;
    if (pct == 1.0) return '¡Perfecto! ¡Eres un genio financiero!';
    if (pct >= 0.75) return '¡Muy bien! ¡Casi perfecto!';
    if (pct >= 0.5) return '¡Buen intento! Sigue practicando.';
    return '¡No te rindas! Repasa y vuelve a intentarlo.';
  }

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder + SingleChildScrollView: centra cuando el contenido cabe
    // y activa scroll cuando la pantalla es demasiado pequeña (landscape).
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: AppSizes.lg, vertical: AppSizes.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusXl),
                  ),
                  color: const Color(0xFF1565C0),
                  elevation: 12,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.lg, vertical: AppSizes.md),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Medalla — tamaño reducido para landscape
                        Text(_medal, style: const TextStyle(fontSize: 56))
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .scale(
                              begin: const Offset(1, 1),
                              end: const Offset(1.1, 1.1),
                              duration: 700.ms,
                            ),
                        const SizedBox(height: AppSizes.sm),
                        Text(
                          _message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: AppSizes.sm),
                        // Score
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _StatChip(
                              label: 'Correctas',
                              value: '$correctCount/$totalCount',
                              color: const Color(0xFF2E7D32),
                            ),
                            const SizedBox(width: 12),
                            _StatChip(
                              label: 'Ganadas',
                              value: '$coinsEarned',
                              showCoin: true,
                              color: const Color(0xFFE65100),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.md),
                        FilledButton(
                          onPressed: onFinish,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD600),
                            foregroundColor: Colors.black87,
                            minimumSize: const Size(double.infinity, 46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text(
                            '🌲 Volver al Bosque',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms).scale(
                      begin: const Offset(0.85, 0.85),
                      end: const Offset(1, 1),
                      curve: Curves.easeOutBack,
                    ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    this.showCoin = false,
  });
  final String label;
  final String value;
  final Color color;
  final bool showCoin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              if (showCoin) ...[
                const SizedBox(width: 5),
                const AnimatedCoin(size: 18),
              ],
            ],
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontFamily: 'Nunito',
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Vistas auxiliares ────────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🌿', style: TextStyle(fontSize: 64)),
          SizedBox(height: 16),
          Text(
            'No hay preguntas disponibles\npor ahora. ¡Vuelve pronto!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'Nunito',
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('😕', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text(
            'No se pudieron cargar las preguntas',
            style: TextStyle(color: Colors.white70, fontFamily: 'Nunito'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar',
                style: TextStyle(fontFamily: 'Nunito')),
          ),
        ],
      ),
    );
  }
}
