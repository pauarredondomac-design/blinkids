import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mensaje de burbuja de Blink que se muestra brevemente en el mapa principal.
/// null = no hay nada que mostrar.
final blinkAmbientMessageProvider = StateProvider<String?>((ref) => null);

/// Se activa cuando el jugador guarda un cambio de vestuario, para que
/// Blink reaccione la próxima vez que se vea en el mapa principal.
final justChangedOutfitProvider = StateProvider<bool>((ref) => false);
