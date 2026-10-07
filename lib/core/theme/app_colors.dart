import 'package:flutter/material.dart';

// https://colorhunt.co/palette/576a8fb7bdf7fff8deff7444
const brandBlue = Color(0xff576a8f);
const brandLavender = Color(0xffb7bdf7);
const brandCream = Color(0xfffff8de);
const brandOrange = Color(0xffff7444);

/// Semantic colors shared by mobile, workspaces, and public pages.
/// Web keeps [light]/[dark]; the mobile app uses [mobileLight]/[mobileDark],
/// which add the reward palette (XP gold, success green, quest categories).
class AppColors extends ThemeExtension<AppColors> {
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
    this.card = const Color(0xffffffff),
    this.primary = brandOrange,
    this.primaryEdge = const Color(0xffd85a2e),
    this.onPrimary = const Color(0xff291407),
    this.streak = const Color(0xffff9600),
    this.xp = const Color(0xfff59e0b),
    this.xpSoft = const Color(0xfffef3c7),
    this.onXp = const Color(0xff7c3a06),
    this.success = const Color(0xff047857),
    this.successSoft = const Color(0xffdcfce7),
    this.body = const Color(0xff16a34a),
    this.energy = const Color(0xff7c3aed),
    this.reduction = const Color(0xffea580c),
    this.lifestyle = const Color(0xff0284c7),
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

  /// Reward and quest-category tokens (mobile).
  final Color card,
      primary,
      primaryEdge,
      onPrimary,
      streak,
      xp,
      xpSoft,
      onXp,
      success,
      successSoft,
      body,
      energy,
      reduction,
      lifestyle;

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

  /// Clean, flat palette (Duolingo-like): white surfaces, bold green CTA
  /// with dark text, gold XP. Every text pair meets 4.5:1.
  static const mobileLight = AppColors(
    canvas: Color(0xffffffff),
    surface: Color(0xffffffff),
    raised: Color(0xfff2f4f5),
    border: Color(0xffe5e5e5),
    text: Color(0xff1f2328),
    muted: Color(0xff5f6b76),
    accent: Color(0xff0b7bb5),
    cyan: Color(0xff0b7bb5),
    amber: Color(0xffb45309),
    selected: Color(0xffe8f8d8),
    card: Color(0xffffffff),
    primary: Color(0xff58cc02),
    primaryEdge: Color(0xff46a302),
    onPrimary: Color(0xff0e2a00),
    xp: Color(0xffffc800),
    xpSoft: Color(0xfffff4cc),
    onXp: Color(0xff6b4a00),
    success: Color(0xff2b7a0b),
    successSoft: Color(0xffe8f8d8),
    body: Color(0xff58a700),
    energy: Color(0xff9b51e0),
    reduction: Color(0xffff4b4b),
    lifestyle: Color(0xff0a9bd9),
  );
  static const mobileDark = AppColors(
    canvas: Color(0xff131f24),
    surface: Color(0xff131f24),
    raised: Color(0xff22343c),
    border: Color(0xff37464f),
    text: Color(0xfff1f7fb),
    muted: Color(0xffa9bcc6),
    accent: Color(0xff49c0f8),
    cyan: Color(0xff49c0f8),
    amber: Color(0xffffb020),
    selected: Color(0xff23401a),
    card: Color(0xff1b2b33),
    primary: Color(0xff58cc02),
    primaryEdge: Color(0xff3f8f02),
    onPrimary: Color(0xff0e2a00),
    xp: Color(0xffffc800),
    xpSoft: Color(0xff3a3010),
    onXp: Color(0xffffd84d),
    success: Color(0xff79d93a),
    successSoft: Color(0xff1e3314),
    body: Color(0xff79d93a),
    energy: Color(0xffce82ff),
    reduction: Color(0xffff6b6b),
    lifestyle: Color(0xff49c0f8),
  );

  /// Color for a quest category (Body, Energy, Reduction, Lifestyle).
  Color category(Object? name) => switch (name) {
    'Body' => body,
    'Energy' => energy,
    'Reduction' => reduction,
    'Lifestyle' => lifestyle,
    _ => accent,
  };

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) =>
      other is AppColors && t >= .5 ? other : this;
}

extension AppColorsContext on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppColors.dark
          : AppColors.light);
}
