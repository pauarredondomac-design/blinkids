import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'music_provider.dart';

/// Reproductor de efectos de sonido cortos y puntuales (ej. el "cling" de
/// moneda en Mi Bolsa) — deliberadamente separado del `AudioPlayer` de
/// `music_provider.dart` (que loopea la música de fondo) para no
/// interferirlo. Usa un pool chico de `AudioPlayer` en round-robin para
/// poder sonar varias veces seguidas sin cortarse si el niño suelta
/// varias monedas rápido.
class SfxPlayer {
  SfxPlayer(this.assetPath, {this.poolSize = 4}) {
    _players = List.generate(poolSize, (_) => AudioPlayer());
    for (final p in _players) {
      p.setAsset(assetPath).catchError((_) => null);
    }
  }

  final String assetPath;
  final int poolSize;
  late final List<AudioPlayer> _players;
  int _next = 0;

  Future<void> play({double volume = 0.8}) async {
    final player = _players[_next];
    _next = (_next + 1) % _players.length;
    try {
      await player.setVolume(volume);
      await player.seek(Duration.zero);
      unawaited(player.play());
    } catch (_) {}
  }

  void dispose() {
    for (final p in _players) {
      p.dispose();
    }
  }
}

/// El "cling" de moneda de Mi Bolsa. `state` de [musicProvider] es el único
/// toggle de sonido que existe hoy en el juego (aunque todavía no hay un
/// botón en Opciones que lo llame) — se reutiliza para que, el día que se
/// agregue ese botón, el SFX quede silenciado igual que la música.
final coinSfxProvider = Provider<SfxPlayer>((ref) {
  final player = SfxPlayer('assets/sounds/sonido_moneda.wav');
  ref.onDispose(player.dispose);
  return player;
});
