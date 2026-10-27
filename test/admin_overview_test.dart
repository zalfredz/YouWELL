import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/application/admin_progress_editor.dart';
import 'package:youwell/application/progress_sync_controller.dart';
import 'package:youwell/application/research_overview.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_theme.dart';
import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/features/community/presentation/admin_overview_page.dart';
import 'package:youwell/features/progress/domain/research_store.dart';
import 'package:youwell/features/sync/domain/cloud_progress.dart';

import 'account_sync_test.dart' show FakeCloud, newCache;
import 'research_dashboard_test.dart' show FakeResearch;
import 'support/sim.dart';

/// A reduction participant who did one quest on day 1 and then stopped
/// (days 2 and 3 have no card), as synced to the server.
Future<(JsonMap, DateTime)> lapsedParticipant() async {
  final sim = Sim();
  await sim.start(path: 'reduction');
  sim.takeCard();
  sim.finish(sim.controller.coreQuests.first);
  sim.nextDay();
  sim.nextDay();
  final payload = CloudProgress.project(sim.controller.export());
  // Moving the test clock opens the app; this participant did not.
  payload['openedDays'] = ['2026-10-24'];
  payload['activityDays'] = ['2026-10-24'];
  return (payload, sim.now);
}

WellnessController phoneWith(JsonMap payload, DateTime now) =>
    WellnessController(
      saved: CloudProgress.apply(payload, null),
      clock: () => now,
    );

