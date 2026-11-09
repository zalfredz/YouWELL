import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/application/bab4_report.dart';
import 'package:youwell/application/research_overview.dart';
import 'package:youwell/core/theme/app_theme.dart';
import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/features/community/presentation/bab4_analysis_view.dart';
import 'package:youwell/features/sync/domain/cloud_progress.dart';

import 'study_dashboard_test.dart' show smoker, study;
import 'support/sim.dart';

/// A coded wellness participant who did every core mission for [days] days.
Future<(JsonMap, DateTime)> wellness({int days = 10}) async {
  final sim = Sim();
  await sim.start();
  for (var day = 0; day < days; day++) {
    sim.takeCard();
    for (final task in sim.controller.coreQuests) {
      sim.finish(task);
    }
    sim.nextDay();
  }
  return (
    {
      'account': 'acc-2',
      'code': 'P1',
      'alias': 'pagicerah',
      'payload': CloudProgress.project(sim.controller.export()),
    },
    sim.now,
  );
}

void main() {
  test('Groups: rokok/vape follow the logged product', () async {
    final (row, now) = await smoker();
    final p = study(row, now);
    expect(bab4Members([p], 'all'), [p]);
    expect(bab4Members([p], 'rokok'), [p]);
    expect(bab4Members([p], 'vape'), isEmpty);
    expect(bab4Members([p], 'wellness'), isEmpty);
    expect(reductionWithoutProduct([p]), isEmpty);
  });

  test('Engagement per week and criterion 3 stay provisional', () async {
    final (row, now) = await smoker();
    final p = study(row, now);
    final weeks = engagementByWeek([p]);
    expect(weeks[0].n, 1);
    expect(weeks[0].active, 1);
    expect(weeks[0].provisional, isFalse);
    expect(weeks[0].activeDays, 7);
    expect(weeks[1].provisional, isTrue, reason: 'day 12 of week 2');
    expect(weeks[2].n, 0);

    final c = criterion3([p]);
    expect(c.reached, 0);
    expect(c.met, isNull, reason: 'nobody reached week 4 yet');
  });

  test('Appendix A.5 rows and CSV', () async {
    final (row, now) = await smoker();
    final p = study(row, now);
    final rows = a5Rows([p]);
    expect(rows.map((r) => r.week.week), [1, 2]);
    expect(rows.first.status, 'ya');
    expect(rows.first.coreDone, greaterThan(0));
    expect(rows.first.swaps, isNotNull, reason: 'smoking/vaping path');
    final csv = a5CsvRows([p]);
    expect(csv.first.keys, a5CsvColumns);
    expect(csv.first['kode'], 'P3');
    expect(csv.first['jalur'], 'rokok_vape');
  });

  test('Logged use: week 1 against the last week with >= 4 days', () async {
    final (row, now) = await smoker();
    final u = UsageCase(study(row, now), 'rokok');
    expect(u.weeks.map((w) => w.loggedDays), [7, 4]);
    expect(u.loggedDays, 11);
    // Day 12: week 2 still runs and the 28 days are not over.
    expect(u.weekPercent(1), isNull);
    expect(u.change, isNull);
    expect(medianUsageChange([u]), isNull);

    // After day 28 (no more logs): week 2 counts, weeks 3–4 have no data.
    final done = UsageCase(
      study(row, now.add(const Duration(days: 20))),
      'rokok',
    );
    final percent = (3 - 40 / 7) / (40 / 7) * 100;
    expect(done.weekPercent(1), closeTo(percent, 1e-6));
    expect(done.weekPercent(2), isNull, reason: 'nothing logged');
    expect(done.change!.week, 2);
    expect(done.change!.change.difference, closeTo(3 - 40 / 7, 1e-9));
    expect(medianUsageChange([done]), closeTo(percent, 1e-6));
  });

  test('Mission levels per pillar come from the daily cards', () async {
    final (row, now) = await wellness();
    final p = study(row, now);
    expect(p.reduction, isFalse);
    final levels = [
      for (final key in const ['Body', 'Lifestyle', 'Food', 'Energy'])
        levelChange(p, key),
    ].nonNulls;
    expect(levels, isNotEmpty);
    for (final l in levels) {
      expect(l.last, greaterThanOrEqualTo(l.first));
    }
  });

  testWidgets('BAB 4 view: four groups render their sections', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (smokerRow, now) = await smoker();
    final (wellnessRow, _) = await wellness();
    final people = [
      ParticipantOverview.fromRow(smokerRow, now: now)!,
      ParticipantOverview.fromRow(wellnessRow, now: now)!,
    ];
    final downloads = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Bab4AnalysisView(
              people: people,
              now: now,
              onDownload: (name, _) => downloads.add(name),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Keterlibatan minggu 4'), findsOneWidget);
    expect(find.text('Perbandingan jalur (eksploratif)'), findsOneWidget);
    expect(find.text('Rekap log pemakaian (Lampiran A.5)'), findsOneWidget);

    Finder chip(String label) => find.widgetWithText(ChoiceChip, label);
    await tester.tap(chip('Wellness (n = 1)'));
    await tester.pumpAndSettle();
    expect(find.text('Target per pilar'), findsOneWidget);
    expect(find.text('Level misi'), findsOneWidget);
    expect(find.text('Pola harian'), findsOneWidget);

    await tester.tap(chip('Rokok (n = 1)'));
    await tester.pumpAndSettle();
    expect(find.text('Habit Swap per minggu'), findsOneWidget);
    expect(find.text('Konsumsi yang dicatat peserta'), findsOneWidget);
    await tester.tap(find.text('Unduh A.5 (CSV)'));
    expect(downloads, ['youwell-a5-log-rokok.csv']);

    await tester.tap(chip('Vape (n = 0)'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada peserta di kelompok ini.'), findsOneWidget);
  });
}
