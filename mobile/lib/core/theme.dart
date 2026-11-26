import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const teal = Color(0xFF0B7F8B);
  static const tealDark = Color(0xFF07525B);
  static const tealLight = Color(0xFFDDF6F7);
  static const cream = Color(0xFFFFF8E7);
  static const sun = Color(0xFFFFC93C);
  static const coral = Color(0xFFFF6B4A);
  static const ink = Color(0xFF12294A);
  static const muted = Color(0xFF4A6178);
  static const amber = Color(0xFFB45309);
  static const amberLight = Color(0xFFFEF3C7);
  static const green = Color(0xFF15803D);
  static const greenLight = Color(0xFFDCFCE7);
  static const line = Color(0xFFCDEBED);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.teal,
    primary: AppColors.teal,
    secondary: AppColors.sun,
    surface: Colors.white,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: AppColors.cream);
  final body = GoogleFonts.nunitoTextTheme(base.textTheme)
      .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
  TextStyle head(double size) =>
      GoogleFonts.baloo2(fontSize: size, fontWeight: FontWeight.w800, color: AppColors.ink, height: 1.1);

  return base.copyWith(
    textTheme: body.copyWith(
      headlineMedium: head(32),
      headlineSmall: head(26),
      titleLarge: head(22),
      titleMedium: head(18),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.cream,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: head(22),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: AppColors.teal,
        side: const BorderSide(color: AppColors.teal, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.line, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.teal, width: 2)),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: const StadiumBorder(),
      side: const BorderSide(color: AppColors.line),
      selectedColor: AppColors.teal,
      checkmarkColor: Colors.white,
      labelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w700),
      secondaryLabelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: Colors.white),
    ),
  );
}
