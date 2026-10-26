import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

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

abstract final class StyleSpacing {
  static const bottomContentClearance = 150.0;
}

// Paste this into lib/core/app_theme.dart, replacing your current
// buildAppTheme(). Keep your existing StyleColor, StyleFont and StyleSpacing
// classes in that file, and make sure it imports:
//   import 'package:flutter/material.dart';

OutlineInputBorder _inputBorder(Color color, double width) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );

ThemeData buildAppTheme() {
  const noShadow = Colors.transparent;

  final scheme = ColorScheme.fromSeed(
    seedColor: StyleColor.ink,
    primary: StyleColor.ink,
    secondary: StyleColor.accent,
    surface: Colors.white,
    surfaceTint: noShadow, // removes the Material 3 tint on raised surfaces
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: StyleFont.family,
    colorScheme: scheme,
    scaffoldBackgroundColor: StyleColor.canvas,
    shadowColor: noShadow, // global fallback for any Material widget
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
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white.withValues(alpha: .7),
      foregroundColor: StyleColor.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: noShadow,
      surfaceTintColor: noShadow,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: StyleColor.ink,
        fontSize: StyleFont.largeSize,
        fontWeight: FontWeight.w400,
      ),
    ),
    cupertinoOverrideTheme: CupertinoThemeData(
      barBackgroundColor: Colors.white.withValues(alpha: .7),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shadowColor: noShadow,
      surfaceTintColor: noShadow,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: _inputBorder(StyleColor.line, 0.5),
      enabledBorder: _inputBorder(StyleColor.line, 0.5),
      disabledBorder: _inputBorder(StyleColor.line, 0.5),
      focusedBorder: _inputBorder(StyleColor.ink, 1),
      errorBorder: _inputBorder(scheme.error, 0.5),
      focusedErrorBorder: _inputBorder(scheme.error, 1),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
      shadowColor: noShadow,
      surfaceTintColor: noShadow,
      indicatorColor: StyleColor.accent.withValues(alpha: .25),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: states.contains(WidgetState.selected)
              ? StyleColor.ink
              : StyleColor.muted,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(elevation: 0, shadowColor: noShadow),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(elevation: 0, shadowColor: noShadow),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      elevation: 0,
      modalElevation: 0,
      shadowColor: noShadow,
      surfaceTintColor: noShadow,
    ),
    dialogTheme: const DialogThemeData(
      elevation: 0,
      shadowColor: noShadow,
      surfaceTintColor: noShadow,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      elevation: 0,
      shadowColor: noShadow,
      surfaceTintColor: noShadow,
    ),
    snackBarTheme: const SnackBarThemeData(elevation: 0),
  );
}
