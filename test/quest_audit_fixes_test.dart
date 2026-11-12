import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/application/admin_progress_editor.dart';
import 'package:youwell/application/research_overview.dart';
import 'package:youwell/application/study_dashboard.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/features/home/domain/daily_card_generator.dart';

/// Fixes from the 4 Nov 2026 quest audit; each test is its repro.
void main() {
  var now = DateTime(2026, 10, 20, 15);
  List<String> categories(Map card) =>
      (card['categories'] as List).cast<String>();

  Future<WellnessController> participant({
    String path = 'wellness',
    int pace = 2,
  }) async {
    final c = WellnessController(clock: () => now);
    await c.setup({
      'alias': 'preview',
      'path': path,
      'pace': pace,
      'lowImpact': false,
      'companion': 'plant',
    });
    return c;
  }

  group('Sleep check-in (last sleep quests)', () {
    test(
      'A daytime tap does not start a night; the evening one does',
      () async {
        now = DateTime(2026, 10, 20, 15);
        final c = await participant();
        expect(c.canCheckInSleep, isFalse);
        expect(c.checkInSleep(), isFalse);
        expect(c.sleepCheckIn, isNull);
        now = DateTime(2026, 10, 20, 23, 30);
        expect(c.checkInSleep(), isTrue);
        now = DateTime(2026, 10, 21, 6, 30);
        c.prepareToday();
        expect(c.checkOutSleep(), isTrue);
        expect(c.lastNightSleep!['bedAt'], startsWith('2026-10-20T23:30'));
      },
    );

    test(
      'An evening nap never replaces the night that ended that morning',
      () async {
        now = DateTime(2026, 10, 21, 22);
        final c = await participant();
        expect(
          c.recordSleep(
            bedAt: DateTime(2026, 10, 20, 22),
            wakeAt: DateTime(2026, 10, 21, 6),
          ),
          isTrue,
        );
        c.recordSleep(
          bedAt: DateTime(2026, 10, 21, 19),
          wakeAt: DateTime(2026, 10, 21, 21, 30),
        );
        expect(c.sleepLogs, hasLength(1));
        expect(c.lastNightSleep!['bedAt'], startsWith('2026-10-20T22:00'));
      },
    );
  });

  test(
    'Hidrasi: same evidence in either order, no step up on partials',
    () async {
      final steps = <String>[];
      for (final logFirst in [true, false]) {
        now = DateTime(2026, 10, 20, 8);
        final c = await participant(pace: 3);
        c.enableMobileRewards();
        for (var day = 0; day < 7; day++) {
          c.prepareToday();
          // 1250 of 1500 ml: never the full target.
          if (logFirst) {
            for (var i = 0; i < 5; i++) {
              c.addWater();
            }
          }
          final card = c.dailyDrawCards.firstWhere(
            (card) => categories(card).contains('Lifestyle'),
          );
          c.selectDailyCard(card['id']);
          c.commitDailyCardPack();
          if (!logFirst) {
            for (var i = 0; i < 5; i++) {
              c.addWater();
            }
          }
          final water = c.coreQuests.firstWhere(
            (t) => t['ladder'] == 'Lifestyle',
          );
          expect(water['status'], isNot('completed'));
          expect(water['partial'], .83, reason: 'logFirst=$logFirst');
          // Another mission keeps the day active (no inactivity step-down).
          final other = c.coreQuests
              .where((t) => t['activityKind'] == null)
              .firstOrNull;
          if (other != null) c.completeCard(other['id']);
          now = now.add(const Duration(days: 1));
        }
        c.prepareToday();
        final entry = c.capacity['Lifestyle']!;
        expect(entry['offerStep'], isNull, reason: 'logFirst=$logFirst');
        steps.add('${entry['step']}:${entry['change']}');
      }
      expect(steps.toSet(), hasLength(1), reason: '$steps');
    },
  );

  test(
    'Cards: meal window closing within the hour, sunlight after noon',
    () async {
      final cards = const DailyCardGenerator().cardPacks(
        today: '2026-10-21',
        steps: const {'Body': 1, 'Food': 4, 'Lifestyle': 1, 'Energy': 1},
        pace: 2,
        lowImpact: false,
        reduction: false,
        hour: 9,
        wellnessUat: true,
      );
      final food = cards
          .expand((card) => (card['tasks'] as List).cast<Map>())
          .firstWhere((task) => task['ladder'] == 'Food');
      expect(food['photoWindows'], isNull, reason: 'anytime version at 09.xx');

      bool sunlight(Map card) => (card['tasks'] as List).any(
        (task) => task['catalogId'] == 'sunlight',
      );
      var drawnAtNight = 0;
      for (var day = 0; day < 28; day++) {
        now = DateTime(2026, 10, 20, 0, 5).add(Duration(days: day));
        final c = await participant();
        final card = c.dailyDrawCards.where(sunlight).firstOrNull;
        if (card == null) continue;
        drawnAtNight++;
        // Taken at 14.05: the morning quest is swapped before it is kept.
        now = now.add(const Duration(hours: 14));
        c.selectDailyCard(card['id']);
        if (!c.commitDailyCardPack()) c.commitDailyCardPack();
        expect(c.coreQuests.any((t) => t['catalogId'] == 'sunlight'), isFalse);
        expect(c.coreQuests, hasLength((card['tasks'] as List).length));
      }
      expect(drawnAtNight, greaterThan(0), reason: 'the case was exercised');
    },
  );

  test('Research: a week without app use keeps the last known level', () async {
    now = DateTime(2026, 10, 20, 9);
    final c = await participant();
    for (var day = 1; day < 21; day++) {
      now = now.add(const Duration(days: 1));
      c.prepareToday();
    }
    now = DateTime(2026, 11, 18, 9);
    c.prepareToday();
    final week4 = c.researchSummary(4).toJson();
    expect(week4['active'], isFalse);
    expect(
      week4['ladder_gerak'],
      c.researchSummary(3).toJson()['ladder_gerak'],
    );
    expect(week4['ladder_gerak'], isNotNull);
  });

  test('Admin card for a past day uses that day\'s levels', () async {
    now = DateTime(2026, 10, 20, 9);
    final c = await participant(pace: 1);
    final payload = jsonDecode(c.export()) as JsonMap;
    (payload['capacity'] as Map)['Body']['step'] = 4;
    final editor = AdminProgressEditor(payload, now: DateTime(2026, 11, 2, 9));
    editor.createCard('2026-10-22');
    final day = (editor.payload['days'] as Map)['2026-10-22'] as Map;
    final body = editor
        .questsOn('2026-10-22')
        .where((task) => task['ladder'] == 'Body');
    final recorded =
        (payload['days'] as Map)['2026-10-20']['ladderSteps']['Body'];
    expect(day['ladderSteps']['Body'], recorded);
    if (body.isNotEmpty) expect(body.first['step'], recorded);
  });

  test('Admin cards are drawn from all five cards, 3 to 5 missions', () async {
    now = DateTime(2026, 10, 20, 9);
    final c = await participant(pace: 1);
    final payload = jsonDecode(c.export()) as JsonMap;
    final editor = AdminProgressEditor(payload, now: DateTime(2026, 11, 8, 9));
    final random = Random(7);
    final sizes = <int>{};
    for (var day = 21; day <= 31; day++) {
      final key = '2026-10-$day';
      editor.createCard(key, random: random);
      sizes.add(editor.questsOn(key).length);
    }
    expect(sizes.length, greaterThan(1));
    expect(sizes.every((n) => n >= 3 && n <= 5), isTrue);
  });

  test('Dashboard group mean uses completed weeks only', () {
    // Two coded participants: one in week 2, one still in week 1.
    JsonMap row(String code, String started) => {
      'account': code,
      'code': code,
      'payload': {
        'schemaVersion': 1,
        'version': 3,
        'profile': {'alias': 'p$code', 'path': 'wellness', 'started': started},
        'days': {},
        'capacity': {},
        'openedDays': [
          for (var d = 0; d < 10; d++) '2026-10-${(20 + d).toString()}',
        ],
        'activityDays': [],
        'workoutSessions': [],
        'mealCheckIns': [],
        'habitDelays': [],
        'habitSwaps': [],
      },
    };
    final at = DateTime(2026, 10, 29, 12);
    final people = [
      for (final r in [row('P1', '2026-10-20'), row('P2', '2026-10-25')])
        StudyParticipant.from(
          ParticipantOverview.fromRow(r, now: at)!,
          now: at,
        )!,
    ];
    expect(people[0].weeks[0].complete, isTrue);
    expect(people[1].weeks[0].complete, isFalse);
  });
}
