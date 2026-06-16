import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Color Tokens ─────────────────────────────────────────────────────────────

class AppColors {
  AppColors._();

  // Primary brand
  static const Color primary = Color(0xFF00A1FF);
  static const Color primaryDark = Color(0xFF40B8FF);
  static const Color primaryContainer = Color(0xFFE0F4FF);
  static const Color primaryContainerDark = Color(0xFF003D5C);

  // Accent — warm amber, scientific instrument feel
  static const Color accent = Color(0xFF8B6914);
  static const Color accentDark = Color(0xFFC49A3A);

  // Page backgrounds — warm, not clinical-white
  static const Color bgPage = Color(0xFFF5F3EF);
  static const Color bgPageDark = Color(0xFF181818);

  // Sidebar
  static const Color bgSidebar = Color(0xFFEDEAE4);
  static const Color bgSidebarDark = Color(0xFF101010);
  static const Color bgSidebarHover = Color(0xFFE2DED7);
  static const Color bgSidebarHoverDark = Color(0xFF252525);
  static const Color bgSidebarActive = Color(0xFFD6D1C9);
  static const Color bgSidebarActiveDark = Color(0xFF2E2E2E);

  // Surface (cards, AI bubbles)
  static const Color bgSurface = Color(0xFFFFFFFF);
  static const Color bgSurfaceDark = Color(0xFF222222);

  // Input
  static const Color bgInput = Color(0xFFFFFFFF);
  static const Color bgInputDark = Color(0xFF2A2A2A);

  // Text
  static const Color textPrimary = Color(0xFF1A1917);
  static const Color textPrimaryDark = Color(0xFFEEEDEB);
  static const Color textSecondary = Color(0xFF6A6764);
  static const Color textSecondaryDark = Color(0xFF9A9896);
  static const Color textTertiary = Color(0xFF9E9B98);
  static const Color textTertiaryDark = Color(0xFF605E5C);

  // User bubble
  static const Color userBubble = Color(0xFF00A1FF);
  static const Color userBubbleText = Color(0xFFFFFFFF);

  // Utility
  static const Color divider = Color(0xFFDDD9D3);
  static const Color dividerDark = Color(0xFF2E2E2E);
  static const Color error = Color(0xFFC0392B);
  static const Color errorDark = Color(0xFFEF5350);

  // AI bubble left accent border
  static const Color aiBubbleBorder = Color(0xFF016469);
  static const Color aiBubbleBorderDark = Color(0xFF26A69A);
}

// ── Semantic palette (theme-aware) ────────────────────────────────────────────
//
// Resolves light/dark automatically via ThemeData. Read it in widgets with
// `context.palette` (see the BuildContext extension below) instead of branching
// on `Theme.of(context).brightness`.

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.primary,
    required this.primaryContainer,
    required this.accent,
    required this.bgPage,
    required this.bgSidebar,
    required this.bgSidebarHover,
    required this.bgSidebarActive,
    required this.bgSurface,
    required this.bgInput,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.divider,
    required this.error,
    required this.aiBubbleBorder,
  });

  final Color primary;
  final Color primaryContainer;
  final Color accent;
  final Color bgPage;
  final Color bgSidebar;
  final Color bgSidebarHover;
  final Color bgSidebarActive;
  final Color bgSurface;
  final Color bgInput;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color divider;
  final Color error;
  final Color aiBubbleBorder;

  static const light = AppPalette(
    primary: AppColors.primary,
    primaryContainer: AppColors.primaryContainer,
    accent: AppColors.accent,
    bgPage: AppColors.bgPage,
    bgSidebar: AppColors.bgSidebar,
    bgSidebarHover: AppColors.bgSidebarHover,
    bgSidebarActive: AppColors.bgSidebarActive,
    bgSurface: AppColors.bgSurface,
    bgInput: AppColors.bgInput,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textTertiary: AppColors.textTertiary,
    divider: AppColors.divider,
    error: AppColors.error,
    aiBubbleBorder: AppColors.aiBubbleBorder,
  );

  static const dark = AppPalette(
    primary: AppColors.primaryDark,
    primaryContainer: AppColors.primaryContainerDark,
    accent: AppColors.accentDark,
    bgPage: AppColors.bgPageDark,
    bgSidebar: AppColors.bgSidebarDark,
    bgSidebarHover: AppColors.bgSidebarHoverDark,
    bgSidebarActive: AppColors.bgSidebarActiveDark,
    bgSurface: AppColors.bgSurfaceDark,
    bgInput: AppColors.bgInputDark,
    textPrimary: AppColors.textPrimaryDark,
    textSecondary: AppColors.textSecondaryDark,
    textTertiary: AppColors.textTertiaryDark,
    divider: AppColors.dividerDark,
    error: AppColors.errorDark,
    aiBubbleBorder: AppColors.aiBubbleBorderDark,
  );

  @override
  AppPalette copyWith({
    Color? primary,
    Color? primaryContainer,
    Color? accent,
    Color? bgPage,
    Color? bgSidebar,
    Color? bgSidebarHover,
    Color? bgSidebarActive,
    Color? bgSurface,
    Color? bgInput,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? divider,
    Color? error,
    Color? aiBubbleBorder,
  }) {
    return AppPalette(
      primary: primary ?? this.primary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      accent: accent ?? this.accent,
      bgPage: bgPage ?? this.bgPage,
      bgSidebar: bgSidebar ?? this.bgSidebar,
      bgSidebarHover: bgSidebarHover ?? this.bgSidebarHover,
      bgSidebarActive: bgSidebarActive ?? this.bgSidebarActive,
      bgSurface: bgSurface ?? this.bgSurface,
      bgInput: bgInput ?? this.bgInput,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      divider: divider ?? this.divider,
      error: error ?? this.error,
      aiBubbleBorder: aiBubbleBorder ?? this.aiBubbleBorder,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryContainer:
          Color.lerp(primaryContainer, other.primaryContainer, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      bgPage: Color.lerp(bgPage, other.bgPage, t)!,
      bgSidebar: Color.lerp(bgSidebar, other.bgSidebar, t)!,
      bgSidebarHover: Color.lerp(bgSidebarHover, other.bgSidebarHover, t)!,
      bgSidebarActive: Color.lerp(bgSidebarActive, other.bgSidebarActive, t)!,
      bgSurface: Color.lerp(bgSurface, other.bgSurface, t)!,
      bgInput: Color.lerp(bgInput, other.bgInput, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      error: Color.lerp(error, other.error, t)!,
      aiBubbleBorder: Color.lerp(aiBubbleBorder, other.aiBubbleBorder, t)!,
    );
  }
}

extension PaletteX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}

