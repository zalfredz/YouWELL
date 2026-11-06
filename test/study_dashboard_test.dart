import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/application/research_overview.dart';
import 'package:youwell/application/study_dashboard.dart';
import 'package:youwell/core/theme/app_theme.dart';
import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/core/utils/date_key.dart';
import 'package:youwell/features/community/presentation/study_analysis_view.dart';
import 'package:youwell/features/sync/domain/cloud_progress.dart';

import 'support/sim.dart';

/// A coded smoking participant, 12 days in: rokok 5/day on days 1–6, an
/// admin-filled 10 on day 7, 3/day on days 8–11, nothing on day 12.
Future<(JsonMap, DateTime)> smoker({String? studyPath}) async {
  final sim = Sim();
  await sim.start(path: 'reduction');
  for (var day = 0; day < 11; day++) {
    sim.takeCard();
    for (final task in sim.controller.coreQuests) {
      sim.finish(task);
    }
    sim.nextDay();
  }
  final payload = CloudProgress.project(sim.controller.export());
  String day(int n) => shiftDayKey('2026-10-24', n - 1);
  payload['usageTotals'] = [
    for (var n = 1; n <= 6; n++)
      {'day': day(n), 'type': 'rokok', 'total': 5, 'confirmed': true},
    {
      'day': day(7),
      'type': 'rokok',
      'total': 10,
      'confirmed': true,
      'source': 'admin',
    },
    for (var n = 8; n <= 11; n++)
      {'day': day(n), 'type': 'rokok', 'total': 3, 'confirmed': true},
  ];
  payload['adminOpenedDays'] = [day(7)];
  return (
    {
      'account': 'acc-1',
      'code': 'P3',
      'alias': 'daunpagi',
      'updated_at': '2026-11-04T08:00:00+00:00',
      'study_path': studyPath,
      'study_started': studyPath == null ? null : '2026-10-24',
      'payload': payload,
    },
    sim.now,
  );
}

StudyParticipant study(JsonMap row, DateTime now) => StudyParticipant.from(
  ParticipantOverview.fromRow(row, now: now)!,
  now: now,
)!;

