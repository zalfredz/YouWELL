import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/checkin/presentation/energy_checkin_sheet.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';
import 'package:youwell/shared/widgets/wellness_companion.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.onOpenDraw,
  });

  final WellnessController controller;
  final VoidCallback onOpenDraw;

  @override
  Widget build(BuildContext context) {
    final done = controller.completedCards.length;
    final companion = controller.profile!['companion'].toString();
    final name =
        const {'plant': 'Mori', 'cat': 'Milo', 'cloud': 'Awan'}[companion] ??
        'Mori';
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 42),
      children: [
        Text(
          'Hai, ${controller.profile!['alias']}',
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        const Text(
          'Satu langkah kecil untuk hari yang lebih baik.',
          style: TextStyle(color: appMuted),
        ),
        const SizedBox(height: 20),
        _CompanionStage(
          kind: companion,
          name: name,
          level: controller.level,
          xp: controller.xp,
          activeDays: controller.activeDaysIn(7),
          progress: (controller.xp % 100) / 100,
          completedToday: done,
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Langkah hari ini',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ),
            tag('$done / ${controller.quests.length}'),
          ],
        ),
        const SizedBox(height: 12),
        ...controller.quests.map(
          (task) => _TaskTile(
            task: task,
            onComplete: () => controller.completeCard(task['id'].toString()),
          ),
        ),
        if (controller.needsDailyCardDraw) ...[
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: onOpenDraw,
            icon: const Icon(Icons.auto_awesome_rounded, color: appAccent),
            label: const Text('Ambil bonus card'),
          ),
        ],
        const SizedBox(height: 18),
        _QuickCheckIn(controller: controller),
      ],
    );
  }
}

class _CompanionStage extends StatelessWidget {
  const _CompanionStage({
    required this.kind,
    required this.name,
    required this.level,
    required this.xp,
    required this.activeDays,
    required this.progress,
    required this.completedToday,
  });

  final String kind, name;
  final int level, xp, activeDays, completedToday;
  final double progress;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
    decoration: BoxDecoration(
      gradient: const RadialGradient(
        center: Alignment(0, -.15),
        radius: .9,
        colors: [Color(0xff23493c), Color(0xff14221e), appSurface],
      ),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: const Color(0xff315043)),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            tag('LV $level'),
          ],
        ),
        WellnessCompanion(kind: kind, level: level, size: 286),
        Text(
          completedToday >= 3 ? 'Hari ini keren!' : 'Kita jalan pelan-pelan.',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _Metric(value: '$xp XP', label: 'total progress'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Metric(value: '$activeDays / 7', label: 'hari aktif'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 7,
            value: progress,
            backgroundColor: appCanvas,
            color: appAccent,
          ),
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: appCanvas.withValues(alpha: .5),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(color: appAccent, fontWeight: FontWeight.w800),
        ),
        Text(label, style: const TextStyle(color: appMuted, fontSize: 11)),
      ],
    ),
  );
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.onComplete});
  final Map<String, dynamic> task;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final done = task['status'] == 'completed';
    final bonus = task['source'] == 'bonus';
    final icon = switch (task['category']) {
      'Body' => Icons.directions_walk_rounded,
      'Energy' => Icons.bolt_rounded,
      'Reduction' => Icons.air_rounded,
      _ => Icons.auto_awesome_rounded,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: appRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: done ? const Color(0xff315043) : appBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: appSurface,
            child: Icon(icon, color: bonus ? appAccentAmber : appAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['title'].toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  '${task['durationMinutes']} min  •  +${task['xp']} XP${bonus ? '  •  Bonus' : ''}',
                  style: const TextStyle(color: appMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: done ? 'Selesai' : 'Tandai selesai',
            onPressed: done ? null : onComplete,
            icon: Icon(
              done ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: appAccent,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCheckIn extends StatelessWidget {
  const _QuickCheckIn({required this.controller});
  final WellnessController controller;
  @override
  Widget build(BuildContext context) {
    final checked = controller.energyCheckIns.any(
      (row) => row['day'] == controller.today,
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: appSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: appBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.battery_charging_full_rounded, color: appAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              checked
                  ? 'Energi hari ini sudah dicatat.'
                  : 'Energi kamu sekarang?',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: checked
                ? null
                : () => sheet(
                    context,
                    EnergyCheckInSheet(controller: controller),
                  ),
            child: Text(checked ? 'Selesai' : 'Check-in'),
          ),
        ],
      ),
    );
  }
}
