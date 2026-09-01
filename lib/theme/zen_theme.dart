import 'package:flutter/material.dart';

class ZenTheme {
  // ── Theme mode (set from app level) ──
  static bool isLight = false;

  // ── Core palette ──
  static const Color primaryPurple = Color(0xFF9C27B0);
  static const Color deepPurple = Color(0xFF7B1FA2);
  static const Color accentPurple = Color(0xFFCE93D8);
  static const Color lightPurple = Color(0xFFE1BEE7);

  // ── Dark backgrounds ──
  static const Color _darkBg = Color(0xFF0A0A10);
  static const Color _darkSurface = Color(0xFF13131D);
  static const Color _darkCard = Color(0xFF1A1A28);
  static const Color _darkCardHover = Color(0xFF222236);
  static const Color _darkBorder = Color(0xFF2A2A40);
  static const Color _darkBorderLight = Color(0xFF35354D);

  // ── Light backgrounds ──
  static const Color _lightBg = Color(0xFFF6F4FB);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightCard = Color(0xFFFFFFFF);
  static const Color _lightCardHover = Color(0xFFF0EBF7);
  static const Color _lightBorder = Color(0xFFE4DEF0);
  static const Color _lightBorderLight = Color(0xFFD5CCE8);

  // ── Dark text ──
  static const Color _darkTextPrimary = Color(0xFFF0F0F5);
  static const Color _darkTextSecondary = Color(0xFF9898B0);
  static const Color _darkTextTertiary = Color(0xFF6A6A82);

  // ── Light text ──
  static const Color _lightTextPrimary = Color(0xFF1C1A26);
  static const Color _lightTextSecondary = Color(0xFF5A5470);
  static const Color _lightTextTertiary = Color(0xFF8A84A0);

  // ── Backgrounds (mode-aware) ──
  static Color get darkBg => isLight ? _lightBg : _darkBg;
  static Color get darkSurface => isLight ? _lightSurface : _darkSurface;
  static Color get darkCard => isLight ? _lightCard : _darkCard;
  static Color get darkCardHover => isLight ? _lightCardHover : _darkCardHover;
  static Color get darkBorder => isLight ? _lightBorder : _darkBorder;
  static Color get darkBorderLight => isLight ? _lightBorderLight : _darkBorderLight;

  // ── Text (mode-aware) ──
  static Color get textPrimary => isLight ? _lightTextPrimary : _darkTextPrimary;
  static Color get textSecondary => isLight ? _lightTextSecondary : _darkTextSecondary;
  static Color get textTertiary => isLight ? _lightTextTertiary : _darkTextTertiary;

  // ── Semantic ──
  static const Color success = Color(0xFF66BB6A);
  static const Color error = Color(0xFFEF5350);
  static const Color warning = Color(0xFFFFCA28);
  static const Color info = Color(0xFF42A5F5);

  // ── Glow ──
  static const Color transferGlow = Color(0xFFAB47BC);
  static const Color deviceGlow = Color(0xFF7C4DFF);

  // ── Device card colors ──
  static const List<Color> deviceColors = [
    Color(0xFF7C4DFF), // indigo
    Color(0xFF00BFA5), // teal
    Color(0xFFFF6D00), // orange
    Color(0xFF2979FF), // blue
    Color(0xFFFF1744), // red
    Color(0xFF00E676), // green
  ];

  /// Current theme (dark or light based on [isLight])
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: isLight ? Brightness.light : Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      colorScheme: isLight
          ? const ColorScheme.light(
              primary: primaryPurple,
              secondary: accentPurple,
              surface: Color(0xFFFFFFFF),
              error: Color(0xFFD32F2F),
              onPrimary: Colors.white,
              onSecondary: Colors.white,
              onSurface: Color(0xFF1C1A26),
            )
          : ColorScheme.dark(
              primary: primaryPurple,
              secondary: accentPurple,
              surface: darkSurface,
              error: error,
              onPrimary: Colors.white,
              onSecondary: Colors.white,
              onSurface: textPrimary,
            ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: darkBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentPurple,
          side: BorderSide(color: darkBorderLight, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryPurple, width: 2),
        ),
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: textTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: primaryPurple,
        unselectedItemColor: textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: darkBorder,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkCard,
        contentTextStyle: TextStyle(color: textPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Backward-compatible alias
  static ThemeData get darkTheme => theme;
  static ThemeData get lightTheme => theme;

  // ── Gradient decorations ──
  static BoxDecoration get glowGradient => BoxDecoration(
    gradient: LinearGradient(
      colors: [
        primaryPurple.withValues(alpha: 0.15),
        deepPurple.withValues(alpha: 0.05),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );

  static BoxDecoration get cardGlow => BoxDecoration(
    color: darkCard,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: darkBorder, width: 1),
  );

  static BoxDecoration get cardGlowActive => BoxDecoration(
    color: darkCard,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: primaryPurple.withValues(alpha: 0.4), width: 1.5),
    boxShadow: [
      BoxShadow(
        color: primaryPurple.withValues(alpha: 0.15),
        blurRadius: 24,
        spreadRadius: 0,
      ),
    ],
  );

  // ── Device card gradient ──
  static LinearGradient deviceGradient(int index) {
    final color = deviceColors[index % deviceColors.length];
    return LinearGradient(
      colors: [
        color.withValues(alpha: 0.8),
        color.withValues(alpha: 0.4),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  // ── Utility ──
  static List<BoxShadow> get glowShadow => [
    BoxShadow(
      color: primaryPurple.withValues(alpha: 0.2),
      blurRadius: 20,
      spreadRadius: 0,
    ),
  ];

  static LinearGradient get purpleGradient => const LinearGradient(
    colors: [primaryPurple, deepPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
