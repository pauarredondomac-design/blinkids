import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Volver a la misión" — MVP de una sola misión activa a la vez (decisión
/// del cliente: no hace falta un sistema de pila/varias misiones pendientes).
///
/// Cuando el niño toca "IR A TRABAJOS/TIENDA/MI BOLSA/BANCO ESTELAR" desde una
/// misión que le pide algo, guardamos aquí el id de esa misión. La pantalla
/// destino muestra un banner "Volver a la misión" mientras este valor no sea
/// null; al tocarlo, se limpia y se reabre Misiones.
final activeMissionReturnProvider = StateProvider<String?>((ref) => null);
