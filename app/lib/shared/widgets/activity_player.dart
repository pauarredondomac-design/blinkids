import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/question.dart';
import '../../data/repositories/building_question_repository.dart';
import '../../data/repositories/mission_tracker.dart';
import '../../data/repositories/question_repository.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../data/services/analytics_service.dart';
import '../providers/demo_progress_provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/character_provider.dart';
import '../providers/fuel_provider.dart';
import 'coin_display.dart';
import 'badges_row.dart';
import 'badge_unlock_celebration.dart';
import 'rocket_launch_overlay.dart';
import 'game_card.dart';
import 'blink_dialogue_box.dart';
import '../theme/game_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ActivityPlayer — motor genérico de actividades narrativas.
// Renderiza las 5 mecánicas del catálogo (Elegir, Clasificar, Relacionar,
// Ordenar, Trivia) a partir de la misma tabla `questions`, y otorga
// monedas/XP/combustible/medallas usando la arquitectura de recompensas ya
// existente (awardXp, WalletRepository, fuelNotifierProvider, badges).
// ─────────────────────────────────────────────────────────────────────────────
enum _AnswerState { unanswered, correct, wrong }

class ActivityPlayer extends ConsumerStatefulWidget {
  const ActivityPlayer({
    super.key,
    required this.activities,
    required this.accentColor,
    this.worldIdForFuel = 'space',
    this.onAllComplete,
    this.allOrNothing = false,
    this.rewardsEnabled = true,
    this.onSessionComplete,
    this.coinOverride,
  });

  final List<Question> activities;
  final Color accentColor;
  final String worldIdForFuel;
  final VoidCallback? onAllComplete;

  /// Si se da, reemplaza el coin_reward guardado en cada pregunta (uso:
  /// Quizzes da 10 monedas fijas por pregunta, sin importar que el banco
  /// original de esa pregunta esté configurado en 0 para su uso normal).
  final int? coinOverride;

  /// Si es true (uso: Quizzes), la recompensa NO se entrega pregunta por
  /// pregunta — se acumula y solo se entrega al final, y solo si el niño no
  /// falló ninguna. Si falla una sola, no recibe nada de esa sesión.
  final bool allOrNothing;

  /// Si es false, ni siquiera se acumula/entrega recompensa aunque salga
  /// todo correcto (uso: Quizzes ya alcanzó el máximo de veces con premio).
  final bool rewardsEnabled;

  /// Se llama al terminar la sesión completa (todas las preguntas
  /// respondidas), con `true` si el niño no falló ninguna.
  final void Function(bool allCorrect)? onSessionComplete;

  @override
  ConsumerState<ActivityPlayer> createState() => _ActivityPlayerState();
}

class _ActivityPlayerState extends ConsumerState<ActivityPlayer> {
  int _index = 0;
  _AnswerState _answerState = _AnswerState.unanswered;
  int _coinsEarned = 0;
  int _correctCount = 0;
  bool _showSummary = false;
  bool _hadWrong = false;

  Question get _current => widget.activities[_index];

  Future<void> _handleSubmit(bool isCorrect) async {
    if (_answerState != _AnswerState.unanswered) return;
    setState(() =>
        _answerState = isCorrect ? _AnswerState.correct : _AnswerState.wrong);

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      QuestionRepository().recordAnswer(
        userId: userId,
        questionId: _current.id,
        isCorrect: isCorrect,
      );
    }
    AnalyticsService.instance.quizCompleted(
        _current.id, isCorrect, isCorrect ? _current.xpReward : 0);

    if (!isCorrect) {
      _hadWrong = true;
      if (mounted) await _showResultPopup(false);
      return;
    }
    _correctCount++;

    // Modo todo-o-nada (Quizzes): no se entrega nada pregunta por pregunta,
    // se acumula todo y se entrega al final solo si no hubo ningún fallo.
    if (widget.allOrNothing) {
      if (mounted) await _showResultPopup(true);
      return;
    }

