import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/core/utils/date_key.dart';

/// Numbers-only weekly summary for research_logs (UAT participants only).
/// It deliberately holds no alias, text, photo, location, or user id.
class ResearchSummary {
  const ResearchSummary({
    required this.week,
    required this.activeDays,
    required this.questsDone,
    required this.ladderBody,
    required this.ladderEnergy,
    required this.ladderReduction,
    required this.delayCravingCount,
    required this.habitSwapCount,
    required this.openedDayCount,
    required this.activityDayCount,
    required this.questDayCount,
  });

  /// Week 1–4 counted from the day the profile started.
  factory ResearchSummary.forWeek({
    required int week,
    required String started,
    required Map<String, dynamic> days,
    required List<String> openedDays,
    List<String> activityDays = const [],
    required List<JsonMap> habitDelays,
    required List<JsonMap> habitSwaps,
  }) {
    final first = DateTime.parse(started).add(Duration(days: 7 * (week - 1)));
    final from = dayKey(first);
    final to = dayKey(first.add(const Duration(days: 6)));
    bool inWeek(Object? day) =>
        day is String && day.compareTo(from) >= 0 && day.compareTo(to) <= 0;

    RangeError.checkValueInInterval(week, 1, 4, 'week');
    final questDays = <String>{};
    final opened = openedDays.where(inWeek).toSet();
    final activity = activityDays.where(inWeek).toSet();
    final weekEntries =
        days.entries.where((entry) => inWeek(entry.key)).toList()
          ..sort((a, b) => b.key.compareTo(a.key));
    final historicalSteps = weekEntries
        .map((entry) => entry.value is Map ? entry.value['ladderSteps'] : null)
        .whereType<Map>()
        .firstOrNull;
    var questsDone = 0;
    for (final entry in days.entries.where((entry) => inWeek(entry.key))) {
      final quests = (entry.value is Map ? entry.value['quests'] : null) ?? [];
      final done = (quests as List)
          .whereType<Map>()
          .where(
            (task) =>
                task['status'] == 'completed' &&
                task['validationInvalidated'] != true,
          )
          .length;
      questsDone += done;
      if (done > 0) questDays.add(entry.key);
    }
    return ResearchSummary(
      week: week,
      // Research engagement counts opening the app, not finishing a quest.
      activeDays: opened.length,
      openedDayCount: opened.length,
      activityDayCount: activity.length,
      questDayCount: questDays.length,
      questsDone: questsDone,
      ladderBody: (historicalSteps?['Body'] as num?)?.toInt(),
      ladderEnergy: (historicalSteps?['Energy'] as num?)?.toInt(),
      ladderReduction: (historicalSteps?['Reduction'] as num?)?.toInt(),
      delayCravingCount: habitDelays.where((row) => inWeek(row['day'])).length,
      habitSwapCount: habitSwaps.where((row) => inWeek(row['day'])).length,
    );
  }

  final int week, activeDays, questsDone, delayCravingCount, habitSwapCount;
  final int openedDayCount, activityDayCount, questDayCount;
  final int? ladderBody, ladderEnergy, ladderReduction;

  /// Numeric export fields. Remote storage must adopt this schema later.
  JsonMap toJson() => {
    'week': week,
    'active_days': activeDays,
    'opened_days': openedDayCount,
    'activity_days': activityDayCount,
    'quest_days': questDayCount,
    'quests_done': questsDone,
    'ladder_body': ladderBody,
    'ladder_energy': ladderEnergy,
    'ladder_reduction': ladderReduction,
    'delay_craving_count': delayCravingCount,
    'habit_swap_count': habitSwapCount,
  };
}
