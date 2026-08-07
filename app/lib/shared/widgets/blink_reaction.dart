import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Estados cortos de reacción de Blink (1-2s) y vuelta a idle.
enum BlinkMood { contento, sorprendido, celebrando }

/// PNG de pose dedicado por estado, si ya existe (ver assets/blink/poses/).
/// 'celebrando' ya tiene arte real; 'contento'/'sorprendido' quedan
/// pendientes de encargar — mientras tanto `BlinkAvatar` anima el
/// personaje compuesto como fallback (ver _reactionFallback).
const blinkMoodPoseAsset = <BlinkMood, String>{
  BlinkMood.celebrando: 'assets/blink/poses/celebrando.png',
  BlinkMood.contento: 'assets/blink/poses/contento.png',
  BlinkMood.sorprendido: 'assets/blink/poses/sorprendido.png',
};

/// Dispara una reacción corta en un `BlinkAvatar` existente (el que ya
/// está parado en la pantalla — esquina de Tienda, preview del Vestidor,
/// etc.) sin necesidad de agregar un Blink nuevo. Pasa el mismo
/// controller al `BlinkAvatar` que quieras que reaccione.
class BlinkReactionController extends ChangeNotifier {
  BlinkMood? _mood;
  BlinkMood? get mood => _mood;

  void react(BlinkMood mood, {Duration hold = const Duration(seconds: 2)}) {
    _mood = mood;
    notifyListeners();
    Future.delayed(hold, () {
      if (_mood == mood) {
        _mood = null;
        notifyListeners();
      }
    });
  }
}

/// Animación de respaldo sobre el personaje compuesto mientras no exista
/// PNG dedicado para ese estado (contento/sorprendido hoy).
Widget blinkReactionFallback(Widget character, BlinkMood mood) {
  switch (mood) {
    case BlinkMood.celebrando:
      return character.animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(
          begin: 1, end: 1.12, duration: 260.ms, curve: Curves.easeInOut);
    case BlinkMood.contento:
      return character
          .animate()
          .scale(
              begin: const Offset(0.85, 0.85),
              end: const Offset(1, 1),
              duration: 260.ms,
              curve: Curves.elasticOut)
          .then()
          .moveY(begin: 0, end: -14, duration: 240.ms, curve: Curves.easeOut)
          .then()
          .moveY(begin: -14, end: 0, duration: 260.ms, curve: Curves.bounceOut);
    case BlinkMood.sorprendido:
      return character
          .animate()
          .scale(
              begin: const Offset(1, 1),
              end: const Offset(1.12, 1.12),
              duration: 160.ms,
              curve: Curves.easeOut)
          .then()
          .shake(hz: 3, duration: 400.ms);
  }
}
