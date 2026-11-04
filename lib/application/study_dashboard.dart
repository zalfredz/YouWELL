import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/core/utils/date_key.dart';
import 'research_overview.dart';

/// Researcher dashboard metrics (brief of 4 Nov 2026): days 1–28 of each
/// coded participant, computed from the synced snapshot. The chart and the
/// CSV read the same objects, so their numbers always match.
///
/// What the numbers mean is limited on purpose: engagement and targets
/// reached, not health; daily totals as reported, where an empty day is not
/// zero and cigarettes and vape sessions are never added together.

/// Dates the way something is measured changed; charts mark them so old
/// and new values are not read as one series.
const measurementChanges = [
  (day: '2026-10-23', label: 'Misi tidur & verifikasi foto makan berubah'),
  (day: '2026-10-27', label: 'Total rokok/vape mulai tersinkron'),
  (day: '2026-11-05', label: 'Misi Istirahat: tidur diganti Hibernasi'),
];

const studyDays = 28;
const usageTypes = ['rokok', 'vape'];

/// Wellness ladders by research name (Energy is the sleep ladder).
const targetCategories = {
  'Body': 'Gerak',
  'Lifestyle': 'Hidrasi',
  'Food': 'Makan',
  'Energy': 'Istirahat',
};

bool _adminId(Map row) => row['id']?.toString().startsWith('admin-') ?? false;

bool _done(Map task) =>
    task['status'] == 'completed' && task['validationInvalidated'] != true;

class StudyDay {
  StudyDay(this.day, this.number);
  final String day;
  final int number;
  bool opened = false, active = false;
  int coreDone = 0, coreTotal = 0, workouts = 0, workoutSeconds = 0;
  int workoutMeters = 0, swaps = 0, adminItems = 0;
  int mealApproved = 0, mealRejected = 0, mealPending = 0, mealUnverified = 0;
  final targets = <String>{};

  /// Confirmed daily total per type; a missing type was not logged.
  final usage = <String, int>{};
  final usageByAdmin = <String>{};

  bool get hasData =>
      active ||
      usage.isNotEmpty ||
      swaps > 0 ||
      workouts > 0 ||
      mealApproved + mealRejected + mealPending + mealUnverified > 0;

  String? get measurementNote =>
      measurementChanges.where((m) => m.day == day).firstOrNull?.label;
}

/// Total and logged days of one product in one week.
class UsageWeek {
  const UsageWeek(this.total, this.loggedDays);
  final int total, loggedDays;

  /// Mean per logged day; null when nothing was logged.
  double? get mean => loggedDays == 0 ? null : total / loggedDays;

  /// Weeks are compared only with at least 4 logged days (progress rule).
  bool get comparable => loggedDays >= 4;
}

/// Week [week] against week 1. Null when either week has < 4 logged days.
/// [percent] is null when week 1's mean is 0 (difference only).
({double difference, double? percent})? usageChange(
  UsageWeek first,
  UsageWeek week,
) {
  if (!first.comparable || !week.comparable) return null;
  final base = first.mean!, now = week.mean!;
  return (
    difference: now - base,
    percent: base == 0 ? null : (now - base) / base,
  );
}

class StudyWeek {
  StudyWeek(this.week, this.days, {required this.complete});
  final int week;
  final List<StudyDay> days;

  /// The week's 7 days are over.
  final bool complete;

  int _sum(int Function(StudyDay day) value) =>
      days.fold(0, (sum, day) => sum + value(day));

  int get activeDays => days.where((d) => d.active).length;
  int get coreDone => _sum((d) => d.coreDone);
  int get coreTotal => _sum((d) => d.coreTotal);
  double? get coreRate => coreTotal == 0 ? null : coreDone / coreTotal;
  int targetDays(String category) =>
      days.where((d) => d.targets.contains(category)).length;
  int get workouts => _sum((d) => d.workouts);
  int get workoutMinutes => _sum((d) => d.workoutSeconds) ~/ 60;
  int get workoutMeters => _sum((d) => d.workoutMeters);
  int get mealApproved => _sum((d) => d.mealApproved);
  int get mealRejected => _sum((d) => d.mealRejected);
  int get mealPending => _sum((d) => d.mealPending);
  int get mealUnverified => _sum((d) => d.mealUnverified);
  int get swaps => _sum((d) => d.swaps);
  int get adminItems => _sum((d) => d.adminItems);

  UsageWeek usage(String type) {
    final logged = days.where((d) => d.usage.containsKey(type));
    return UsageWeek(
      logged.fold(0, (sum, d) => sum + d.usage[type]!),
      logged.length,
    );
  }
}

