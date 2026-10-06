import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/reduction/presentation/delay_craving_panel.dart';

void openReductionSupport(BuildContext context, WellnessController controller) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ReductionSupportPage(controller: controller),
    ),
  );
}

/// A visible entry into the existing delay timer, independent of today's card.
class ReductionSupportPage extends StatelessWidget {
  const ReductionSupportPage({super.key, required this.controller});
  final WellnessController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Delay Craving & Habit Swap')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: DelayCravingPanel(controller: controller),
        ),
      ),
    ),
  );
}

class ReductionEntryCard extends StatelessWidget {
  const ReductionEntryCard({super.key, required this.controller});
  final WellnessController controller;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: context.colors.selected,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: context.colors.accent.withValues(alpha: .35)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.smoke_free_rounded, color: context.colors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                controller.reductionLabel,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${controller.totalDelayMinutes} menit sudah kamu tunda',
          style: TextStyle(
            color: context.colors.accent,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Jalur aktif. Saat keinginan muncul, mulai Delay Craving '
          '${controller.delayTargetMinutes} menit, lalu pilih Habit Swap.',
          style: TextStyle(color: context.colors.muted, height: 1.5),
        ),
        const SizedBox(height: 8),
        Text(
          '${controller.delayedToday} Delay Craving & '
          '${controller.habitSwapsToday} Habit Swap hari ini',
          style: TextStyle(
            color: context.colors.accent,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () => openReductionSupport(context, controller),
          icon: const Icon(Icons.air_rounded),
          label: const Text('Buka Delay Craving & Habit Swap'),
        ),
      ],
    ),
  );
}