void main() {
  test('Weekly means per logged day, compared only with >= 4 days', () async {
    final (row, now) = await smoker();
    final p = study(row, now);
    expect(p.elapsed, 12);
    expect(p.weeks, hasLength(2));
    final first = p.weeks[0].usage('rokok'), second = p.weeks[1].usage('rokok');
    expect((first.total, first.loggedDays), (40, 7));
    expect((second.total, second.loggedDays), (12, 4));
    expect(second.mean, 3);
    final change = usageChange(first, second)!;
    expect(change.difference, closeTo(3 - 40 / 7, 1e-9));
    // An empty day is not zero: day 12 is not logged and not counted.
    expect(p.days.last.usage, isEmpty);
    expect(p.days.last.hasData, isTrue, reason: 'the app was still opened');
    expect(p.weeks[1].usage('vape').mean, isNull);
  });

  test(
    'Recovered admin records count once in the primary data and CSV',
    () async {
      final (row, now) = await smoker();
      final p = study(row, now);
      expect(p.adminItems, 2, reason: 'usage + opened day remain auditable');
      expect(p.weeks[0].usage('rokok').loggedDays, 7);
      expect(p.weeks[0].usage('rokok').total, 40);
      expect(p.days[6].opened, isTrue);
      final rows = dashboardCsvRows([p]);
      expect(rows.first.keys, dashboardCsvColumns);
      expect(rows.first['rokok_mean_per_logged_day'], '5.71');
      expect(rows.first['rokok_total'], 40);
      expect(rows.first['includes_admin_data'], isTrue);
      expect(rows.first['admin_items'], 2);
      expect(rows.first['week_complete'], isTrue);
      expect(rows.last['week_complete'], isFalse);
    },
  );

  test('A zero baseline gives a difference without a percentage', () {
    const zero = UsageWeek(0, 5), later = UsageWeek(4, 4);
    expect(usageChange(zero, later), (difference: 1.0, percent: null));
    expect(usageChange(zero, const UsageWeek(9, 3)), isNull);
  });

  test(
    'Recovered quests, opened days and swaps count in week-four retention',
    () async {
      final (row, _) = await smoker();
      final payload = row['payload'] as JsonMap;
      payload['days'] = {
        '2026-11-14': {
          'quests': [
            {
              'id': 'recovered',
              'status': 'completed',
              'ladder': 'Body',
              'adminCompleted': true,
              'xp': 20,
            },
          ],
        },
      };
      payload['openedDays'] = ['2026-11-16'];
      payload['adminOpenedDays'] = ['2026-11-16'];
      payload['activityDays'] = [];
      payload['habitSwaps'] = [
        {'id': 'admin-swap', 'day': '2026-11-15'},
      ];
      payload['usageTotals'] = [
        {
          'day': '2026-11-14',
          'type': 'rokok',
          'total': 4,
          'confirmed': true,
          'source': 'admin',
        },
      ];
      final now = DateTime(2026, 11, 21);
      final p = study(row, now);
      expect(p.weeks[3].coreDone, 1);
      expect(p.weeks[3].activeDays, 3);
      expect(p.weeks[3].adminItems, 4);
      expect(StudySummary([p]).weekFour.active, 1);
      final exported = dashboardCsvRows([p]).last;
      expect(exported['active_days'], 3);
      expect(exported['core_quests_done'], 1);
      expect(exported['rokok_total'], 4);
      final research = ParticipantOverview.fromRow(
        row,
        now: now,
      )!.researchRows().last;
      expect(research['active_days'], 3);
      expect(research['quests_done'], 1);
    },
  );

  test('The locked study group wins over a later path switch', () async {
    final (row, now) = await smoker(studyPath: 'wellness');
    final p = study(row, now);
    expect(p.path, 'wellness');
    expect(p.groupLocked, isTrue);
    expect(p.pathChanged, isTrue);
    final summary = StudySummary([p]);
    expect(summary.weekFour.provisional, isTrue);
    expect(summary.reached(2), 1);
    expect(summary.reached(3), 0);
  });

  test('Week report: completed weeks only, with n and running', () async {
    final (row, now) = await smoker();
    final later = {
      ...row,
      'account': 'acc-2',
      'code': 'P4',
      'study_started': '2026-11-01',
      'study_path': 'reduction',
    };
    final people = [
      for (final r in [row, later])
        StudyParticipant.from(
          ParticipantOverview.fromRow(r, now: now)!,
          now: now,
        )!,
    ];
    final rows = weekReport(people);
    WeekRow find(String label) => rows.firstWhere((r) => r.label == label);
    final active = find('Peserta aktif (≥ 1 hari)').cells;
    expect((active[0].value, active[0].n, active[0].running), (1.0, 1, 1));
    expect(active[1].value, isNull, reason: 'Week 2 still running for P3');
    expect(active[1].running, 1);
    expect(
      formatWeekValue(find('Peserta aktif (≥ 1 hari)'), active[0]),
      '1 dari 1',
    );
    expect(
      formatWeekValue(find('Peserta aktif (≥ 1 hari)'), active[1]),
      'berjalan',
    );
    final smoking = find('Rata-rata rokok per hari tercatat').cells[0];
    expect(smoking.value, closeTo(40 / 7, 1e-9));
    expect(smoking.n, 1);
    expect(weekReportCsvRows(rows).first.keys, weekReportCsvColumns);

    final lines = weekHighlights(people, now);
    expect(
      lines.first,
      contains('2 peserta berkode (0 wellness, 2 rokok/vape)'),
    );
    expect(lines, contains(startsWith('Week 1: 1 dari 1 peserta aktif')));
    // Week 2 is not complete yet, so no smoking comparison is claimed.
    expect(
      lines.where((l) => l.startsWith('Rokok,')).single,
      contains('2 data belum cukup'),
    );
    expect(lines.last, startsWith('Kualitas data:'));
  });

  testWidgets('Week report reads top to bottom and copies for slides', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    final (row, now) = await smoker();
    final downloaded = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StudyAnalysisView(
              people: [ParticipantOverview.fromRow(row, now: now)!],
              now: now,
              onDownload: (name, csv) => downloaded.add(name),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final title in [
      'Temuan utama',
      'Ringkasan per week',
      'Grafik per week',
      'Progres per peserta',
      'Rokok/vape per peserta',
      'Detail harian peserta',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    expect(
      find.textContaining('Week 1: 1 dari 1 peserta aktif'),
      findsOneWidget,
    );
    expect(find.text('Week 2: -2,7 (-48%) (sementara)'), findsOneWidget);
    expect(find.textContaining('Minggu'), findsNothing);

    await tester.tap(find.text('Salin untuk slide'));
    await tester.pumpAndSettle();
    expect(copied, contains('Temuan utama YouWELL'));
    expect(copied, contains('Metrik\tWeek 1\tWeek 2\tWeek 3\tWeek 4'));
    expect(
      copied,
      contains('Peserta aktif (≥ 1 hari)\t1 dari 1 (n=1)\tberjalan'),
    );

    await tester.tap(find.text('Unduh tabel week (CSV)'));
    await tester.tap(find.text('Unduh data per peserta (CSV)'));
    expect(downloaded, [
      'youwell-ringkasan-week.csv',
      'youwell-dashboard-studi.csv',
    ]);
    await tester.tap(find.text('Tentang data'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Week = 7 hari sejak peserta mulai'),
      findsWidgets,
    );
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Detail harian peserta'));
    await tester.tap(find.text('Detail harian peserta'));
    await tester.pumpAndSettle();
    expect(find.text('Koreksi admin: 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Narrow dark layout: groups switch and nothing overflows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (row, now) = await smoker(studyPath: 'wellness');
    final later = {
      ...row,
      'account': 'acc-2',
      'code': 'P4',
      'study_started': '2026-11-01',
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: StudyAnalysisView(
                people: [
                  ParticipantOverview.fromRow(row, now: now)!,
                  ParticipantOverview.fromRow(later, now: now)!,
                ],
                now: now,
                onDownload: (_, _) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Wellness (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Rokok/vape per peserta'), findsNothing);
    expect(find.textContaining('1 berjalan'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  group('Cek perubahan konsumsi', () {
    /// A smoker with [daily] totals from day 1 (null = not logged),
    /// [days] study days in.
    StudyParticipant smokerWith(List<int?> daily, {int days = 15}) {
      final now = DateTime(2026, 10, 24 + days - 1, 20);
      final row = {
        'account': 'a',
        'code': 'P2',
        'study_path': 'reduction',
        'study_started': '2026-10-24',
        'payload': {
          'schemaVersion': 1,
          'version': 3,
          'profile': {
            'alias': 'p2',
            'path': 'reduction',
            'started': '2026-10-24',
          },
          'days': {},
          'capacity': {},
          'openedDays': [],
          'activityDays': [],
          'workoutSessions': [],
          'mealCheckIns': [],
          'habitDelays': [],
          'habitSwaps': [],
          'usageTotals': [
            for (final (i, total) in daily.indexed)
              if (total != null)
                {
                  'day': shiftDayKey('2026-10-24', i),
                  'type': 'rokok',
                  'total': total,
                  'confirmed': true,
                },
          ],
        },
      };
      return StudyParticipant.from(
        ParticipantOverview.fromRow(row, now: now)!,
        now: now,
      )!;
    }

    test('Halved use, zero days and a falling trend', () {
      final o = UsageOutcome(
        smokerWith([10, 10, 10, 10, 10, 10, 10, 5, 5, 4, 0, 5, 6, 0]),
        'rokok',
      );
      expect(o.first!.mean, 10);
      expect(o.lastWeek, 2);
      expect(o.last!.mean, 25 / 7);
      expect(o.lastZeroDays, 2);
      expect(o.category, 'Turun ≥ 50%');
      expect(o.slopePerWeek, isNegative);
      expect(usageOutcomeCsvRows([o]).single.keys, usageOutcomeCsvColumns);
    });

    test('Too few logged days, or a running week, are not compared', () {
      final sparse = UsageOutcome(
        smokerWith([
          10,
          10,
          10,
          10,
          10,
          10,
          10,
          5,
          null,
          null,
          null,
          5,
          null,
          null,
        ]),
        'rokok',
      );
      expect(sparse.category, 'Data belum cukup');
      final running = UsageOutcome(
        smokerWith([8, 8, 8, 8, 8, 8, 8, 4, 4, 4, 4], days: 11),
        'rokok',
      );
      expect(running.lastWeek, isNull, reason: 'Week 2 is not over');
      expect(running.category, 'Data belum cukup');
    });

    test('Bands and a zero week 1', () {
      String band(List<int?> week2) => UsageOutcome(
        smokerWith([10, 10, 10, 10, 10, 10, 10, ...week2]),
        'rokok',
      ).category;
      expect(band([7, 7, 7, 7, 7, 7, 7]), 'Turun 20–49%');
      expect(band([9, 9, 11, 10, 9, 10, 10]), 'Stabil (±20%)');
      expect(band([13, 13, 13, 13, 13, 13, 13]), 'Naik > 20%');
      final zero = UsageOutcome(
        smokerWith([0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0]),
        'rokok',
      );
      expect(zero.change!.percent, isNull);
      expect(zero.category, 'Naik > 20%');
      expect(median([3, 1, 2]), 2);
      expect(median([4, 1, 3, 2]), 2.5);
      expect(
        usageOutcomeHighlights([
          UsageOutcome(
            smokerWith([10, 10, 10, 10, 10, 10, 10, 5, 5, 5, 5, 5, 5, 5]),
            'rokok',
          ),
        ]).single,
        contains('1 turun ≥ 50%; median -50%'),
      );
    });
  });
}
