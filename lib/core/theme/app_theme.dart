import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import 'app_color_tokens.dart';

/// Tema "Brisa Caribeña" — YALO
///
/// Tipografía dual:
///   Playfair Display → títulos hero y display  (elegancia, lujo tropical)
///   Nunito           → cuerpo, labels, botones  (calidez, cercanía)
class AppTheme {
  AppTheme._();

  // Paleta oscura — se construye a partir de los colores del brand
  // conservando la identidad tropical pero con superficies profundas para
  // reducir fatiga visual en usuarios sensibles a la luz.
  //
  // IMPORTANTE: estos valores deben coincidir exactamente con
  // AppColorTokens.dark (app_color_tokens.dart) — Dart no permite acceder
  // a campos de una instancia const de una clase que extiende
  // ThemeExtension dentro de otra expresión const, así que no se pueden
  // referenciar directamente y quedan duplicados a propósito.
  static const _darkBg = Color(0xFF0A1C2C);        // Océano nocturno
  static const _darkSurface = Color(0xFF122A3D);   // Marea profunda
  static const _darkSurfaceVariant = Color(0xFF1B3A52);
  static const _darkTextPrimary = Color(0xFFF1F5F9);
  static const _darkTextSecondary = Color(0xFFB7C6D3); // AA sobre _darkBg
  static const _darkTextHint = Color(0xFF8DA1B4);      // AA sobre _darkBg
  static const _darkDivider = Color(0xFF25405A);
  static const _darkBorder = Color(0xFF2E4B67);

