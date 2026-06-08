import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Primary — Teal profundo (limpieza + confianza) ──────────────────────────
  static const Color primary = Color(0xFF0D9488);        // Teal 600
  static const Color primaryDark = Color(0xFF0F766E);   // Teal 700
  static const Color primaryLight = Color(0xFF2DD4BF);  // Teal 400
  static const Color primaryLighter = Color(0xFFCCFBF1);// Teal 100

  // ── Accent — Ámbar cálido (hogar + calidez) ─────────────────────────────────
  static const Color accent = Color(0xFFF97316);         // Orange 500
  static const Color accentDark = Color(0xFFEA580C);    // Orange 600
  static const Color accentLight = Color(0xFFFED7AA);   // Orange 200

  // ── Secondary ────────────────────────────────────────────────────────────────
  static const Color secondary = Color(0xFF0891B2);     // Cyan 600

  // ── Fondos ──────────────────────────────────────────────────────────────────
  static const Color background = Color(0xFFF4F7F6);    // Blanco cálido verdoso
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEEFAF8); // Teal-50 cálido

  // ── Texto ────────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A2B2A);   // Navy oscuro cálido
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textHint = Color(0xFF94A3B8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ── Semánticos ───────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // ── UI ───────────────────────────────────────────────────────────────────────
  static const Color divider = Color(0xFFE2E8F0);
  static const Color border = Color(0xFFCBD5E1);
  static const Color shadow = Color(0x18000000);
  static const Color star = Color(0xFFFBBF24);

  // ── Gradientes ───────────────────────────────────────────────────────────────

  /// Gradiente principal (botones, cards destacadas)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
  );

  /// Hero del header (oscuro → teal → cyan)
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.55, 1.0],
    colors: [Color(0xFF134E4A), Color(0xFF0D9488), Color(0xFF0891B2)],
  );

  /// Gradiente cálido (promo banners, accent)
  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEA580C), Color(0xFFF59E0B)],
  );

  /// Alias para compatibilidad con screens que usan headerGradient
  static const LinearGradient headerGradient = heroGradient;
}
