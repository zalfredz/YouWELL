import 'package:youwell/application/study_dashboard.dart';
import 'package:youwell/core/types/json_map.dart';

/// Chapter 4 report (proposal §3.6 and §3.8): the app log only describes
/// engagement and supports triangulation with the questionnaire and the
/// interviews; it is not a measure of effectiveness.
///
/// Groups: everyone, Better Daily Rhythm (wellness), and the smoking/vaping
/// path split by the product a participant logged (rokok, vape; someone
/// logging both is in both).
const bab4Groups = {
  'all': 'Semua',
  'wellness': 'Wellness',
  'rokok': 'Rokok',
  'vape': 'Vape',
};

List<StudyParticipant> bab4Members(
  List<StudyParticipant> people,
  String group,
) => switch (group) {
  'wellness' => people.where((p) => !p.reduction).toList(),
  'rokok' || 'vape' =>
    people.where((p) => p.reduction && p.types.contains(group)).toList(),
  _ => people,
};

/// Smoking/vaping participants without any logged total yet (they are in
/// neither the Rokok nor the Vape group).
List<StudyParticipant> reductionWithoutProduct(List<StudyParticipant> people) =>
    people.where((p) => p.reduction && p.types.isEmpty).toList();

/// One study week across a group. Means are per participant who reached the
/// week; [provisional] when the week is still running for someone.
class EngagementWeek {
  EngagementWeek(this.week, List<StudyParticipant> people)
    : reached = [
        for (final p in people)
          if (p.weeks.length >= week) p.weeks[week - 1],
      ];
  final int week;
  final List<StudyWeek> reached;

  int get n => reached.length;
  int get active => reached.where((w) => w.activeDays > 0).length;
  bool get provisional => reached.any((w) => !w.complete);
  double? _mean(int Function(StudyWeek w) value) =>
      n == 0 ? null : reached.fold<int>(0, (s, w) => s + value(w)) / n;
  double? get activeDays => _mean((w) => w.activeDays);
  double? get openedDays => _mean((w) => w.openedDays);
  double? get coreDone => _mean((w) => w.coreDone);
}

List<EngagementWeek> engagementByWeek(List<StudyParticipant> people) => [
  for (var week = 1; week <= 4; week++) EngagementWeek(week, people),
];

/// Criterion 3: at least [engagementTarget] of [plannedParticipants] active
/// in week 4. [met] is null while it can still change.
({int active, int reached, int total, bool provisional, bool? met}) criterion3(
  List<StudyParticipant> people,
) {
  final week = EngagementWeek(4, people);
  final settled = week.n == people.length && !week.provisional;
  return (
    active: week.active,
    reached: week.n,
    total: people.length,
    provisional: !settled,
    met: week.active >= engagementTarget
        ? true
        : settled
        ? false
        : null,
  );
}

/// Appendix A.5: one row per participant per week.
class A5Row {
  A5Row(this.participant, this.week);
  final StudyParticipant participant;
  final StudyWeek week;

  String get code => participant.code;
  int get opened => week.openedDays;
  int get coreDone => week.coreDone;

  /// Habit Swap moments tried; only the smoking/vaping path has them.
  /// The synced results (rokok + vape) when present, else the moments.
  int? get swaps {
    if (!participant.reduction) return null;
    final tried = usageTypes.fold(0, (s, t) => s + week.swapResult(t).tried);
    return tried > 0 ? tried : week.swaps;
  }

  /// "ya" or "tidak"; "berjalan" while an inactive week is still running.
  String get status => week.activeDays > 0
      ? 'ya'
      : week.complete
      ? 'tidak'
      : 'berjalan';
}

List<A5Row> a5Rows(List<StudyParticipant> people) => [
  for (final p in people)
    for (final w in p.weeks) A5Row(p, w),
];

const a5CsvColumns = [
  'kode',
  'jalur',
  'minggu',
  'minggu_selesai',
  'hari_membuka_aplikasi',
  'hari_aktif',
  'core_quest_selesai',
  'habit_swap_dicoba',
  'status_aktif',
  'isian_admin',
];

List<JsonMap> a5CsvRows(List<StudyParticipant> people) => [
  for (final row in a5Rows(people))
    {
      'kode': row.code,
      'jalur': row.participant.reduction ? 'rokok_vape' : 'wellness',
      'minggu': row.week.week,
      'minggu_selesai': row.week.complete,
      'hari_membuka_aplikasi': row.opened,
      'hari_aktif': row.week.activeDays,
      'core_quest_selesai': row.coreDone,
      'habit_swap_dicoba': row.swaps,
      'status_aktif': row.status,
      'isian_admin': row.week.adminItems,
    },
];

/// Level of [category] at the end of the first and the last week with a
/// recorded card; null when no card recorded it.
({int first, int last})? levelChange(StudyParticipant p, String category) {
  final levels = [for (final w in p.weeks) ?w.stepAt(category)];
  if (levels.isEmpty) return null;
  return (first: levels.first, last: levels.last);
}

/// Smoking or vaping logged by one participant, per week, against week 1.
class UsageCase {
  UsageCase(this.participant, this.type);
  final StudyParticipant participant;
  final String type;

  List<UsageWeek> get weeks => [
    for (final w in participant.weeks) w.usage(type),
  ];

  int get loggedDays => weeks.fold(0, (s, w) => s + w.loggedDays);

  /// Change of week [index] (0-based, 1–3) against week 1, in percent of the
  /// mean per logged day. Only for a finished week, and only when both weeks
  /// have at least 4 logged days.
  double? weekPercent(int index) {
    final all = weeks;
    if (index < 1 ||
        index >= all.length ||
        !participant.weeks[index].complete) {
      return null;
    }
    final p = usageChange(all.first, all[index])?.percent;
    return p == null ? null : p * 100;
  }

  /// Last week with at least 4 logged days, compared with week 1. Only once
  /// the participant has finished the 28 days.
  ({int week, ({double difference, double? percent}) change})? get change {
    final all = weeks;
    if (!participant.finished || all.isEmpty) return null;
    for (var i = all.length - 1; i > 0; i--) {
      if (usageChange(all.first, all[i]) case final c?) {
        return (week: i + 1, change: c);
      }
    }
    return null;
  }
}

/// Median change in percent across [cases] with a comparable week (only
/// participants who finished the 28 days).
double? medianUsageChange(List<UsageCase> cases) => median([
  for (final c in cases)
    if (c.change?.change.percent case final p?) p * 100,
]);
