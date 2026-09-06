import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:youwell/app/app_shell.dart';
import 'package:youwell/application/app_auth_controller.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/config/app_environment.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/theme/app_theme.dart';
import 'package:youwell/features/auth/presentation/sign_in_page.dart';
import 'package:youwell/features/onboarding/presentation/onboarding_page.dart';
import 'package:youwell/features/web/presentation/public_recap_page.dart';
import 'package:youwell/features/web/presentation/web_landing_page.dart';
import 'package:youwell/features/web/presentation/web_workspace_page.dart';

class YouWellApp extends StatelessWidget {
  const YouWellApp({super.key, required this.controller, required this.auth});

  final WellnessController controller;
  final AppAuthController auth;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '${AppEnvironment.appName} • Little steps, better days',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routes: {
          '/app': (_) => _AppEntry(controller: controller, auth: auth),
          '/recap': (_) => PublicRecapPage(controller: controller),
          '/admin': (_) => _AdminEntry(controller: controller, auth: auth),
          '/moderator': (_) => _AdminEntry(controller: controller, auth: auth),
        },
        home: _AppEntry(controller: controller, auth: auth),
      );
}

class _AppEntry extends StatelessWidget {
  const _AppEntry({required this.controller, required this.auth});

  final WellnessController controller;
  final AppAuthController auth;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([controller, auth]),
        builder: (context, _) {
          if (!auth.isReady) return const _LoadingPage();
          if (auth.isEnabled && !auth.isAuthenticated) {
            return kIsWeb
                ? WebLandingPage(onJoin: auth.signInWithGoogle)
                : SignInPage(auth: auth);
          }
          if (controller.profile == null) {
            return OnboardingPage(controller: controller);
          }
          return kIsWeb
              ? WebWorkspacePage(
                  controller: controller,
                  isAdmin: auth.isAdmin,
                  accountEmail: auth.email,
                  onSignOut: auth.signOut,
                )
              : AppShell(controller: controller);
        },
      );
}

class _AdminEntry extends StatelessWidget {
  const _AdminEntry({required this.controller, required this.auth});

  final WellnessController controller;
  final AppAuthController auth;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([controller, auth]),
        builder: (context, _) {
          if (!auth.isReady) return const _LoadingPage();
          if (!auth.isAuthenticated) {
            return _AppEntry(controller: controller, auth: auth);
          }
          if (!auth.isAdmin) return const _AdminAccessDenied();
          if (controller.profile == null) {
            return OnboardingPage(controller: controller);
          }
          return WebWorkspacePage(
            controller: controller,
            isAdmin: true,
            accountEmail: auth.email,
            onSignOut: auth.signOut,
          );
        },
      );
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: cream,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.spa_rounded, color: green, size: 38),
              SizedBox(height: 14),
              Text('Menyiapkan YouWell…', style: TextStyle(color: muted)),
            ],
          ),
        ),
      );
}

class _AdminAccessDenied extends StatelessWidget {
  const _AdminAccessDenied();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: cream,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      color: green, size: 42),
                  const SizedBox(height: 20),
                  const Text(
                    'Community Admin hanya untuk tim moderasi.',
                    style: TextStyle(
                      color: ink,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Akunmu tetap dapat menggunakan YouWell Web App, tetapi tidak memiliki izin meninjau konten komunitas.',
                    style: TextStyle(color: muted, height: 1.55),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/',
                      (route) => false,
                    ),
                    child: const Text('Kembali ke aplikasi'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
