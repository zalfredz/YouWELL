import 'package:youwell/core/theme/app_theme.dart';
import 'package:youwell/core/config/app_environment.dart';
import 'package:flutter/material.dart';
import 'package:youwell/app/app_shell.dart';
import 'package:youwell/app/web_experience_gate.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/features/moderation/presentation/moderator_page.dart';
import 'package:youwell/features/onboarding/presentation/onboarding_page.dart';

class YouWellApp extends StatelessWidget {
  const YouWellApp({super.key, required this.controller});
  final WellnessController controller;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '${AppEnvironment.appName} • Little steps, better days',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    builder: (context, child) =>
        WebExperienceGate(child: child ?? const SizedBox.shrink()),
    routes: {'/moderator': (_) => ModeratorPage(controller: controller)},
    home: AnimatedBuilder(
      animation: controller,
      builder: (_, __) => controller.profile == null
          ? OnboardingPage(controller: controller)
          : AppShell(controller: controller),
    ),
  );
}
