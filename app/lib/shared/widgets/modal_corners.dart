import 'package:flutter/material.dart';

/// Envuelve cualquier modal con las 4 esquinas decorativas del set de
/// diseño (assets/ui/modal/frame_corner_*.png) — se dibujan ENCIMA del
/// marco que ya existe, ancladas a cada esquina real del cuadro. No
/// interceptan toques (IgnorePointer), así que no cambian el hit-test
/// del contenido de abajo.
///
/// Los PNG traen relleno transparente alrededor del gráfico (no llegan
/// hasta el borde del canvas 231×306), así que se compensa con un offset
/// negativo por esquina para que la parte visible quede en la orilla del
/// modal. Además se le suma un pequeño "overshoot" para que sobresalga
/// un poco de la línea del marco original, en vez de quedar perfectamente
/// al ras — así es como se ve mejor.
class ModalCorners extends StatelessWidget {
  const ModalCorners({
    super.key,
    required this.child,
    this.size = 64,
    this.onClose,
    this.title,
  });
  final Widget child;

  /// Ancho de referencia de cada esquina — el alto se ajusta solo (las
  /// imágenes son verticales, 231×306).
  final double size;

  /// Si se da, se dibuja un botón de cerrar redondo sobre la esquina
  /// superior derecha (se "prende" — cambia de morado a turquesa — al
  /// presionarlo, y luego llama a este callback).
  final VoidCallback? onClose;

  /// Si se da, se dibuja la placa de título flotando arriba, centrada,
  /// encima de la línea del marco — reemplaza los encabezados de texto
  /// que cada modal traía por su cuenta.
  final String? title;

  // ── Ajustes a mano de la placa de título ──────────────────────────────
  // Súbela (más negativo) o bájala (menos negativo) cambiando este número.
  static const double titleOffsetY = -65;
  // Ancho de la placa — súbelo para agrandarla, bájalo para achicarla.
  static const double titleWidth = 410;

  static const double _canvasW = 231;

  /// Cuánto sobresale la esquina más allá de la línea del marco.
  static const double _overshoot = 8;

  /// Grosor de las tiras de borde (frame_edge_h/v) — se conectan con las
  /// esquinas para formar un marco continuo.
  static const double _edgeThickness = 14;

  /// Cuánto se meten las tiras por debajo de cada esquina para que no
  /// quede un hueco visible entre la esquina y el borde.
  double get _edgeInset => size * 0.55;

  @override
  Widget build(BuildContext context) {
    final s = size / _canvasW;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        // ── Tiras de borde (detrás de las esquinas) ──────────────────────
        Positioned(
          top: -_overshoot,
          left: _edgeInset,
          right: _edgeInset,
          child: IgnorePointer(
            child: Image.asset(
              'assets/ui/modal/frame_edge_ar.png',
              height: _edgeThickness,
              fit: BoxFit.fill,
            ),
          ),
        ),
        Positioned(
          bottom: -_overshoot,
          left: _edgeInset,
          right: _edgeInset,
          child: IgnorePointer(
            child: Image.asset(
              'assets/ui/modal/frame_edge_ab.png',
              height: _edgeThickness,
              fit: BoxFit.fill,
            ),
          ),
        ),
        Positioned(
          left: -_overshoot,
          top: _edgeInset,
          bottom: _edgeInset,
          child: IgnorePointer(
            child: Image.asset(
              'assets/ui/modal/frame_edge_iz.png',
              width: _edgeThickness,
              fit: BoxFit.fill,
            ),
          ),
        ),
        Positioned(
          right: -_overshoot,
          top: _edgeInset,
          bottom: _edgeInset,
          child: IgnorePointer(
            child: Image.asset(
              'assets/ui/modal/frame_edge_dr.png',
              width: _edgeThickness,
              fit: BoxFit.fill,
            ),
          ),
        ),
        // ── Esquinas (encima de las tiras) ───────────────────────────────
        Positioned(
          top: -20 * s - _overshoot,
          left: -21 * s - _overshoot,
          child: IgnorePointer(
            child:
                Image.asset('assets/ui/modal/frame_corner_tl.png', width: size),
          ),
        ),
        Positioned(
          top: -20 * s - _overshoot,
          right: -19 * s - _overshoot,
          child: IgnorePointer(
            child:
                Image.asset('assets/ui/modal/frame_corner_tr.png', width: size),
          ),
        ),
        Positioned(
          bottom: -33 * s - _overshoot,
          left: -18 * s - _overshoot,
          child: IgnorePointer(
            child:
                Image.asset('assets/ui/modal/frame_corner_bl.png', width: size),
          ),
        ),
        Positioned(
          bottom: -33 * s - _overshoot,
          right: -18 * s - _overshoot,
          child: IgnorePointer(
            child:
                Image.asset('assets/ui/modal/frame_corner_br.png', width: size),
          ),
        ),
        // ── Placa de título (centrada arriba) ────────────────────────────
        // IgnorePointer: la placa se superpone a la parte de arriba del
        // contenido (ej. las monedas arrastrables de Mi Bolsa) — sin esto,
        // su caja invisible robaba el toque/arrastre de lo que hay debajo.
        if (title != null)
          Positioned(
            top: titleOffsetY,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(child: _TitlePlate(title: title!)),
            ),
          ),
        // ── Botón de cerrar (encima de todo) ─────────────────────────────
        if (onClose != null)
          Positioned(
            top: -size * 0.35,
            right: -size * 0.35,
            child: _CloseButton(onClose: onClose!),
          ),
      ],
    );
  }
}

class _TitlePlate extends StatelessWidget {
  const _TitlePlate({required this.title});
  final String title;

  // Proporción real del PNG (2171×724).
  static const double _aspect = 2171 / 724;

  @override
  Widget build(BuildContext context) {
    final width = ModalCorners.titleWidth;
    final height = width / _aspect;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset('assets/ui/modal/title_plate.png', fit: BoxFit.fill),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: width * 0.15),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w900,
                fontSize: height * 0.24,
                letterSpacing: 0.5,
                shadows: const [
                  Shadow(color: Color(0xFF4DE8E8), blurRadius: 14),
                  Shadow(color: Colors.black54, blurRadius: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.onClose});
  final VoidCallback onClose;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _lit = false;

  void _handleTap() {
    if (_lit) return;
    setState(() => _lit = true);
    Future.delayed(const Duration(milliseconds: 140), widget.onClose);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedScale(
        scale: _lit ? 1.12 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: _lit
                ? [
                    BoxShadow(
                      color: const Color(0xFF4DE8E8).withOpacity(0.75),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : const [],
          ),
          child: Image.asset(
            _lit
                ? 'assets/ui/modal/buttons/icon_close_teal.png'
                : 'assets/ui/modal/buttons/icon_close_purple.png',
            width: 52,
            height: 52,
          ),
        ),
      ),
    );
  }
}
