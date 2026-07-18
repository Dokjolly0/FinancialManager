import 'package:flutter/material.dart';

/// Raw palette values from plan.md section 6.3. Keep these as the single
/// source of truth for the hex values; [AppTheme] and [SemanticColors]
/// build Material [ColorScheme]s and the credit/debit extension from here.
abstract final class AppColors {
  // Light theme
  static const lightPrimary = Color(0xFF176B5B);
  static const lightPrimaryContainer = Color(0xFFD7F4EC);
  static const lightBackground = Color(0xFFF7F9F8);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightTextPrimary = Color(0xFF16201D);
  static const lightTextSecondary = Color(0xFF5C6965);
  static const lightBorder = Color(0xFFDCE4E1);

  // Dark theme
  static const darkBackground = Color(0xFF0E1513);
  static const darkSurface = Color(0xFF17211E);
  static const darkElevatedSurface = Color(0xFF1F2B27);
  static const darkTextPrimary = Color(0xFFF1F6F4);
  static const darkTextSecondary = Color(0xFFAAB8B3);
  static const darkPrimary = Color(0xFF65CDB5);

  // Semantic — shared across themes unless noted otherwise.
  static const creditLight = Color(0xFF067647);
  static const debitLight = Color(0xFFB42318);
  static const warningLight = Color(0xFFB54708);
  static const infoLight = Color(0xFF175CD3);

  // Dark-theme semantic tones lean lighter for contrast against dark surfaces.
  static const creditDark = Color(0xFF3FCE84);
  static const debitDark = Color(0xFFF2795F);
  static const warningDark = Color(0xFFF0A15D);
  static const infoDark = Color(0xFF6FA8F5);
}
