import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';
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

  /// Delay milestones that unlock personal badges (see achievementNames).
  static const _milestones = [30, 60, 300];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = controller.totalDelayMinutes;
    final goal = _milestones.firstWhere(
      (minutes) => minutes > total,
      orElse: () => total,
    );
    final previous = _milestones.lastWhere(
      (minutes) => minutes <= total,
      orElse: () => 0,
    );
    final progress = goal == previous
        ? 1.0
        : (total - previous) / (goal - previous);
    return GameCard(
      borderColor: c.reduction.withValues(alpha: .45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.reduction.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.smoke_free_rounded, color: c.reduction),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  controller.reductionLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$total',
                style: const TextStyle(
                  fontSize: 34,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    'menit sudah kamu tunda',
                    style: TextStyle(
                      color: c.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          XpBar(value: progress, height: 10),
          const SizedBox(height: 6),
          Text(
            goal > total
                ? '${goal - total} menit lagi ke lencana "${_badgeName(goal)}"'
                : 'Semua lencana jeda sudah terbuka',
            style: TextStyle(
              fontSize: 12.5,
              color: c.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${controller.delayedToday} Delay Craving & '
            '${controller.habitSwapsToday} Habit Swap hari ini',
            style: TextStyle(color: c.text, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => openReductionSupport(context, controller),
              icon: const Icon(Icons.timer_outlined),
              label: const Text('Buka Delay Craving & Habit Swap'),
            ),
          ),
        ],
      ),
    );
  }

  static String _badgeName(int minutes) => switch (minutes) {
    30 => '30 menit ditunda',
    60 => '1 jam ditunda',
    _ => '5 jam ditunda',
  };
}
