import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/providers/world_provider.dart';
import '../../../shared/providers/wallet_provider.dart';
import '../../../shared/widgets/blink_character.dart';
import '../../../shared/widgets/coin_display.dart';
import '../../../shared/theme/game_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Pantalla intermedia entre el mapa y el Vestidor/Inventario — se abre al
// tocar la tarjeta de perfil en cualquier mundo. En Galaxia usa las 3
// imágenes reales (nave/vestidor/mochila); en los demás mundos, mientras no
// haya arte propio, usa el fondo del mundo + botones genéricos centrados.
//
// Blink/vestidor/inventario están "pegados" al fondo: sus posiciones se
// guardan como fracciones (0..1) de la imagen ORIGINAL de fondo, no de la
// pantalla, y sus tamaños se guardan en "unidades de imagen" (equivalen a
// px de esa imagen original). En build() se calcula cuánto escala y recorta
// BoxFit.cover el fondo para la pantalla real, y se aplica ESA MISMA escala
// a las 3 imágenes — así, al cambiar de resolución, todo se mueve y crece
// junto, como si fueran una sola imagen compuesta.
// ─────────────────────────────────────────────────────────────────────────────
class _ShipHubConfig {
  const _ShipHubConfig({
    required this.title,
    required this.background,
    this.bgImageSize,
    this.vestidorAsset,
    this.inventarioAsset,
  });
  final String title;
  final String background;

  /// Tamaño nativo (px) del archivo de `background` — necesario para
  /// calcular el recorte/escala de BoxFit.cover. Si es null, no hay arte
  /// anclable (mundos sin diseño propio todavía) y se usa el layout
  /// genérico centrado.
  final Size? bgImageSize;
  final String? vestidorAsset;
  final String? inventarioAsset;
}

const _configs = <String, _ShipHubConfig>{
  'space': _ShipHubConfig(
    title: 'Mi nave',
    background: 'assets/worlds/space/mi_nave_fondo.png',
    bgImageSize: Size(1619, 972),
    vestidorAsset: 'assets/worlds/space/mi_nave_vestidor.png',
    inventarioAsset: 'assets/worlds/space/mi_nave_inventario.png',
  ),
  'forest': _ShipHubConfig(
    title: 'Mi Refugio',
    background: 'assets/worlds/forest/forest_background.png',
  ),
  'sea': _ShipHubConfig(
    title: 'Mi Barco',
    background: 'assets/worlds/sea/ocean_background.png',
  ),
};

