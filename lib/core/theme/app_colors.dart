import 'package:flutter/material.dart';

// https://colorhunt.co/palette/576a8fb7bdf7fff8deff7444
const brandBlue = Color(0xff576a8f);
const brandLavender = Color(0xffb7bdf7);
const brandCream = Color(0xfffff8de);
const brandOrange = Color(0xffff7444);

/// Semantic colors shared by mobile, workspaces, and public pages.
class AppColors {
  const AppColors({
    required this.canvas,
    required this.surface,
    required this.raised,
    required this.border,
    required this.text,
    required this.muted,
    required this.accent,
    required this.cyan,
    required this.amber,
    required this.selected,
  });
  final Color canvas,
      surface,
      raised,
      border,
      text,
      muted,
      accent,
      cyan,
      amber,
      selected;
  static const light = AppColors(
    canvas: brandCream,
    surface: Color(0xfffffcf0),
    raised: Color(0xffeeeffb),
    border: Color(0xffc3c8dc),
    text: Color(0xff28364f),
    muted: brandBlue,
    accent: brandBlue,
    cyan: Color(0xff6267a5),
    amber: Color(0xffa83d1c),
    selected: Color(0xffe8eaff),
  );
  static const dark = AppColors(
    canvas: Color(0xff151d2c),
    surface: Color(0xff202c42),
    raised: Color(0xff2a3853),
    border: Color(0xff425372),
    text: brandCream,
    muted: Color(0xffbfc8de),
    accent: brandLavender,
    cyan: brandLavender,
    amber: brandOrange,
    selected: Color(0xff354461),
  );
}

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;
}
