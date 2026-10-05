import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';

/// Public-safe recap shell. Server-issued share tokens replace this demo route.
class PublicRecapPage extends StatelessWidget {
  const PublicRecapPage({super.key, required this.controller});
  final WellnessController controller;

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile;
    final alias = profile?['alias']?.toString() ?? 'daunpagi';
    final compliance = profile == null
        ? 74
        : (controller.compliance(7) * 100).round();
    final activeDays = profile == null ? 4 : controller.activeDaysIn(7);
    final level = profile == null ? 3 : controller.level;
    return Scaffold(
      backgroundColor: context.colors.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.spa_rounded, color: context.colors.accent),
                      const SizedBox(width: 8),
                      Text(
                        'youwell',
                        style: TextStyle(
                          color: context.colors.text,
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/',
                          (route) => false,
                        ),
                        child: const Text('Kembali ke YouWell'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 60),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(34),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          context.colors.selected,
                          context.colors.raised,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WEEKLY WRAPPED',
                          style: TextStyle(
                            color: context.colors.accent,
                            letterSpacing: 1.2,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '$alias memilih\ntetap bertumbuh.',
                          style: TextStyle(
                            color: context.colors.text,
                            fontSize: 45,
                            height: 1.04,
                            letterSpacing: -1.8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'Ringkasan ini dibagikan secara sukarela. Catatan pribadi dan detail sensitif tidak ditampilkan.',
                          style: TextStyle(
                            color: context.colors.text,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 30),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 560;
                            final cards = [
                              _RecapStat(
                                value: '$compliance%',
                                label: 'compliance',
                              ),
                              _RecapStat(
                                value: '$activeDays',
                                label: 'hari aktif',
                              ),
                              _RecapStat(
                                value: 'Lv $level',
                                label: 'companion',
                              ),
                            ];
                            return compact
                                ? Column(children: cards)
                                : Row(
                                    children: cards
                                        .map((card) => Expanded(child: card))
                                        .toList(),
                                  );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Minggu ini',
                    style: TextStyle(
                      color: context.colors.text,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Setiap langkah kecil membantu membangun ritme yang lebih baik.',
                    style: TextStyle(
                      color: context.colors.muted,
                      fontSize: 16,
                      height: 1.65,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Yang dirayakan',
                          style: TextStyle(
                            color: context.colors.text,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                        SizedBox(height: 16),
                        _RecapLine(
                          icon: Icons.air_rounded,
                          text:
                              'Memberi diri sendiri waktu untuk mengambil jeda.',
                        ),
                        _RecapLine(
                          icon: Icons.check_circle_outline_rounded,
                          text:
                              'Kembali ke kebiasaan kecil dengan ritme sendiri.',
                        ),
                        _RecapLine(
                          icon: Icons.favorite_outline_rounded,
                          text: 'Menjaga energi lewat langkah yang realistis.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Perjalananmu boleh punya ritmenya sendiri.',
                          style: TextStyle(
                            color: context.colors.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/',
                            (route) => false,
                          ),
                          icon: const Icon(Icons.spa_rounded),
                          label: const Text('Kenal YouWell'),
                        ),
                      ],
                    ),
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

class _RecapStat extends StatelessWidget {
  const _RecapStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8, bottom: 8),
    child: Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: context.colors.text,
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(color: context.colors.muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _RecapLine extends StatelessWidget {
  const _RecapLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: context.colors.accent, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: context.colors.text, height: 1.45),
          ),
        ),
      ],
    ),
  );
}