class ShipHubScreen extends ConsumerWidget {
  const ShipHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worldId = ref.watch(currentWorldProvider);
    final config = _configs[worldId] ?? _configs['space']!;
    final wallet = ref.watch(currentWalletProvider).valueOrNull;
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: GameTokens.bgDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(config.background, fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.10)),
          if (config.bgImageSize != null)
            _AnchoredProps(
              screenSize: screenSize,
              bgImageSize: config.bgImageSize!,
              vestidorAsset: config.vestidorAsset,
              inventarioAsset: config.inventarioAsset,
            )
          else
            _FallbackProps(
              vestidorAsset: config.vestidorAsset,
              inventarioAsset: config.inventarioAsset,
            ),
          // Positioned (no un hijo suelto del Stack): con `fit:
          // StackFit.expand` en el Stack de afuera, un hijo normal se
          // estira a TODA la pantalla y su Row queda centrado verticalmente
          // en medio (encimado con Blink) en vez de pegado arriba. Positioned
          // no se ve afectado por StackFit, así que respeta top:0.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    _RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => context.pop(),
                    ),
                    const Spacer(),
                    Text(config.title.toUpperCase(),
                        style: GameText.title(size: 22)),
                    const Spacer(),
                    CoinDisplay(coins: wallet?.totalCoins ?? 0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Blink + vestidor + inventario anclados al fondo real (mundos con arte
// propio, hoy solo 'space').
// ─────────────────────────────────────────────────────────────────────────────
class _AnchoredProps extends StatelessWidget {
  const _AnchoredProps({
    required this.screenSize,
    required this.bgImageSize,
    required this.vestidorAsset,
    required this.inventarioAsset,
  });
  final Size screenSize;
  final Size bgImageSize;
  final String? vestidorAsset;
  final String? inventarioAsset;

  @override
  Widget build(BuildContext context) {
    // Matemática de BoxFit.cover: la imagen se escala UNIFORME hasta cubrir
    // ambos lados de la pantalla, y el sobrante se recorta parejo de cada
    // lado. `scale` es el mismo factor con el que Flutter dibuja el fondo.
    final scale = math.max(
      screenSize.width / bgImageSize.width,
      screenSize.height / bgImageSize.height,
    );
    final cropX = (bgImageSize.width * scale - screenSize.width) / 2;
    final cropY = (bgImageSize.height * scale - screenSize.height) / 2;

    // (fx, fy) = punto de anclaje como fracción (0..1) de la imagen ORIGINAL
    // — dónde debe caer la base (pies/plataforma) de cada elemento sobre el
    // dibujo del fondo. `imgSize` = tamaño en "unidades de imagen" (px de
    // esa imagen original); se multiplica por `scale` para dibujarse al
    // tamaño correcto en cualquier pantalla. `offsetX/offsetY` (también en
    // unidades de imagen) son el ajuste fino que ya se había hecho a mano.
    Offset anchorToScreen(double fx, double fy) => Offset(
          fx * bgImageSize.width * scale - cropX,
          fy * bgImageSize.height * scale - cropY,
        );

    final vestidorAnchor = anchorToScreen(0.188, 0.794);
    final blinkAnchor = anchorToScreen(0.507, 0.738);
    final inventarioAnchor = anchorToScreen(0.789, 0.794);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: vestidorAnchor.dx,
          top: vestidorAnchor.dy,
          child: FractionalTranslation(
            translation: const Offset(-0.5, -1.0),
            child: _Hotspot(
              assetPath: vestidorAsset,
              emoji: '👕',
              label: 'VESTIDOR',
              size: 400.4 * scale,
              offsetX: 50.5 * scale,
              offsetY: 150.6 * scale,
              labelOffsetX: 30,
              labelOffsetY: 15,
              onTap: () => context.push('/mi-nave/vestidor'),
            ),
          ),
        ),
        Positioned(
          left: blinkAnchor.dx,
          top: blinkAnchor.dy,
          child: FractionalTranslation(
            translation: const Offset(-0.5, -0.8),
            child: Transform.translate(
              offset: Offset(-35.4 * scale, -19.7 * scale),
              child: BlinkCharacterWidget(
                  width: 240.3 * scale, enableBounce: false),
            ),
          ),
        ),
        Positioned(
          left: inventarioAnchor.dx,
          top: inventarioAnchor.dy,
          child: FractionalTranslation(
            translation: const Offset(-0.5, -1.0),
            child: _Hotspot(
              assetPath: inventarioAsset,
              emoji: '🎒',
              label: 'INVENTARIO',
              size: 300.6 * scale,
              offsetX: -29.5 * scale,
              offsetY: 150.0 * scale,
              labelOffsetX: -25,
              labelOffsetY: 20,
              onTap: () => context.push('/mi-nave/inventario'),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Layout genérico centrado — mundos sin arte propio todavía (forest/sea).
// ─────────────────────────────────────────────────────────────────────────────
class _FallbackProps extends StatelessWidget {
  const _FallbackProps(
      {required this.vestidorAsset, required this.inventarioAsset});
  final String? vestidorAsset;
  final String? inventarioAsset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _Hotspot(
                assetPath: vestidorAsset,
                emoji: '👕',
                label: 'VESTIDOR',
                size: 150,
                onTap: () => context.push('/mi-nave/vestidor'),
              ),
            ),
            const SizedBox(width: 16),
            const BlinkCharacterWidget(width: 110, enableBounce: false),
            const SizedBox(width: 16),
            Expanded(
              child: _Hotspot(
                assetPath: inventarioAsset,
                emoji: '🎒',
                label: 'INVENTARIO',
                size: 150,
                onTap: () => context.push('/mi-nave/inventario'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hotspot extends StatelessWidget {
  const _Hotspot({
    required this.assetPath,
    required this.emoji,
    required this.label,
    required this.onTap,
    this.size = 150,
    this.offsetX = 0,
    this.offsetY = 0,
    this.labelOffsetX = 0,
    this.labelOffsetY = 0,
  });
  final String? assetPath;
  final String emoji;
  final String label;
  final VoidCallback onTap;

  /// Alto de la imagen (o del círculo genérico si no hay imagen).
  final double size;

  /// Empuje manual SOLO de la imagen: positivo = derecha/abajo, negativo =
  /// izquierda/arriba. La etiqueta ("VESTIDOR"/"INVENTARIO") NO se mueve
  /// con esto — se queda siempre pegada abajo y visible, sin importar qué
  /// tan grande sea el offset.
  final double offsetX;
  final double offsetY;

  /// Empuje manual SOLO de la etiqueta (independiente de la imagen).
  final double labelOffsetX;
  final double labelOffsetY;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.translate(
            offset: Offset(offsetX, offsetY),
            child: assetPath != null
                ? Image.asset(assetPath!, height: size, fit: BoxFit.contain)
                : Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: GameTokens.bgPanel.withOpacity(0.85),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: GameTokens.cyan.withOpacity(0.6), width: 2),
                      boxShadow: GameTokens.cardGlow,
                    ),
                    alignment: Alignment.center,
                    child: Text(emoji, style: const TextStyle(fontSize: 48)),
                  ),
          ),
          const SizedBox(height: 20),
          Transform.translate(
            offset: Offset(labelOffsetX, labelOffsetY),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
              decoration: BoxDecoration(
                color: GameTokens.bgPanel.withOpacity(0.90),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
                boxShadow: GameTokens.cardGlow,
              ),
              child: Text(label, style: GameText.button(size: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: GameTokens.bgPanel.withOpacity(0.85),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon,
            color: const Color.fromARGB(255, 248, 248, 248), size: 22),
      ),
    );
  }
}
