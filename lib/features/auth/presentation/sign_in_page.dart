import 'package:flutter/material.dart';
import 'package:youwell/application/app_auth_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';

/// Native sign-in entry. Web uses the public landing page as its entry point.
class SignInPage extends StatelessWidget {
  const SignInPage({super.key, required this.auth});
  final AppAuthController auth;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xffeef2e9),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                    gap(54),
                    const Text(
                      'Satu akun untuk\nsetiap langkah kecil.',
                      style: TextStyle(
                        color: ink,
                        fontSize: 42,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    gap(14),
                    const Text(
                      'Masuk untuk menyimpan perjalananmu dan melanjutkannya dari mobile maupun web.',
                      style:
                          TextStyle(color: muted, fontSize: 16, height: 1.55),
                    ),
                    gap(28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          try {
                            await auth.signInWithGoogle();
                          } on Object {
                            if (context.mounted) {
                              toast(
                                  context, 'Google Login belum dapat dibuka.');
                            }
                          }
                        },
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Lanjutkan dengan Google'),
                      ),
                    ),
                    if (auth.error != null) ...[
                      gap(14),
                      Text(auth.error!,
                          style: const TextStyle(color: Colors.red)),
                    ],
                    gap(22),
                    caption(
                      'Data hanya dapat diakses oleh akunmu sesuai pengaturan privasi YouWell.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
