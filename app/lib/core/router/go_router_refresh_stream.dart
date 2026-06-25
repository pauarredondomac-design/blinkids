import 'dart:async';
import 'package:flutter/foundation.dart';

/// Puente entre un Stream y GoRouter para que el router
/// se re-evalúe cuando el stream emite nuevos eventos.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (_) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
