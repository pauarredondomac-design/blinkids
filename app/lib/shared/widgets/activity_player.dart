import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/question.dart';
import '../../data/repositories/question_repository.dart';
import '../../data/repositories/wallet_repository.dart';
import '../providers/wallet_provider.dart';
import '../providers/character_provider.dart';
import '../providers/fuel_provider.dart';
import 'coin_display.dart';
import 'badges_row.dart';
import 'rocket_launch_overlay.dart';

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
  });

  final List<Question> activities;
  final Color           accentColor;
  final String          worldIdForFuel;
  final VoidCallback?   onAllComplete;

  @override
  ConsumerState<ActivityPlayer> createState() => _ActivityPlayerState();
}

class _ActivityPlayerState extends ConsumerState<ActivityPlayer> {
  int          _index       = 0;
  _AnswerState _answerState = _AnswerState.unanswered;
  int          _coinsEarned = 0;
  int          _correctCount = 0;
  bool         _showSummary = false;

  Question get _current => widget.activities[_index];

  Future<void> _handleSubmit(bool isCorrect) async {
    if (_answerState != _AnswerState.unanswered) return;
    setState(() => _answerState = isCorrect ? _AnswerState.correct : _AnswerState.wrong);

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      QuestionRepository().recordAnswer(
        userId:     userId,
        questionId: _current.id,
        isCorrect:  isCorrect,
      );
    }

    if (!isCorrect) return;

    _correctCount++;
    _coinsEarned += _current.coinReward;

    final xpFuture = awardXp(ref, _current.xpReward);
    final futures = <Future>[];
    if (userId != null) {
      futures.add(
        WalletRepository().awardStarterCoins(userId, _current.coinReward).catchError((_) => null),
      );
    }
    await Future.wait(futures);
    final newBadges = await xpFuture;
    if (userId != null) ref.invalidate(currentWalletProvider);

    var reachedFullFuel = false;
    if (_current.fuelReward > 0) {
      reachedFullFuel = await ref
          .read(fuelNotifierProvider.notifier)
          .addFuel(widget.worldIdForFuel, _current.fuelReward);
    }

    if (!mounted) return;
    if (_current.isHito && _current.badgeName != null) {
      BadgeUnlockToast.show(context, 'hito-${_current.id}',
          name: _current.badgeName, emoji: '⭐');
    } else {
      showBadgeUnlockToasts(context, ref, newBadges);
    }
    if (reachedFullFuel) await handleFuelReachedFull(context, ref);
  }

  void _handleNext() {
    if (_index < widget.activities.length - 1) {
      setState(() {
        _index++;
        _answerState = _AnswerState.unanswered;
      });
    } else {
      setState(() => _showSummary = true);
      widget.onAllComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.activities.isEmpty) {
      return const _EmptyActivities();
    }
    if (_showSummary) {
      return _ActivitySummary(
        correctCount: _correctCount,
        total:        widget.activities.length,
        coinsEarned:  _coinsEarned,
        accentColor:  widget.accentColor,
        onRestart: () => setState(() {
          _index = 0;
          _answerState = _AnswerState.unanswered;
          _coinsEarned = 0;
          _correctCount = 0;
          _showSummary = false;
        }),
      );
    }

    return SingleChildScrollView(
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
          const SizedBox(height: 12),
          if (_current.gancho != null) ...[
            _GanchoBanner(text: _current.gancho!, accentColor: widget.accentColor),
            const SizedBox(height: 10),
          ],
          _ActivityCard(question: _current, accentColor: widget.accentColor),
          const SizedBox(height: 16),
          _MechanicBody(
            key: ValueKey('mech-${_current.id}'),
            question: _current,
            accentColor: widget.accentColor,
            answered: _answerState != _AnswerState.unanswered,
            onSubmit: _handleSubmit,
          ),
          if (_answerState != _AnswerState.unanswered) ...[
            const SizedBox(height: 14),
            _RetroBanner(
              isCorrect: _answerState == _AnswerState.correct,
              text: _answerState == _AnswerState.correct
                  ? (_current.explanation ?? '¡Muy bien!')
                  : (_current.retroWrong ?? '¡Estuvo cerca! Pensemos juntos qué nos acerca más a Marte.'),
              accentColor: widget.accentColor,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _handleNext,
                style: FilledButton.styleFrom(
                  backgroundColor: widget.accentColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  _index < widget.activities.length - 1 ? 'Siguiente' : 'Terminar',
                  style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ],
        ],
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
            style: TextStyle(color: Colors.white70, fontFamily: 'Nunito', fontSize: 14),
          ),
        ),
      );
}

class _ActivityProgress extends StatelessWidget {
  const _ActivityProgress({required this.current, required this.total, required this.accentColor});
  final int current;
  final int total;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$current / $total',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w700)),
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

class _GanchoBanner extends StatelessWidget {
  const _GanchoBanner({required this.text, required this.accentColor});
  final String text;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Text('🦊', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: Colors.white, fontFamily: 'Nunito', fontSize: 12.5, fontStyle: FontStyle.italic)),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.question, required this.accentColor});
  final Question question;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.35)),
      ),
      child: Text(
        question.questionText,
        style: const TextStyle(color: Colors.white, fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 16, height: 1.3),
      ),
    );
  }
}

