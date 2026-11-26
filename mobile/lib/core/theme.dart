import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tutobridge palette: lime yellow + white, with near-black for text and icons.
///
/// Contrast rules (WCAG 2.2 AA):
///  * [lime] is a FILL colour only. Text and icons on lime or white are always [ink] (about 17:1 on lime).
///    Never use lime for text, icons or thin borders on white (about 1.2:1).
///  * Focus rings and selected outlines are 2px [ink].
///  * [muted] (#595959) is the only grey for secondary text (about 7:1 on white).
///  * Status is never colour alone: use a label or icon, not red/green.
class AppColors {
  static const lime = Color(0xFFD4FF00); // buttons, active chips, badges, banners
  static const limeDark = Color(0xFFB8E600); // pressed / hover
  static const limeLight = Color(0xFFF2F2F2); // subtle neutral fill to separate white-on-white
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF111111); // text and icons
  static const muted = Color(0xFF595959); // secondary text
  static const line = Color(0xFFE5E5E5); // borders
}

ThemeData buildTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.lime,
    onPrimary: AppColors.ink,
    primaryContainer: AppColors.lime,
    onPrimaryContainer: AppColors.ink,
    secondary: AppColors.lime,
    onSecondary: AppColors.ink,
    secondaryContainer: AppColors.lime,
    onSecondaryContainer: AppColors.ink,
    tertiary: AppColors.lime,
    onTertiary: AppColors.ink,
    error: AppColors.ink,
    onError: AppColors.white,
    surface: AppColors.white,
    onSurface: AppColors.ink,
    surfaceContainerHighest: AppColors.limeLight,
    onSurfaceVariant: AppColors.muted,
    outline: AppColors.line,
    outlineVariant: AppColors.line,
    shadow: Colors.black,
    surfaceTint: Colors.transparent,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: AppColors.white);
  final body = GoogleFonts.nunitoTextTheme(base.textTheme).apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
  TextStyle head(double size) => GoogleFonts.baloo2(fontSize: size, fontWeight: FontWeight.w800, color: AppColors.ink, height: 1.1);

  // A button/chip state resolves to [pressed] while pressed/hovered, otherwise [normal].
  WidgetStateProperty<Color?> limeStates() => WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled)
          ? AppColors.limeLight
          : (s.contains(WidgetState.pressed) || s.contains(WidgetState.hovered))
              ? AppColors.limeDark
              : AppColors.lime);

  const focusRing = BorderSide(color: AppColors.ink, width: 2);

  return base.copyWith(
    textTheme: body.copyWith(
      headlineMedium: head(32),
      headlineSmall: head(26),
      titleLarge: head(22),
      titleMedium: head(18),
    ),
    iconTheme: const IconThemeData(color: AppColors.ink),
    dividerColor: AppColors.line,
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: head(22),
      iconTheme: const IconThemeData(color: AppColors.ink),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: AppColors.ink,
        disabledForegroundColor: AppColors.muted,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16),
      ).copyWith(backgroundColor: limeStates(), side: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.focused) ? focusRing : null)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16),
      ).copyWith(backgroundColor: limeStates()),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: AppColors.ink,
        backgroundColor: AppColors.white,
        side: const BorderSide(color: AppColors.ink, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16),
      ).copyWith(backgroundColor: WidgetStateProperty.resolveWith((s) => (s.contains(WidgetState.pressed) || s.contains(WidgetState.hovered)) ? AppColors.lime : AppColors.white)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.ink, textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: AppColors.ink)),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: AppColors.lime, foregroundColor: AppColors.ink),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(color: AppColors.muted),
      floatingLabelStyle: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700),
      hintStyle: const TextStyle(color: AppColors.muted),
      prefixIconColor: AppColors.ink,
      suffixIconColor: AppColors.ink,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.line, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.ink, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.ink, width: 2)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.ink, width: 3)),
      errorStyle: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: const StadiumBorder(),
      backgroundColor: AppColors.white,
      side: const BorderSide(color: AppColors.line, width: 1.5),
      selectedColor: AppColors.lime,
      checkmarkColor: AppColors.ink,
      iconTheme: const IconThemeData(color: AppColors.ink),
      labelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.ink),
      secondaryLabelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: AppColors.ink),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.lime,
      iconTheme: const WidgetStatePropertyAll(IconThemeData(color: AppColors.ink)),
      labelTextStyle: WidgetStatePropertyAll(GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.ink)),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.ink,
      unselectedLabelColor: AppColors.muted,
      indicatorColor: AppColors.ink,
      indicator: const UnderlineTabIndicator(borderSide: BorderSide(color: AppColors.ink, width: 3)),
      labelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.lime : AppColors.white),
      checkColor: const WidgetStatePropertyAll(AppColors.ink),
      side: const BorderSide(color: AppColors.ink, width: 2),
    ),
    radioTheme: RadioThemeData(fillColor: const WidgetStatePropertyAll(AppColors.ink)),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(AppColors.ink),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.lime : AppColors.white),
      trackOutlineColor: const WidgetStatePropertyAll(AppColors.ink),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.lime : AppColors.white),
        foregroundColor: const WidgetStatePropertyAll(AppColors.ink),
        side: const WidgetStatePropertyAll(BorderSide(color: AppColors.ink, width: 1.5)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: GoogleFonts.nunito(color: AppColors.white, fontWeight: FontWeight.w700),
      actionTextColor: AppColors.lime,
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: AppColors.white, surfaceTintColor: Colors.transparent),
    dialogTheme: const DialogThemeData(backgroundColor: AppColors.white, surfaceTintColor: Colors.transparent),
    cardTheme: CardThemeData(
      color: AppColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppColors.line, width: 1.5)),
    ),
    listTileTheme: const ListTileThemeData(iconColor: AppColors.ink, textColor: AppColors.ink),
    drawerTheme: const DrawerThemeData(backgroundColor: AppColors.white, surfaceTintColor: Colors.transparent),
    focusColor: AppColors.lime,
  );
}
