import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/utils/extensions.dart';

const _kCoinFrames = 9;
const _kCoinPath   = 'assets/ui/coin/frame_';

/// Moneda animada con sprite de 9 frames.
/// Úsala en cualquier lugar de la app donde antes se mostraba el emoji 🪙.
class AnimatedCoin extends StatefulWidget {
  const AnimatedCoin({super.key, this.size = 18});
  final double size;

  @override
  State<AnimatedCoin> createState() => _AnimatedCoinState();
}

class _AnimatedCoinState extends State<AnimatedCoin> {
  int    _frame = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // ~18 fps → cada 55 ms avanza un frame
    _timer = Timer.periodic(const Duration(milliseconds: 55), (_) {
      if (mounted) setState(() => _frame = (_frame + 1) % _kCoinFrames);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      '${_kCoinPath}${_frame + 1}.png',
      width:  widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      // Fallback al ícono si el asset no carga
      errorBuilder: (_, __, ___) => Icon(
        Icons.monetization_on_rounded,
        color: AppColors.coinGold,
        size: widget.size,
      ),
    );
  }
}

/// Widget que muestra la cantidad de monedas del jugador.
/// Se puede usar en el HUD superior del mapa y en la bolsa.
class CoinDisplay extends StatelessWidget {
  const CoinDisplay({
    super.key,
    required this.coins,
    this.isLarge = false,
    this.animate = false,
  });

  final int  coins;
  final bool isLarge;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final iconSize = isLarge ? AppSizes.iconXl : AppSizes.iconMd;
    final fontSize = isLarge ? AppSizes.fontXxl : AppSizes.fontMd;

    Widget content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? AppSizes.lg : AppSizes.sm,
        vertical:   isLarge ? AppSizes.sm : AppSizes.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(AppSizes.radiusRound),
        border: Border.all(color: AppColors.coinGold, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedCoin(size: iconSize),
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
