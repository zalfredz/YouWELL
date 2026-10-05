import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/shared/widgets/wellness_companion.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key, required this.controller});
  final WellnessController controller;

  @override
  Widget build(BuildContext context) {
    final rate = controller.compliance(7);
    final energy = controller.energyCheckIns.reversed.take(7).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 42),
      children: [
        const Text(
          'Perjalanan',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          'Semua langkah kecil tetap dihitung.',
          style: TextStyle(color: context.colors.muted),
        ),
        const SizedBox(height: 22),
        _Panel(
          title: 'Companion-mu tumbuh',
          child: Column(
            children: [
              WellnessCompanion(
                kind: controller.profile?['companion']?.toString() ?? 'plant',
                level: controller.level,
                size: 180,
              ),
              const SizedBox(height: 6),
              Text(
                'Level ${controller.level} • ${controller.xp % 100} / 100 XP ke level berikutnya',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.muted),
              ),
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: (controller.xp % 100) / 100,
                minHeight: 8,
                borderRadius: BorderRadius.circular(99),
                color: context.colors.accent,
                backgroundColor: context.colors.raised,
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _Stat(value: '${controller.level}', label: 'Level'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Stat(value: '${controller.xp}', label: 'Total XP'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Stat(
                value: '${controller.activeDaysIn(7)}/7',
                label: 'Hari aktif',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _Panel(
          title: 'Minggu ini',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${(rate * 100).round()}%',
                style: TextStyle(
                  fontSize: 42,
                  color: context.colors.accent,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'langkah selesai',
                style: TextStyle(color: context.colors.muted),
              ),
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: rate,
                minHeight: 8,
                borderRadius: BorderRadius.circular(99),
                backgroundColor: context.colors.raised,
                color: context.colors.accent,
              ),
            ],
          ),
        ),
        _Panel(
          title: 'Energi terbaru',
          child: energy.isEmpty
              ? Text(
                  'Belum ada check-in. Mulai dari Home.',
                  style: TextStyle(color: context.colors.muted),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: energy
                      .map(
                        (row) => Chip(
                          label: Text(_energyLabel(row['energy'].toString())),
                        ),
                      )
                      .toList(),
                ),
        ),
        _Panel(
          title: 'Waktu fokus',
          child: Row(
            children: [
              Icon(Icons.timer_outlined, color: context.colors.cyan, size: 34),
              const SizedBox(width: 14),
              Text(
                '${controller.focusMinutesToday} menit',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text('hari ini', style: TextStyle(color: context.colors.muted)),
            ],
          ),
        ),
        _Panel(
          title: 'Jejak aktivitas',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${controller.workoutSessions.length} sesi jalan/lari'),
              const SizedBox(height: 6),
              Text('${controller.mealCheckIns.length} meal snap'),
              const SizedBox(height: 6),
              Text(
                '${controller.completedCards.length} quest selesai hari ini',
              ),
            ],
          ),
        ),
        if (controller.reduction)
          _Panel(
            title: 'Jeda rokok / vape',
            child: Row(
              children: [
                Icon(Icons.air_rounded, color: context.colors.accent, size: 34),
                const SizedBox(width: 14),
                Text(
                  '${controller.delayedToday} kali jeda',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text('hari ini', style: TextStyle(color: context.colors.muted)),
              ],
            ),
          ),
      ],
    );
  }

  String _energyLabel(String value) =>
      const {
        'low': 'Low',
        'steady': 'Santai',
        'good': 'Good',
        'charged': 'Charged',
      }[value] ??
      value;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.colors.raised,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            color: context.colors.accent,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.muted, fontSize: 11),
        ),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 14),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: context.colors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}
