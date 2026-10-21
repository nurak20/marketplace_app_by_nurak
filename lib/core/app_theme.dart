import 'package:flutter/material.dart';

abstract final class StyleColor {
  static const double iconSize = 20;
  static const ink = Color(0xFF12302E);
  static const muted = Color(0xFF5C7471);
  static const accent = Color(0xFFF0A020);
  static const canvas = Color(0xFFE8EFED);
  static const line = Color(0xFFDCE6E3);
  static const success = Color(0xFF1F8A5B);
  static const softMint = Color(0xFFCFE3DE);
  static const sand = Color(0xFFF4DCAE);
  static const teal = Color(0xFF2B6B62);
  static const unreadSurface = Color(0xFFFFF8E9);
}

abstract final class StyleFont {
  static const family = 'Roboto';
  static const mediumSize = 14.0;
  static const largeSize = 18.0;
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: StyleColor.ink,
    primary: StyleColor.ink,
    secondary: StyleColor.accent,
    surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: StyleFont.family,
    colorScheme: scheme,
    scaffoldBackgroundColor: StyleColor.canvas,
    iconTheme: const IconThemeData(size: StyleColor.iconSize),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(iconSize: StyleColor.iconSize),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: StyleFont.largeSize),
      displayMedium: TextStyle(fontSize: StyleFont.largeSize),
      displaySmall: TextStyle(fontSize: StyleFont.largeSize),
      headlineLarge: TextStyle(fontSize: StyleFont.largeSize),
      headlineMedium: TextStyle(fontSize: StyleFont.largeSize),
      headlineSmall: TextStyle(fontSize: StyleFont.largeSize),
      titleLarge: TextStyle(fontSize: StyleFont.largeSize),
      titleMedium: TextStyle(fontSize: StyleFont.largeSize),
      titleSmall: TextStyle(fontSize: StyleFont.largeSize),
      bodyLarge: TextStyle(fontSize: StyleFont.mediumSize),
      bodyMedium: TextStyle(fontSize: StyleFont.mediumSize),
      bodySmall: TextStyle(fontSize: StyleFont.mediumSize),
      labelLarge: TextStyle(fontSize: StyleFont.mediumSize),
      labelMedium: TextStyle(fontSize: StyleFont.mediumSize),
      labelSmall: TextStyle(fontSize: StyleFont.mediumSize),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: StyleColor.canvas,
      foregroundColor: StyleColor.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: StyleColor.ink,
        fontSize: StyleFont.largeSize,
        fontWeight: FontWeight.w400,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: StyleColor.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: StyleColor.ink, width: 1.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: StyleColor.accent.withValues(alpha: .25),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: StyleFont.mediumSize,
          fontWeight: FontWeight.w400,
          color: states.contains(WidgetState.selected)
              ? StyleColor.ink
              : StyleColor.muted,
        ),
      ),
    ),
  );
}
