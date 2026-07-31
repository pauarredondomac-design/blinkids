import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/question_provider.dart';
import '../../../shared/widgets/activity_player.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Desafíos — minijuegos que mezclan todo lo aprendido (antes "Preguntas").
// Documento maestro: "'Desafíos' en vez de 'Preguntas' — preguntas suena a
// escuela; desafíos invita a jugar". Usa el catálogo MS-016..020.
// ─────────────────────────────────────────────────────────────────────────────
void showDesafiosDialog(BuildContext context) {
  final size = MediaQuery.of(context).size;
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Desafíos',
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
          child: const DesafiosScreen(),
        ),
      ),
    ),
  );
}

class DesafiosScreen extends ConsumerWidget {
  const DesafiosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(questionsForModuleProvider('misiones'));

    return Scaffold(
      backgroundColor: const Color(0xFF1B0F3D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A1860),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('🎮 Desafíos',
            style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 20)),
      ),
      body: activitiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (_, __) => const Center(
          child: Text('No se pudieron cargar los desafíos.', style: TextStyle(color: Colors.white70, fontFamily: 'Nunito')),
        ),
        data: (all) {
          final desafios = all.where((q) => q.groupName?.contains('Desafío') == true).toList();
          return ActivityPlayer(
            activities: desafios,
            accentColor: const Color(0xFFAB47BC),
          );
        },
      ),
    );
  }
}