class StudyParticipant {
  StudyParticipant._({
    required this.source,
    required this.path,
    required this.started,
    required this.days,
    required this.weeks,
    required this.elapsed,
    required this.types,
  });

  /// Days 1–28 of [person], including recovered participant data entered
  /// by an admin. Null without a code or a start date.
  static StudyParticipant? from(
    ParticipantOverview person, {
    required DateTime now,
  }) {
    final code = person.code;
    final started = person.studyStarted ?? person.started;
    if (code == null || started == null || DateTime.tryParse(started) == null) {
      return null;
    }
    final payload = person.payload;
    final today = dayKey(now);
    final elapsed = (daysBetweenKeys(started, today) + 1).clamp(0, studyDays);
    final days = [
      for (var i = 0; i < elapsed; i++)
        StudyDay(shiftDayKey(started, i), i + 1),
    ];
    final byDay = {for (final day in days) day.day: day};
    _fill(byDay, payload);
    final weeks = [
      for (var week = 1; week <= 4 && (week - 1) * 7 < elapsed; week++)
        StudyWeek(
          week,
          days.skip((week - 1) * 7).take(7).toList(),
          complete: daysBetweenKeys(started, today) >= week * 7,
        ),
    ];
    final current = person.payload['profile'] is Map
        ? person.payload['profile']['path']?.toString()
        : null;
    final types = <String>{
      for (final row
          in ((payload['usageTotals'] ?? const []) as List).whereType<Map>())
        if (usageTypes.contains(row['type'])) row['type'].toString(),
    };
    return StudyParticipant._(
      source: person,
      path: person.studyPath ?? current ?? 'wellness',
      started: started,
      days: days,
      weeks: weeks,
      elapsed: elapsed,
      types: [
        for (final type in usageTypes)
          if (types.contains(type)) type,
      ],
    );
  }

  static void _fill(Map<String, StudyDay> byDay, JsonMap payload) {
    StudyDay? on(Object? day) => byDay[day?.toString()];
    for (final day in ((payload['openedDays'] ?? const []) as List)) {
      on(day)?.opened = true;
      on(day)?.active = true;
    }
    for (final day in ((payload['activityDays'] ?? const []) as List)) {
      on(day)?.active = true;
    }
    for (final day in ((payload['adminOpenedDays'] ?? const []) as List)) {
      on(day)?.adminItems++;
    }
    for (final MapEntry(:key, :value)
        in ((payload['days'] ?? const {}) as Map).entries) {
      final day = on(key);
      if (day == null || value is! Map) continue;
      for (final task
          in ((value['quests'] ?? const []) as List).whereType<Map>()) {
        if (task['bonus'] == true) continue;
        day.coreTotal++;
        if (!_done(task)) continue;
        day
          ..coreDone += 1
          ..active = true;
        if (task['adminCompleted'] == true) day.adminItems++;
        if (targetCategories.containsKey(task['ladder'])) {
          day.targets.add(task['ladder'].toString());
        }
      }
    }
    for (final row
        in ((payload['workoutSessions'] ?? const []) as List)
            .whereType<Map>()) {
      final day = on(row['day']);
      if (day == null || row['countsForQuest'] == false) continue;
      day
        ..workouts += 1
        ..workoutSeconds += (row['seconds'] as num?)?.toInt() ?? 0
        ..workoutMeters += (row['meters'] as num?)?.toInt() ?? 0;
    }
    for (final row
        in ((payload['mealCheckIns'] ?? const []) as List).whereType<Map>()) {
      final day = on(row['day']);
      if (day == null || row['photoCaptured'] != true) continue;
      switch (row['verification']) {
        case 'approved':
          day.mealApproved++;
        case 'rejected':
          day.mealRejected++;
        case 'pending':
          day.mealPending++;
        default:
          day.mealUnverified++;
      }
    }
    for (final row
        in ((payload['usageTotals'] ?? const []) as List).whereType<Map>()) {
      final day = on(row['day']);
      final type = row['type']?.toString();
      if (day == null ||
          !usageTypes.contains(type) ||
          row['confirmed'] != true ||
          row['total'] is! num) {
        continue;
      }
      day.usage[type!] = (row['total'] as num).toInt();
      if (row['source'] == 'admin') {
        day
          ..usageByAdmin.add(type)
          ..adminItems += 1;
      }
    }
    for (final row
        in ((payload['habitSwaps'] ?? const []) as List).whereType<Map>()) {
      final day = on(row['day']);
      if (day == null) continue;
      day.swaps++;
      day.active = true;
      if (_adminId(row)) day.adminItems++;
    }
  }

  final ParticipantOverview source;

  /// Study group: locked at code assignment, else today's path.
  final String path, started;
  final List<StudyDay> days;
  final List<StudyWeek> weeks;