    await _grantReward(_current);
    if (mounted) await _showResultPopup(true);
  }

  /// Popup con el resultado (correcto/incorrecto + comentario) — reemplaza
  /// el banner + botón "Siguiente" de abajo de pantalla. Al cerrarse (tap
  /// afuera o el botón), avanza sola a la siguiente pregunta.
  Future<void> _showResultPopup(bool isCorrect) async {
    final q = _current;
    final isLast = _index >= widget.activities.length - 1;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _AnswerResultDialog(
        isCorrect: isCorrect,
        text: isCorrect
            ? (q.explanation ?? '¡Muy bien!')
            : (q.retroWrong ??
                '¡Estuvo cerca! Pensemos juntos qué nos acerca más a Marte.'),
        accentColor: widget.accentColor,
        isLast: isLast,
      ),
    );
    if (mounted) await _handleNext();
  }

  /// Entrega la recompensa de una pregunta (monedas + XP + combustible +
  /// medalla/hito). Compartido por el modo normal (pregunta por pregunta) y
  /// por el cierre del modo todo-o-nada (una vez, al final, por cada
  /// pregunta de la sesión).
  Future<void> _grantReward(Question q) async {
    final coins = widget.coinOverride ?? q.coinReward;
    _coinsEarned += coins;
    final userId = Supabase.instance.client.auth.currentUser?.id;

    final xpFuture = awardXp(ref, q.xpReward);
    final futures = <Future>[];
    if (DemoStore.isActive) {
      if (coins > 0) ref.read(demoProgressProvider).addCoins(coins);
    } else if (userId != null && coins > 0) {
      futures.add(
        WalletRepository()
            .awardStarterCoins(userId, coins)
            .catchError((_) => null),
      );
    }
    await Future.wait(futures);
    final newBadges = await xpFuture;
    if (userId != null) ref.invalidate(currentWalletProvider);

    var reachedFullFuel = false;
    if (q.fuelReward > 0) {
      reachedFullFuel = await ref
          .read(fuelNotifierProvider.notifier)
          .addFuel(widget.worldIdForFuel, q.fuelReward);
    }

    if (!mounted) return;
    if (q.isHito && q.badgeName != null) {
      BadgeUnlockToast.show(context, 'hito-${q.id}',
          name: q.badgeName, emoji: '⭐');
    } else {
      showBadgeUnlockCelebrations(context, ref, newBadges);
    }
    if (reachedFullFuel) await handleFuelReachedFull(context, ref);
  }

  Future<void> _handleNext() async {
    if (_index < widget.activities.length - 1) {
      setState(() {
        _index++;
        _answerState = _AnswerState.unanswered;
      });
      return;
    }

    if (widget.allOrNothing) {
      final allCorrect = !_hadWrong;
      if (allCorrect && widget.rewardsEnabled) {
        for (final q in widget.activities) {
          await _grantReward(q);
        }
      }
      widget.onSessionComplete?.call(allCorrect);
    }

    if (!mounted) return;
    setState(() => _showSummary = true);
    widget.onAllComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.activities.isEmpty) {
      return const _EmptyActivities();
    }
    if (_showSummary) {
      return _ActivitySummary(
        correctCount: _correctCount,
        total: widget.activities.length,
        coinsEarned: _coinsEarned,
        accentColor: widget.accentColor,
        onRestart: () => setState(() {
          _index = 0;
          _answerState = _AnswerState.unanswered;
          _coinsEarned = 0;
          _correctCount = 0;
          _hadWrong = false;
          _showSummary = false;
        }),
      );
    }

    // Sin scroll: todo debe caber en pantalla. El cuerpo de la mecánica
    // (Expanded) es lo único con altura variable — si sus opciones no caben,
    // se apretuja él solo en vez de forzar scroll a toda la pantalla.
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        key: ValueKey(_current.id),
        children: [
          _ActivityProgress(
            current: _index + 1,
            total: widget.activities.length,
            accentColor: widget.accentColor,
          ),
          const SizedBox(height: 10),
          if (_current.gancho != null) ...[
            BlinkDialogueBox(
                text: _current.gancho!, accentColor: widget.accentColor),
            const SizedBox(height: 8),
          ],
          _ActivityCard(question: _current, accentColor: widget.accentColor),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: _MechanicBody(
                key: ValueKey('mech-${_current.id}'),
                question: _current,
                accentColor: widget.accentColor,
                answered: _answerState != _AnswerState.unanswered,
                onSubmit: _handleSubmit,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Popup de resultado — reemplaza el banner inline + botón "Siguiente".
// ─────────────────────────────────────────────────────────────────────────────
class _AnswerResultDialog extends StatelessWidget {
  const _AnswerResultDialog({
    required this.isCorrect,
    required this.text,
    required this.accentColor,
    required this.isLast,
  });
  final bool isCorrect;
  final String text;
  final Color accentColor;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = isCorrect ? const Color(0xFF4ADE80) : accentColor;
    return Dialog(
      backgroundColor: const Color(0xFF0D1230),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: color.withOpacity(0.6), width: 1.5),
      ),
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isCorrect ? '✅' : '💭', style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text(
                isCorrect ? '¡Correcto!' : 'Casi...',
                style: TextStyle(
                  color: color,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    isLast ? 'Terminar' : 'Siguiente',
                    style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 14),
                  ),
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
class _EmptyActivities extends StatelessWidget {
  const _EmptyActivities();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aún no hay actividades cargadas aquí.\n¡Vuelve pronto! 🦊',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white70, fontFamily: 'Nunito', fontSize: 14),
          ),
        ),
      );
}

