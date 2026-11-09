// Preview only: renders the BAB 4 view with made-up data for 10 participants
// to ~/Downloads/YouWELL_Screenshots/bab4. Run:
// flutter test tool/capture_bab4_test.dart (not part of the suite).
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/application/research_overview.dart';
import 'package:youwell/core/theme/app_theme.dart';
import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/core/utils/date_key.dart';
import 'package:youwell/features/community/presentation/bab4_analysis_view.dart';
import 'package:youwell/features/sync/domain/cloud_progress.dart';

import '../test/support/sim.dart';
import 'capture_screens_test.dart' show loadFonts;

final out =
    '${Platform.environment['HOME']}/Downloads/YouWELL_Screenshots/bab4';
final shotKey = GlobalKey();

/// [activeUntil]: last active day; [skipEvery]: inactive every n-th day.
Future<(JsonMap, DateTime)> person(
  String code, {
  String path = 'wellness',
  int activeUntil = 28,
  int skipEvery = 0,
  String? product,
  double start = 0,
  double end = 0,
  int seed = 1,
}) async {
  final random = Random(seed);
  final sim = Sim();
  await sim.start(path: path);
  final active = <String>[];
  for (var day = 1; day <= 28; day++) {
    final on = day <= activeUntil && (skipEvery == 0 || day % skipEvery != 0);
    if (on) {
      active.add(dayKey(sim.now));
      sim.takeCard();
      final quests = [...sim.controller.coreQuests];
      final done = random.nextDouble() < .7 ? quests.length : 1;
      for (final task in quests.take(done)) {
        sim.finish(task);
      }
    }
    sim.nextDay();
  }
  final payload = CloudProgress.project(sim.controller.export());
  payload['openedDays'] = active;
  payload['activityDays'] = active;
  if (product != null) {
    String day(int n) => shiftDayKey('2026-10-24', n - 1);
    payload['usageTotals'] = [
      for (var n = 1; n <= 28; n++)
        if (n <= activeUntil && random.nextDouble() < .85)
          {
            'day': day(n),
            'type': product,
            'total': (start + (end - start) * (n - 1) / 27 + random.nextInt(3))
                .round(),
            'confirmed': true,
          },
    ];
    payload['swapResults'] = [
      for (var n = 1; n <= 28; n++)
        if (n <= activeUntil && random.nextDouble() < .5)
          () {
            final skipped = random.nextInt(3), used = random.nextInt(2);
            return {
              'day': day(n),
              'type': product,
              'tried': skipped + used,
              'skipped': skipped,
              'used': used,
            };
          }(),
    ];
  }
  return (
    {
      'account': 'acc-$code',
      'code': code,
      'alias': 'peserta$code',
      'study_path': path,
      'study_started': '2026-10-24',
      'payload': payload,
    },
    sim.now,
  );
}

void main() {
  testWidgets('BAB 4 preview', (t) async {
    await t.runAsync(loadFonts);
    final rows = [
      await person('P1', seed: 1),
      await person('P2', skipEvery: 4, seed: 2),
      await person('P3', activeUntil: 17, seed: 3),
      await person('P4', skipEvery: 3, seed: 4),
      for (final (i, code) in ['P5', 'P6', 'P7'].indexed)
        await person(
          code,
          path: 'reduction',
          product: 'rokok',
          start: 12.0 - i * 2,
          end: 7.0 - i,
          skipEvery: i == 2 ? 5 : 0,
          activeUntil: i == 1 ? 24 : 28,
          seed: 10 + i,
        ),
      for (final (i, code) in ['P8', 'P9', 'P10'].indexed)
        await person(
          code,
          path: 'reduction',
          product: 'vape',
          start: 16.0 - i * 3,
          end: 12.0 - i * 2,
          skipEvery: i == 0 ? 6 : 0,
          activeUntil: i == 2 ? 13 : 28,
          seed: 20 + i,
        ),
    ];
    final now = rows.first.$2;
    final people = [
      for (final (row, _) in rows) ParticipantOverview.fromRow(row, now: now)!,
    ];
    t.view.physicalSize = const Size(1280 * 1.5, 5200 * 1.5);
    t.view.devicePixelRatio = 1.5;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: shotKey,
              child: Material(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Bab4AnalysisView(
                    people: people,
                    now: now,
                    onDownload: (_, _) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Future<void> snap(String name) async {
      await t.pumpAndSettle();
      final boundary =
          shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await t.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final dir = Directory(out)..createSync(recursive: true);
        File(
          '${dir.path}/$name.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    await snap('1_semua');
    for (final (i, label) in ['Wellness', 'Rokok', 'Vape'].indexed) {
      await t.tap(
        find.byWidgetPredicate(
          (w) =>
              w is ChoiceChip &&
              w.label is Text &&
              (w.label as Text).data!.startsWith(label),
        ),
      );
      await snap('${i + 2}_${label.toLowerCase()}');
    }

    // The same people on day 19: weeks 1–2 over, week 3 running.
    final day19 = DateTime(2026, 11, 11, 20);
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: shotKey,
              child: Material(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Bab4AnalysisView(
                    key: const ValueKey('day19'),
                    people: [
                      for (final (row, _) in rows)
                        ParticipantOverview.fromRow(row, now: day19)!,
                    ],
                    now: day19,
                    onDownload: (_, _) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(
      find.byWidgetPredicate(
        (w) =>
            w is ChoiceChip &&
            w.label is Text &&
            (w.label as Text).data!.startsWith('Rokok'),
      ),
    );
    await snap('5_rokok_hari19');
  });
}
