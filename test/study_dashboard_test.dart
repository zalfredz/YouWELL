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

StudyParticipant study(JsonMap row, DateTime now, {bool admin = true}) =>
    StudyParticipant.from(
      ParticipantOverview.fromRow(row, now: now)!,
      now: now,
      includeAdmin: admin,
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

  test('Without admin data the numbers change and the CSV says so', () async {
    final (row, now) = await smoker();
    final withAdmin = study(row, now);
    final without = study(row, now, admin: false);
    expect(withAdmin.adminItems, 2, reason: 'usage + opened day');
    expect(without.adminItems, 0);
    expect(without.weeks[0].usage('rokok').loggedDays, 6);
    expect(without.weeks[0].usage('rokok').mean, 5);
    expect(without.days[6].opened, isFalse);

    final rows = dashboardCsvRows([without], includeAdmin: false);
    expect(rows.first.keys, dashboardCsvColumns);
    expect(rows.first['rokok_mean_per_logged_day'], '5.00');
    expect(rows.first['includes_admin_data'], isFalse);
    expect(rows.first['week_complete'], isTrue);
    expect(rows.last['week_complete'], isFalse);
  });

  test('A zero baseline gives a difference without a percentage', () {
    const zero = UsageWeek(0, 5), later = UsageWeek(4, 4);
    expect(usageChange(zero, later), (difference: 1.0, percent: null));
    expect(usageChange(zero, const UsageWeek(9, 3)), isNull);
  });

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

  testWidgets('Analysis view renders the study sections and toggles admin '
      'data', (tester) async {
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
      'Batas tafsir',
      'A. Ringkasan studi',
      'B. Jalur wellness',
      'C. Jalur rokok/vape',
      'D. Detail peserta dan kualitas data',
      'P3 · Rokok (batang/hari)',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    expect(
      find.textContaining('Aktif minggu ke-4 (sementara)'),
      findsOneWidget,
    );
    expect(find.textContaining('2 isian admin'), findsOneWidget);

    await tester.tap(find.text('Sertakan data intervensi admin'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Isian admin tidak dihitung'), findsOneWidget);
    await tester.tap(find.text('Unduh data grafik (CSV)'));
    expect(downloaded, 'youwell-dashboard-studi-tanpa-admin.csv');
    expect(tester.takeException(), isNull);
  });
}
