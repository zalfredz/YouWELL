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

  /// Habit Swap moments per type: tried, ended "tidak jadi" (skipped) and
  /// "tetap memakai" (used). Synced since phase 13.
  final swapResults = <String, ({int tried, int skipped, int used})>{};

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

  ({int tried, int skipped, int used}) swapResult(String type) {
    var tried = 0, skipped = 0, used = 0;
    for (final d in days) {
      if (d.swapResults[type] case final r?) {
        tried += r.tried;
        skipped += r.skipped;
        used += r.used;
      }
    }
    return (tried: tried, skipped: skipped, used: used);
  }

  /// Share of moments with a chosen result that ended "tidak jadi".
  double? skipRate(String type) {
    final r = swapResult(type);
    final resolved = r.skipped + r.used;
    return resolved == 0 ? null : r.skipped / resolved;
  }

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
        in ((payload['swapResults'] ?? const []) as List).whereType<Map>()) {
      final day = on(row['day']);
      final type = row['type']?.toString();
      if (day == null || !usageTypes.contains(type)) continue;
      int count(String key) => (row[key] as num?)?.toInt() ?? 0;
      day.swapResults[type!] = (
        tried: count('tried'),
        skipped: count('skipped'),
        used: count('used'),
      );
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
final dashboardCsvColumns = [
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
  for (final type in usageTypes) ...[
    'swap_${type}_tried',
    'swap_${type}_skipped',
    'swap_${type}_used',
  ],
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
        for (final type in usageTypes) ...{
          'swap_${type}_tried': week.swapResult(type).tried,
          'swap_${type}_skipped': week.swapResult(type).skipped,
          'swap_${type}_used': week.swapResult(type).used,
        },
        'admin_items': week.adminItems,
        'includes_admin_data': true,
        'synced_at': p.lastSync?.toIso8601String(),
      },
];

// ---------------------------------------------------------------------------
// Week report (checkpoint presentations): a Week is 7 study days from each
// participant's start (Week 1 = days 1–7), not a calendar week. Group
// numbers use completed weeks only; the participants behind each number
// are shown as n, and those still inside that week as "running".

/// One number of the week table: [value] over the [n] participants whose
/// week is complete; [running] are still inside that week.
class WeekCell {
  const WeekCell(this.value, this.n, this.running);
  final double? value;
  final int n, running;
}

/// One row of the week table. [count] rows show "value of n".
class WeekRow {
  const WeekRow({
    required this.group,
    required this.label,
    required this.cells,
    this.unit = '',
    this.count = false,
    this.note,
  });
  final String group, label, unit;
  final List<WeekCell> cells;
  final bool count;
  final String? note;
}

String formatWeekValue(WeekRow row, WeekCell cell) {
  final value = cell.value;
  if (value == null) return cell.running > 0 ? 'berjalan' : '–';
  if (row.count) return '${value.round()} dari ${cell.n}';
  final text = value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1).replaceAll('.', ',');
  return '$text${row.unit}';
}

