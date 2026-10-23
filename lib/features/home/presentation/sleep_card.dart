import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/home/domain/quest_ladder.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';

String _clock(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}.${time.minute.toString().padLeft(2, '0')}';

/// The current sleep level's targets, e.g. "23.00 · 06.00".
(String, String) _targets(WellnessController c) {
  final rungs = ladders['Energy']!;
  final step = (c.ladderSteps['Energy'] ?? 1).clamp(1, rungs.length);
  final rung = rungs[step - 1];
  String at(int minutes) =>
      '${(minutes ~/ 60 % 24).toString().padLeft(2, '0')}.${(minutes % 60).toString().padLeft(2, '0')}';
  return (at(rung.bedBefore! + 1080), at(rung.wakeBefore!));
}

/// Shows on Home only when it matters: check-in in the evening, check-out
/// after a check-in, and last night's summary in the morning.
class SleepCard extends StatelessWidget {
  const SleepCard({super.key, required this.controller});
  final WellnessController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final colors = context.colors;
    final open = c.sleepCheckIn;
    final last = c.lastNightSleep;
    final hour = c.now.hour;
    final (bedTarget, wakeTarget) = _targets(c);
    final Widget body;
    if (open != null) {
      body = _Row(
        icon: Icons.bedtime_rounded,
        color: colors.energy,
        title: 'Tidur sejak ${_clock(open)} · selamat tidur',
        subtitle: 'Target bangun sebelum $wakeTarget',
        primary: FilledButton.icon(
          onPressed: () {
            final ok = c.checkOutSleep();
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? 'Selamat pagi! Tidurmu tercatat.'
                        : 'Bisa dicatat minimal 2 jam setelah mulai tidur.',
                  ),
                ),
              );
          },
          icon: const Icon(Icons.wb_sunny_rounded),
          label: const Text('Aku sudah bangun'),
        ),
        secondary: TextButton(
          onPressed: c.cancelSleepCheckIn,
          child: const Text('Batal'),
        ),
      );
    } else if (hour >= 18 || hour < 4) {
      body = _Row(
        icon: Icons.nights_stay_rounded,
        color: colors.energy,
        title: 'Siap tidur?',
        subtitle: 'Target tidur sebelum $bedTarget',
        primary: FilledButton.icon(
          onPressed: c.checkInSleep,
          icon: const Icon(Icons.bedtime_rounded),
          label: const Text('Aku mau tidur'),
        ),
      );
    } else if (last != null) {
      final bed = DateTime.parse(last['bedAt'].toString());
      final wake = DateTime.parse(last['wakeAt'].toString());
      final minutes = wake.difference(bed).inMinutes;
      body = _Row(
        icon: Icons.check_circle_rounded,
        color: colors.success,
        title: 'Tidur ${_clock(bed)} – ${_clock(wake)}',
        subtitle: '${minutes ~/ 60} jam ${minutes % 60} menit',
      );
    } else {
      return const SizedBox.shrink();
    }
    return GameCard(padding: const EdgeInsets.all(16), child: body);
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.primary,
    this.secondary,
  });
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final Widget? primary, secondary;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Container(
            width: 44,
            height: 44,
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
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.colors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      if (primary != null) ...[const SizedBox(height: 12), primary!],
      ?secondary,
    ],
  );
}

/// The sleep quest's sheet: just the one button that fits right now.
Future<void> openSleepSheet(BuildContext context, WellnessController c) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final awake = c.sleepCheckIn != null;
        void press() {
          final ok = awake ? c.checkOutSleep() : c.checkInSleep();
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(sheetContext);
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  !ok
                      ? 'Bisa ditekan minimal 2 jam setelah mulai tidur.'
                      : awake
                      ? 'Selamat pagi! Tidurmu tercatat.'
                      : 'Selamat tidur!',
                ),
              ),
            );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: press,
                icon: Icon(
                  awake ? Icons.wb_sunny_rounded : Icons.bedtime_rounded,
                ),
                label: Text(awake ? 'Aku sudah bangun' : 'Aku mau tidur'),
              ),
            ),
          ),
        );
      },
    );
