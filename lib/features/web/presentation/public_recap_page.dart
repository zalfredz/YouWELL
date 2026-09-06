import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';

/// Public-safe recap preview. Server-issued share tokens replace this demo route.
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
    final streak = profile == null ? 6 : controller.streak;
    final level = profile == null ? 3 : controller.level;
    return Scaffold(
      backgroundColor: const Color(0xffeef2e9),
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
                      const Icon(Icons.spa_rounded, color: green),
                      const SizedBox(width: 8),
                      const Text(
                        'youwell.',
                        style: TextStyle(
                          color: ink,
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
                      gradient: const LinearGradient(
                        colors: [Color(0xff1d4438), Color(0xff42745b)],
                      ),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'WEEKLY WRAPPED',
                          style: TextStyle(
                            color: Color(0xffc6e0ba),
                            letterSpacing: 1.2,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '$alias memilih\ntetap bertumbuh.',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 45,
                            height: 1.04,
                            letterSpacing: -1.8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          'Ringkasan ini dibagikan secara sukarela. Catatan pribadi dan detail sensitif tidak ditampilkan.',
                          style: TextStyle(
                            color: Color(0xffd9e8d8),
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
                                value: '$streak',
                                label: 'hari beruntun',
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
                  const Text(
                    'Minggu ini',
                    style: TextStyle(
                      color: ink,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Ada hari yang produktif, ada pula hari yang hanya cukup untuk bernapas. Keduanya tetap bagian dari perjalanan.',
                    style: TextStyle(color: muted, fontSize: 16, height: 1.65),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Yang dirayakan',
                          style: TextStyle(
                            color: ink,
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
                              'Kembali ke kebiasaan kecil setelah hari yang berat.',
                        ),
                        _RecapLine(
                          icon: Icons.favorite_outline_rounded,
                          text: 'Menerima dukungan dari komunitas dengan aman.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          'Perjalananmu boleh punya ritmenya sendiri.',
                          style: TextStyle(
                            color: ink,
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
        color: const Color(0x22ffffff),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(color: Color(0xffd8e8d8), fontSize: 12),
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
        Icon(icon, color: green, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(color: ink, height: 1.45)),
        ),
      ],
    ),
  );
}