void main() {
  test('Ticking quests restores XP; app quests stay as they were', () async {
    final (payload, now) = await lapsedParticipant();
    final editor = AdminProgressEditor(payload, now: now);
    final day1 = editor.days.last;
    final before = ParticipantOverview.fromRow({'payload': payload}, now: now)!;

    final quests = editor.questsOn(day1);
    final byApp = quests.firstWhere(AdminProgressEditor.doneByApp);
    final open = quests.where((t) => t['status'] != 'completed').toList();
    editor.setQuestDone(day1, byApp['id'], false);
    for (final task in open) {
      editor.setQuestDone(day1, task['id'], true);
    }
    // A missed day gets the card the app would recommend, then ticked.
    final day2 = editor.days[1];
    expect(editor.hasCard(day2), isFalse);
    editor.createCard(day2);
    for (final task in editor.questsOn(day2)) {
      editor.setQuestDone(day2, task['id'], true);
    }

    final after = ParticipantOverview.fromRow({
      'payload': editor.payload,
    }, now: now)!;
    expect(after.xp, greaterThan(before.xp));
    expect(
      after.questsDone,
      before.questsDone + open.length + editor.questsOn(day2).length,
    );
    expect(
      editor
          .questsOn(day1)
          .firstWhere((t) => t['id'] == byApp['id'])['adminCompleted'],
      isNull,
      reason: 'a quest done in the app is never touched',
    );
    expect(
      editor.changes.where((c) => c['kind'] == 'quest'),
      hasLength(open.length + editor.questsOn(day2).length),
    );
    expect(editor.changes.where((c) => c['kind'] == 'card'), hasLength(1));
  });

  test('Usage, Habit Swap, opened days and levels reach the phone and '
      'the research export, marked as admin', () async {
    final (payload, now) = await lapsedParticipant();
    final editor = AdminProgressEditor(payload, now: now);
    final day2 = editor.days[1];
    editor
      ..setUsage(day2, 'rokok', 10)
      ..setSwaps(day2, 2)
      ..setOpened(day2, true)
      ..setStep('Body', 3);
    expect(editor.changes.map(describeChange), [
      'Level Gerak: 2 → 3',
      '$day2: ditandai membuka aplikasi',
      '$day2: rokok – → 10',
      '$day2: Habit Swap 0 → 2',
    ]);

    // The phone adopts it; its next upload keeps every admin mark.
    final phone = phoneWith(editor.payload, now);
    expect(phone.nicotineDay(day2)?['cigarette'], 10);
    expect(phone.ladderSteps['Body'], 3);
    final again = CloudProgress.project(phone.export());
    expect(again['usageTotals'], [
      {
        'day': day2,
        'type': 'rokok',
        'total': 10,
        'confirmed': true,
        'source': 'admin',
      },
    ]);
    expect(again['adminOpenedDays'], [day2]);
    expect(
      (again['habitSwaps'] as List).where((r) => r['day'] == day2),
      hasLength(2),
    );

    final week = phone.researchSummary(1).toJson();
    expect(week['cigarettes_total'], 10);
    expect(week['usage_days_logged'], 1);
    expect(week['habit_swap_count'], 3, reason: '1 from the app on day 1');
    expect(week['opened_days_by_admin'], 1);
    expect(week['admin_intervention'], isTrue);
    expect(researchCsvColumns, containsAll(week.keys));
  });

  test('A day the phone already logged keeps its own total unless the '
      'admin set it', () {
    final device = jsonEncode({
      ...jsonDecode(phoneWithEmpty()) as Map,
      'nicotineDays': [
        {
          'day': '2026-10-25',
          'product': 'cigarette',
          'confirmed': true,
          'cigarette': 3,
        },
      ],
    });
    JsonMap cloud(List<JsonMap> usage) => {
      ...CloudProgress.project(device),
      'usageTotals': usage,
    };
    final kept = jsonDecode(
      CloudProgress.apply(
        cloud([
          {'day': '2026-10-25', 'type': 'rokok', 'total': 7, 'confirmed': true},
        ]),
        device,
      ),
    );
    expect(kept['nicotineDays'].single['cigarette'], 3);
    final admin = jsonDecode(
      CloudProgress.apply(
        cloud([
          {
            'day': '2026-10-25',
            'type': 'rokok',
            'total': 7,
            'confirmed': true,
            'source': 'admin',
          },
        ]),
        device,
      ),
    );
    expect(admin['nicotineDays'].single['cigarette'], 7);
  });

  test('A running phone takes an admin edit without a conflict', () async {
    final (payload, now) = await lapsedParticipant();
    final cache = await newCache();
    final cloud = FakeCloud();
    String? applied;
    final sync = ProgressSyncController(
      userId: 'u1',
      cache: cache,
      remote: cloud,
      onApplied: (raw) => applied = raw,
      debounce: const Duration(hours: 1),
    );
    addTearDown(sync.dispose);
    await sync.open(CloudProgress.apply(payload, null));
    final revision = cloud.snapshot!.revision;

    final editor = AdminProgressEditor(cloud.snapshot!.payload, now: now)
      ..setStep('Body', 3);
    await cloud.save(editor.payload, expectedRevision: revision);
    await sync.syncNow();

    expect(sync.hasConflict, isFalse);
    expect(applied, isNotNull);
    expect(
      phoneWith(CloudProgress.project(applied!), now).ladderSteps['Body'],
      3,
    );
  });

  testWidgets('Overview: pick a participant, tick a quest, save with a '
      'reason', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (payload, now) = await lapsedParticipant();
    final store = FakeResearch([
      {
        'account': 'acc-1',
        'code': 'P3',
        'alias': 'daunpagi',
        'revision': 4,
        'payload': payload,
      },
    ]);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AdminOverviewPage(store: store, now: now),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('P3 · daunpagi'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada perubahan.'), findsOneWidget);

    await tester.tap(find.textContaining('Hari 1 ·'));
    await tester.pumpAndSettle();
    final box = find.byWidgetPredicate(
      (w) => w is CheckboxListTile && w.value == false && w.onChanged != null,
    );
    await tester.tap(box.first);
    await tester.pumpAndSettle();
    expect(find.text('1 perubahan belum disimpan'), findsOneWidget);

    await tester.tap(find.text('Simpan intervensi'));
    await tester.pumpAndSettle();
    expect(store.writes, isEmpty, reason: 'a reason is required');
    await tester.enterText(
      find.widgetWithText(TextField, 'Alasan intervensi'),
      'Data hilang setelah install ulang',
    );
    await tester.tap(find.text('Simpan intervensi'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();

    expect(store.writes.single['reason'], 'Data hilang setelah install ulang');
    expect((store.writes.single['changes'] as List).single['kind'], 'quest');
    expect(find.text('Belum ada perubahan.'), findsOneWidget);
    expect(find.textContaining('dicentang'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

String phoneWithEmpty() => WellnessController().export();
