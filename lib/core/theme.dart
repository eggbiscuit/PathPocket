import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF01696F);
  static const Color background = Color(0xFFFFFFFF);
  static const Color aiBubble = Color(0xFFF0F7F7);
  static const Color userBubbleText = Color(0xFFFFFFFF);
  static const Color aiBubbleText = Color(0xFF1A1A1A);
  static const Color timestamp = Color(0xFF8A8A8A);
  static const Color error = Color(0xFFD32F2F);
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
  );
}
