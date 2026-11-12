import 'package:flutter/material.dart';
import 'package:youwell/app/app_shell.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/config/app_environment.dart';
import 'package:youwell/core/config/app_mode.dart';
import 'package:youwell/core/theme/app_theme.dart';
import 'package:youwell/core/theme/appearance_scope.dart';
import 'package:youwell/features/onboarding/presentation/onboarding_page.dart';
import 'package:youwell/features/community/presentation/admin_shell.dart';
import 'package:youwell/features/community/presentation/admin_overview_page.dart';

/// One codebase with separate moderator web and phone app entry points.
class YouWellApp extends StatefulWidget {
  const YouWellApp({super.key, required this.controller, this.surface});

  final WellnessController controller;
  final AppSurface? surface;
  @override
  State<YouWellApp> createState() => _YouWellAppState();
}

class _YouWellAppState extends State<YouWellApp> {
  WellnessController get controller => widget.controller;
  late String _themePreference;
  @override
  void initState() {
    super.initState();
    _themePreference = controller.themePreference;
    controller.addListener(_themeChanged);
  }

  // Quest and activity changes rebuild their screen, not the whole navigator.
  void _themeChanged() {
    if (_themePreference != controller.themePreference) {
      setState(() => _themePreference = controller.themePreference);
    }
  }

  @override
  void didUpdateWidget(YouWellApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != controller) {
      oldWidget.controller.removeListener(_themeChanged);
      controller.addListener(_themeChanged);
      _themePreference = controller.themePreference;
    }
  }

  @override
  void dispose() {
    controller.removeListener(_themeChanged);
    super.dispose();
  }

  AppSurface get _surface => widget.surface ?? appSurface;
  bool get _mobilePreview => _surface == AppSurface.mobilePreview;
  bool get _admin => _surface == AppSurface.admin;
  Widget get _entry => _admin
      ? AdminShell(controller: controller)
      : _LocalAppEntry(controller: controller);

  @override
  Widget build(BuildContext context) {
    final app = AppearanceScope(controller: controller, child: _buildApp());
    if (!_mobilePreview) return app;

    // Keep the navigator and its dialogs inside a portrait phone viewport.
    const screenSize = Size(393, 852);
    return ColoredBox(
      color: const Color(0xff25262b),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FittedBox(
            fit: BoxFit.contain,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: SizedBox(
                width: screenSize.width,
                height: screenSize.height,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: screenSize,
                    padding: const EdgeInsets.only(top: 47, bottom: 34),
                    viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
                    viewInsets: EdgeInsets.zero,
                  ),
                  child: app,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApp() => MaterialApp(
    // Short browser tab title, the same name as index.html and the manifest.
    title: _admin ? '${AppEnvironment.appName} Admin' : AppEnvironment.appName,
    debugShowCheckedModeBanner: false,
    theme: _admin
        ? AppTheme.light
        : _mobilePreview
        ? AppTheme.mobileLight.copyWith(platform: TargetPlatform.iOS)
        : AppTheme.mobileLight,
    darkTheme: _admin
        ? AppTheme.dark
        : _mobilePreview
        ? AppTheme.mobileDark.copyWith(platform: TargetPlatform.iOS)
        : AppTheme.mobileDark,
    themeMode: switch (controller.themePreference) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    },
    routes: _routes,
    // One page for the opening URL, matched on its path only, so the Google
    // login return ("/?code=…") or an unknown path opens the app without a
    // stacked back button.
    onGenerateInitialRoutes: (name) => [
      MaterialPageRoute<void>(
        settings: RouteSettings(name: name),
        builder: _routes[Uri.parse(name).path] ?? (_) => _entry,
      ),
    ],
  );

  Map<String, WidgetBuilder> get _routes => {
    '/': (_) => _entry,
    '/app': (_) => _entry,
    '/admin': (_) => _admin ? _entry : const _AdminUnavailablePage(),
    '/overview': (_) => _admin
        ? Scaffold(
            appBar: AppBar(title: const Text('YouWELL Admin')),
            body: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: const AdminOverviewPage(),
              ),
            ),
          )
        : const _AdminUnavailablePage(),
  };
}

class _AdminUnavailablePage extends StatelessWidget {
  const _AdminUnavailablePage();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('YouWELL')),
    body: const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Moderasi tersedia melalui web admin.',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

class _LocalAppEntry extends StatelessWidget {
  const _LocalAppEntry({required this.controller});

  final WellnessController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      if (controller.profile == null) {
        return OnboardingPage(controller: controller);
      }
      return AppShell(controller: controller);
    },
  );
}
