import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';

// Sleep check-in quests ran 23 Oct–4 Nov 2026; Istirahat is calm breathing
// from 5 Nov. What remains here lets an open check-in and those last sleep
// quests finish.

String _clock(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}.${time.minute.toString().padLeft(2, '0')}';

/// A sleep quest's own targets, e.g. "23.00 · 06.00".
(String, String) _targets(Map task) {
  String at(int minutes) =>
      '${(minutes ~/ 60 % 24).toString().padLeft(2, '0')}.${(minutes % 60).toString().padLeft(2, '0')}';
  return (
    at(((task['bedBefore'] as num?)?.toInt() ?? 390) + 1080),
    at((task['wakeBefore'] as num?)?.toInt() ?? 450),
  );
}

/// On Home only while a check-in is still open, so it can be closed.
class SleepCard extends StatelessWidget {
  const SleepCard({super.key, required this.controller});
  final WellnessController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final open = c.sleepCheckIn;
    if (open == null) return const SizedBox.shrink();
    return GameCard(
      padding: const EdgeInsets.all(16),
      child: _Row(
        icon: Icons.bedtime_rounded,
        color: context.colors.energy,
        title: 'Tidur sejak ${_clock(open)}',
        subtitle: 'Tekan saat kamu sudah bangun.',
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
      ),
    );
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

/// A sleep quest's sheet (4 Nov and earlier): the one button that fits
/// right now, or, during the day, what last night looked like.
Future<void> openSleepSheet(
  BuildContext context,
  WellnessController c,
  Map task,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (sheetContext) {
    final awake = c.sleepCheckIn != null;
    final colors = sheetContext.colors;
    if (!awake && !c.canCheckInSleep) {
      final last = c.lastNightSleep;
      final (bedTarget, wakeTarget) = _targets(task);
      final night = last == null
          ? null
          : (
              DateTime.parse(last['bedAt'].toString()),
              DateTime.parse(last['wakeAt'].toString()),
            );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                night == null
                    ? 'Tidur tadi malam belum tercatat'
                    : 'Tidur tadi malam ${_clock(night.$1)} – ${_clock(night.$2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Misi ini dinilai dari malam yang berakhir pagi ini (tidur '
                'sebelum $bedTarget, bangun sebelum $wakeTarget). Mulai besok '
                'misi Istirahat berganti menjadi hibernasi (hitung mundur napas tenang).',
                style: TextStyle(color: colors.muted, height: 1.4),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Mengerti'),
                ),
              ),
            ],
          ),
        ),
      );
    }
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
            icon: Icon(awake ? Icons.wb_sunny_rounded : Icons.bedtime_rounded),
            label: Text(awake ? 'Aku sudah bangun' : 'Aku mau tidur'),
          ),
        ),
      ),
    );
  },
);
