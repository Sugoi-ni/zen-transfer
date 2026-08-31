import 'package:flutter/material.dart';

class ZenTheme {
  // ── Core palette ──
  static const Color primaryPurple = Color(0xFF9C27B0);
  static const Color deepPurple = Color(0xFF7B1FA2);
  static const Color accentPurple = Color(0xFFCE93D8);
  static const Color lightPurple = Color(0xFFE1BEE7);

  // ── Backgrounds ──
  static const Color darkBg = Color(0xFF0A0A10);
  static const Color darkSurface = Color(0xFF13131D);
  static const Color darkCard = Color(0xFF1A1A28);
  static const Color darkCardHover = Color(0xFF222236);
  static const Color darkBorder = Color(0xFF2A2A40);
  static const Color darkBorderLight = Color(0xFF35354D);

  // ── Text ──
  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFF9898B0);
  static const Color textTertiary = Color(0xFF6A6A82);

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

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: primaryPurple,
        secondary: accentPurple,
        surface: darkSurface,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
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
          side: const BorderSide(color: darkBorder, width: 1),
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
          side: const BorderSide(color: darkBorderLight, width: 1.5),
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
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryPurple, width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: primaryPurple,
        unselectedItemColor: textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkCard,
        contentTextStyle: const TextStyle(color: textPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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
