import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'semantic_colors.dart';

/// Builds the light and dark [ThemeData] for the app from the palette in
/// plan.md section 6.3 and the typography scale in section 6.4. Material 3
/// components are used as-is wherever possible (section 6.2) — this file
/// only sets tokens (colors, type, shape), not custom widget behavior.
abstract final class AppTheme {
  static ThemeData light() => _build(
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.lightPrimary,
      brightness: Brightness.light,
      primary: AppColors.lightPrimary,
      primaryContainer: AppColors.lightPrimaryContainer,
      surface: AppColors.lightSurface,
      outline: AppColors.lightBorder,
    ),
    background: AppColors.lightBackground,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    semanticColors: SemanticColors.light,
  );

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.darkPrimary,
      brightness: Brightness.dark,
      primary: AppColors.darkPrimary,
      surface: AppColors.darkSurface,
    ),
    background: AppColors.darkBackground,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    semanticColors: SemanticColors.dark,
  );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required Color background,
    required Color textPrimary,
    required Color textSecondary,
    required SemanticColors semanticColors,
  }) {
    final textTheme = _textTheme(textPrimary, textSecondary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      extensions: [semanticColors],
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.4)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
        ),
      ),
      visualDensity: VisualDensity.standard,
    );
  }

  /// Typography scale from plan.md section 6.4, mapped onto Material's
  /// TextTheme slots so `Theme.of(context).textTheme.*` works everywhere.
  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      // Balance display: 36-44sp / weight 700.
      displayLarge: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      // Page title: 24-28sp / weight 650-700.
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      // Card title: 16-18sp / weight 600.
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      // Body: 14-16sp.
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: primary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: primary,
      ),
      // Secondary data: 12-14sp.
      bodySmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: secondary,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
    );
  }
}
