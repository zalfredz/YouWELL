import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/activity/presentation/meal_snap_page.dart';
import 'package:youwell/features/activity/presentation/workout_page.dart';

class ActivityPage extends StatelessWidget {
  const ActivityPage({
    super.key,
    required this.controller,
    required this.onOpenReset,
  });
  final WellnessController controller;
  final VoidCallback onOpenReset;

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final workouts = controller.workoutSessions;
    final meals = controller.mealCheckIns;
    final todayWorkouts = workouts
        .where((row) => row['day'] == controller.today)
        .toList();
    final todayMeals = meals
        .where((row) => row['day'] == controller.today)
        .length;
    final activeMinutes =
        todayWorkouts.fold<int>(
          0,
          (sum, row) => sum + ((row['seconds'] as num?)?.toInt() ?? 0),
        ) ~/
        60;
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 42),
      children: [
        const Text(
          'Aktivitas',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        const Text(
          'Gerak, makan, dan jeda kecilmu.',
          style: TextStyle(color: appMuted),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: _TodayMetric(
                icon: Icons.directions_walk_rounded,
                value: '$activeMinutes m',
                label: 'gerak hari ini',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TodayMetric(
                icon: Icons.photo_camera_outlined,
                value: '$todayMeals',
                label: 'meal snap',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ActivityAction(
          icon: Icons.directions_run_rounded,
          title: 'Jalan atau lari',
          detail: 'Catat waktu dan jarak saat aktif.',
          onTap: () => _open(context, WorkoutPage(controller: controller)),
        ),
        _ActivityAction(
          icon: Icons.photo_camera_outlined,
          title: 'Meal Snap',
          detail: 'Simpan foto makan secara privat.',
          onTap: () => _open(context, MealSnapPage(controller: controller)),
        ),
        _ActivityAction(
          icon: Icons.self_improvement_rounded,
          title: 'Ambil jeda',
          detail: 'Napas singkat, fokus, atau tunda kebiasaan.',
          onTap: onOpenReset,
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: appSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: appBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hidrasi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                '${controller.water.toInt()} / ${controller.profile?['waterGoal'] ?? 2000} ml',
                style: const TextStyle(color: appMuted),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value:
                    (controller.water /
                            ((controller.profile?['waterGoal'] as num?) ??
                                2000))
                        .clamp(0, 1),
                minHeight: 8,
                borderRadius: BorderRadius.circular(99),
                color: appAccent,
                backgroundColor: appRaised,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: controller.addWater,
                icon: const Icon(Icons.water_drop_outlined),
                label: const Text('+250 ml'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Terakhir dicatat',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (workouts.isEmpty && meals.isEmpty)
          const Text(
            'Belum ada. Mulai dari satu aktivitas kecil.',
            style: TextStyle(color: appMuted),
          )
        else ...[
          for (final row in workouts.reversed.take(3))
            _HistoryRow(
              icon: row['kind'] == 'run'
                  ? Icons.directions_run
                  : Icons.directions_walk,
              title: row['kind'] == 'run' ? 'Lari' : 'Jalan',
              detail:
                  '${((row['seconds'] as num?)?.toInt() ?? 0) ~/ 60} menit • ${((row['meters'] as num?)?.toInt() ?? 0)} m',
            ),
          for (final row in meals.reversed.take(2))
            _HistoryRow(
              icon: Icons.photo_camera_outlined,
              title: 'Meal Snap',
              detail: row['day'].toString(),
            ),
        ],
      ],
    );
  }
}

class _TodayMetric extends StatelessWidget {
  const _TodayMetric({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value, label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: appRaised,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: appAccent),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
        ),
        Text(label, style: const TextStyle(color: appMuted)),
      ],
    ),
  );
}

class _ActivityAction extends StatelessWidget {
  const _ActivityAction({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });
  final IconData icon;
  final String title, detail;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    color: appSurface,
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      leading: CircleAvatar(
        backgroundColor: appRaised,
        child: Icon(icon, color: appAccent),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(detail, style: const TextStyle(color: appMuted)),
      trailing: const Icon(Icons.chevron_right_rounded, color: appMuted),
      onTap: onTap,
    ),
  );
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title, detail;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: appAccent),
    title: Text(title),
    subtitle: Text(detail, style: const TextStyle(color: appMuted)),
  );
}
