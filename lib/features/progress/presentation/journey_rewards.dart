import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/utils/date_key.dart';
import 'package:youwell/features/companion/domain/companion_rewards.dart';

class JourneyRewards extends StatelessWidget {
  const JourneyRewards({super.key, required this.controller});
  final WellnessController controller;
  @override
  Widget build(BuildContext context) {
    final active = controller.activeDaysIn(7);
    final start =
        DateTime.tryParse(controller.profile?['started']?.toString() ?? '') ??
        controller.now;
    final doneDays = controller.activeDays.toSet();
    final fullDays = controller.completedDays.toSet();
    final entries = controller.workoutSessions
        .where(
          (row) =>
              row['day'].toString().compareTo(
                    dayKey(controller.now.subtract(const Duration(days: 6))),
                  ) >=
                  0 &&
              row['day'].toString().compareTo(controller.today) <= 0,
        )
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _JourneyPanel(
          child: Row(
            children: [
              SizedBox.square(
                dimension: 82,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: (active / 4).clamp(0, 1),
                        strokeWidth: 7,
                        color: context.colors.accent,
                        backgroundColor: context.colors.raised,
                      ),
                    ),
                    Text(
                      '$active/7',
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ritme mingguan',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      active >= 4
                          ? 'Target 4 hari tercapai ✨'
                          : '${4 - active} hari lagi menuju target',
                      style: TextStyle(color: context.colors.accent),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hari terlewat tidak menghapus progress.',
                      style: TextStyle(color: context.colors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _JourneyPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '28 hari perjalananmu',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Mulai ${dayKey(start)} · setiap warna adalah satu langkah.',
                style: TextStyle(color: context.colors.muted),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 28,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  final day = dayKey(start.add(Duration(days: index)));
                  final full = fullDays.contains(day),
                      done = doneDays.contains(day),
                      today = day == controller.today;
                  final future = day.compareTo(controller.today) > 0;
                  return Tooltip(
                    message:
                        '$day · ${full
                            ? 'semua quest selesai'
                            : done
                            ? 'langkah tercatat'
                            : future
                            ? 'belum tiba'
                            : 'ruang untuk istirahat'}',
                    child: Semantics(
                      label:
                          '$day ${full
                              ? 'hari penuh'
                              : done
                              ? 'aktif'
                              : 'istirahat'}',
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: full
                              ? context.colors.accent
                              : done
                              ? context.colors.selected
                              : context.colors.raised,
                          borderRadius: BorderRadius.circular(12),
                          border: today
                              ? Border.all(
                                  color: context.colors.accent,
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: full
                                ? context.colors.canvas
                                : future
                                ? context.colors.muted
                                : context.colors.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                '$entries sesi gerak dalam 7 hari terakhir.',
                style: TextStyle(color: context.colors.muted),
              ),
            ],
          ),
        ),
        _JourneyPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Koleksi pencapaian',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Hanya untukmu. Tidak ada peringkat.',
                style: TextStyle(color: context.colors.muted),
              ),
              const SizedBox(height: 12),
              for (final entry in achievementNames.entries.where(
                (entry) => controller.reduction || !entry.key.contains('delay'),
              ))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    controller.achievements.containsKey(entry.key)
                        ? Icons.workspace_premium_rounded
                        : Icons.lock_outline,
                    color: controller.achievements.containsKey(entry.key)
                        ? context.colors.accent
                        : context.colors.muted,
                  ),
                  title: Text(entry.value),
                  subtitle: controller.achievements[entry.key] == null
                      ? null
                      : Text('Terbuka ${controller.achievements[entry.key]}'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _JourneyPanel extends StatelessWidget {
  const _JourneyPanel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: context.colors.border),
    ),
    child: child,
  );
}
