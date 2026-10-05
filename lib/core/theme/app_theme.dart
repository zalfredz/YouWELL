import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light, AppColors.light);
  static ThemeData get dark => _build(Brightness.dark, AppColors.dark);
  static ThemeData _build(Brightness brightness, AppColors c) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: brandBlue,
          brightness: brightness,
        ).copyWith(
          primary: brandOrange,
          onPrimary: const Color(0xff291407),
          primaryContainer: c.selected,
          onPrimaryContainer: c.text,
          secondary: c.accent,
          onSecondary: c.canvas,
          secondaryContainer: c.selected,
          onSecondaryContainer: c.text,
          tertiary: c.amber,
          surface: c.surface,
          onSurface: c.text,
          onSurfaceVariant: c.muted,
          outline: c.border,
          surfaceContainerHighest: c.raised,
        );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.canvas,
      fontFamily: 'Arial',
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: c.text, displayColor: c.text),
      appBarTheme: AppBarTheme(
        backgroundColor: c.canvas,
        foregroundColor: c.text,
        surfaceTintColor: Colors.transparent,
      ),
      dividerColor: c.border,
      iconTheme: IconThemeData(color: c.accent),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.raised,
        labelStyle: TextStyle(color: c.muted),
        hintStyle: TextStyle(color: c.muted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.accent, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brandOrange,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.accent),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text,
          side: BorderSide(color: c.border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.selected,
        iconTheme: WidgetStatePropertyAll(IconThemeData(color: c.accent)),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: c.text, fontWeight: FontWeight.w600),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        modalBackgroundColor: c.surface,
      ),
      dialogTheme: DialogThemeData(backgroundColor: c.surface),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.raised,
      ),
    );
  }
}