class _RetroBanner extends StatelessWidget {
  const _RetroBanner({required this.isCorrect, required this.text, required this.accentColor});
  final bool isCorrect;
  final String text;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final color = isCorrect ? const Color(0xFF4ADE80) : accentColor;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isCorrect ? '✅' : '💭', style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white, fontFamily: 'Nunito', fontSize: 13, height: 1.35)),
          ),
        ],
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
                style: TextStyle(color: Colors.white, fontFamily: 'Nunito', fontWeight: FontWeight.w900, fontSize: 20)),
            const SizedBox(height: 8),
            Text('$correctCount / $total correctas',
                style: const TextStyle(color: Colors.white70, fontFamily: 'Nunito', fontSize: 14)),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('+$coinsEarned ', style: const TextStyle(color: Color(0xFFFFD600), fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 16)),
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
        return _OrdenarBody(question: question, accentColor: accentColor, answered: answered, onSubmit: onSubmit);
      case QuestionType.classify:
        return _ClasificarBody(question: question, accentColor: accentColor, answered: answered, onSubmit: onSubmit);
      case QuestionType.dragMatch:
        return _RelacionarBody(question: question, accentColor: accentColor, answered: answered, onSubmit: onSubmit);
      case QuestionType.multipleChoice:
      case QuestionType.trueFalse:
      case QuestionType.fillBlank:
        return _ElegirBody(question: question, accentColor: accentColor, answered: answered, onSubmit: onSubmit);
    }
  }
}

// ─── Elegir / Trivia ──────────────────────────────────────────────────────────
class _ElegirBody extends StatefulWidget {
  const _ElegirBody({required this.question, required this.accentColor, required this.answered, required this.onSubmit});
  final Question question;
  final Color accentColor;
  final bool answered;
  final void Function(bool) onSubmit;

  @override
  State<_ElegirBody> createState() => _ElegirBodyState();
}

class _ElegirBodyState extends State<_ElegirBody> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: widget.question.options.map((opt) {
        final isSelected = _selected == opt.id;
        final isCorrectOpt = widget.question.correctAnswer == opt.id;
        Color? bg;
        Color border = Colors.white24;
        if (widget.answered) {
          if (isCorrectOpt) {
            bg = const Color(0xFF4ADE80).withOpacity(0.25);
            border = const Color(0xFF4ADE80);
          } else if (isSelected) {
            bg = Colors.redAccent.withOpacity(0.20);
            border = Colors.redAccent;
          }
        } else if (isSelected) {
          bg = widget.accentColor.withOpacity(0.2);
          border = widget.accentColor;
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: widget.answered
                ? null
                : () {
                    setState(() => _selected = opt.id);
                    widget.onSubmit(isCorrectOpt);
                  },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: bg ?? Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  if (opt.icon != null) ...[Text(opt.icon!, style: const TextStyle(fontSize: 18)), const SizedBox(width: 8)],
                  Expanded(child: Text(opt.text, style: const TextStyle(color: Colors.white, fontFamily: 'Nunito', fontSize: 14))),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Ordenar ──────────────────────────────────────────────────────────────────
class _OrdenarBody extends StatefulWidget {
  const _OrdenarBody({required this.question, required this.accentColor, required this.answered, required this.onSubmit});
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
      final correct = (widget.question.correctAnswer as List?)?.cast<String>() ?? const [];
      final isCorrect = order.length == correct.length &&
          List.generate(order.length, (i) => order[i] == correct[i]).every((v) => v);
      widget.onSubmit(isCorrect);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Toca en el orden correcto:', style: TextStyle(color: Colors.white.withOpacity(0.6), fontFamily: 'Nunito', fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: List.generate(widget.question.options.length, (i) {
            final filled = i < _picked.length;
            return Container(
              width: 40, height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: filled ? widget.accentColor.withOpacity(0.3) : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: filled ? widget.accentColor : Colors.white24),
              ),
              child: Text(filled ? '${i + 1}' : '${i + 1}',
                  style: TextStyle(color: filled ? Colors.white : Colors.white38, fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
            );
          }),
        ),
        const SizedBox(height: 8),
        if (_picked.isNotEmpty)
          Wrap(
            spacing: 6, runSpacing: 6,
            children: _picked.map((o) => Chip(
              label: Text(o.text, style: const TextStyle(color: Colors.white, fontFamily: 'Nunito', fontSize: 12)),
              backgroundColor: widget.accentColor.withOpacity(0.35),
            )).toList(),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _remaining.map((opt) => GestureDetector(
            onTap: () => _pick(opt),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(opt.text, style: const TextStyle(color: Colors.white, fontFamily: 'Nunito', fontSize: 13)),
            ),
          )).toList(),
        ),
      ],
    );
  }
}