  /// Study days passed so far (0–28).
  final int elapsed;

  /// Products with logged totals, rokok before vape.
  final List<String> types;

  String get code => source.code!;
  bool get reduction => path == 'reduction';
  bool get groupLocked => source.studyPath != null;

  /// The profile's path today differs from the locked study group.
  bool get pathChanged {
    final profile = source.payload['profile'];
    return groupLocked &&
        profile is Map &&
        profile['path'] != null &&
        profile['path'] != source.studyPath;
  }

  int get daysWithData => days.where((d) => d.hasData).length;
  double? get completeness => elapsed == 0 ? null : daysWithData / elapsed;
  int get adminItems => days.fold(0, (sum, d) => sum + d.adminItems);
  DateTime? get lastSync => source.updatedAt;

  /// Week 4 is over, so its activity is final.
  bool get finished => weeks.length == 4 && weeks.last.complete;
}

class StudySummary {
  StudySummary(this.people);
  final List<StudyParticipant> people;

  int reached(int week) => people.where((p) => p.weeks.length >= week).length;

  double? get completeness {
    final values = [
      for (final p in people)
        if (p.completeness case final value?) value,
    ];
    return values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;
  }

  int get adminItems => people.fold(0, (sum, p) => sum + p.adminItems);
  int get adminPeople => people.where((p) => p.adminItems > 0).length;

  DateTime? get oldestSync => _sync((a, b) => a.isBefore(b));
  DateTime? get newestSync => _sync((a, b) => a.isAfter(b));
  DateTime? _sync(bool Function(DateTime a, DateTime b) better) {
    DateTime? best;
    for (final p in people) {
      final time = p.lastSync;
      if (time != null && (best == null || better(time, best))) best = time;
    }
    return best;
  }

  /// Proposal criterion: ≥ 6 of the coded participants active in week 4.
  /// Final only once every coded participant finished week 4.
  ({int active, int reached, bool provisional}) get weekFour {
    final inWeek = people.where((p) => p.weeks.length == 4);
    return (
      active: inWeek.where((p) => p.weeks[3].activeDays > 0).length,
      reached: inWeek.length,
      provisional: people.isEmpty || !people.every((p) => p.finished),
    );
  }
}

/// One row per coded participant and reached week; matches the charts.
const dashboardCsvColumns = [
  'participant_code',
  'study_path',
  'group_locked',
  'week',
  'week_complete',
  'days_elapsed',
  'days_with_data',
  'active_days',
  'core_quests_done',
  'core_quests_total',
  'gerak_target_days',
  'hidrasi_target_days',
  'makan_target_days',
  'istirahat_target_days',
  'workout_sessions',
  'workout_minutes',
  'workout_meters',
  'meal_photos_approved',
  'meal_photos_rejected',
  'meal_photos_pending',
  'meal_photos_unverified',
  'rokok_total',
  'rokok_days_logged',
  'rokok_mean_per_logged_day',
  'vape_total',
  'vape_days_logged',
  'vape_mean_per_logged_day',
  'habit_swaps',
  'admin_items',
  'includes_admin_data',
  'synced_at',
];

List<JsonMap> dashboardCsvRows(Iterable<StudyParticipant> people) => [
  for (final p in people)
    for (final week in p.weeks)
      {
        'participant_code': p.code,
        'study_path': p.path,
        'group_locked': p.groupLocked,
        'week': week.week,
        'week_complete': week.complete,
        'days_elapsed': week.days.length,
        'days_with_data': week.days.where((d) => d.hasData).length,
        'active_days': week.activeDays,
        'core_quests_done': week.coreDone,
        'core_quests_total': week.coreTotal,
        for (final MapEntry(:key, :value) in targetCategories.entries)
          '${value.toLowerCase()}_target_days': week.targetDays(key),
        'workout_sessions': week.workouts,
        'workout_minutes': week.workoutMinutes,
        'workout_meters': week.workoutMeters,
        'meal_photos_approved': week.mealApproved,
        'meal_photos_rejected': week.mealRejected,
        'meal_photos_pending': week.mealPending,
        'meal_photos_unverified': week.mealUnverified,
        for (final type in usageTypes) ...{
          '${type}_total': week.usage(type).loggedDays == 0
              ? null
              : week.usage(type).total,
          '${type}_days_logged': week.usage(type).loggedDays,
          '${type}_mean_per_logged_day': week
              .usage(type)
              .mean
              ?.toStringAsFixed(2),
        },
        'habit_swaps': week.swaps,
        'admin_items': week.adminItems,
        'includes_admin_data': true,
        'synced_at': p.lastSync?.toIso8601String(),
      },
];
