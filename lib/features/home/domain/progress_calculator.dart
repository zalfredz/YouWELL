import 'dart:math';
import 'package:youwell/core/utils/date_key.dart';

/// Pure progression rules: daily streak, freeze tokens, XP and weekly difficulty.
class ProgressCalculator {
  const ProgressCalculator(
      {required this.days,
      required this.frozenDays,
      required this.now,
      required this.fitness,
      required this.lowImpact});
  final Map<String, dynamic> days;
  final List<String> frozenDays;
  final DateTime now;
  final int fitness;
  final bool lowImpact;
  String get today => dayKey(now);
  List<String> get completedDays => days.entries
      .where(
        (e) =>
            (e.value['quests'] as List).isNotEmpty &&
            (e.value['quests'] as List).every((q) => q['done'] == true),
      )
      .map((e) => e.key)
      .toList()
    ..sort();
  int get xp => days.values.fold(
        0,
        (sum, d) =>
            sum +
            (d['quests'] as List).where((q) => q['done'] == true).length * 20,
      );
  int get level => 1 + xp ~/ 100;
  int get tokens => max(0, 1 + completedDays.length ~/ 7 - frozenDays.length);
  int get streak {
    final valid = {
      ...completedDays,
      ...frozenDays,
    };
    var date = now;
    if (!valid.contains(today)) date = date.subtract(const Duration(days: 1));
    var count = 0;
    while (valid.contains(dayKey(date))) {
      count++;
      date = date.subtract(const Duration(days: 1));
    }
    return count;
  }

  double compliance(int period) {
    var total = 0, done = 0;
    final start = dayKey(now.subtract(Duration(days: period - 1)));
    for (final e in days.entries.where(
      (e) => e.key.compareTo(start) >= 0 && e.key.compareTo(today) <= 0,
    )) {
      final q = e.value['quests'] as List;
      total += q.length;
      done += q.where((q) => q['done'] == true).length;
    }
    return total == 0 ? 0 : done / total;
  }

  int get difficulty {
    final previous = days.entries
        .where(
          (e) =>
              e.key != today &&
              e.key.compareTo(dayKey(now.subtract(const Duration(days: 7)))) >=
                  0,
        )
        .toList();
    final base = fitness;
    if (lowImpact) return 1;
    if (previous.length < 3) return base;
    final all = previous.expand((e) => e.value['quests'] as List).toList();
    final rate = all.isEmpty
        ? 0
        : all.where((q) => q['done'] == true).length / all.length;
    return (base +
            (rate > .8
                ? 1
                : rate < .4
                    ? -1
                    : 0))
        .clamp(1, 3);
  }
}