class _ActivityProgress extends StatelessWidget {
  const _ActivityProgress(
      {required this.current, required this.total, required this.accentColor});
  final int current;
  final int total;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$current / $total',
            style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontFamily: 'Nunito',
                fontSize: 12,
                fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: current / total,
              minHeight: 7,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation(accentColor),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.question, required this.accentColor});
  final Question question;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return GameCard(
      accentColor: accentColor,
      padding: const EdgeInsets.all(16),
      child: Text(
        question.questionText,
        style: GameText.body(weight: FontWeight.w800, size: 16),
      ),
    );
  }
}


class _ActivitySummary extends StatelessWidget {
  const _ActivitySummary({
    required this.correctCount,
    required this.total,
    required this.coinsEarned,
    required this.accentColor,
    required this.onRestart,
  });
  final int correctCount;
  final int total;
  final int coinsEarned;
  final Color accentColor;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            const Text('¡Actividades completadas!',
                style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w900,
                    fontSize: 20)),
            const SizedBox(height: 8),
            Text('$correctCount / $total correctas',
                style: const TextStyle(
                    color: Colors.white70, fontFamily: 'Nunito', fontSize: 14)),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('+$coinsEarned ',
                    style: const TextStyle(
                        color: Color(0xFFFFD600),
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
                const AnimatedCoin(size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MechanicBody — despacha a la mecánica correcta
// ─────────────────────────────────────────────────────────────────────────────
class _MechanicBody extends StatelessWidget {
  const _MechanicBody({
    super.key,
    required this.question,
    required this.accentColor,
    required this.answered,
    required this.onSubmit,
  });
  final Question question;
  final Color accentColor;
  final bool answered;
  final void Function(bool isCorrect) onSubmit;

  @override
  Widget build(BuildContext context) {
    switch (question.type) {
      case QuestionType.orderSteps:
        return _OrdenarBody(
            question: question,
            accentColor: accentColor,
            answered: answered,
            onSubmit: onSubmit);
      case QuestionType.classify:
        return _ClasificarBody(
            question: question,
            accentColor: accentColor,
            answered: answered,
            onSubmit: onSubmit);
      case QuestionType.dragMatch:
        return _RelacionarBody(
            question: question,
            accentColor: accentColor,
            answered: answered,
            onSubmit: onSubmit);
      case QuestionType.multipleChoice:
      case QuestionType.trueFalse:
      case QuestionType.fillBlank:
        return _ElegirBody(
            question: question,
            accentColor: accentColor,
            answered: answered,
            onSubmit: onSubmit);
      case QuestionType.reflection:
        return _ReflexionBody(
            accentColor: accentColor,
            answered: answered,
            onSubmit: onSubmit);
    }
  }
}

// ─── Reflexión (sin respuesta incorrecta) ─────────────────────────────────────
class _ReflexionBody extends StatelessWidget {
  const _ReflexionBody({
    required this.accentColor,
    required this.answered,
    required this.onSubmit,
  });
  final Color accentColor;
  final bool answered;
  final void Function(bool) onSubmit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: answered ? null : () => onSubmit(true),
        style: FilledButton.styleFrom(
          backgroundColor: accentColor,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          answered ? '¡Listo!' : 'Continuar',
          style: const TextStyle(
              fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
    );
  }
}

// ─── Elegir / Trivia ──────────────────────────────────────────────────────────
class _ElegirBody extends StatefulWidget {
  const _ElegirBody(
      {required this.question,
      required this.accentColor,
      required this.answered,
      required this.onSubmit});
  final Question question;
  final Color accentColor;
  final bool answered;
  final void Function(bool) onSubmit;

  @override
  State<_ElegirBody> createState() => _ElegirBodyState();
}

class _ElegirBodyState extends State<_ElegirBody> {
  String? _selected;
  static const _letters = ['A', 'B', 'C', 'D', 'E'];

  @override
  Widget build(BuildContext context) {
    final options = widget.question.options;
    return Column(
      children: List.generate(options.length, (i) {
        final opt = options[i];
        final isSelected = _selected == opt.id;
        // correctAnswer normalmente es un solo id, pero para preguntas
        // "ambas opciones son válidas" (sin respuesta incorrecta) puede
        // venir como lista de ids — cualquiera de ellos cuenta como acierto.
        final _correct = widget.question.correctAnswer;
        final isCorrectOpt =
            _correct is List ? _correct.contains(opt.id) : _correct == opt.id;
        Color accent = Colors.white38;
        Color bg = Colors.white.withOpacity(0.05);
        IconData? trailingIcon;
        if (widget.answered) {
          if (isCorrectOpt) {
            accent = const Color(0xFF4ADE80);
            bg = const Color(0xFF4ADE80).withOpacity(0.16);
            trailingIcon = Icons.check_circle_rounded;
          } else if (isSelected) {
            accent = Colors.redAccent;
            bg = Colors.redAccent.withOpacity(0.14);
            trailingIcon = Icons.cancel_rounded;
          }
        } else if (isSelected) {
          accent = widget.accentColor;
          bg = widget.accentColor.withOpacity(0.16);
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withOpacity(0.7), width: 1.6),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: widget.answered
                    ? null
                    : () {
                        setState(() => _selected = opt.id);
                        widget.onSubmit(isCorrectOpt);
                      },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.22),
                          shape: BoxShape.circle,
                          border: Border.all(color: accent),
                        ),
                        child: Text(
                          _letters[i % _letters.length],
                          style: TextStyle(
                              color: accent,
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w800,
                              fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (opt.icon != null) ...[
                        Text(opt.icon!, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(opt.text,
                            style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                height: 1.3)),
                      ),
                      if (trailingIcon != null) ...[
                        const SizedBox(width: 6),
                        Icon(trailingIcon, color: accent, size: 20),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─── Ordenar ──────────────────────────────────────────────────────────────────
class _OrdenarBody extends StatefulWidget {
  const _OrdenarBody(
      {required this.question,
      required this.accentColor,
      required this.answered,
      required this.onSubmit});
  final Question question;
  final Color accentColor;
  final bool answered;
  final void Function(bool) onSubmit;

  @override
  State<_OrdenarBody> createState() => _OrdenarBodyState();
}

class _OrdenarBodyState extends State<_OrdenarBody> {
  final List<QuestionOption> _picked = [];
  late List<QuestionOption> _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = List.of(widget.question.options);
  }

  void _pick(QuestionOption opt) {
    if (widget.answered) return;
    setState(() {
      _remaining.remove(opt);
      _picked.add(opt);
    });
    if (_remaining.isEmpty) {
      final order = _picked.map((o) => o.id).toList();
      final correct =
          (widget.question.correctAnswer as List?)?.cast<String>() ?? const [];
      final isCorrect = order.length == correct.length &&
          List.generate(order.length, (i) => order[i] == correct[i])
              .every((v) => v);
      widget.onSubmit(isCorrect);
    }
  }

  /// Quita [opt] de la secuencia elegida y lo regresa a las opciones
  /// disponibles — permite corregir un orden antes de completarlo.
  void _unpick(QuestionOption opt) {
    if (widget.answered) return;
    setState(() {
      _picked.remove(opt);
      _remaining.add(opt);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Toca en el orden correcto:',
            style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w600,
                fontSize: 12)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(widget.question.options.length, (i) {
            final filled = i < _picked.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: filled
                    ? LinearGradient(colors: [
                        widget.accentColor,
                        widget.accentColor.withOpacity(0.6),
                      ])
                    : null,
                color: filled ? null : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: filled ? widget.accentColor : Colors.white24),
                boxShadow: filled
                    ? [
                        BoxShadow(
                            color: widget.accentColor.withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2)),
                      ]
                    : null,
              ),
              child: Text('${i + 1}',
                  style: TextStyle(
                      color: filled ? Colors.white : Colors.white38,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800)),
            );
          }),
        ),
        const SizedBox(height: 10),
        if (_picked.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _picked.asMap().entries.map((e) {
              final i = e.key;
              final o = e.value;
              return GestureDetector(
                onTap: () => _unpick(o),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: widget.accentColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${i + 1}. ${o.text}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      if (!widget.answered) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.close_rounded,
                            color: Colors.white70, size: 15),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _remaining
              .map((opt) => GestureDetector(
                    onTap: () => _pick(opt),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Text(opt.text,
                          style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

// ─── Clasificar ───────────────────────────────────────────────────────────────
class _ClasificarBody extends StatefulWidget {
  const _ClasificarBody(
      {required this.question,
      required this.accentColor,
      required this.answered,
      required this.onSubmit});
  final Question question;
  final Color accentColor;
  final bool answered;
  final void Function(bool) onSubmit;

  @override
  State<_ClasificarBody> createState() => _ClasificarBodyState();
}

class _ClasificarBodyState extends State<_ClasificarBody> {
  final Map<String, String> _placed = {}; // optionId -> bucket ('a'/'b')
  late List<QuestionOption> _pending;

  @override
  void initState() {
    super.initState();
    _pending = List.of(widget.question.options);
  }

  Map<String, dynamic> get _labels =>
      (widget.question.correctAnswer as Map?)?.cast<String, dynamic>() ??
      {'a': 'Sí', 'b': 'No'};

  List<QuestionOption> _itemsIn(String bucket) => widget.question.options
      .where((o) => _placed[o.id] == bucket)
      .toList();

  void _drop(QuestionOption opt, String bucket) {
    if (widget.answered || _placed.containsKey(opt.id)) return;
    setState(() {
      _placed[opt.id] = bucket;
      _pending.remove(opt);
    });
    if (_pending.isEmpty) {
      final allCorrect =
          widget.question.options.every((o) => _placed[o.id] == o.bucket);
      widget.onSubmit(allCorrect);
    }
  }

  /// Quita [opt] de la bolsa donde cayó y lo regresa a las tarjetas
  /// pendientes — permite corregir una clasificación antes de completarla.
  void _remove(QuestionOption opt) {
    if (widget.answered) return;
    setState(() {
      _placed.remove(opt.id);
      _pending.add(opt);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: _BucketZone(
                    label: _labels['a']?.toString() ?? 'Sí',
                    accentColor: widget.accentColor,
                    items: _itemsIn('a'),
                    answered: widget.answered,
                    onAccept: (opt) => _drop(opt, 'a'),
                    onRemoveItem: _remove)),
            const SizedBox(width: 10),
            Expanded(
                child: _BucketZone(
                    label: _labels['b']?.toString() ?? 'No',
                    accentColor: widget.accentColor,
                    items: _itemsIn('b'),
                    answered: widget.answered,
                    onAccept: (opt) => _drop(opt, 'b'),
                    onRemoveItem: _remove)),
          ],
        ),
        const SizedBox(height: 14),
        if (_pending.isNotEmpty) ...[
          Text('Arrastra cada tarjeta a su bolsa:',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _pending
                .map((opt) => Draggable<QuestionOption>(
                      data: opt,
                      feedback: Material(
                          color: Colors.transparent,
                          child: _ClasifChip(
                              opt: opt, accentColor: widget.accentColor)),
                      childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: _ClasifChip(
                              opt: opt, accentColor: widget.accentColor)),
                      child: _ClasifChip(
                          opt: opt, accentColor: widget.accentColor),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _ClasifChip extends StatelessWidget {
  const _ClasifChip({
    required this.opt,
    required this.accentColor,
    this.onTap,
    this.removable = false,
  });
  final QuestionOption opt;
  final Color accentColor;
  final VoidCallback? onTap;
  final bool removable;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(removable ? 0.22 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.6)),
        boxShadow: removable
            ? null
            : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2)),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (opt.icon != null) ...[
            Text(opt.icon!, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 6)
          ],
          Text(opt.text,
              style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5)),
          if (removable) ...[
            const SizedBox(width: 5),
            const Icon(Icons.close_rounded, color: Colors.white70, size: 14),
          ],
        ],
      ),
    );
    return onTap != null ? GestureDetector(onTap: onTap, child: chip) : chip;
  }
}

class _BucketZone extends StatefulWidget {
  const _BucketZone({
    required this.label,
    required this.accentColor,
    required this.items,
    required this.answered,
    required this.onAccept,
    required this.onRemoveItem,
  });
  final String label;
  final Color accentColor;
  final List<QuestionOption> items;
  final bool answered;
  final void Function(QuestionOption) onAccept;
  final void Function(QuestionOption) onRemoveItem;

  @override
  State<_BucketZone> createState() => _BucketZoneState();
}

class _BucketZoneState extends State<_BucketZone> {
  @override
  Widget build(BuildContext context) {
    return DragTarget<QuestionOption>(
      onAcceptWithDetails: (details) => widget.onAccept(details.data),
      builder: (context, candidate, __) {
        final hovering = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: hovering
                ? LinearGradient(colors: [
                    widget.accentColor.withOpacity(0.35),
                    widget.accentColor.withOpacity(0.15),
                  ])
                : null,
            color: hovering ? null : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.accentColor.withOpacity(hovering ? 0.9 : 0.45),
              width: hovering ? 2 : 1.4,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: widget.accentColor,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
              if (widget.items.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.items
                      .map((o) => _ClasifChip(
                            opt: o,
                            accentColor: widget.accentColor,
                            removable: !widget.answered,
                            onTap: widget.answered
                                ? null
                                : () => widget.onRemoveItem(o),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── Relacionar ───────────────────────────────────────────────────────────────
class _RelacionarBody extends StatefulWidget {
  const _RelacionarBody(
      {required this.question,
      required this.accentColor,
      required this.answered,
      required this.onSubmit});
  final Question question;
  final Color accentColor;
  final bool answered;
  final void Function(bool) onSubmit;

  @override
  State<_RelacionarBody> createState() => _RelacionarBodyState();
}

class _RelacionarBodyState extends State<_RelacionarBody> {
  String? _selectedLeftId;
  final Map<String, String> _matched = {}; // leftId -> rightId chosen
  final List<String> _matchOrder = []; // leftIds, en el orden en que se unieron
  late List<QuestionOption> _rightShuffled;

  @override
  void initState() {
    super.initState();
    _rightShuffled = List.of(widget.question.options)
      ..shuffle(Random(widget.question.id.hashCode));
  }

  /// Tocar una tarjeta izquierda ya unida la desune (deshacer).
  void _tapLeft(QuestionOption opt) {
    if (widget.answered) return;
    if (_matched.containsKey(opt.id)) {
      setState(() {
        _matched.remove(opt.id);
        _matchOrder.remove(opt.id);
      });
      return;
    }
    setState(
        () => _selectedLeftId = _selectedLeftId == opt.id ? null : opt.id);
  }

  void _tapRight(QuestionOption right) {
    if (widget.answered || _selectedLeftId == null) return;
    if (_matched.values.contains(right.id)) return; // ya está en uso
    setState(() {
      _matched[_selectedLeftId!] = right.id;
      _matchOrder.add(_selectedLeftId!);
      _selectedLeftId = null;
    });
    if (_matched.length == widget.question.options.length) {
      final allCorrect =
          widget.question.options.every((o) => _matched[o.id] == o.id);
      widget.onSubmit(allCorrect);
    }
  }

  int? _numberFor(String leftId) {
    final idx = _matchOrder.indexOf(leftId);
    return idx == -1 ? null : idx + 1;
  }

  Widget _numberBadge(int number, Color color) => Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Text('$number',
            style: const TextStyle(
                color: Colors.black87,
                fontSize: 10,
                fontWeight: FontWeight.w800)),
      );

  @override
  Widget build(BuildContext context) {
    final lefts = widget.question.options;
    const doneColor = Color(0xFF4ADE80);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.answered)
          Text(
              'Toca una tarjeta y luego su pareja. Toca una ya unida para deshacerla.',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: lefts.map((o) {
                  final done = _matched.containsKey(o.id);
                  final selected = _selectedLeftId == o.id;
                  final number = _numberFor(o.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () => _tapLeft(o),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 12),
                        decoration: BoxDecoration(
                          color: done
                              ? doneColor.withOpacity(0.18)
                              : (selected
                                  ? widget.accentColor.withOpacity(0.28)
                                  : Colors.white.withOpacity(0.06)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: done
                                  ? doneColor
                                  : (selected
                                      ? widget.accentColor
                                      : Colors.white24),
                              width: selected ? 1.8 : 1.2),
                        ),
                        child: Row(
                          children: [
                            if (number != null) ...[
                              _numberBadge(number, doneColor),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(o.text,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Nunito',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12.5)),
                            ),
                            if (done && !widget.answered)
                              const Icon(Icons.close_rounded,
                                  color: Colors.white54, size: 15),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                children: _rightShuffled.map((o) {
                  final usedBy = _matched.entries
                      .where((e) => e.value == o.id)
                      .map((e) => e.key)
                      .toList();
                  final done = usedBy.isNotEmpty;
                  final number = done ? _numberFor(usedBy.first) : null;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () => _tapRight(o),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 12),
                        decoration: BoxDecoration(
                          color: done
                              ? doneColor.withOpacity(0.10)
                              : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: done
                                  ? doneColor.withOpacity(0.6)
                                  : Colors.white24),
                        ),
                        child: Row(
                          children: [
                            if (number != null) ...[
                              _numberBadge(number, doneColor.withOpacity(0.7)),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(o.right ?? o.text,
                                  style: TextStyle(
                                      color: done
                                          ? Colors.white60
                                          : Colors.white,
                                      fontFamily: 'Nunito',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12.5)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pregunta diaria de edificio — una sola pregunta con carcasa de diálogo de
// Blink (pose en la esquina + burbuja con la pregunta, al estilo
// ScreenTutorial) y reacciones de Blink en la retroalimentación en vez del
// banner plano de ActivityPlayer. Reutiliza _MechanicBody (mismo motor de
// mecánicas Elegir/Clasificar/Relacionar/Ordenar) pero es independiente de
// ActivityPlayer — no lo modifica ni cambia su comportamiento.
//
// Se muestra una sola vez al día por edificio (BuildingQuestionRepository):
// no vuelve a salir el resto del día sin importar si se contestó bien o mal.
// ─────────────────────────────────────────────────────────────────────────────

/// Muestra la pregunta diaria del edificio [buildingSlug] si corresponde
/// (primera vez hoy). No hace nada si ya se mostró hoy o si aún no hay
/// preguntas "Diario" cargadas para ese edificio.
Future<void> maybeShowDailyBuildingQuestion(
  BuildContext context,
  WidgetRef ref, {
  required String buildingSlug,
  required Color accentColor,
  String worldIdForFuel = 'space',
  // Clave del catálogo de preguntas (questions.module_slug), si es distinta
  // de [buildingSlug]. Necesario cuando ese module_slug ya lo usa OTRA
  // función (ej. 'banco_estelar' ya lo usa goal_dream_flow.dart para las
  // actividades reales de Mis Sueños, sin filtrar por group_name) — así no
  // se mezclan las preguntas diarias con ese catálogo existente.
  String? questionModuleSlug,
  // Nombre del grupo que marca las preguntas diarias dentro de ese catálogo.
  // Todas usan 'Diario' salvo Misiones, que ya traía su propio grupo
  // '🌞 Diaria' cargado de antes — se reutiliza tal cual en vez de duplicar
  // esas preguntas con una etiqueta nueva.
  String dailyGroupName = 'Diario',
}) async {
  final repo = BuildingQuestionRepository();
  if (!await repo.isIntroComplete()) return;
  if (await repo.shownToday(buildingSlug)) return;

  final all = await QuestionRepository()
      .getQuestionsForModule(questionModuleSlug ?? buildingSlug);
  final pool = all.where((q) => q.groupName == dailyGroupName).toList();
  if (pool.isEmpty) return;
  pool.shuffle();
  final question = pool.first;

  if (!context.mounted) return;
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.75),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (ctx, __, ___) => _DailyQuestionDialog(
      question: question,
      buildingSlug: buildingSlug,
      accentColor: accentColor,
      worldIdForFuel: worldIdForFuel,
    ),
  );
}

class _DailyQuestionDialog extends ConsumerStatefulWidget {
  const _DailyQuestionDialog({
    required this.question,
    required this.buildingSlug,
    required this.accentColor,
    required this.worldIdForFuel,
  });
  final Question question;
  final String buildingSlug;
  final Color accentColor;
  final String worldIdForFuel;

  @override
  ConsumerState<_DailyQuestionDialog> createState() =>
      _DailyQuestionDialogState();
}

class _DailyQuestionDialogState extends ConsumerState<_DailyQuestionDialog> {
  _AnswerState _answerState = _AnswerState.unanswered;

  Question get _q => widget.question;

  Future<void> _handleSubmit(bool isCorrect) async {
    if (_answerState != _AnswerState.unanswered) return;
    setState(() =>
        _answerState = isCorrect ? _AnswerState.correct : _AnswerState.wrong);

    await BuildingQuestionRepository().markShown(
      widget.buildingSlug,
      questionId: _q.id,
      correct: isCorrect,
    );
    await MissionTracker().recordQuiz();

    if (!DemoStore.isActive) {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        QuestionRepository().recordAnswer(
          userId: userId,
          questionId: _q.id,
          isCorrect: isCorrect,
        );
      }
    }

    // La pregunta del día del edificio ya NO da recompensa (monedas/XP/
    // combustible) — eso quedó exclusivo de Quizzes, que reutiliza este
    // mismo banco "Diario". Antes esta pregunta y Quizzes podían dar
    // monedas dos veces por la misma pregunta; ahora solo Quizzes paga.
  }

  String get _blinkPose {
    switch (_answerState) {
      case _AnswerState.correct:
        return 'assets/blink/poses/contento.png';
      case _AnswerState.wrong:
        return 'assets/blink/poses/triste.png';
      case _AnswerState.unanswered:
        return 'assets/blink/poses/dialogo.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final answered = _answerState != _AnswerState.unanswered;
    final retroColor = _answerState == _AnswerState.correct
        ? const Color(0xFF4ADE80)
        : widget.accentColor;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Blink + burbuja de diálogo con la pregunta ──────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Image.asset(_blinkPose,
                          width: 84, height: 84, fit: BoxFit.contain),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GameCard(
                          accentColor: widget.accentColor,
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            _q.questionText,
                            style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                height: 1.3),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _MechanicBody(
                    key: ValueKey('daily-${_q.id}'),
                    question: _q,
                    accentColor: widget.accentColor,
                    answered: answered,
                    onSubmit: _handleSubmit,
                  ),
                  if (answered) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: retroColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: retroColor.withOpacity(0.5)),
                      ),
                      child: Text(
                        _answerState == _AnswerState.correct
                            ? (_q.explanation ?? '¡Muy bien!')
                            : (_q.retroWrong ??
                                '¡Casi! Lo volvemos a intentar mañana.'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Nunito',
                            fontSize: 13,
                            height: 1.35),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: widget.accentColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('¡Listo!',
                            style: TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w800,
                                fontSize: 15)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
