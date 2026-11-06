import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/application/admin_progress_editor.dart';
import 'package:youwell/application/research_overview.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/application/study_dashboard.dart';
import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/features/sync/domain/cloud_progress.dart';

import 'support/sim.dart';

/// Habit Swap results as research data (phase 13): daily counts per
/// product only; the moments themselves stay on the phone.
void main() {
  Future<Sim> smokerWithMoments(List<String> outcomes) async {
    final sim = Sim();
    await sim.start(path: 'reduction');
    for (final (i, outcome) in outcomes.indexed) {
      sim.controller.recordHabitSwap(
        eventId: 'moment-$i',
        product: 'cigarette',
        trigger: 'after_meal',
        activity: 'walk',
        outcome: outcome,
      );
    }
    return sim;
  }

  test('Only counts leave the phone', () async {
    final sim = await smokerWithMoments(['skipped', 'skipped', 'used']);
    final payload = CloudProgress.project(sim.controller.export());
    expect(payload['swapResults'], [
      {
        'day': '2026-10-24',
        'type': 'rokok',
        'tried': 3,
        'skipped': 2,
        'used': 1,
      },
    ]);
    final text = jsonEncode(payload);
    for (final private in ['outcome', 'trigger', 'activity', 'eventId']) {
      expect(text, isNot(contains('"$private"')), reason: private);
    }
  });

  test('A wellness snapshot has no swapResults key at all', () async {
    final sim = Sim();
    await sim.start();
    expect(
      CloudProgress.project(sim.controller.export()),
      isNot(contains('swapResults')),
    );
  });

  test('A reinstalled phone keeps the cloud counts instead of zeros', () async {
    final sim = await smokerWithMoments(['skipped', 'used']);
    final cloud = CloudProgress.project(sim.controller.export());
    // A new phone: only the cloud copy, the moments arrive without outcomes.
    final restored = CloudProgress.apply(cloud, null);
    final again = CloudProgress.project(restored);
    expect(again['swapResults'], cloud['swapResults']);
  });

  test('Dashboard: share of moments that ended "tidak jadi"', () async {
    final sim = await smokerWithMoments([
      'skipped',
      'skipped',
      'skipped',
      'used',
    ]);
    for (var day = 0; day < 7; day++) {
      sim.nextDay();
    }
    final payload = CloudProgress.project(sim.controller.export());
    final JsonMap row = {
      'account': 'a',
      'code': 'P3',
      'study_path': 'reduction',
      'study_started': '2026-10-24',
      'payload': payload,
    };
    final p = StudyParticipant.from(
      ParticipantOverview.fromRow(row, now: sim.now)!,
      now: sim.now,
    )!;
    expect(p.weeks.first.complete, isTrue);
    expect(p.weeks.first.swapResult('rokok'), (tried: 4, skipped: 3, used: 1));
    expect(p.weeks.first.skipRate('rokok'), .75);
    final rows = weekReport([p], products: ['rokok']);
    final share = rows.firstWhere(
      (r) => r.label == 'Momen Habit Swap tidak jadi merokok',
    );
    expect(share.cells.first.value, 75);
    final csv = dashboardCsvRows([p]).first;
    expect(csv['swap_rokok_skipped'], 3);
    expect(csv.keys, dashboardCsvColumns);
  });

  test('Admin restores results per day; they win over the phone and are '
      'marked', () async {
    final sim = await smokerWithMoments(['skipped']);
    final payload = CloudProgress.project(sim.controller.export());
    final editor = AdminProgressEditor(payload, now: sim.now);
    final day = editor.days.first;
    editor
      ..setSwapResult(day, 'rokok', skipped: 3)
      ..setSwapResult(day, 'rokok', used: 2)
      ..setSwapResult(day, 'vape', used: 1);
    expect(editor.swapResult(day, 'rokok'), (tried: 5, skipped: 3, used: 2));
    expect(
      editor.changes.map(describeChange),
      containsAll([
        '$day: Habit Swap rokok: 3 tidak jadi, 2 tetap memakai',
        '$day: Habit Swap vape: 0 tidak jadi, 1 tetap memakai',
      ]),
    );

    // The phone still holds its own moment (1 skipped); the admin's day wins.
    final phone = CloudProgress.apply(editor.payload, sim.controller.export());
    final rokok = (CloudProgress.project(phone)['swapResults'] as List)
        .firstWhere((r) => r['type'] == 'rokok');
    expect(rokok, {
      'day': day,
      'type': 'rokok',
      'tried': 5,
      'skipped': 3,
      'used': 2,
      'source': 'admin',
    });

    final p = StudyParticipant.from(
      ParticipantOverview.fromRow({
        'account': 'a',
        'code': 'P3',
        'study_path': 'reduction',
        'study_started': day,
        'payload': editor.payload,
      }, now: sim.now)!,
      now: sim.now,
    )!;
    expect(p.days.first.swapResultsByAdmin, {'rokok', 'vape'});
    expect(p.adminItems, greaterThanOrEqualTo(2));
  });
}
