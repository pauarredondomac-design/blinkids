import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

class MusicNotifier extends Notifier<bool> with WidgetsBindingObserver {
  late final AudioPlayer _player;

  @override
  bool build() {
    _player = AudioPlayer();
    _initAndPlay();
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _player.dispose();
    });
    return true;
  }

  Future<void> _initAndPlay() async {
    try {
      await _player.setAsset('assets/sounds/background_music.mp3');
      await _player.setLoopMode(LoopMode.one);
      await _player.setVolume(0.4);
      await _player.play();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.detached) {
      _player.pause();
    } else if (lifecycle == AppLifecycleState.resumed && state) {
      _player.play();
    }
  }

  void toggle() {
    if (state) {
      _player.pause();
    } else {
      _player.play();
    }
    state = !state;
  }

  void setVolume(double v) => _player.setVolume(v);
}

final musicProvider = NotifierProvider<MusicNotifier, bool>(MusicNotifier.new);
