import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/utils/date_key.dart';
import 'package:youwell/features/mood/presentation/mood_check_in_sheet.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';
import 'package:youwell/shared/widgets/wellness_companion.dart';

/// Mobile Home puts the companion before dashboards or copy. Daily Draw lives
/// in its own popup ritual, so this screen stays focused on the user and Mori.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.controller, required this.onStats});

  final WellnessController controller;
  final VoidCallback onStats;

  @override
  Widget build(BuildContext context) {
    final done = controller.quests
        .where((quest) => quest['done'] == true)
        .length;
    final frozen =
        controller.frozenDays.contains(
          dayKey(controller.now.subtract(const Duration(days: 1))),
        ) &&
        !controller.completedDays.contains(controller.today);
    final companion = controller.profile!['companion'].toString();
    final companionName = {
      'plant': 'Mori',
      'cat': 'Milo',
      'cloud': 'Awan',
    }[companion]!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 110),
      children: [
        title('Hai, ${controller.profile!['alias']}', size: 34),
        gap(18),
        LayoutBuilder(
          builder: (context, bounds) {
            final mobile = bounds.maxWidth <= 740;
            final companionHero = _CompanionHero(
              name: companionName,
              kind: companion,
              level: controller.level,
              xp: controller.xp,
              streak: controller.streak,
              frozen: frozen,
              isMobile: mobile,
              allTasksComplete: done == controller.quests.length && done > 0,
            );
            final dailyContent = _DailyContent(
              controller: controller,
              done: done,
            );
            final extras = _DesktopExtras(
              controller: controller,
              onStats: onStats,
            );

            if (mobile) {
              return Column(children: [companionHero, dailyContent]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: dailyContent),
                const SizedBox(width: 24),
                Expanded(
                  flex: 3,
                  child: Column(children: [companionHero, extras]),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CompanionHero extends StatelessWidget {
  const _CompanionHero({
    required this.name,
    required this.kind,
    required this.level,
    required this.xp,
    required this.streak,
    required this.frozen,
    required this.isMobile,
    required this.allTasksComplete,
  });

  final String name;
  final String kind;
  final int level;
  final int xp;
  final int streak;
  final bool frozen;
  final bool isMobile;
  final bool allTasksComplete;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 20),
    padding: EdgeInsets.fromLTRB(
      isMobile ? 22 : 20,
      18,
      isMobile ? 22 : 20,
      20,
    ),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff1c382f), appSurface, Color(0xff121817)],
      ),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: const Color(0xff315043)),
      boxShadow: const [
        BoxShadow(color: Color(0x3310b981), blurRadius: 26, spreadRadius: -8),
      ],
    ),
    child: Column(
      children: [
        Row(
          children: [
            Text(
              name,
              style: const TextStyle(
                color: appText,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            tag('LV $level'),
          ],
        ),
        SizedBox(height: isMobile ? 2 : 8),
        WellnessCompanion(
          kind: kind,
          level: level,
          frozen: frozen,
          size: isMobile ? 286 : 210,
        ),
        Text(
          frozen
              ? 'Istirahat dulu.'
              : allTasksComplete
              ? 'Hebat hari ini!'
              : 'Aku di sini.',
          style: const TextStyle(color: appText, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _HeroMetric(value: '$xp XP', label: 'progress'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _HeroMetric(value: '$streak hari', label: 'streak'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: appCanvas.withValues(alpha: .42),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: appBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(color: appAccent, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: appMuted, fontSize: 11)),
      ],
    ),
  );
}

class _DailyContent extends StatelessWidget {
  const _DailyContent({required this.controller, required this.done});

  final WellnessController controller;
  final int done;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (controller.quests.isNotEmpty) ...[
        Row(
          children: [
            Expanded(child: title('Hari ini', size: 22)),
            tag('$done / ${controller.quests.length}'),
          ],
        ),
        gap(10),
        meter(
          done / controller.quests.length,
          'Progress',
          '${(done / controller.quests.length * 100).round()}%',
        ),
        gap(6),
        ...controller.quests.map(
          (quest) => _QuestTile(
            quest: quest,
            onComplete: () => controller.completeCard(quest['id']),
          ),
        ),
        gap(8),
      ],
      panel([
        Row(
          children: [
            const Icon(Icons.favorite_border, color: appAccent),
            const SizedBox(width: 10),
            Expanded(child: title('Check-in', size: 19)),
            FilledButton(
              onPressed: () =>
                  sheet(context, MoodCheckInSheet(controller: controller)),
              child: const Text('Mulai'),
            ),
          ],
        ),
      ]),
    ],
  );
}

class _QuestTile extends StatelessWidget {
  const _QuestTile({required this.quest, required this.onComplete});

  final Map<String, dynamic> quest;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final completed = quest['status'] == 'completed';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: appRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: completed ? const Color(0xff315043) : appBorder,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: appSurface,
          child: Icon(
            {
              'Gerak': Icons.directions_walk,
              'Nutrisi': Icons.restaurant_outlined,
              'Mental': Icons.favorite_border,
              'Habit swap': Icons.air,
              'Sosial': Icons.people_outline,
            }[quest['category']],
            color: appAccent,
          ),
        ),
        title: Text(
          quest['title'],
          style: TextStyle(
            fontWeight: FontWeight.w700,
            decoration: completed ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          '+${quest['xp']} XP',
          style: const TextStyle(fontSize: 12, color: appMuted),
        ),
        trailing: IconButton(
          tooltip: completed ? 'Selesai' : 'Selesaikan',
          onPressed: completed ? null : onComplete,
          icon: Icon(
            completed ? Icons.check_circle : Icons.circle_outlined,
            color: appAccent,
          ),
        ),
      ),
    );
  }
}

class _DesktopExtras extends StatelessWidget {
  const _DesktopExtras({required this.controller, required this.onStats});

  final WellnessController controller;
  final VoidCallback onStats;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      panel([
        title('Streak', size: 20),
        gap(12),
        Row(
          children: [
            const Icon(
              Icons.local_fire_department_outlined,
              color: appAccentAmber,
              size: 28,
            ),
            const SizedBox(width: 10),
            title('${controller.streak}', size: 30),
            const SizedBox(width: 8),
            const Expanded(child: Text('hari')),
          ],
        ),
        gap(12),
        OutlinedButton.icon(
          onPressed: () => controller.freeze(),
          icon: const Icon(Icons.ac_unit),
          label: Text('Freeze · ${controller.tokens}'),
        ),
      ]),
      panel([
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mode low-impact'),
          value: controller.profile?['lowImpact'] == true,
          onChanged: controller.setLowImpact,
        ),
        TextButton(onPressed: onStats, child: const Text('Statistik')),
      ]),
    ],
  );
}
