import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Typography, form fields, buttons and global Material styling.
abstract final class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: green,
          surface: Colors.white,
        ),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );
}
