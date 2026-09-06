import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:youwell/core/config/app_environment.dart';
import 'package:youwell/core/platform/platform.dart' as platform;
import 'package:youwell/core/theme/app_colors.dart';

/// Gives the website a desktop-only workspace while native apps stay full-screen.
class WebExperienceGate extends StatelessWidget {
  const WebExperienceGate({super.key, required this.child});

  static const desktopBreakpoint = 1080.0;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < desktopBreakpoint) {
          return const _MobileDownloadPage();
        }

        return _DesktopFrame(
          availableSize: Size(constraints.maxWidth, constraints.maxHeight),
          child: child,
        );
      },
    );
  }
}

class _DesktopFrame extends StatelessWidget {
  const _DesktopFrame({required this.availableSize, required this.child});

  final Size availableSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const margin = 24.0;
    final availableWidth = math.max(0.0, availableSize.width - margin * 2);
    final availableHeight = math.max(0.0, availableSize.height - margin * 2);
    final width = math.min(
      1600.0,
      math.min(availableWidth, availableHeight * 16 / 9),
    );
    final height = width * 9 / 16;

    return ColoredBox(
      color: const Color(0xffdfe5dc),
      child: Center(
        child: SizedBox(
          width: width,
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cream,
                boxShadow: [
                  BoxShadow(
                    color: ink.withValues(alpha: .12),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileDownloadPage extends StatelessWidget {
  const _MobileDownloadPage();

  @override
  Widget build(BuildContext context) {
    final isApple = defaultTargetPlatform == TargetPlatform.iOS;
    final storeName = isApple ? 'App Store' : 'Google Play';
    final storeUrl =
        isApple ? AppEnvironment.appStoreUrl : AppEnvironment.playStoreUrl;
    final available = storeUrl.isNotEmpty;

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
                    'YouWell lebih nyaman di aplikasi.',
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
                    'Versi mobile dirancang khusus untuk check-in, misi harian, dan teman tumbuh yang selalu ikut bersamamu.',
                    style: TextStyle(color: muted, fontSize: 16, height: 1.55),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          available ? () => platform.openLink(storeUrl) : null,
                      icon: Icon(isApple ? Icons.apple : Icons.shop_rounded),
                      label: Text(
                        available
                            ? 'Download di $storeName'
                            : 'Aplikasi mobile segera hadir',
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Website YouWell tersedia untuk layar desktop.',
                    style: TextStyle(color: muted, fontSize: 12),
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
