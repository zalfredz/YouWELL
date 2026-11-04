import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/data/models/wellness_snapshot.dart';
import 'package:youwell/features/home/domain/quest_ladder.dart';
import 'package:youwell/features/home/presentation/hibernation_page.dart';
import 'package:youwell/features/home/presentation/sleep_card.dart';
import 'package:youwell/features/sync/domain/cloud_progress.dart';

import 'support/sim.dart';

/// Istirahat is Hibernasi from 5 Nov 2026 (decision 4 Nov): a countdown of
/// calm breathing that finishes the quest when it ends. The sleep
/// check-in quests of 23 Oct–4 Nov stay in history and the last ones can
/// still be finished.
void main() {
  /// A level-1 sleep quest as cards made it on [day] (before 5 Nov).
  JsonMap sleepQuest(String day, {String status = 'committed'}) => {
    'id': '$day-card-0-ladder-Energy',
    'catalogId': 'ladder-energy',
    'ladder': 'Energy',
    'step': 1,
    'difficulty': 1,
    'category': 'Energy',
    'title': 'Tidur sebelum 00.30, bangun sebelum 07.30',
    'description': 'Catat waktu tidur dan bangun untuk menyelesaikan misi.',
    'durationMinutes': 0,
    'xp': 20,
    'activityKind': 'sleep',
    'bedBefore': 390,
    'wakeBefore': 450,
    'status': status,
    'done': status == 'completed',
  };

  WellnessController withDays(
    Map<String, List<JsonMap>> quests,
    DateTime Function() clock,
  ) => WellnessController(
    saved: jsonEncode(
      createEmptyWellnessState()
        ..['profile'] = {
          'alias': 'preview',
          'path': 'wellness',
          'pace': 1,
          'companion': 'plant',
          'started': '2026-11-01',
        }
        ..['capacity'] = {
          for (final category in healthyCategories)
            category: {'step': 1, 'reviewedOn': '2026-11-01'},
        }
        ..['days'] = {
          for (final MapEntry(:key, :value) in quests.entries)
            key: {
              'quests': value,
              'water': 0,
              'cardDraw': {'committedCardId': '$key-card-0'},
            },
        },
    ),
    clock: clock,
  );

  group('Hibernasi', () {
    test('Four countdown levels of 1, 2, 3 and 5 minutes', () {
      final rungs = ladders['Energy']!;
      expect(rungs.map((r) => r.durationMinutes), [1, 2, 3, 5]);
      expect(rungs.first.title, 'Hibernasi 1 menit');
      expect(rungs.every((r) => r.activityKind == 'calm'), isTrue);
      expect(ladderLabels['Energy'], 'Istirahat');
    });

    test('Cards carry Hibernasi, never a sleep quest, at any hour', () async {
      for (final hour in [5, 15, 22]) {
        final sim = Sim()..now = DateTime(2026, 11, 5, hour);
        await sim.start();
        final tasks = sim.cards.expand(sim.tasksOf);
        expect(tasks.any((t) => t['activityKind'] == 'sleep'), isFalse);
        expect(
          sim.cards.where((c) => sim.categoriesOf(c).contains('Energy')),
          isNotEmpty,
        );
        expect(sim.cards.every((c) => sim.categoriesOf(c).length == 3), isTrue);
        sim.takeCard(category: 'Energy');
        final rest = sim.controller.coreQuests.firstWhere(
          (t) => t['ladder'] == 'Energy',
        );
        expect(rest['title'], startsWith('Hibernasi'));
        expect(rest['activityKind'], 'calm');
      }
    });

    test('Open sleep quests from 5 Nov become Hibernasi; earlier ones and '
        'finished ones stay', () {
      final c = withDays({
        '2026-11-04': [sleepQuest('2026-11-04')],
        '2026-11-05': [sleepQuest('2026-11-05')],
        '2026-11-03': [sleepQuest('2026-11-03', status: 'completed')],
      }, () => DateTime(2026, 11, 5, 8));
      final today = c.quests.single;
      expect(today['title'], 'Hibernasi 1 menit');
      expect(today['activityKind'], 'calm');
      expect(today.containsKey('bedBefore'), isFalse);
      expect(today['xp'], 20, reason: 'XP and id stay');
      expect(today['id'], '2026-11-05-card-0-ladder-Energy');
      // Days before 5 Nov keep their sleep quests as they were.
      for (final day in ['2026-11-03', '2026-11-04']) {
        expect(
          ((c.days[day] as Map)['quests'] as List).single['activityKind'],
          'sleep',
        );
      }
    });
  });

  group('Last sleep quests (4 Nov and earlier)', () {
    test('Check-in at night and check-out in the morning finish it', () {
      var now = DateTime(2026, 11, 3, 23, 40);
      final c = withDays({
        '2026-11-04': [sleepQuest('2026-11-04')],
      }, () => now);
      expect(c.checkInSleep(), isTrue);
      expect(c.checkInSleep(), isFalse, reason: 'one check-in at a time');
      now = DateTime(2026, 11, 4, 7, 10);
      expect(c.checkOutSleep(), isTrue);
      expect(c.sleepCheckIn, isNull);
      expect(c.quests.single['status'], 'completed');
    });

    test('Too late does not count; a daytime tap starts no night', () {
      var now = DateTime(2026, 11, 4, 15);
      final c = withDays({
        '2026-11-04': [sleepQuest('2026-11-04')],
      }, () => now);
      expect(c.checkInSleep(), isFalse);
      c.recordSleep(
        bedAt: DateTime(2026, 11, 4, 1, 45),
        wakeAt: DateTime(2026, 11, 4, 6, 50),
      );
      expect(c.quests.single['status'], isNot('completed'));
    });

    test('An evening nap never replaces the night that ended that morning', () {
      final c = withDays({}, () => DateTime(2026, 11, 4, 22));
      c.recordSleep(
        bedAt: DateTime(2026, 11, 3, 22),
        wakeAt: DateTime(2026, 11, 4, 6),
      );
      c.recordSleep(
        bedAt: DateTime(2026, 11, 4, 19),
        wakeAt: DateTime(2026, 11, 4, 21, 30),
      );
      expect(c.sleepLogs, hasLength(1));
      expect(c.lastNightSleep!['bedAt'], startsWith('2026-11-03T22:00'));
    });

    test('Sleep times stay on this device', () {
      var now = DateTime(2026, 11, 4, 22, 55);
      final c = withDays({
        '2026-11-04': [sleepQuest('2026-11-04')],
      }, () => now);
      c.recordSleep(
        bedAt: DateTime(2026, 11, 3, 23, 10),
        wakeAt: DateTime(2026, 11, 4, 6, 20),
      );
      c.checkInSleep();
      final cloud = jsonEncode(CloudProgress.project(c.export()));
      expect(cloud, isNot(contains('sleepLogs')));
      expect(cloud, isNot(contains('bedAt')));
      expect(cloud, isNot(contains('openSleep')));
      expect(cloud, isNot(contains('23:10')));
    });

    testWidgets('The quest sheet shows one button; Home shows only an open '
        'check-in', (tester) async {
      var now = DateTime(2026, 11, 3, 22, 50);
      final c = withDays({
        '2026-11-04': [sleepQuest('2026-11-04')],
      }, () => now);
      final task = sleepQuest('2026-11-04');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  TextButton(
                    onPressed: () => openSleepSheet(context, c, task),
                    child: const Text('misi'),
                  ),
                  AnimatedBuilder(
                    animation: c,
                    builder: (_, _) => SleepCard(controller: c),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('Aku sudah bangun'), findsNothing);
      await tester.tap(find.text('misi'));
      await tester.pumpAndSettle();
      expect(find.byType(FilledButton), findsOneWidget);
      await tester.tap(find.text('Aku mau tidur'));
      await tester.pumpAndSettle();
      expect(c.sleepCheckIn, DateTime(2026, 11, 3, 22, 50));
      // The open check-in now shows on Home so it can be closed.
      expect(find.text('Aku sudah bangun'), findsOneWidget);
      now = DateTime(2026, 11, 4, 6, 5);
      await tester.tap(find.text('Aku sudah bangun'));
      await tester.pumpAndSettle();
      expect(c.lastNightSleep, isNotNull);
      expect(find.text('Aku sudah bangun'), findsNothing);

      // During the day the sheet explains instead of starting a night.
      now = DateTime(2026, 11, 4, 14);
      await tester.tap(find.text('misi'));
      await tester.pumpAndSettle();
      expect(find.text('Aku mau tidur'), findsNothing);
      expect(find.textContaining('hibernasi'), findsOneWidget);
    });
  });

  testWidgets('Hibernasi counts down and finishes the quest only at the end', (
    tester,
  ) async {
    var now = DateTime(2026, 11, 5, 10);
    final c = withDays({
      '2026-11-05': [sleepQuest('2026-11-05')],
    }, () => now)..setReduceMotion(true);
    final quest = c.quests.single;
    expect(quest['durationMinutes'], 1);
    await tester.pumpWidget(
      MaterialApp(
        home: HibernationPage(controller: c, questId: quest['id']),
      ),
    );
    expect(find.text('Hibernasi 1 menit'), findsOneWidget);
    expect(find.text('1:00'), findsOneWidget);

    // Stopping early gives nothing.
    await tester.tap(find.text('Mulai'));
    now = now.add(const Duration(seconds: 30));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('0:30'), findsOneWidget);
    await tester.tap(find.text('Berhenti'));
    await tester.pump();
    expect(c.quests.single['status'], isNot('completed'));

    // The full minute finishes it, even after the app was in the background.
    await tester.tap(find.text('Mulai'));
    now = now.add(const Duration(minutes: 2));
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.quests.single['status'], 'completed');
    expect(find.text('Hibernasi selesai. Misinya tercentang.'), findsOneWidget);
    expect(find.text('Kembali'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
