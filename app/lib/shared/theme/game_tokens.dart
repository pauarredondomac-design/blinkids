import 'package:flutter/material.dart';

/// Design tokens del sistema visual "juego" (Mapa, Tienda, Vestidor, Trabajos
/// y widgets compartidos). Basado en la estética del Mapa principal: fondo
/// espacial azul/morado con estrellas y acentos dorados.
///
/// No reemplaza `AppTheme`/`AppColors` (usados por login/registro/parent) —
/// esos siguen intactos. `GameTokens` es específico de las pantallas de juego.
abstract class GameTokens {
  // ── Fondo ──────────────────────────────────────────────────────────────
  static const bgDeep = Color(0xFF020A18); // fondo base (Mapa)
  static const bgPanel = Color(0xFF0D0A2A); // paneles/sidebars/diálogos
  static const bgPanelDark = Color(0xFF08061A);
  static const bgOverlay = Color(0x26000000); // overlay sobre el fondo espacial

  // ── Acentos ────────────────────────────────────────────────────────────
  static const gold = Color(0xFFFFD600); // moneda / recompensas
  static const cyan =
      Color(0xFF4FC3F7); // borde/glow principal (Mapa, Trabajos)
  static const purple = Color(0xFF7B2FBE); // acento Tienda
  static const purpleLight = Color(0xFFCE93D8);
  static const green = Color(0xFF69F0AE); // éxito
  static const red = Color(0xFFFF3B3B); // error / badge notificación

  // ── Texto ──────────────────────────────────────────────────────────────
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFFD8D8E0); // gris cálido, más legible sobre fondos oscuros
  static const textMuted = Colors.white38;

  // ── Bordes / radius ────────────────────────────────────────────────────
  static const cardRadius = 16.0;
  static const cardRadiusSm = 12.0;
  static const chipRadius = 100.0;
  static const borderWidth = 1.0;
  static const borderWidthHighlight = 1.5;

  static Color cardBorder({bool locked = false}) =>
      locked ? Colors.white.withOpacity(0.15) : cyan.withOpacity(0.40);

  // ── Sombra / glow ──────────────────────────────────────────────────────
  static List<BoxShadow> glow(Color color,
          {double blur = 12, double opacity = 0.35}) =>
      [
        BoxShadow(color: color.withOpacity(opacity), blurRadius: blur),
      ];

  static List<BoxShadow> get cardGlow => glow(cyan, blur: 10, opacity: 0.18);
  static List<BoxShadow> get goldGlow => glow(gold, blur: 10, opacity: 0.35);

  // ── Espaciado ──────────────────────────────────────────────────────────
  static const spaceXs = 4.0;
  static const spaceSm = 8.0;
  static const spaceMd = 12.0;
  static const spaceLg = 16.0;
  static const spaceXl = 24.0;
}

/// Tipografía compartida: Baloo 2 para títulos/headers/botones, Nunito para
/// cuerpo de texto/diálogos/labels. 4 tamaños fijos.
///
/// Las fuentes van bundleadas en assets/fonts/ (declaradas en pubspec.yaml)
/// en vez de descargarse en tiempo de ejecución vía el paquete `google_fonts`
/// — Tienda/Trabajos/Vestidor/Misiones son parte del flujo demo sin login,
/// así que el texto tiene que verse bien desde la primera apertura sin
/// depender de conexión a internet.
abstract class GameText {
  /// Título de pantalla / header grande (28–32px).
  static TextStyle title(
          {Color color = GameTokens.textPrimary, double size = 30}) =>
      TextStyle(
          fontFamily: 'Baloo2',
          fontSize: size,
          fontWeight: FontWeight.w800,
          color: color);

  /// Subtítulo / nombre de sección (20–22px).
  static TextStyle subtitle(
          {Color color = GameTokens.textPrimary, double size = 21}) =>
      TextStyle(
          fontFamily: 'Baloo2',
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: color);

  /// Texto de botón (usa Baloo 2, misma familia que títulos/headers).
  static TextStyle button(
          {Color color = GameTokens.textPrimary, double size = 16}) =>
      TextStyle(
          fontFamily: 'Baloo2',
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: color);

  /// Cuerpo de texto / diálogos (16px).
  static TextStyle body(
          {Color color = GameTokens.textPrimary,
          double size = 16,
          FontWeight weight = FontWeight.w500}) =>
      TextStyle(
          fontFamily: 'Nunito',
          fontSize: size,
          fontWeight: weight,
          color: color);

  /// Label pequeño (13–14px) — nombres de item, precios, chips.
  static TextStyle label(
          {Color color = GameTokens.textPrimary,
          double size = 13,
          FontWeight weight = FontWeight.w700}) =>
      TextStyle(
          fontFamily: 'Nunito',
          fontSize: size,
          fontWeight: weight,
          color: color);
}
