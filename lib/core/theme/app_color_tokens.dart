import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Colores que sí necesitan variar entre tema claro y oscuro — texto,
/// fondos y bordes. Los colores de marca (primary, accent, gold, los
/// semánticos como error/warning/success) se quedan iguales en ambos
/// temas a propósito; por eso no están aquí, se siguen usando desde
/// [AppColors] directamente.
///
/// Uso: `context.colors.textPrimary` en vez de `AppColors.textPrimary`.
/// Requiere quitar el `const` del widget que lo envuelve (Theme.of
/// depende del árbol, no puede resolverse en tiempo de compilación).
@immutable
class AppColorTokens extends ThemeExtension<AppColorTokens> {
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color divider;
  final Color border;

  const AppColorTokens({
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.divider,
    required this.border,
  });

  static const light = AppColorTokens(
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textHint: AppColors.textHint,
    background: AppColors.background,
    surface: AppColors.surface,
    surfaceVariant: AppColors.surfaceVariant,
    divider: AppColors.divider,
    border: AppColors.border,
  );

  // Deben coincidir exactamente con las constantes _dark* privadas de
  // AppTheme.dark (app_theme.dart) — no se pueden compartir directamente
  // porque Dart no permite acceder a campos de una instancia const de una
  // clase ThemeExtension dentro de otra expresión const.
  static const dark = AppColorTokens(
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFFB7C6D3),
    textHint: Color(0xFF8DA1B4),
    background: Color(0xFF0A1C2C),
    surface: Color(0xFF122A3D),
    surfaceVariant: Color(0xFF1B3A52),
    divider: Color(0xFF25405A),
    border: Color(0xFF2E4B67),
  );

  @override
  AppColorTokens copyWith({
    Color? textPrimary,
    Color? textSecondary,
    Color? textHint,
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? divider,
    Color? border,
  }) {
    return AppColorTokens(
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textHint: textHint ?? this.textHint,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      divider: divider ?? this.divider,
      border: border ?? this.border,
    );
  }

  @override
  AppColorTokens lerp(ThemeExtension<AppColorTokens>? other, double t) {
    if (other is! AppColorTokens) return this;
    return AppColorTokens(
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

extension AppColorTokensContext on BuildContext {
  AppColorTokens get colors =>
      Theme.of(this).extension<AppColorTokens>() ?? AppColorTokens.light;
}