/// [products] limits the smoking/vaping rows (the Rokok or Vape view).
List<WeekRow> weekReport(
  List<StudyParticipant> people, {
  List<String> products = usageTypes,
}) {
  WeekCell cell(
    int week,
    Iterable<StudyParticipant> group,
    num? Function(StudyParticipant p, StudyWeek w) value, {
    bool sum = false,
  }) {
    final values = <num>[];
    var running = 0;
    for (final p in group) {
      if (week >= p.weeks.length) continue;
      final w = p.weeks[week];
      if (!w.complete) {
        running++;
        continue;
      }
      if (value(p, w) case final v?) values.add(v);
    }
    final total = values.fold<num>(0, (a, b) => a + b);
    return WeekCell(
      values.isEmpty ? null : (sum ? total : total / values.length).toDouble(),
      values.length,
      running,
    );
  }

  List<WeekCell> cells(
    Iterable<StudyParticipant> group,
    num? Function(StudyParticipant p, StudyWeek w) value, {
    bool sum = false,
  }) => [for (var w = 0; w < 4; w++) cell(w, group, value, sum: sum)];

  final reduction = people.where((p) => p.reduction).toList();
  return [
    WeekRow(
      group: 'Keterlibatan',
      label: 'Peserta aktif (≥ 1 hari)',
      count: true,
      cells: cells(people, (p, w) => w.activeDays > 0 ? 1 : 0, sum: true),
    ),
    WeekRow(
      group: 'Keterlibatan',
      label: 'Rata-rata hari aktif',
      unit: ' dari 7 hari',
      cells: cells(people, (p, w) => w.activeDays),
    ),
    WeekRow(
      group: 'Keterlibatan',
      label: 'Misi inti selesai',
      unit: '%',
      note: 'rata-rata per peserta',
      cells: cells(
        people,
        (p, w) => w.coreRate == null ? null : w.coreRate! * 100,
      ),
    ),
    WeekRow(
      group: 'Keterlibatan',
      label: 'Misi inti selesai per peserta',
      unit: ' misi',
      cells: cells(people, (p, w) => w.coreDone),
    ),
    for (final MapEntry(:key, :value) in targetCategories.entries)
      WeekRow(
        group: 'Target harian tercapai',
        label: value,
        unit: ' hari',
        note: key == 'Energy'
            ? 'tidur s.d. 4 Nov, Hibernasi mulai 5 Nov'
            : null,
        cells: cells(people, (p, w) => w.targetDays(key)),
      ),
    WeekRow(
      group: 'Target harian tercapai',
      label: 'Foto makan disetujui',
      unit: ' foto',
      cells: cells(people, (p, w) => w.mealApproved),
    ),
    if (reduction.isNotEmpty) ...[
      for (final (type, unit) in const [('rokok', 'batang'), ('vape', 'sesi')])
        // A product nobody logs gets no rows of dashes.
        if (products.contains(type) &&
            reduction.any((p) => p.types.contains(type))) ...[
          WeekRow(
            group: 'Rokok/vape',
            label:
                'Peserta ${type == 'rokok' ? 'rokok' : 'vape'} dengan ≥ 4 hari tercatat',
            count: true,
            cells: [
              for (var w = 0; w < 4; w++)
                () {
                  final users = reduction.where((p) => p.types.contains(type));
                  final c = cell(
                    w,
                    users,
                    (p, wk) => wk.usage(type).comparable ? 1 : 0,
                    sum: true,
                  );
                  return c;
                }(),
            ],
          ),
          WeekRow(
            group: 'Rokok/vape',
            label:
                'Rata-rata ${type == 'rokok' ? 'rokok' : 'vape'} per hari tercatat',
            unit: ' $unit',
            note: 'peserta dengan ≥ 4 hari tercatat',
            cells: cells(
              reduction.where((p) => p.types.contains(type)),
              (p, w) => w.usage(type).comparable ? w.usage(type).mean : null,
            ),
          ),
        ],
      for (final type in usageTypes)
        if (products.contains(type) &&
            reduction.any(
              (p) => p.days.any((d) => d.swapResults.containsKey(type)),
            ))
          WeekRow(
            group: 'Rokok/vape',
            label:
                'Momen Habit Swap tidak jadi ${type == 'rokok' ? 'merokok' : 'vape'}',
            unit: '%',
            note: 'dari momen yang hasilnya dipilih, rata-rata per peserta',
            cells: cells(
              reduction,
              (p, w) =>
                  w.skipRate(type) == null ? null : w.skipRate(type)! * 100,
            ),
          ),
      WeekRow(
        group: 'Rokok/vape',
        label: 'Habit Swap per peserta',
        unit: ' kali',
        cells: cells(reduction, (p, w) => w.swaps),
      ),
    ],
    WeekRow(
      group: 'Kualitas data',
      label: 'Hari berisi data',
      unit: '%',
      cells: cells(
        people,
        (p, w) => w.days.where((d) => d.hasData).length / w.days.length * 100,
      ),
    ),
    WeekRow(
      group: 'Kualitas data',
      label: 'Isian koreksi admin',
      unit: ' isian',
      note: 'jumlah',
      cells: cells(people, (p, w) => w.adminItems, sum: true),
    ),
  ];
}

/// Week table rows for a spreadsheet: one row per metric, value and n per
/// week.
List<JsonMap> weekReportCsvRows(List<WeekRow> rows) => [
  for (final row in rows)
    {
      'kelompok': row.group,
      'metrik': row.label,
      'satuan': row.count ? 'jumlah peserta' : row.unit.trim(),
      for (var w = 0; w < 4; w++) ...{
        'week_${w + 1}': row.cells[w].value?.toStringAsFixed(2),
        'n_week_${w + 1}': row.cells[w].n,
        'berjalan_week_${w + 1}': row.cells[w].running,
      },
    },
];

final weekReportCsvColumns = [
  'kelompok',
  'metrik',
  'satuan',
  for (var w = 1; w <= 4; w++) ...['week_$w', 'n_week_$w', 'berjalan_week_$w'],
];

// ---------------------------------------------------------------------------
// Change in reported use (smoking/vaping path). Descriptive only: week 1 is
// already a week of app use, there is no comparison group, and totals are
// self-reported, so this shows change during use, not effectiveness.
// Weeks are compared only when complete and with >= 4 logged days.

/// Change categories, most reduction first.
const usageCategories = [
  'Turun ≥ 50%',
  'Turun 20–49%',
  'Stabil (±20%)',
  'Naik > 20%',
  'Data belum cukup',
];

class UsageOutcome {
  UsageOutcome._(this.participant, this.type);

