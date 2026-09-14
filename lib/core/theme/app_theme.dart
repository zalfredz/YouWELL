import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Typography, form fields, buttons and global Material styling.
abstract final class AppTheme {
  /// Native app theme, aligned with the dark web workspace palette.
  static ThemeData get mobile => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: appAccent,
      onPrimary: appCanvas,
      secondary: appAccentCyan,
      onSecondary: appCanvas,
      surface: appSurface,
      onSurface: appText,
      error: Color(0xffffa6a6),
    ),
    scaffoldBackgroundColor: appCanvas,
    fontFamily: 'Arial',
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: appText, height: 1.5),
      bodyMedium: TextStyle(color: appText, height: 1.5),
      bodySmall: TextStyle(color: appMuted, height: 1.4),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: appRaised,
      labelStyle: const TextStyle(color: appMuted),
      hintStyle: const TextStyle(color: appMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: appBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: appBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: appAccent, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: appAccent,
        foregroundColor: appCanvas,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: appText,
        side: const BorderSide(color: appBorder),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: appSurface,
      indicatorColor: Color(0xff243a34),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: appSurface,
      modalBackgroundColor: appSurface,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: appSurface),
  );

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: green, surface: Colors.white),
    scaffoldBackgroundColor: cream,
    fontFamily: 'Arial',
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: ink, height: 1.5),
      bodyLarge: TextStyle(color: ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cream,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}
