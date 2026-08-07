import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../../shared/widgets/game_popup.dart';

extension StringX on String {
  bool get isValidEmail {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(this);
  }

  String get capitalized {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}

extension IntX on int {
  /// Formatea monedas: 1500 → "1,500"
  String get coinsFormatted {
    if (this < 1000) return toString();
    final s = toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  /// Pesos mexicanos: 15000 centavos → "$150.00"
  String get mxnFormatted {
    final pesos = this / 100;
    return '\$${pesos.toStringAsFixed(2)}';
  }
}

extension ContextX on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  Size get screenSize => MediaQuery.of(this).size;
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  bool get isLandscape =>
      MediaQuery.of(this).orientation == Orientation.landscape;

  void showError(String message) =>
      showGamePopup(this, message, accentColor: AppColors.error);

  void showSuccess(String message) =>
      showGamePopup(this, message, accentColor: AppColors.success);
}