  static ThemeData get dark {
    final base = light;
    return base.copyWith(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryLight,
        onPrimary: AppColors.textPrimary,
        secondary: AppColors.secondary,
        onSecondary: AppColors.textPrimary,
        tertiary: AppColors.accent,
        onTertiary: AppColors.textPrimary,
        surface: _darkSurface,
        onSurface: _darkTextPrimary,
        error: AppColors.error,
        onError: AppColors.textOnPrimary,
        surfaceContainerHighest: _darkSurfaceVariant,
        outline: _darkBorder,
        outlineVariant: _darkDivider,
      ),
      scaffoldBackgroundColor: _darkBg,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: _darkSurface,
        foregroundColor: _darkTextPrimary,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: _darkTextPrimary,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: _darkTextPrimary, size: 22),
      ),
      // Texto: reusamos la tipografía pero ajustamos los colores para dark
      textTheme: base.textTheme.apply(
        bodyColor: _darkTextPrimary,
        displayColor: _darkTextPrimary,
      ),
      cardTheme: base.cardTheme.copyWith(
        color: _darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _darkDivider, width: 1),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: _darkSurfaceVariant,
        labelStyle: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _darkTextPrimary),
        side: const BorderSide(color: _darkBorder),
      ),
      bottomNavigationBarTheme: base.bottomNavigationBarTheme.copyWith(
        backgroundColor: _darkSurface,
        unselectedItemColor: _darkTextHint,
      ),
      dividerTheme: const DividerThemeData(
        color: _darkDivider,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: _darkSurface,
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: _darkTextPrimary,
        ),
        contentTextStyle: GoogleFonts.nunito(
          fontSize: 14,
          color: _darkTextSecondary,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _darkSurface,
        modalBackgroundColor: _darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        elevation: 16,
        modalElevation: 24,
        showDragHandle: true,
        dragHandleColor: _darkDivider,
        dragHandleSize: Size(44, 4),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: _darkSurface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _darkBorder, width: 1),
        ),
        hintStyle:
            GoogleFonts.nunito(color: _darkTextHint, fontSize: 14),
        labelStyle:
            GoogleFonts.nunito(color: _darkTextSecondary, fontSize: 14),
      ),
      listTileTheme: base.listTileTheme.copyWith(
        titleTextStyle: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _darkTextPrimary),
        subtitleTextStyle: GoogleFonts.nunito(
            fontSize: 13, color: _darkTextSecondary),
        iconColor: _darkTextSecondary,
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        backgroundColor: _darkSurfaceVariant,
      ),
      extensions: const [AppColorTokens.dark],
    );
  }

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.textOnPrimary,
        secondary: AppColors.secondary,
        onSecondary: AppColors.textOnPrimary,
        tertiary: AppColors.accent,
        onTertiary: AppColors.textOnPrimary,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        onError: AppColors.textOnPrimary,
        surfaceContainerHighest: AppColors.surfaceVariant,
        outline: AppColors.border,
        outlineVariant: AppColors.divider,
      ),
      scaffoldBackgroundColor: AppColors.background,

      // ── App bar ──────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.shadow,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 22),
      ),

      // ── Tipografía ───────────────────────────────────────────────────────────
      textTheme: TextTheme(
        // Display — Playfair elegante (hero, splash, pantallas principales)
        displayLarge: GoogleFonts.playfairDisplay(
          fontSize: 40, fontWeight: FontWeight.w700,
          color: AppColors.textPrimary, letterSpacing: -0.5, height: 1.1,
        ),
        displayMedium: GoogleFonts.playfairDisplay(
          fontSize: 32, fontWeight: FontWeight.w700,
          color: AppColors.textPrimary, letterSpacing: -0.5, height: 1.15,
        ),
        headlineLarge: GoogleFonts.playfairDisplay(
          fontSize: 26, fontWeight: FontWeight.w700,
          color: AppColors.textPrimary, letterSpacing: -0.3, height: 1.2,
        ),
        headlineMedium: GoogleFonts.playfairDisplay(
          fontSize: 22, fontWeight: FontWeight.w600,
          color: AppColors.textPrimary, height: 1.25,
        ),
        headlineSmall: GoogleFonts.playfairDisplay(
          fontSize: 19, fontWeight: FontWeight.w600,
          color: AppColors.textPrimary, height: 1.3,
        ),
        // Titles — Nunito cálido (cards, labels de UI)
        titleLarge: GoogleFonts.nunito(
          fontSize: 17, fontWeight: FontWeight.w700,
          color: AppColors.textPrimary, letterSpacing: -0.1,
        ),
        titleMedium: GoogleFonts.nunito(
          fontSize: 15, fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleSmall: GoogleFonts.nunito(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
        // Body — Nunito amigable y legible
        bodyLarge: GoogleFonts.nunito(
          fontSize: 16, fontWeight: FontWeight.w500,
          color: AppColors.textPrimary, height: 1.55,
        ),
        bodyMedium: GoogleFonts.nunito(
          fontSize: 14, fontWeight: FontWeight.w400,
          color: AppColors.textSecondary, height: 1.55,
        ),
        bodySmall: GoogleFonts.nunito(
          fontSize: 12, fontWeight: FontWeight.w400,
          color: AppColors.textSecondary, height: 1.4,
        ),
        // Labels — Nunito semibold
        labelLarge: GoogleFonts.nunito(
          fontSize: 15, fontWeight: FontWeight.w700,
          color: AppColors.textOnPrimary, letterSpacing: 0.2,
        ),
        labelMedium: GoogleFonts.nunito(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
        labelSmall: GoogleFonts.nunito(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: AppColors.textHint, letterSpacing: 0.3,
        ),
      ),

      // ── Elevated buttons ─────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.1,
          ),
        ),
      ),

      // ── Outlined buttons ─────────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 15, fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // ── Text buttons ─────────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.nunito(
            fontSize: 14, fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // ── Inputs ───────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        hintStyle: GoogleFonts.nunito(color: AppColors.textHint, fontSize: 14),
        labelStyle:
            GoogleFonts.nunito(color: AppColors.textSecondary, fontSize: 14),
        prefixIconColor: AppColors.textHint,
        suffixIconColor: AppColors.textHint,
        floatingLabelStyle:
            GoogleFonts.nunito(color: AppColors.primary, fontSize: 13,
                fontWeight: FontWeight.w600),
      ),

      // ── Cards ────────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.divider, width: 1),
        ),
        margin: EdgeInsets.zero,
        shadowColor: AppColors.shadow,
      ),

      // ── Chips ────────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        selectedColor: AppColors.primaryLighter,
        labelStyle:
            GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22)),
        side: const BorderSide(color: AppColors.border),
      ),

      // ── Bottom Nav ───────────────────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textHint,
        selectedLabelStyle:
            GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.nunito(fontSize: 11),
        type: BottomNavigationBarType.fixed,
        elevation: 16,
        showUnselectedLabels: true,
      ),

      // ── Divider ──────────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      // ── SnackBar ─────────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle:
            GoogleFonts.nunito(color: Colors.white, fontSize: 13,
                fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 8,
      ),

      // ── CheckBox ─────────────────────────────────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return null;
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: const BorderSide(color: AppColors.border, width: 1.5),
      ),

      // ── Switch ───────────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.textHint;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryLighter;
          }
          return AppColors.divider;
        }),
      ),

      // ── Dialog ───────────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.surface,
        elevation: 24,
        shadowColor: AppColors.shadow,
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: GoogleFonts.nunito(
          fontSize: 14,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),

      // ── Bottom Sheet ─────────────────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        elevation: 16,
        modalElevation: 24,
        showDragHandle: true,
        dragHandleColor: AppColors.divider,
        dragHandleSize: Size(44, 4),
      ),

      // ── FAB ──────────────────────────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 6,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        extendedTextStyle:
            GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700),
      ),

      // ── Tab bar ──────────────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textHint,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle:
            GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w500),
        dividerColor: AppColors.divider,
      ),

      // ── List tile ────────────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        titleTextStyle: GoogleFonts.nunito(
            fontSize: 15, fontWeight: FontWeight.w600,
            color: AppColors.textPrimary),
        subtitleTextStyle:
            GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
        iconColor: AppColors.textSecondary,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
      ),

      // ── Progress indicator ────────────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.primaryLighter,
        circularTrackColor: AppColors.primaryLighter,
      ),
      extensions: const [AppColorTokens.light],
    );
  }
}
