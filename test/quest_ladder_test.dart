import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/features/home/domain/daily_card_generator.dart';
import 'package:youwell/features/home/domain/quest_ladder.dart';

/// A controller whose clock the test can move day by day.
class _Sim {
  _Sim();
  DateTime now = DateTime(2026, 10, 24, 8);
  late final controller = WellnessController(clock: () => now);

  Future<void> start({
    String path = 'wellness',
    int pace = 1,
    bool lowImpact = false,
  }) => controller.setup({
    'alias': 'preview',
    'path': path,
    'pace': pace,
    'lowImpact': lowImpact,
    'companion': 'plant',
    if (path == 'reduction') 'reductionConsent': true,
  });

  void nextDay() {
    now = now.add(const Duration(days: 1));
    controller.prepareToday();
  }

  /// Draws today's first card and finishes the ladder quests in it.
  void doLadderQuests({String? effort, Set<String> skip = const {}}) {
    controller.selectDailyCard(controller.dailyDrawCards.first['id']);
    controller.commitDailyCardPack();
    for (final task in controller.quests) {
      if (task['ladder'] == null || skip.contains(task['ladder'])) continue;
      if (task['activityKind'] == 'walk' || task['activityKind'] == 'run') {
        controller.recordWorkout(
          kind: task['activityKind'],
          seconds: (task['durationMinutes'] as int) * 60,
          meters: (task['targetMeters'] as int?) ?? 0,
        );
      } else {
        controller.completeCard(task['id']);
      }
      if (effort != null) controller.rateQuestEffort(task['id'], effort);
    }
  }

  Map<String, dynamic> ladderTask(String category) => controller
      .dailyDrawCards
      .first['tasks']
      .cast<Map<String, dynamic>>()
      .firstWhere((task) => task['ladder'] == category);
}

