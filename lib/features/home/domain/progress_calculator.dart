import 'package:youwell/core/utils/date_key.dart';

/// Pure, pressure-free progress rules used by mobile and web.
class ProgressCalculator {
  const ProgressCalculator({required this.days, required this.now});

  final Map<String, dynamic> days;
  final DateTime now;
  String get today => dayKey(now);

  List<String> get activeDays =>
      days.entries
          .where((entry) => _quests(entry.value).any(_isCompleted))
          .map((entry) => entry.key)
          .toList()
        ..sort();

  List<String> get completedDays =>
      days.entries
          .where((entry) {
            final quests = _quests(entry.value);
            return quests.isNotEmpty && quests.every(_isCompleted);
          })
          .map((entry) => entry.key)
          .toList()
        ..sort();

  int get xp => days.values.fold<int>(
    0,
    (total, day) =>
        total +
        _quests(day)
            .where(_isCompleted)
            .fold<int>(0, (sum, task) => sum + _number(task['xp'], 15)),
  );
  int get level => 1 + xp ~/ 100;

  int activeDaysIn(int period) {
    final start = dayKey(now.subtract(Duration(days: period - 1)));
    return activeDays
        .where((day) => day.compareTo(start) >= 0 && day.compareTo(today) <= 0)
        .length;
  }

  double completionRate(int period) {
    final start = dayKey(now.subtract(Duration(days: period - 1)));
    var total = 0, completed = 0;
    for (final entry in days.entries.where(
      (entry) =>
          entry.key.compareTo(start) >= 0 && entry.key.compareTo(today) <= 0,
    )) {
      final quests = _quests(entry.value);
      total += quests.length;
      completed += quests.where(_isCompleted).length;
    }
    return total == 0 ? 0 : completed / total;
  }

  List<Map<String, dynamic>> _quests(dynamic day) {
    if (day is! Map || day['quests'] is! List) return const [];
    return (day['quests'] as List)
        .whereType<Map>()
        .map((task) => Map<String, dynamic>.from(task))
        .toList();
  }

  bool _isCompleted(Map<String, dynamic> task) =>
      task['status'] == 'completed' || task['done'] == true;
  int _number(dynamic value, int fallback) =>
      value is num ? value.toInt() : fallback;
}