// ── Radius ────────────────────────────────────────────────────────────────────

class AppRadius {
  AppRadius._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 20;
  static const double bubble = 18;
  static const double full = 999;

  static BorderRadius get mdBr => BorderRadius.circular(md);
  static BorderRadius get lgBr => BorderRadius.circular(lg);
  static BorderRadius get bubbleBr => BorderRadius.circular(bubble);
}

// ── Typography helpers ────────────────────────────────────────────────────────

class AppTextStyles {
  AppTextStyles._();

  static Color _primary(BuildContext ctx) => ctx.palette.textPrimary;

  static Color _secondary(BuildContext ctx) => ctx.palette.textSecondary;

  static Color _tertiary(BuildContext ctx) => ctx.palette.textTertiary;

  static TextStyle display(BuildContext ctx) => GoogleFonts.dmSerifDisplay(
        fontSize: 32, fontWeight: FontWeight.w400,
        letterSpacing: -0.5, color: _primary(ctx));

  static TextStyle title(BuildContext ctx) => GoogleFonts.dmSans(
        fontSize: 16, fontWeight: FontWeight.w600, color: _primary(ctx));

  static TextStyle body(BuildContext ctx) => GoogleFonts.dmSans(
        fontSize: 15, fontWeight: FontWeight.w400,
        height: 1.65, color: _primary(ctx));

  static TextStyle bodyMd(BuildContext ctx) => GoogleFonts.dmSans(
        fontSize: 14, fontWeight: FontWeight.w400,
        height: 1.55, color: _primary(ctx));

  static TextStyle caption(BuildContext ctx) => GoogleFonts.dmSans(
        fontSize: 12, fontWeight: FontWeight.w400, color: _secondary(ctx));

  static TextStyle tiny(BuildContext ctx) => GoogleFonts.dmSans(
        fontSize: 11, fontWeight: FontWeight.w400, color: _tertiary(ctx));

  static TextStyle label(BuildContext ctx) => GoogleFonts.dmSans(
        fontSize: 13, fontWeight: FontWeight.w500, color: _primary(ctx));
}

// ── Theme builders ────────────────────────────────────────────────────────────

ThemeData buildAppTheme() {
  final base = GoogleFonts.dmSansTextTheme();
  final cs = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    brightness: Brightness.light,
    surface: AppColors.bgSurface,
  ).copyWith(error: AppColors.error);

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    textTheme: base,
    extensions: const [AppPalette.light],
    scaffoldBackgroundColor: AppColors.bgPage,
    dividerColor: AppColors.divider,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bgPage,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.dmSans(
        fontSize: 16, fontWeight: FontWeight.w600,
        color: AppColors.textPrimary),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: AppColors.bgSidebar),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.bgSurface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg)),
    ),
    popupMenuTheme: const PopupMenuThemeData(color: AppColors.bgSurface),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgInput,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w500),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AppColors.primaryContainer,
        selectedForegroundColor: AppColors.primary,
        textStyle:
            GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    ),
  );
}

ThemeData buildDarkTheme() {
  final base = GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme);
  final cs = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primaryDark,
    brightness: Brightness.dark,
    surface: AppColors.bgSurfaceDark,
    onSurface: AppColors.textPrimaryDark,
  ).copyWith(error: AppColors.errorDark);

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    textTheme: base,
    extensions: const [AppPalette.dark],
    scaffoldBackgroundColor: AppColors.bgPageDark,
    dividerColor: AppColors.dividerDark,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bgPageDark,
      foregroundColor: AppColors.textPrimaryDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.dmSans(
        fontSize: 16, fontWeight: FontWeight.w600,
        color: AppColors.textPrimaryDark),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: AppColors.bgSidebarDark),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.bgSurfaceDark,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg)),
    ),
    popupMenuTheme: const PopupMenuThemeData(color: AppColors.bgSurfaceDark),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bgInputDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.dividerDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.dividerDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryDark,
        textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w500),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AppColors.primaryContainerDark,
        selectedForegroundColor: AppColors.primaryDark,
        textStyle:
            GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    ),
  );
}
