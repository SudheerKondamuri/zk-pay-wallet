import 'package:flutter/material.dart';

/// Verdigris palette — dark mode only.
/// Teal = actionable. Gold = completed. Never swap.
abstract final class AppColors {
  static const Color background = Color(0xFF0F1512);
  static const Color surfaceFlat = Color(0xFF1A211C);

  // Glass: used via GlassCard only (Dashboard balance, Review sheet, signature visual).
  static const Color glassFill = Color.fromRGBO(255, 255, 255, 0.05);
  static const Color glassBorder = Color.fromRGBO(255, 255, 255, 0.09);

  static const Color primaryAccent = Color(0xFF5EC9A8); // verdigris teal — CTAs, active nav
  static const Color secondaryGold = Color(0xFFD4A15C); // aged brass — committed/success
  static const Color danger = Color(0xFFE0574A);

  static const Color textPrimary = Color(0xFFEFF3F0);
  static const Color textSecondary = Color(0xFF8C9A92);
  static const Color textMuted = Color(0xFF5C6A62);

  static const Color divider = Color.fromRGBO(255, 255, 255, 0.08);
}

/// Verdigris ThemeData — Space Grotesk for display, Inter for body.
/// Two weights only: 400 (regular), 500 (medium). Never bold.
ThemeData buildVerdigrisTheme() {
  const displayFont = 'SpaceGrotesk';
  const bodyFont = 'Inter';

  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    useMaterial3: true,
    fontFamily: bodyFont,
    colorScheme: const ColorScheme.dark(
      surface: AppColors.surfaceFlat,
      primary: AppColors.primaryAccent,
      secondary: AppColors.secondaryGold,
      error: AppColors.danger,
      onSurface: AppColors.textPrimary,
      onPrimary: AppColors.background,
      onSecondary: AppColors.background,
      onError: AppColors.textPrimary,
    ),
    textTheme: const TextTheme(
      // Display — large balance numbers
      displayLarge: TextStyle(
        fontFamily: displayFont,
        fontSize: 40,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      // Display medium — section headings
      displayMedium: TextStyle(
        fontFamily: displayFont,
        fontSize: 28,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      // Display small — card headings
      displaySmall: TextStyle(
        fontFamily: displayFont,
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      // Title large — screen titles
      titleLarge: TextStyle(
        fontFamily: displayFont,
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      // Title medium
      titleMedium: TextStyle(
        fontFamily: displayFont,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      // Body large
      bodyLarge: TextStyle(
        fontFamily: bodyFont,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      // Body medium
      bodyMedium: TextStyle(
        fontFamily: bodyFont,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
      // Body small
      bodySmall: TextStyle(
        fontFamily: bodyFont,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textMuted,
      ),
      // Label — buttons, nav items
      labelLarge: TextStyle(
        fontFamily: bodyFont,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      labelMedium: TextStyle(
        fontFamily: bodyFont,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: displayFont,
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      iconTheme: IconThemeData(color: AppColors.textPrimary),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceFlat,
      contentTextStyle: const TextStyle(
        fontFamily: bodyFont,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surfaceFlat,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primaryAccent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      hintStyle: const TextStyle(
        fontFamily: bodyFont,
        fontSize: 14,
        color: AppColors.textMuted,
      ),
      labelStyle: const TextStyle(
        fontFamily: bodyFont,
        fontSize: 14,
        color: AppColors.textSecondary,
      ),
    ),
  );
}