// ─── Clasificar ───────────────────────────────────────────────────────────────
class _ClasificarBody extends StatefulWidget {
  const _ClasificarBody({required this.question, required this.accentColor, required this.answered, required this.onSubmit});
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
      (widget.question.correctAnswer as Map?)?.cast<String, dynamic>() ?? {'a': 'Sí', 'b': 'No'};

  void _drop(QuestionOption opt, String bucket) {
    if (widget.answered || _placed.containsKey(opt.id)) return;
    setState(() {
      _placed[opt.id] = bucket;
      _pending.remove(opt);
    });
    if (_pending.isEmpty) {
      final allCorrect = widget.question.options.every((o) => _placed[o.id] == o.bucket);
      widget.onSubmit(allCorrect);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _BucketZone(label: _labels['a']?.toString() ?? 'Sí', bucket: 'a', accentColor: widget.accentColor, onAccept: (opt) => _drop(opt, 'a'))),
            const SizedBox(width: 10),
            Expanded(child: _BucketZone(label: _labels['b']?.toString() ?? 'No', bucket: 'b', accentColor: widget.accentColor, onAccept: (opt) => _drop(opt, 'b'))),
          ],
        ),
        const SizedBox(height: 14),
        Text('Arrastra cada tarjeta a su bolsa:', style: TextStyle(color: Colors.white.withOpacity(0.6), fontFamily: 'Nunito', fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _pending.map((opt) => Draggable<QuestionOption>(
            data: opt,
            feedback: Material(color: Colors.transparent, child: _ClasifChip(opt: opt, accentColor: widget.accentColor)),
            childWhenDragging: Opacity(opacity: 0.3, child: _ClasifChip(opt: opt, accentColor: widget.accentColor)),
            child: _ClasifChip(opt: opt, accentColor: widget.accentColor),
          )).toList(),
        ),
      ],
    );
  }
}

class _ClasifChip extends StatelessWidget {
  const _ClasifChip({required this.opt, required this.accentColor});
  final QuestionOption opt;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (opt.icon != null) ...[Text(opt.icon!, style: const TextStyle(fontSize: 15)), const SizedBox(width: 6)],
          Text(opt.text, style: const TextStyle(color: Colors.white, fontFamily: 'Nunito', fontSize: 13)),
        ],
      ),
    );
  }
}

class _BucketZone extends StatefulWidget {
  const _BucketZone({required this.label, required this.bucket, required this.accentColor, required this.onAccept});
  final String label;
  final String bucket;
  final Color accentColor;
  final void Function(QuestionOption) onAccept;

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
        return Container(
          height: 72,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: hovering ? widget.accentColor.withOpacity(0.3) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: widget.accentColor.withOpacity(hovering ? 0.9 : 0.4), width: hovering ? 2 : 1.2, style: BorderStyle.solid),
          ),
          child: Text(widget.label, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 13)),
        );
      },
    );
  }
}

// ─── Relacionar ───────────────────────────────────────────────────────────────
class _RelacionarBody extends StatefulWidget {
  const _RelacionarBody({required this.question, required this.accentColor, required this.answered, required this.onSubmit});
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
  late List<QuestionOption> _rightShuffled;

  @override
  void initState() {
    super.initState();
    _rightShuffled = List.of(widget.question.options)..shuffle(Random(widget.question.id.hashCode));
  }

  void _tapLeft(QuestionOption opt) {
    if (widget.answered || _matched.containsKey(opt.id)) return;
    setState(() => _selectedLeftId = opt.id);
  }

  void _tapRight(QuestionOption right) {
    if (widget.answered || _selectedLeftId == null) return;
    setState(() {
      _matched[_selectedLeftId!] = right.id;
      _selectedLeftId = null;
    });
    if (_matched.length == widget.question.options.length) {
      final allCorrect = widget.question.options.every((o) => _matched[o.id] == o.id);
      widget.onSubmit(allCorrect);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lefts = widget.question.options;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: lefts.map((o) {
              final done = _matched.containsKey(o.id);
              final selected = _selectedLeftId == o.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => _tapLeft(o),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      color: done ? const Color(0xFF4ADE80).withOpacity(0.2) : (selected ? widget.accentColor.withOpacity(0.3) : Colors.white.withOpacity(0.06)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: done ? const Color(0xFF4ADE80) : (selected ? widget.accentColor : Colors.white24)),
                    ),
                    child: Text(o.text, style: const TextStyle(color: Colors.white, fontFamily: 'Nunito', fontSize: 12.5)),
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
              final usedBy = _matched.entries.where((e) => e.value == o.id).map((e) => e.key).toList();
              final done = usedBy.isNotEmpty;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => _tapRight(o),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      color: done ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: done ? Colors.white12 : Colors.white24),
                    ),
                    child: Text(o.right ?? o.text,
                        style: TextStyle(color: done ? Colors.white38 : Colors.white, fontFamily: 'Nunito', fontSize: 12.5)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
