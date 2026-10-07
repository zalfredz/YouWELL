import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/features/home/domain/quest_ladder.dart';

import 'support/sim.dart';

void main() {
  group('nextStep follows the proposal rule', () {
    test('up only with ≥ 3 days and ≥ 80% done', () {
      expect(nextStep(3, 10, completion: .8, cardDays: 3, inactiveDays: 0), 4);
      expect(nextStep(3, 10, completion: 1, cardDays: 2, inactiveDays: 0), 3);
      expect(nextStep(3, 10, completion: .7, cardDays: 5, inactiveDays: 0), 3);
    });
    test('down below 50%, never on how a quest felt', () {
      expect(nextStep(3, 10, completion: .4, cardDays: 5, inactiveDays: 0), 2);
      expect(nextStep(3, 10, completion: .5, cardDays: 5, inactiveDays: 0), 3);
    });
    test('inactivity of 5 days steps down, never below 1', () {
      expect(nextStep(3, 10, completion: 1, cardDays: 7, inactiveDays: 5), 2);
      expect(nextStep(1, 10, completion: 0, cardDays: 0, inactiveDays: 9), 1);
    });
  });

  test('A good week offers a step up the user can accept', () async {
    final sim = Sim();
    await sim.start(pace: 1);
    sim.runWeek((_) => true);
    expect(sim.controller.ladderOffers, contains('Body'));
    expect(sim.controller.ladderSteps['Body'], 1, reason: 'not before consent');
    expect(
      sim.controller.capacity['Body']!['reason'],
      startsWith('Naik karena'),
    );

    sim.controller.acceptLadderStep('Body');
    expect(sim.controller.ladderSteps['Body'], 2);
    final body = sim.cards
        .expand(sim.tasksOf)
        .firstWhere((task) => task['ladder'] == 'Body');
    expect(body['title'], 'Jalan 800 m');
  });

  test('Declining keeps the step and clears the offer', () async {
    final sim = Sim();
    await sim.start(pace: 1);
    sim.runWeek((_) => true);
    sim.controller.declineLadderStep('Body');
    expect(sim.controller.ladderSteps['Body'], 1);
    expect(sim.controller.ladderOffers, isNot(contains('Body')));
  });

  test('Unfinished quests step down with a stated reason', () async {
    final sim = Sim();
    await sim.start(pace: 3);
    final before = sim.controller.ladderSteps['Body']!;
    sim.runWeek((_) => true);
    sim.controller.acceptLadderStep('Body');
    expect(sim.controller.ladderSteps['Body'], before + 1);
    // A card every day, but the Gerak quest only done on 2 of 7 days.
    for (var day = 0; day < 7; day++) {
      if (day == 2 || day == 5) {
        sim.doLadder();
      } else {
        sim.takeCard(category: 'Body');
      }
      sim.nextDay();
    }
    expect(sim.controller.ladderSteps['Body'], before);
    expect(sim.controller.capacity['Body']!['change'], 'down');
    expect(
      sim.controller.capacity['Body']!['reason'],
      startsWith('Turun satu anak tangga karena 2 dari 7'),
    );
  });

  test('Five quiet days step down once, without blame', () async {
    final sim = Sim();
    await sim.start(pace: 3);
    sim.doLadder();
    sim.now = sim.now.add(const Duration(days: 6));
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

  test('Habit Swap logs at most once per 10 minutes', () async {
    final sim = Sim();
    await sim.start(path: 'reduction');
    expect(sim.controller.recordHabitSwap('Jalan sebentar'), isTrue);
    expect(sim.controller.recordHabitSwap('Kabari teman'), isFalse);
    expect(sim.controller.habitSwapCooldownMinutes, 10);
    sim.now = sim.now.add(const Duration(minutes: 10));
    expect(sim.controller.recordHabitSwap('Kabari teman'), isTrue);
  });

  test('Water ladder completes from logged glasses', () async {
    final sim = Sim();
    await sim.start();
    sim.takeCard(category: 'Lifestyle');
    final hydration = sim.controller.coreQuests.firstWhere(
      (task) => task['ladder'] == 'Lifestyle',
    );
    sim.finish(hydration);
    expect(
      sim.controller.coreQuests.firstWhere(
        (task) => task['ladder'] == 'Lifestyle',
      )['status'],
      'completed',
    );
  });
}
