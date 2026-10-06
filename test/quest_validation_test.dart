import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/core/utils/date_key.dart';
import 'package:youwell/data/models/wellness_snapshot.dart';
import 'package:youwell/features/reduction/presentation/delay_craving_panel.dart';

final _now = DateTime(2026, 10, 12, 9);

JsonMap _quest(String catalogId, {String? activityKind, int minutes = 10}) => {
  'id': 'q-$catalogId',
  'catalogId': catalogId,
  'title': catalogId,
  'category': 'Body',
  'difficulty': 1,
  'durationMinutes': minutes,
  'xp': 20,
  'status': 'committed',
  'done': false,
  'activityKind': ?activityKind,
};

WellnessController _controller(List<JsonMap> quests) {
  final state = createEmptyWellnessState()
    ..['profile'] = {
      'alias': 'preview',
      'path': 'reduction',
      'pace': 1,
      'companion': 'plant',
      'started': dayKey(_now),
    }
    ..['days'] = {
      dayKey(_now): {
        'quests': quests,
        'water': 0,
        'cardDraw': {'committedCardId': 'card'},
      },
    };
  return WellnessController(saved: jsonEncode(state), clock: () => _now);
}

String? _status(WellnessController controller, String catalogId) => controller
    .quests
    .firstWhere((task) => task['catalogId'] == catalogId)['status']
    ?.toString();

void main() {
  test('Delay Craving quest completes only after a full timer', () {
    final controller = _controller([_quest('delay', activityKind: 'delay')]);
    controller.recordHabitDelay(minutes: 2, completed: false);
    expect(_status(controller, 'delay'), 'committed');
    expect(controller.delayedToday, 0);
    expect(controller.habitDelays.single['minutes'], 2);

    controller.recordHabitDelay();
    expect(_status(controller, 'delay'), 'completed');
    expect(controller.delayedToday, 1);
  });

  test('Logging a Habit Swap ticks the Habit Swap quest', () {
    final controller = _controller([
      _quest('habit-swap', activityKind: 'habit_swap'),
    ]);
    controller.recordHabitSwap('Minum segelas air');
    expect(controller.habitSwapsToday, 1);
    expect(_status(controller, 'habit-swap'), 'completed');
  });

  test('Walks complete on target, stay partial below it', () {
    final controller = _controller([_quest('walk', activityKind: 'walk')]);
    final short = controller.recordWorkout(
      kind: 'walk',
      seconds: 6 * 60,
      meters: 500,
    );
    expect(short.partial, ['walk']);
    expect(controller.quests.single['partial'], .6);
    expect(_status(controller, 'walk'), 'committed');

    final full = controller.recordWorkout(
      kind: 'walk',
      seconds: 10 * 60,
      meters: 800,
    );
    expect(full.completed, ['walk']);
    expect(_status(controller, 'walk'), 'completed');
  });

  test('Sessions faster than 20 km/h never complete a quest', () {
    final controller = _controller([_quest('walk', activityKind: 'walk')]);
    final result = controller.recordWorkout(
      kind: 'walk',
      seconds: 10 * 60,
      meters: 5000,
    );
    expect(result.tooFast, isTrue);
    expect(_status(controller, 'walk'), 'committed');
    expect(controller.workoutSessions.single.keys, isNot(contains('route')));
  });

  test('One reaction per post and one report per post', () {
    final controller = _controller([]);
    controller.reactToCommunityPost('seed-water', '👏');
    controller.reactToCommunityPost('seed-water', '🌱');
    expect(controller.hasCommunityReaction('seed-water', '👏'), isFalse);
    expect(controller.hasCommunityReaction('seed-water', '🌱'), isTrue);
    controller.reactToCommunityPost('seed-water', '🌱');
    expect(controller.hasCommunityReaction('seed-water', '🌱'), isFalse);

    expect(controller.reportCommunityPost('seed-water', 'spam'), isTrue);
    expect(controller.reportCommunityPost('seed-water', 'spam'), isFalse);
    expect(controller.communityReports, hasLength(1));
  });

  testWidgets('Stopping Delay Craving early logs the minutes delayed', (
    tester,
  ) async {
    final controller = _controller([_quest('delay', activityKind: 'delay')]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DelayCravingPanel(controller: controller)),
      ),
    );
    await tester.tap(find.text('Mulai'));
    await tester.pump(const Duration(minutes: 3));
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump();

    expect(find.text('Tercatat: kamu sudah menunda 3 menit.'), findsOneWidget);
    expect(controller.habitDelays.single['completed'], isFalse);
    expect(controller.delayedToday, 0);
    expect(_status(controller, 'delay'), 'committed');
  });
}
