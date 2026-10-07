import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/core/utils/date_key.dart';

/// Numbers-only weekly summary for research_logs (UAT participants only).
/// It deliberately holds no alias, text, photo, location, or user id.
class ResearchSummary {
  const ResearchSummary({
    required this.week,
    required this.activeDays,
    required this.questsDone,
    required this.ladderGerak,
    required this.ladderIstirahat,
    required this.ladderHidrasi,
    required this.ladderMakan,
    required this.ladderJeda,
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
                task['validationInvalidated'] != true &&
                // Kartu Bonus extras are not Core Quests (§10).
                task['bonus'] != true,
          )
          .length;
      questsDone += done;
      if (done > 0) questDays.add(entry.key);
    }
    return ResearchSummary(
      week: week,
      // "Aktif" (proposal §7): app opened OR at least one quest finished.
      activeDays: {...opened, ...activity, ...questDays}.length,
      openedDayCount: opened.length,
      activityDayCount: activity.length,
      questDayCount: questDays.length,
      questsDone: questsDone,
      ladderGerak: (historicalSteps?['Body'] as num?)?.toInt(),
      ladderIstirahat: (historicalSteps?['Energy'] as num?)?.toInt(),
      ladderHidrasi: (historicalSteps?['Lifestyle'] as num?)?.toInt(),
      ladderMakan: (historicalSteps?['Food'] as num?)?.toInt(),
      ladderJeda: (historicalSteps?['Reduction'] as num?)?.toInt(),
      delayCravingCount: habitDelays.where((row) => inWeek(row['day'])).length,
      habitSwapCount: habitSwaps.where((row) => inWeek(row['day'])).length,
    );
  }

  final int week, activeDays, questsDone, delayCravingCount, habitSwapCount;
  final int openedDayCount, activityDayCount, questDayCount;

  /// Ladder position per category; null when the category is not in use.
  final int? ladderGerak, ladderIstirahat, ladderHidrasi, ladderMakan;
  final int? ladderJeda;

  /// Columns of `research_logs` (CLAUDE.md §3). Internal category keys map
  /// to research names here: Body → gerak, Energy → istirahat,
  /// Lifestyle → hidrasi, Food → makan, Reduction → jeda. Tidur is not used
  /// yet. `quests_done` includes practice quests from relaxed days but not
  /// Kartu Bonus extras (§10).
  JsonMap toJson() => {
    'week': week,
    'active_days': activeDays,
    'quests_done': questsDone,
    'ladder_gerak': ladderGerak,
    'ladder_istirahat': ladderIstirahat,
    'ladder_tidur': null,
    'ladder_hidrasi': ladderHidrasi,
    'ladder_makan': ladderMakan,
    'ladder_jeda': ladderJeda,
    'delay_craving_count': delayCravingCount,
    'habit_swap_count': habitSwapCount,
  };
}
