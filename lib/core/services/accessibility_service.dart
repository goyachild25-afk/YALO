import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Escala del texto en toda la app. Riverpod state persistido a disco.
///
/// Se aplica globalmente vía `MediaQuery.textScaler` en `app.dart`, así que
/// cualquier `Text` (o widget que use el TextTheme) hereda la escala sin
/// tocar código en las pantallas. Los tap targets escalan proporcionalmente
/// porque los `Padding` de los botones también dependen del texto interno.
enum AppTextScale {
  normal(1.0, 'Normal', '14 px de referencia'),
  large(1.20, 'Grande', 'Recomendado 60+ años'),
  extraLarge(1.40, 'Muy grande', 'Ideal para baja visión');

  final double scale;
  final String label;
  final String description;
  const AppTextScale(this.scale, this.label, this.description);
}

/// Tema visual. `system` sigue la preferencia del OS (respetuoso para mayores
/// que ya configuraron modo oscuro por sensibilidad a la luz).
enum AppThemeMode {
  system(ThemeMode.system, 'Automático', 'Sigue tu dispositivo'),
  light(ThemeMode.light, 'Claro', 'Fondo blanco'),
  dark(ThemeMode.dark, 'Oscuro', 'Menos brillo, cómodo de noche');

  final ThemeMode mode;
  final String label;
  final String description;
  const AppThemeMode(this.mode, this.label, this.description);
}

const _kTextScaleKey = 'a11y_text_scale';
const _kThemeModeKey = 'a11y_theme_mode';

// ─── Providers ───────────────────────────────────────────────────────────────

/// Escala de texto actual. Se lee de shared_preferences al arrancar.
final textScaleProvider =
    StateNotifierProvider<TextScaleController, AppTextScale>(
  (ref) => TextScaleController(),
);

class TextScaleController extends StateNotifier<AppTextScale> {
  TextScaleController() : super(AppTextScale.normal) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kTextScaleKey);
      if (raw != null) {
        state = AppTextScale.values.firstWhere(
          (e) => e.name == raw,
          orElse: () => AppTextScale.normal,
        );
      }
    } catch (_) {
      // fallback silencioso, se queda en normal
    }
  }

  Future<void> set(AppTextScale value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTextScaleKey, value.name);
    } catch (_) {}
  }
}

/// Modo de tema actual (auto/claro/oscuro).
final themeModeProvider =
    StateNotifierProvider<ThemeModeController, AppThemeMode>(
  (ref) => ThemeModeController(),
);

class ThemeModeController extends StateNotifier<AppThemeMode> {
  ThemeModeController() : super(AppThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kThemeModeKey);
      if (raw != null) {
        state = AppThemeMode.values.firstWhere(
          (e) => e.name == raw,
          orElse: () => AppThemeMode.system,
        );
      }
    } catch (_) {}
  }

  Future<void> set(AppThemeMode value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kThemeModeKey, value.name);
    } catch (_) {}
  }
}
