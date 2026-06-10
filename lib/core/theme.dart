import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Light mode
  static const Color primary = Color(0xFF01696F);
  static const Color background = Color(0xFFFFFFFF);
  static const Color aiBubble = Color(0xFFF0F7F7);
  static const Color userBubbleText = Color(0xFFFFFFFF);
  static const Color aiBubbleText = Color(0xFF1A1A1A);
  static const Color timestamp = Color(0xFF8A8A8A);
  static const Color error = Color(0xFFD32F2F);

  // Dark mode overrides
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkAiBubble = Color(0xFF1C2B2C);
  static const Color darkAiBubbleText = Color(0xFFE0E0E0);
  static const Color darkTimestamp = Color(0xFF9E9E9E);
  static const Color darkInputFill = Color(0xFF2A2A2A);
  static const Color darkDivider = Color(0xFF2E2E2E);
}

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    dividerColor: const Color(0xFFEAEAEA),
  );
}

ThemeData buildDarkTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    brightness: Brightness.dark,
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkAiBubbleText,
  ).copyWith(
    error: AppColors.error,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.darkBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: AppColors.darkSurface,
    ),
    dividerColor: AppColors.darkDivider,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkInputFill,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.darkSurface,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: AppColors.darkSurface,
    ),
  );
}
