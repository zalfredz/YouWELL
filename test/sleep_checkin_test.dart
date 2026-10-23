import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/features/home/presentation/sleep_card.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/features/home/domain/quest_ladder.dart';
import 'package:youwell/features/sync/domain/cloud_progress.dart';

import 'support/sim.dart';

/// Sleep check-in at bedtime, check-out on waking; targets step towards
/// bed by 23.00 and up by 06.00.
void main() {
  Future<Sim> withSleepQuest() async {
    final sim = Sim();
    sim.now = DateTime(2026, 10, 24, 7);
    await sim.start(pace: 1);
    sim.takeCard(category: 'Energy');
    return sim;
  }

  Map<String, dynamic> sleepQuest(WellnessController c) =>
      c.coreQuests.firstWhere((task) => task['ladder'] == 'Energy');

  test('Levels step towards 23.00 and 06.00', () {
    final rungs = ladders['Energy']!;
    expect(rungs.last.title, 'Tidur sebelum 23.00, bangun sebelum 06.00');
    for (var i = 1; i < rungs.length; i++) {
      expect(rungs[i].bedBefore!, lessThan(rungs[i - 1].bedBefore!));
      expect(rungs[i].wakeBefore!, lessThan(rungs[i - 1].wakeBefore!));
    }
  });

  test(
    'Check-in at night and check-out in the morning finish the quest',
    () async {
      final sim = await withSleepQuest();
      final c = sim.controller;
      expect(sleepQuest(c)['status'], isNot('completed'));
      sim.now = DateTime(2026, 10, 24, 23, 40);
      expect(c.checkInSleep(), isTrue);
      expect(c.checkInSleep(), isFalse, reason: 'one check-in at a time');
      sim.now = DateTime(2026, 10, 25, 7, 10);
      c.prepareToday();
      sim.takeCard(category: 'Energy');
      expect(c.checkOutSleep(), isTrue);
      expect(c.sleepCheckIn, isNull);
      expect(c.lastNightSleep!['day'], '2026-10-25');
      // Level 1: in bed before 00.30 and up before 07.30.
      expect(sleepQuest(c)['status'], 'completed');
    },
  );

  test('Too late does not count, and is not a failure message', () async {
    final sim = await withSleepQuest();
    final c = sim.controller;
    c.recordSleep(
      bedAt: DateTime(2026, 10, 24, 1, 45),
      wakeAt: DateTime(2026, 10, 24, 6, 50),
    );
    expect(sleepQuest(c)['status'], isNot('completed'));
  });

  test('No "Aku mau tidur" last night: waking up cannot complete it', () async {
    final sim = await withSleepQuest();
    final c = sim.controller;
    expect(c.sleepCheckIn, isNull);
    expect(c.checkOutSleep(), isFalse);
    expect(sleepQuest(c)['status'], isNot('completed'));
    // A press too soon after the other is not a night's sleep.
    sim.now = DateTime(2026, 10, 24, 22, 50);
    c.checkInSleep();
    sim.now = DateTime(2026, 10, 24, 23, 30);
    expect(c.checkOutSleep(), isFalse);
  });

  test('Sleep times stay on this device', () async {
    final sim = await withSleepQuest();
    final c = sim.controller;
    c.recordSleep(
      bedAt: DateTime(2026, 10, 23, 23, 10),
      wakeAt: DateTime(2026, 10, 24, 6, 20),
    );
    sim.now = DateTime(2026, 10, 24, 22, 55);
    c.checkInSleep();
    final cloud = jsonEncode(CloudProgress.project(c.export()));
    expect(cloud, isNot(contains('sleepLogs')));
    expect(cloud, isNot(contains('bedAt')));
    expect(cloud, isNot(contains('openSleep')));
    expect(cloud, isNot(contains('23:10')));
  });

  testWidgets('The quest opens just one button, which records the press', (
    tester,
  ) async {
    final sim = await withSleepQuest();
    final c = sim.controller;
    sim.now = DateTime(2026, 10, 24, 22, 50);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => openSleepSheet(context, c),
              child: const Text('misi'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('misi'));
    await tester.pumpAndSettle();
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.text('Aku mau tidur'), findsOneWidget);
    expect(find.textContaining('Target'), findsNothing);
    await tester.tap(find.text('Aku mau tidur'));
    await tester.pumpAndSettle();
    expect(c.sleepCheckIn, DateTime(2026, 10, 24, 22, 50));
    expect(find.text('Selamat tidur!'), findsOneWidget);

    sim.now = DateTime(2026, 10, 25, 6, 5);
    await tester.tap(find.text('misi'));
    await tester.pumpAndSettle();
    expect(find.text('Aku sudah bangun'), findsOneWidget);
    await tester.tap(find.text('Aku sudah bangun'));
    await tester.pumpAndSettle();
    expect(c.lastNightSleep, isNotNull);
  });
}