  /// One product of one participant, from its completed weeks.
  factory UsageOutcome(StudyParticipant participant, String type) {
    final outcome = UsageOutcome._(participant, type);
    final complete = [
      for (final w in participant.weeks)
        if (w.complete) w,
    ];
    if (complete.isNotEmpty) {
      outcome.first = complete.first.usage(type);
      outcome.firstZeroDays = complete.first.days
          .where((d) => d.usage[type] == 0)
          .length;
      final index = complete.lastIndexWhere((w) => w.usage(type).comparable);
      if (index > 0) {
        outcome.lastWeek = complete[index].week;
        outcome.last = complete[index].usage(type);
        outcome.lastZeroDays = complete[index].days
            .where((d) => d.usage[type] == 0)
            .length;
      }
    }
    // Least-squares slope over every logged day, per week.
    final points = [
      for (final d in participant.days)
        if (d.usage[type] case final total?)
          (d.number.toDouble(), total.toDouble()),
    ];
    outcome.loggedDays = points.length;
    if (points.length >= 8) {
      final mx = points.fold(0.0, (s, p) => s + p.$1) / points.length;
      final my = points.fold(0.0, (s, p) => s + p.$2) / points.length;
      final sxx = points.fold(0.0, (s, p) => s + (p.$1 - mx) * (p.$1 - mx));
      final sxy = points.fold(0.0, (s, p) => s + (p.$1 - mx) * (p.$2 - my));
      if (sxx > 0) outcome.slopePerWeek = sxy / sxx * 7;
    }
    return outcome;
  }

  final StudyParticipant participant;
  final String type;
  UsageWeek? first, last;
  int? lastWeek;
  int firstZeroDays = 0, lastZeroDays = 0, loggedDays = 0;
  double? slopePerWeek;

  String get unit => type == 'rokok' ? 'batang' : 'sesi';

  ({double difference, double? percent})? get change =>
      first == null || last == null ? null : usageChange(first!, last!);

  String get category {
    final c = change;
    if (c == null) return usageCategories.last;
    final percent = c.percent;
    if (percent == null) {
      // Week 1 was 0: only a rise or staying at 0 is possible.
      return c.difference > 0 ? 'Naik > 20%' : 'Stabil (±20%)';
    }
    if (percent <= -.5) return 'Turun ≥ 50%';
    if (percent <= -.2) return 'Turun 20–49%';
    if (percent < .2) return 'Stabil (±20%)';
    return 'Naik > 20%';
  }
}

List<UsageOutcome> usageOutcomes(
  Iterable<StudyParticipant> people, {
  List<String> products = usageTypes,
}) => [
  for (final p in people.where((p) => p.reduction))
    for (final type in p.types)
      if (products.contains(type)) UsageOutcome(p, type),
];

/// Everyone who logs [type], per study day 1–28: the mean of the confirmed
/// totals of those who logged that day, and how many did. Days nobody
/// logged have no mean (an empty day is not zero).
List<({int day, double? mean, int n})> groupDailyUsage(
  Iterable<StudyParticipant> people,
  String type,
) => [
  for (var day = 1; day <= studyDays; day++)
    () {
      final totals = [
        for (final p in people)
          if (day <= p.days.length)
            if (p.days[day - 1].usage[type] case final total?) total,
      ];
      return (
        day: day,
        mean: totals.isEmpty
            ? null
            : totals.reduce((a, b) => a + b) / totals.length,
        n: totals.length,
      );
    }(),
];

/// The same participants in Week 1 and their comparison week: mean of the
/// participant means at both points, and how many pairs.
({double? first, double? last, int n}) pairedUsage(
  List<UsageOutcome> outcomes,
) {
  final pairs = [
    for (final o in outcomes)
      if (o.change != null) (o.first!.mean!, o.last!.mean!),
  ];
  if (pairs.isEmpty) return (first: null, last: null, n: 0);
  double mean(Iterable<double> v) => v.reduce((a, b) => a + b) / v.length;
  return (
    first: mean(pairs.map((p) => p.$1)),
    last: mean(pairs.map((p) => p.$2)),
    n: pairs.length,
  );
}

/// Median of [values]; null when empty.
double? median(Iterable<double> values) {
  final sorted = [...values]..sort();
  if (sorted.isEmpty) return null;
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
}

const usageOutcomeCsvColumns = [
  'participant_code',
  'produk',
  'hari_tercatat_total',
  'week1_rata_rata',
  'week1_hari_tercatat',
  'week1_hari_nol',
  'week_pembanding',
  'pembanding_rata_rata',
  'pembanding_hari_tercatat',
  'pembanding_hari_nol',
  'selisih',
  'persen',
  'kategori',
  'tren_per_week',
];

List<JsonMap> usageOutcomeCsvRows(List<UsageOutcome> outcomes) => [
  for (final o in outcomes)
    {
      'participant_code': o.participant.code,
      'produk': o.type,
      'hari_tercatat_total': o.loggedDays,
      'week1_rata_rata': o.first?.mean?.toStringAsFixed(2),
      'week1_hari_tercatat': o.first?.loggedDays,
      'week1_hari_nol': o.first == null ? null : o.firstZeroDays,
      'week_pembanding': o.lastWeek,
      'pembanding_rata_rata': o.last?.mean?.toStringAsFixed(2),
      'pembanding_hari_tercatat': o.last?.loggedDays,
      'pembanding_hari_nol': o.last == null ? null : o.lastZeroDays,
      'selisih': o.change?.difference.toStringAsFixed(2),
      'persen': o.change?.percent == null
          ? null
          : (o.change!.percent! * 100).toStringAsFixed(1),
      'kategori': o.category,
      'tren_per_week': o.slopePerWeek?.toStringAsFixed(2),
    },
];
