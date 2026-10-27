import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/core/utils/date_key.dart';
import 'package:youwell/data/models/wellness_snapshot.dart';
import 'package:youwell/features/sync/domain/cloud_progress.dart';

/// Meal Snap verification (phase 9): a photo sent for review counts only
/// once approved, on the day it was taken, and is then removed.
void main() {
  var time = DateTime(2026, 10, 24, 8, 30);
  DateTime clock() => time;

  JsonMap breakfast() => {
    'id': 'breakfast',
    'catalogId': 'breakfast',
    'title': 'Sarapan',
    'category': 'Food',
    'ladder': 'Food',
    'step': 1,
    'xp': 20,
    'status': 'committed',
    'activityKind': 'meal_snap',
    'photoCount': 1,
    'photoWindows': [
      [4, 10],
    ],
  };

  WellnessController make() {
    time = DateTime(2026, 10, 24, 8, 30);
    final day = dayKey(time);
    final state = createEmptyWellnessState()
      ..['profile'] = {
        'alias': 'preview',
        'path': 'wellness',
        'pace': 2,
        'companion': 'plant',
        'started': day,
      }
      ..['days'] = {
        day: {
          'quests': [breakfast()],
          'water': 0,
          'cardDraw': {'committedCardId': 'card'},
        },
      };
    return WellnessController(saved: jsonEncode(state), clock: clock);
  }

  test('A photo under review waits, approval completes with XP', () {
    final c = make();
    c.recordMeal(photoPath: '/tmp/a.png', checkId: 'k1');
    final quest = c.quests.single;
    expect(quest['status'], 'committed');
    expect(c.mealVerificationFor(quest), 'pending');
    expect(c.pendingMealChecks, hasLength(1));

    final xp = c.xp;
    final files = c.applyMealVerdicts({'k1': 'approved'});
    expect(files, ['/tmp/a.png']);
    expect(c.quests.single['status'], 'completed');
    expect(c.xp, greaterThan(xp));
    // The photo is gone from the device too, but the check-in still counts.
    expect(c.mealCheckIns.single, isNot(contains('photoPath')));
    expect(c.mealCheckIns.single['verification'], 'approved');
    expect(c.pendingMealChecks, isEmpty);
  });

  test('A rejected photo asks for a new one; the retake can pass', () {
    final c = make();
    c.recordMeal(photoCaptured: true, checkId: 'k1');
    c.applyMealVerdicts({'k1': 'rejected'});
    expect(c.quests.single['status'], 'committed');
    expect(c.mealVerificationFor(c.quests.single), 'rejected');

    c.recordMeal(photoCaptured: true, checkId: 'k2');
    expect(c.mealVerificationFor(c.quests.single), 'pending');
    c.applyMealVerdicts({'k1': 'rejected', 'k2': 'approved'});
    expect(c.quests.single['status'], 'completed');
  });

  test('Approval the next day rewards the day the photo was taken', () {
    final c = make();
    c.recordMeal(photoCaptured: true, checkId: 'k1');
    time = DateTime(2026, 10, 25, 9);
    c.prepareToday();
    final xp = c.xp;
    c.applyMealVerdicts({'k1': 'approved'});
    final quests = c.days['2026-10-24']['quests'] as List;
    expect(quests.single['status'], 'completed');
    expect(c.xp, greaterThan(xp));
  });

  test('An approved photo outside the photo hours says so', () {
    final c = make();
    time = DateTime(2026, 10, 24, 11);
    c.recordMeal(photoCaptured: true, checkId: 'k1');
    c.applyMealVerdicts({'k1': 'approved'});
    expect(c.quests.single['status'], 'committed');
    expect(c.mealVerificationFor(c.quests.single), 'outside');
  });

  test('Pending decisions and unknown answers change nothing', () {
    final c = make();
    c.recordMeal(photoCaptured: true, checkId: 'k1');
    expect(c.applyMealVerdicts({'k1': 'pending', 'other': 'approved'}), []);
    expect(c.mealVerificationFor(c.quests.single), 'pending');
  });

  test('Without verification (local preview, older photos) it counts', () {
    final c = make();
    c.recordMeal(photoCaptured: true);
    expect(c.quests.single['status'], 'completed');
    expect(c.mealVerificationFor(c.quests.single), isNull);
  });

  test('The cloud keeps the status, never the photo', () {
    final c = make();
    c.recordMeal(photoPath: '/tmp/a.png', checkId: 'k1');
    final row = (CloudProgress.project(c.export())['mealCheckIns'] as List)
        .single as Map;
    expect(row['verification'], 'pending');
    expect(row['checkId'], 'k1');
    expect(row, isNot(contains('photoPath')));
  });
}
