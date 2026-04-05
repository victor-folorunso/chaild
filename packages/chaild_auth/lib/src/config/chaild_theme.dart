import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ChailTheme: The single source of truth for all visual styling.
///
/// Developers can override accent color when initializing:
/// ```dart
/// ChailAuth.initialize(accentColor: Colors.blue, ...);
/// ```
class ChailColors {
  ChailColors._();

  // ── Brand ────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF6C47FF);
  static const Color primaryLight = Color(0xFF8B6EFF);
  static const Color primaryDark = Color(0xFF5030E0);
  static const Color primarySurface = Color(0xFF1A1530);

  // ── Neutrals Dark ────────────────────────────────────────────────────────
  static const Color bgDark = Color(0xFF09090B);
  static const Color surfaceDark = Color(0xFF18181B);
  static const Color surfaceDark2 = Color(0xFF27272A);
  static const Color borderDark = Color(0xFF3F3F46);

  // ── Neutrals Light ───────────────────────────────────────────────────────
  static const Color bgLight = Color(0xFFFAFAFA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceLight2 = Color(0xFFF4F4F5);
  static const Color borderLight = Color(0xFFE4E4E7);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimaryDark = Color(0xFFFAFAFA);
  static const Color textSecondaryDark = Color(0xFFA1A1AA);
  static const Color textPrimaryLight = Color(0xFF09090B);
  static const Color textSecondaryLight = Color(0xFF71717A);

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color successSurface = Color(0xFF14532D);
  static const Color error = Color(0xFFEF4444);
  static const Color errorSurface = Color(0xFF450A0A);
  static const Color warning = Color(0xFFF59E0B);
}

class ChailTheme {
  ChailTheme._();

  static ThemeData dark({Color? accentColor}) {
    final accent = accentColor ?? ChailColors.primary;
    final textTheme = _textTheme(ChailColors.textPrimaryDark);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: accent,
        onPrimary: Colors.white,
        surface: ChailColors.surfaceDark,
        onSurface: ChailColors.textPrimaryDark,
        error: ChailColors.error,
        outline: ChailColors.borderDark,
      ),
      scaffoldBackgroundColor: ChailColors.bgDark,
      textTheme: textTheme,
      inputDecorationTheme: _inputTheme(
        border: ChailColors.borderDark,
        fill: ChailColors.surfaceDark2,
        hint: ChailColors.textSecondaryDark,
      ),
      elevatedButtonTheme: _elevatedButtonTheme(accent),
      outlinedButtonTheme: _outlinedButtonTheme(accent, ChailColors.borderDark),
      textButtonTheme: _textButtonTheme(accent),
      dividerTheme: const DividerThemeData(
        color: ChailColors.borderDark,
        thickness: 1,
      ),
      cardTheme: CardTheme(
        color: ChailColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ChailColors.borderDark),
        ),
      ),
    );
  }

  static ThemeData light({Color? accentColor}) {
    final accent = accentColor ?? ChailColors.primary;
    final textTheme = _textTheme(ChailColors.textPrimaryLight);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: accent,
        onPrimary: Colors.white,
        surface: ChailColors.surfaceLight,
        onSurface: ChailColors.textPrimaryLight,
        error: ChailColors.error,
        outline: ChailColors.borderLight,
      ),
      scaffoldBackgroundColor: ChailColors.bgLight,
      textTheme: textTheme,
      inputDecorationTheme: _inputTheme(
        border: ChailColors.borderLight,
        fill: ChailColors.surfaceLight2,
        hint: ChailColors.textSecondaryLight,
      ),
      elevatedButtonTheme: _elevatedButtonTheme(accent),
      outlinedButtonTheme: _outlinedButtonTheme(accent, ChailColors.borderLight),
      textButtonTheme: _textButtonTheme(accent),
      dividerTheme: const DividerThemeData(
        color: ChailColors.borderLight,
        thickness: 1,
      ),
      cardTheme: CardTheme(
        color: ChailColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ChailColors.borderLight),
        ),
      ),
    );
  }

  static TextTheme _textTheme(Color primary) => GoogleFonts.interTextTheme(
        TextTheme(
          displayLarge: TextStyle(
              fontSize: 32, fontWeight: FontWeight.w700, color: primary),
          displayMedium: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w700, color: primary),
          headlineLarge: TextStyle(
              fontSize: 24, fontWeight: FontWeight.w600, color: primary),
          headlineMedium: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w600, color: primary),
          titleLarge: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600, color: primary),
          titleMedium: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w500, color: primary),
          bodyLarge: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w400, color: primary),
          bodyMedium: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w400, color: primary),
          labelLarge: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: primary),
          labelMedium: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500, color: primary),
          labelSmall: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w500, color: primary),
        ),
      );

  static InputDecorationTheme _inputTheme({
    required Color border,
    required Color fill,
    required Color hint,
  }) =>
      InputDecorationTheme(
        filled: true,
        fillColor: fill,
        hintStyle: TextStyle(color: hint, fontSize: 15),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ChailColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ChailColors.error),
        ),
      );

  static ElevatedButtonThemeData _elevatedButtonTheme(Color accent) =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          textStyle: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w600),
        ),
      );

  static OutlinedButtonThemeData _outlinedButtonTheme(
          Color accent, Color border) =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: border),
          textStyle: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w600),
        ),
      );

  static TextButtonThemeData _textButtonTheme(Color accent) =>
      TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w500),
        ),
      );
}
