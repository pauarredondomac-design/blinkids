import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/utils/extensions.dart';

/// Widget que muestra la cantidad de monedas del jugador.
/// Se puede usar en el HUD superior del mapa y en la bolsa.
class CoinDisplay extends StatelessWidget {
  const CoinDisplay({
    super.key,
    required this.coins,
    this.isLarge = false,
    this.animate = false,
  });

  final int coins;
  final bool isLarge;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final iconSize = isLarge ? AppSizes.iconXl : AppSizes.iconMd;
    final fontSize = isLarge ? AppSizes.fontXxl : AppSizes.fontMd;

    Widget content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? AppSizes.lg : AppSizes.sm,
        vertical: isLarge ? AppSizes.sm : AppSizes.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(AppSizes.radiusRound),
        border: Border.all(color: AppColors.coinGold, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.monetization_on_rounded,
            color: AppColors.coinGold,
            size: iconSize,
          ),
          const SizedBox(width: AppSizes.xs),
          Text(
            coins.coinsFormatted,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontFamily: 'Nunito',
              shadows: const [Shadow(blurRadius: 4, color: Colors.black26)],
            ),
          ),
        ],
      ),
    );

    if (animate) {
      content = content.animate().scale(
            duration: 300.ms,
            curve: Curves.elasticOut,
          );
    }

    return content;
  }
}
