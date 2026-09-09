import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:youwell/app/app_shell.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/config/app_environment.dart';
import 'package:youwell/core/theme/app_theme.dart';
import 'package:youwell/features/onboarding/presentation/onboarding_page.dart';
import 'package:youwell/features/web/presentation/public_recap_page.dart';
import 'package:youwell/features/web/presentation/web_landing_page.dart';
import 'package:youwell/features/web/presentation/web_workspace_page.dart';

/// Local-first application root for the current web design phase.
class YouWellApp extends StatelessWidget {
  const YouWellApp({super.key, required this.controller});

  final WellnessController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '${AppEnvironment.appName} • Little steps, better days',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routes: {
          '/app': (_) => _LocalAppEntry(controller: controller),
          '/recap': (_) => PublicRecapPage(controller: controller),
          '/admin': (_) =>
              _LocalAppEntry(controller: controller, isAdmin: true),
          '/moderator': (_) =>
              _LocalAppEntry(controller: controller, isAdmin: true),
        },
        home: kIsWeb
            ? _WebLandingEntry(controller: controller)
            : _LocalAppEntry(controller: controller),
      );
}

class _WebLandingEntry extends StatelessWidget {
  const _WebLandingEntry({required this.controller});

  final WellnessController controller;

  @override
  Widget build(BuildContext context) => WebLandingPage(
        onJoin: () async => Navigator.pushNamed(context, '/app'),
      );
}

class _LocalAppEntry extends StatelessWidget {
  const _LocalAppEntry({required this.controller, this.isAdmin = false});

  final WellnessController controller;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.profile == null) {
            return OnboardingPage(controller: controller);
          }
          return kIsWeb
              ? WebWorkspacePage(controller: controller, isAdmin: isAdmin)
              : AppShell(controller: controller);
        },
      );
}
