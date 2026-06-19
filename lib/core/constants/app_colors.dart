import 'package:flutter/material.dart';

/// Sistema de color "Brisa Caribeña" — ServiciosYa
///
/// Inspirado en la naturaleza de República Dominicana:
///   primary   → azul profundo del Caribe   (confianza, seguridad, océano)
///   accent    → coral del atardecer        (calidez, acogida, energía)
///   gold      → dorado solar               (calidad, excelencia, sol)
///   success   → verde palmera              (completado, naturaleza)
///   background → mañana caribeña           (limpieza, amplitud)
class AppColors {
  AppColors._();

  // ── Primary — Azul Caribeño Profundo ─────────────────────────────────────────
  static const Color primary       = Color(0xFF0077B6); // Caribe vibrante
  static const Color primaryDark   = Color(0xFF023E8A); // Océano nocturno
  static const Color primaryLight  = Color(0xFF48CAE4); // Cielo caribeño
  static const Color primaryLighter = Color(0xFFE0F4FF); // Brisa matutina

  // ── Accent — Coral del Atardecer ─────────────────────────────────────────────
  static const Color accent      = Color(0xFFFF6B47); // Coral tropical
  static const Color accentDark  = Color(0xFFE04F2D); // Coral profundo
  static const Color accentLight = Color(0xFFFFE2D8); // Rosa coral suave

  // ── Gold — Dorado Solar ───────────────────────────────────────────────────────
  static const Color gold      = Color(0xFFFFAA00); // Sol caribeño
  static const Color goldDark  = Color(0xFFE08C00); // Ámbar dorado
  static const Color goldLight = Color(0xFFFFF3CC); // Luz solar suave

  // ── Secondary — Turquesa ─────────────────────────────────────────────────────
  static const Color secondary = Color(0xFF00B4D8); // Turquesa caribeño

  // ── Fondos ───────────────────────────────────────────────────────────────────
  static const Color background      = Color(0xFFFAF8F3); // Crema cálido y acogedor
  static const Color surface         = Color(0xFFFFFFFF); // Blanco perla
  static const Color surfaceVariant  = Color(0xFFE8F4FD); // Agua turquesa suave
  static const Color surfaceTint     = Color(0xFFF5FAFE); // Brisa oceánica

  // ── Texto ─────────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF03213B); // Noche caribeña
  static const Color textSecondary = Color(0xFF4A6B7C); // Azul marino suave
  static const Color textHint      = Color(0xFF8AABB8); // Neblina marina
  static const Color textOnPrimary = Color(0xFFFFFFFF); // Blanco puro

  // ── Semánticos ────────────────────────────────────────────────────────────────
  static const Color success      = Color(0xFF06A87F); // Verde palmera
  static const Color successLight = Color(0xFFCCF2E8); // Verde tropical suave
  static const Color warning      = Color(0xFFFFAA00); // Dorado solar (= gold)
  static const Color warningLight = Color(0xFFFFF3CC); // Luz dorada
  static const Color error        = Color(0xFFEA4C6A); // Rojo tropical
  static const Color errorLight   = Color(0xFFFFE0E8); // Rosa error
  static const Color info         = Color(0xFF48CAE4); // Azul turquesa (= primaryLight)
  static const Color infoLight    = Color(0xFFDEF5FB); // Turquesa suave

  // ── UI ────────────────────────────────────────────────────────────────────────
  static const Color divider = Color(0xFFD0E8F5); // Azul muy suave
  static const Color border  = Color(0xFFB0D2E8); // Borde océano suave
  static const Color shadow  = Color(0x220077B6); // Sombra azul caribeña
  static const Color star    = Color(0xFFFFAA00); // Estrella dorada (= gold)

  // ── Gradientes ────────────────────────────────────────────────────────────────

  /// Hero principal: del océano profundo al cielo caribeño
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.50, 1.0],
    colors: [
      Color(0xFF023E8A), // Océano nocturno
      Color(0xFF0077B6), // Azul caribeño
      Color(0xFF48CAE4), // Cielo tropical
    ],
  );

  /// Botones primarios: azul vivo → turquesa brillante
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0077B6), Color(0xFF00B4D8)],
  );

  /// Acento cálido: coral del atardecer → dorado solar
  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B47), Color(0xFFFFAA00)],
  );

  /// Tropical: océano → verde palmera
  static const LinearGradient tropicalGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0077B6), Color(0xFF06A87F)],
  );

  /// Alias usado en SliverAppBar collapsed y headers
  static const LinearGradient headerGradient = heroGradient;

  // ── Sombras con color ─────────────────────────────────────────────────────────

  /// Sombra suave para cards
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF0077B6).withValues(alpha: 0.09),
          blurRadius: 22,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: const Color(0xFF000000).withValues(alpha: 0.04),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  /// Sombra intensa para botones primarios
  static List<BoxShadow> get buttonShadow => [
        BoxShadow(
          color: const Color(0xFF0077B6).withValues(alpha: 0.42),
          blurRadius: 20,
          offset: const Offset(0, 7),
        ),
      ];

  /// Sombra coral para botones / badges de acento
  static List<BoxShadow> get accentShadow => [
        BoxShadow(
          color: const Color(0xFFFF6B47).withValues(alpha: 0.40),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];
}
