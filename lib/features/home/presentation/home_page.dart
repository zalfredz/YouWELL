import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/home/domain/quest_ladder.dart';
import 'package:youwell/features/reduction/presentation/reduction_support_page.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';
import 'package:youwell/features/companion/presentation/mobile_companion.dart';
import 'package:youwell/features/companion/presentation/companion_page.dart';
import 'package:youwell/features/companion/domain/companion_rewards.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.onOpenDraw,
    required this.onOpenActivity,
    this.companionKey,
  });

  final WellnessController controller;
  final VoidCallback onOpenDraw;
  final VoidCallback onOpenActivity;
  final GlobalKey? companionKey;

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
        Text(
          'Satu langkah kecil untuk hari yang lebih baik.',
          style: TextStyle(color: context.colors.muted),
        ),
        const SizedBox(height: 20),
        _CompanionStage(
          controller: controller,
          companionKey: companionKey,
          kind: companion,
          name: name,
          level: controller.level,
          xp: controller.xp,
          activeDays: controller.activeDaysIn(7),
          progress: (controller.xp % 100) / 100,
        ),
        if (controller.reduction) ...[
          const SizedBox(height: 20),
          ReductionEntryCard(controller: controller),
        ],
        for (final category in controller.ladderOffers) ...[
          const SizedBox(height: 16),
          LadderOfferCard(controller: controller, category: category),
        ],
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
        if (controller.quests.isEmpty && controller.needsDailyCardDraw)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.colors.border),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.style_rounded,
                  color: context.colors.accent,
                  size: 36,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Quest-mu menunggu',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Buka satu kartu untuk 3–5 quest hari ini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.muted),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onOpenDraw,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Ambil kartu'),
                ),
              ],
            ),
          )
        else
          ...controller.quests.map(
            (task) => _TaskTile(
              task: task,
              onComplete: switch (task['activityKind']) {
                null => () => controller.completeCard(task['id'].toString()),
                'delay' ||
                'habit_swap' => () => openReductionSupport(context, controller),
                _ => onOpenActivity,
              },
              onRate: (effort) =>
                  controller.rateQuestEffort(task['id'].toString(), effort),
            ),
          ),
      ],
    );
  }
}

class _CompanionStage extends StatefulWidget {
  const _CompanionStage({
    required this.kind,
    required this.name,
    required this.level,
    required this.xp,
    required this.activeDays,
    required this.progress,
    required this.controller,
    this.companionKey,
  });

  final String kind, name;
  final int level, xp, activeDays;
  final double progress;
  final WellnessController controller;
  final GlobalKey? companionKey;
  @override
  State<_CompanionStage> createState() => _CompanionStageState();
}

class _CompanionStageState extends State<_CompanionStage> {
  int _greeting = 0;
  static const _greetings = [
    'Kita jalan pelan-pelan.',
    'Senang kamu mampir!',
    'Satu langkah juga berarti.',
    'Aku tumbuh bareng kamu.',
  ];

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(0, -.15),
        radius: .9,
        colors: [
          context.colors.selected,
          context.colors.raised,
          context.colors.surface,
        ],
      ),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: context.colors.border),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Text(
              widget.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            tag('LV ${widget.level}'),
            IconButton(
              tooltip: 'Companion & hadiah',
              onPressed: _openWardrobe,
              icon: const Icon(Icons.card_giftcard_rounded),
            ),
          ],
        ),
        SizedBox(
          key: widget.companionKey,
          child: MobileCompanion(
            controller: widget.controller,
            onTap: () =>
                setState(() => _greeting = (_greeting + 1) % _greetings.length),
          ),
        ),
        Text(
          widget.controller.dailyProgress == 1
              ? 'Semua langkah hari ini tercapai! ✨'
              : _greetings[_greeting],
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _Metric(value: '${widget.xp} XP', label: 'total progress'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Metric(
                value: '${widget.activeDays} / 7',
                label: 'target: quest di 4 hari',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 7,
            value: widget.progress,
            backgroundColor: context.colors.canvas,
            color: context.colors.accent,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          companionStageName(widget.kind, companionStage(widget.level)),
          style: TextStyle(color: context.colors.muted),
        ),
        const SizedBox(height: 4),
        Text(
          _nextReward(widget.controller),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  String _nextReward(WellnessController controller) {
    final next = companionUnlocks
        .where((item) => item.level > controller.level)
        .firstOrNull;
    if (next == null) return 'Semua hadiah terbuka. Kita terus tumbuh!';
    return '${(next.level - 1) * 100 - controller.xp} XP lagi: ${next.label}';
  }

  void _openWardrobe() => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => CompanionPage(controller: widget.controller),
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
      color: context.colors.canvas.withValues(alpha: .5),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: context.colors.accent,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: context.colors.muted, fontSize: 11),
        ),
      ],
    ),
  );
}

