import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/activity/presentation/activity_history_page.dart';
import 'package:youwell/features/activity/presentation/meal_snap_page.dart';
import 'package:youwell/features/activity/presentation/workout_page.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key, required this.controller});
  final WellnessController controller;

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final todayWorkouts = controller.workoutSessions
        .where((row) => row['day'] == controller.today)
        .toList();
    final todayMeals = controller.mealCheckIns
        .where((row) => row['day'] == controller.today)
        .length;
    final activeMinutes =
        todayWorkouts.fold<int>(
          0,
          (sum, row) => sum + ((row['seconds'] as num?)?.toInt() ?? 0),
        ) ~/
        60;
    // Quests this tab can finish: they hold XP waiting for an activity.
    final waiting = controller.quests
        .where(
          (task) =>
              task['status'] != 'completed' &&
              const {
                'walk',
                'run',
                'water',
                'meal_snap',
              }.contains(task['activityKind']),
        )
        .toList();
    final waitingXp = waiting.fold<int>(
      0,
      (sum, task) => sum + ((task['xp'] as num?)?.toInt() ?? 0),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Text(
          'Aktivitas',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        Text('Gerak, makan, dan hidrasi.', style: TextStyle(color: c.muted)),
        const SizedBox(height: 16),
        if (waiting.isNotEmpty) ...[
          SectionTitle(
            'XP menunggu di sini',
            icon: Icons.bolt_rounded,
            trailing: XpPill(waitingXp),
          ),
          for (final task in waiting)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _WaitingQuest(
                task: task,
                onTap: () => switch (task['activityKind']) {
                  'water' => controller.addWater(),
                  'meal_snap' => _open(
                    context,
                    MealSnapPage(controller: controller),
                  ),
                  _ => _open(context, WorkoutPage(controller: controller)),
                },
              ),
            ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: _TodayMetric(
                icon: Icons.directions_walk_rounded,
                color: c.body,
                value: '$activeMinutes mnt',
                label: 'gerak hari ini',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TodayMetric(
                icon: Icons.restaurant_rounded,
                color: c.reduction,
                value: '$todayMeals',
                label: 'Meal Snap',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _HydrationCard(controller: controller),
        const SizedBox(height: 14),
        _ActivityAction(
          icon: Icons.directions_run_rounded,
          color: c.body,
          title: 'Jalan atau lari',
          detail: 'GPS hitung jarak. Rute tidak disimpan.',
          onTap: () => _open(context, WorkoutPage(controller: controller)),
        ),
        const SizedBox(height: 10),
        _ActivityAction(
          icon: Icons.photo_camera_rounded,
          color: c.reduction,
          title: 'Meal Snap',
          detail: 'Foto makan tetap di HP-mu.',
          onTap: () => _open(context, MealSnapPage(controller: controller)),
        ),
        const SizedBox(height: 10),
        _ActivityAction(
          icon: Icons.history_rounded,
          color: c.accent,
          title: 'Riwayat aktivitas',
          detail:
              '${controller.workoutSessions.length} sesi gerak · '
              '${controller.mealCheckIns.length} Meal Snap',
          onTap: () =>
              _open(context, ActivityHistoryPage(controller: controller)),
        ),
      ],
    );
  }
}

class _WaitingQuest extends StatelessWidget {
  const _WaitingQuest({required this.task, required this.onTap});
  final Map<String, dynamic> task;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = c.category(task['category']);
    final partial = (task['partial'] as num?)?.toDouble();
    return GameCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(questIcon(task), color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['title'].toString(),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  partial == null
                      ? task['activityKind'] == 'water'
                            ? 'Ketuk untuk tambah 250 ml'
                            : 'Ketuk untuk mulai'
                      : '${(partial * 100).round()}% tercapai',
                  style: TextStyle(
                    color: partial == null ? c.muted : c.amber,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          XpPill((task['xp'] as num?)?.toInt() ?? 0),
        ],
      ),
    );
  }
}

class _HydrationCard extends StatelessWidget {
  const _HydrationCard({required this.controller});
  final WellnessController controller;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final goal = ((controller.profile?['waterGoal'] as num?) ?? 2000).toInt();
    final water = controller.water.toInt();
    final quest = controller.quests
        .where((task) => task['activityKind'] == 'water')
        .firstOrNull;
    return GameCard(
      child: Row(
        children: [
          RingProgress(
            value: water / goal,
            size: 92,
            stroke: 10,
            color: c.lifestyle,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.water_drop_rounded, color: c.lifestyle, size: 22),
                Text(
                  '${(water / goal * 100).clamp(0, 100).round()}%',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hidrasi', style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '$water / $goal ml',
                  style: TextStyle(color: c.muted, fontWeight: FontWeight.w700),
                ),
                if (quest != null)
                  Text(
                    quest['status'] == 'completed'
                        ? 'Misi hidrasi selesai!'
                        : 'Misi: ${quest['waterMl'] ?? goal} ml',
                    style: TextStyle(
                      color: quest['status'] == 'completed'
                          ? c.success
                          : c.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: controller.addWater,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('250 ml'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayMetric extends StatelessWidget {
  const _TodayMetric({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String value, label;
  @override
  Widget build(BuildContext context) => GameCard(
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: context.colors.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ActivityAction extends StatelessWidget {
  const _ActivityAction({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title, detail;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GameCard(
    onTap: onTap,
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                detail,
                style: TextStyle(color: context.colors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: context.colors.muted),
      ],
    ),
  );
}
