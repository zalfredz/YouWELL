import 'package:flutter/material.dart';
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

  testWidgets(
    'Charts lead the view; corrections are primary data and details stay collapsed',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (row, now) = await smoker();
      String? downloaded;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: StudyAnalysisView(
                people: [ParticipantOverview.fromRow(row, now: now)!],
                now: now,
                onDownload: (name, csv) => downloaded = name,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final title in [
        'Keaktifan selama 4 minggu',
        'Aktif minggu 4',
        'P3 · Rokok (batang/hari)',
        'Detail peserta',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      expect(find.text('Sertakan data intervensi admin'), findsNothing);
      expect(find.text('Batas tafsir'), findsNothing);
      expect(find.textContaining('Koreksi admin:'), findsNothing);
      // Nobody reached week 4 yet: no 0 that reads as "nobody active".
      expect(find.text('Belum ada yang mencapai minggu 4'), findsOneWidget);

      await tester.tap(find.text('Unduh CSV'));
      expect(downloaded, 'youwell-dashboard-studi.csv');
      await tester.tap(find.text('Tentang data'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('selalu masuk dalam grafik serta CSV'),
        findsOneWidget,
      );
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Detail peserta'));
      await tester.tap(find.text('Detail peserta'));
      await tester.pumpAndSettle();
      expect(find.text('Koreksi admin: 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Completed wellness weeks show n; narrow dark layout remains usable',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
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
      expect(find.textContaining('n=1'), findsOneWidget);
      expect(find.text('Angka per peserta'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
