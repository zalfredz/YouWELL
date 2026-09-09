import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:youwell/core/config/app_environment.dart';
import 'package:youwell/core/platform/platform.dart' as platform;
import 'package:youwell/core/theme/app_colors.dart';

/// Keeps product workspaces desktop-first while public web pages stay responsive.
class WebWorkspaceGate extends StatelessWidget {
  const WebWorkspaceGate({
    super.key,
    required this.child,
    required this.onReturnToLanding,
  });

  static const desktopBreakpoint = 860.0;
  final Widget child;
  final VoidCallback onReturnToLanding;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < desktopBreakpoint) {
          return _MobileWorkspacePrompt(onReturnToLanding: onReturnToLanding);
        }
        return WebDesktopFrame(child: child);
      },
    );
  }
}

/// Edge-to-edge desktop canvas for signed-in web workspaces and admin tools.
class WebDesktopFrame extends StatelessWidget {
  const WebDesktopFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xff0d0e11),
        child: SizedBox.expand(child: child),
      );
}

class _MobileWorkspacePrompt extends StatelessWidget {
  const _MobileWorkspacePrompt({required this.onReturnToLanding});

  final VoidCallback onReturnToLanding;

  @override
  Widget build(BuildContext context) {
    final isApple = defaultTargetPlatform == TargetPlatform.iOS;
    final storeName = isApple ? 'App Store' : 'Google Play';
    final storeUrl =
        isApple ? AppEnvironment.appStoreUrl : AppEnvironment.playStoreUrl;

    return Scaffold(
      backgroundColor: const Color(0xffeef2e9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.spa_rounded, color: green),
                      SizedBox(width: 8),
                      Text(
                        'youwell.',
                        style: TextStyle(
                          color: ink,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 56),
                  Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.phone_iphone_rounded,
                      size: 38,
                      color: green,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Workspace ini dibuat untuk layar besar.',
                    style: TextStyle(
                      color: ink,
                      fontSize: 36,
                      height: 1.1,
                      letterSpacing: -1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Gunakan aplikasi YouWell untuk check-in saat bepergian. Landing page dan recap publik tetap dapat dibuka di browser ini.',
                    style: TextStyle(color: muted, fontSize: 16, height: 1.55),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: storeUrl.isEmpty
                          ? null
                          : () => platform.openLink(storeUrl),
                      icon: Icon(isApple ? Icons.apple : Icons.shop_rounded),
                      label: Text(
                        storeUrl.isEmpty
                            ? 'Aplikasi mobile segera hadir'
                            : 'Download di $storeName',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: onReturnToLanding,
                    child: const Text('Kembali ke landing page'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