/// Offers a ladder step up; the user may stay ("Tetap di level ini").
class LadderOfferCard extends StatelessWidget {
  const LadderOfferCard({
    super.key,
    required this.controller,
    required this.category,
  });
  final WellnessController controller;
  final String category;

  @override
  Widget build(BuildContext context) {
    final entry = controller.capacity[category]!;
    final next = (entry['offerStep'] as num).toInt();
    final rung = ladders[category]![next - 1];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.selected,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.accent.withValues(alpha: .4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Siap naik? ${ladderLabels[category]}: ${rung.title}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            entry['reason'].toString(),
            style: TextStyle(color: context.colors.muted, height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: () => controller.acceptLadderStep(category),
                child: const Text('Naik satu anak tangga'),
              ),
              OutlinedButton(
                onPressed: () => controller.declineLadderStep(category),
                child: const Text('Tetap di level ini'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.onComplete,
    required this.onRate,
  });
  final Map<String, dynamic> task;
  final VoidCallback onComplete;
  final ValueChanged<String> onRate;

  @override
  Widget build(BuildContext context) {
    final done = task['status'] == 'completed';
    final needsEvidence = task['validationInvalidated'] == true;
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
        color: context.colors.raised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: done ? context.colors.border : context.colors.border,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: context.colors.surface,
            child: Icon(icon, color: context.colors.accent),
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
                  [
                    '${task['durationMinutes']} menit',
                    '+${task['xp']} XP',
                    if (task['ladder'] != null)
                      '${ladderLabels[task['ladder']]} · anak tangga ${task['step']}',
                  ].join('  •  '),
                  style: TextStyle(color: context.colors.muted, fontSize: 12),
                ),
                if (task['strenuous'] == true && !done)
                  Text(
                    'Berhenti jika pusing atau nyeri.',
                    style: TextStyle(color: context.colors.muted, fontSize: 12),
                  ),
                if (!done && task['partial'] is num)
                  Text(
                    'Tercapai sebagian: ${((task['partial'] as num) * 100).round()}%',
                    style: TextStyle(color: context.colors.amber, fontSize: 12),
                  ),
                if (needsEvidence)
                  Text(
                    'Bukti sesi tidak dipakai untuk evaluasi. XP tetap tersimpan.',
                    style: TextStyle(color: context.colors.muted, fontSize: 12),
                  ),
                if (done && !needsEvidence && task['ladder'] != null)
                  _EffortRating(effort: task['effort'], onRate: onRate),
              ],
            ),
          ),
          IconButton(
            tooltip: needsEvidence
                ? 'Catat sesi baru tanpa mengulang XP'
                : done
                ? 'Selesai'
                : task['activityKind'] == null
                ? 'Tandai selesai'
                : task['activityKind'] == 'delay'
                ? 'Mulai timer Delay Craving'
                : task['activityKind'] == 'habit_swap'
                ? 'Pilih Habit Swap'
                : 'Buka Aktivitas untuk menyelesaikan',
            onPressed: done && !needsEvidence ? null : onComplete,
            icon: Icon(
              needsEvidence
                  ? Icons.arrow_forward_rounded
                  : done
                  ? Icons.check_circle_rounded
                  : task['activityKind'] == null
                  ? Icons.circle_outlined
                  : Icons.arrow_forward_rounded,
              color: context.colors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// One tap after a ladder quest; "berat" feeds the weekly ladder review.
class _EffortRating extends StatelessWidget {
  const _EffortRating({required this.effort, required this.onRate});
  final Object? effort;
  final ValueChanged<String> onRate;

  @override
  Widget build(BuildContext context) {
    if (effort != null) {
      return Text(
        'Terasa ${effort.toString()}',
        style: TextStyle(color: context.colors.muted, fontSize: 12),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Gimana rasanya?',
            style: TextStyle(color: context.colors.muted, fontSize: 12),
          ),
          for (final (value, label) in const [
            ('ringan', 'Ringan'),
            ('pas', 'Pas'),
            ('berat', 'Berat'),
          ])
            ActionChip(
              visualDensity: VisualDensity.compact,
              backgroundColor: context.colors.surface,
              side: BorderSide(color: context.colors.border),
              label: Text(label),
              onPressed: () => onRate(value),
            ),
        ],
      ),
    );
  }
}