void main() {
  group('nextStep follows the proposal rule', () {
    test('up only with ≥ 80% and no heavy rating', () {
      expect(
        nextStep(3, 10, completion: .8, heavyCount: 0, inactiveDays: 0),
        4,
      );
      expect(
        nextStep(3, 10, completion: .9, heavyCount: 1, inactiveDays: 0),
        3,
      );
    });
    test('down below 50% or with two heavy ratings', () {
      expect(
        nextStep(3, 10, completion: .4, heavyCount: 0, inactiveDays: 0),
        2,
      );
      expect(
        nextStep(3, 10, completion: .7, heavyCount: 2, inactiveDays: 0),
        2,
      );
    });
    test('inactivity of 5 days steps down, never below 1', () {
      expect(nextStep(3, 10, completion: 1, heavyCount: 0, inactiveDays: 5), 2);
      expect(nextStep(1, 10, completion: 0, heavyCount: 0, inactiveDays: 9), 1);
    });
  });

  test('Every card carries one ladder quest per category plus side quests', () {
    final packs = const DailyCardGenerator().cardPacks(
      today: '2026-10-24',
      steps: const {'Body': 2, 'Energy': 1, 'Reduction': 3},
      pace: 2,
      lowImpact: false,
      reduction: true,
    );
    expect(packs, hasLength(5));
    for (final card in packs) {
      final tasks = (card['tasks'] as List).cast<Map<String, dynamic>>();
      expect(tasks.length, inInclusiveRange(3, 5));
      expect(
        tasks.where((task) => task['ladder'] != null).map((t) => t['title']),
        [
          'Jalan 10 menit',
          'Layar off 10 menit sebelum tidur',
          'Delay Craving 10 menit',
        ],
      );
    }
    expect(
      packs.map((card) => card['tasks'].last['title']).toSet().length,
      greaterThan(1),
      reason: 'side quests should make the five cards differ',
    );
  });

  test('Low-impact never reaches the running part of the Body ladder', () {
    final packs = const DailyCardGenerator().cardPacks(
      today: '2026-10-24',
      steps: const {'Body': 9, 'Energy': 1, 'Lifestyle': 1},
      pace: 3,
      lowImpact: true,
      reduction: false,
    );
    final body = (packs.first['tasks'] as List).firstWhere(
      (task) => task['ladder'] == 'Body',
    );
    expect(body['step'], lowImpactBodyMax);
    expect(body['activityKind'], 'walk');
  });

  test('A good week offers a step up the user can accept', () async {
    final sim = _Sim();
    await sim.start();
    expect(sim.controller.ladderSteps['Body'], 1);
    for (var day = 0; day < 7; day++) {
      sim.doLadderQuests(effort: 'pas');
      sim.nextDay();
    }
    expect(sim.controller.ladderOffers, containsAll(['Body', 'Energy']));
    expect(sim.controller.ladderSteps['Body'], 1, reason: 'not before consent');
    expect(
      sim.controller.capacity['Body']!['reason'],
      'Naik karena 7 dari 7 quest Gerak selesai dan tidak ada yang terasa '
      'berat.',
    );

    sim.controller.acceptLadderStep('Body');
    expect(sim.controller.ladderSteps['Body'], 2);
    expect(sim.ladderTask('Body')['title'], 'Jalan 10 menit');

    sim.controller.declineLadderStep('Energy');
    expect(sim.controller.ladderSteps['Energy'], 1);
    expect(sim.controller.ladderOffers, isNot(contains('Energy')));
  });

  test('Heavy ratings step down with a stated reason', () async {
    final sim = _Sim();
    await sim.start(pace: 3);
    for (var day = 0; day < 7; day++) {
      sim.doLadderQuests(effort: day.isEven ? 'berat' : 'pas');
      sim.nextDay();
    }
    expect(sim.controller.ladderSteps['Body'], 2);
    expect(sim.controller.capacity['Body']!['change'], 'down');
    expect(
      sim.controller.capacity['Body']!['reason'],
      contains('4 quest terasa berat'),
    );
  });

  test('A mixed week holds the step', () async {
    final sim = _Sim();
    await sim.start(pace: 2);
    for (var day = 0; day < 7; day++) {
      sim.doLadderQuests(skip: day < 2 ? {'Body'} : const {});
      sim.nextDay();
    }
    expect(sim.controller.ladderSteps['Body'], 2);
    expect(sim.controller.capacity['Body']!['change'], 'hold');
  });

  test('Five quiet days step down once, without blame', () async {
    final sim = _Sim();
    await sim.start(pace: 3);
    sim.doLadderQuests();
    for (var day = 0; day < 6; day++) {
      sim.now = sim.now.add(const Duration(days: 1));
    }
    sim.controller.prepareToday();
    expect(sim.controller.ladderSteps['Body'], 2);
    expect(sim.controller.capacity['Body']!['change'], 'rest');
    expect(
      sim.controller.capacity['Body']!['reason'],
      startsWith('Selamat datang lagi.'),
    );
    sim.nextDay();
    expect(sim.controller.ladderSteps['Body'], 2, reason: 'only once');
  });

  test('Weekly research summary holds numbers only', () async {
    final sim = _Sim();
    await sim.start(path: 'reduction');
    sim.doLadderQuests();
    sim.controller.recordHabitDelay(minutes: 3, completed: false);
    sim.controller.recordHabitSwap('Minum segelas air');
    sim.nextDay(); // Opening is measured separately from activity/quest days.
    sim.nextDay();
    sim.doLadderQuests();

    final summary = sim.controller.researchSummary(1).toJson();
    expect(summary, {
      'week': 1,
      'active_days': 3,
      'opened_days': 3,
      'activity_days': 2,
      'quest_days': 2,
      'quests_done': 6,
      'ladder_body': 1,
      'ladder_energy': 1,
      'ladder_reduction': 1,
      'delay_craving_count': 1,
      'habit_swap_count': 1,
    });
    expect(sim.controller.researchSummary(2).activeDays, 0);
  });

  test('Habit Swap logs at most once per 10 minutes', () async {
    final sim = _Sim();
    await sim.start(path: 'reduction');
    expect(sim.controller.recordHabitSwap('Jalan sebentar'), isTrue);
    expect(sim.controller.recordHabitSwap('Kabari teman'), isFalse);
    expect(sim.controller.habitSwapCooldownMinutes, 10);
    sim.now = sim.now.add(const Duration(minutes: 10));
    expect(sim.controller.recordHabitSwap('Kabari teman'), isTrue);
  });

  test('Water ladder completes from logged glasses', () async {
    final sim = _Sim();
    await sim.start();
    sim.controller.selectDailyCard(sim.controller.dailyDrawCards.first['id']);
    sim.controller.commitDailyCardPack();
    for (var glass = 0; glass < 4; glass++) {
      sim.controller.addWater();
    }
    final hydration = sim.controller.quests.firstWhere(
      (task) => task['ladder'] == 'Lifestyle',
    );
    expect(hydration['status'], 'completed');
  });
}
