import 'package:flutter/material.dart';

abstract final class StyleColor {
  static const double iconSize = 20;
  static const ink = Color(0xFFE5EEE9);
  static const muted = Color(0xFF9AADA5);
  static const accent = Color(0xFFFFBC55);
  static const action = Color(0xFF91D3BC);
  static const canvas = Color(0xFF101714);
  static const surface = Color(0xFF19221E);
  static const surfaceVariant = Color(0xFF222E28);
  static const line = Color(0xFF35443D);
  static const success = Color(0xFF72D6A1);
  static const softMint = Color(0xFF29463B);
  static const sand = Color(0xFF4B3B22);
  static const teal = Color(0xFF78C8B0);
  static const unreadSurface = Color(0xFF332B1C);
}

abstract final class StyleFont {
  static const family = 'KSR';
  static const mediumSize = 14.0;
  static const largeSize = 18.0;
}

abstract final class StyleSpacing {
  static const bottomContentClearance = 150.0;
}

OutlineInputBorder _inputBorder(Color color, double width) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );

ThemeData buildAppTheme() {
  const noShadow = Colors.transparent;

  final scheme = ColorScheme.fromSeed(
    brightness: Brightness.dark,
    seedColor: StyleColor.action,
    primary: StyleColor.action,
    onPrimary: StyleColor.canvas,
    secondary: StyleColor.accent,
    onSecondary: StyleColor.canvas,
    surface: StyleColor.surface,
    onSurface: StyleColor.ink,
    outline: StyleColor.line,
    surfaceTint: noShadow, // removes the Material 3 tint on raised surfaces
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
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
    ).apply(bodyColor: StyleColor.ink, displayColor: StyleColor.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: StyleColor.surface.withValues(alpha: .96),
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
    cardTheme: CardThemeData(
      color: StyleColor.surface,
      elevation: 0,
      shadowColor: noShadow,
      surfaceTintColor: noShadow,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: StyleColor.surfaceVariant,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: _inputBorder(StyleColor.line, 0.5),
      enabledBorder: _inputBorder(StyleColor.line, 0.5),
      disabledBorder: _inputBorder(StyleColor.line, 0.5),
      focusedBorder: _inputBorder(scheme.primary, 1),
      errorBorder: _inputBorder(scheme.error, 0.5),
      focusedErrorBorder: _inputBorder(scheme.error, 1),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: StyleColor.surface,
      elevation: 0,
      shadowColor: noShadow,
      surfaceTintColor: noShadow,
      indicatorColor: StyleColor.action.withValues(alpha: .2),
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
