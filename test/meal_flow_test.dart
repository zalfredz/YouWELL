// Meal Snap verification through AppAuthController: submit, sync, admin
// decision, poll.
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/application/app_auth_controller.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/config/app_mode.dart';
import 'package:youwell/core/utils/date_key.dart';
import 'package:youwell/data/models/wellness_snapshot.dart';
import 'package:youwell/features/activity/domain/meal_verifier.dart';
import 'account_sync_test.dart' show FakeGateway, FakeCloud, newCache;

class V implements MealVerifier {
  Map<String, String> verdicts = {};
  @override
  Future<Map<String, String>> decisions() async => verdicts;
  @override
  Future<void> checkOverdue() async {}
  @override
  Future<void> checkAllOverdue() async {}
  @override
  Future<List<MealReview>> queue() async => [];
  @override
  Future<List<MealDecision>> recent() async => [];
  @override
  Future<void> review(String id, {required bool approve}) async {}
  @override
  Future<void> submit(String clientId, Uint8List png) async {}
}

void main() {
  test('An admin decision reaches the app and survives sync', () async {
    final today = dayKey(DateTime.now());
    final s = createEmptyWellnessState()
      ..['profile'] = {
        'alias': 'peserta',
        'path': 'wellness',
        'pace': 2,
        'started': today,
      }
      ..['days'] = {
        today: {
          'quests': [
            {
              'id': 'm',
              'catalogId': 'm',
              'title': 'Foto',
              'category': 'Food',
              'ladder': 'Food',
              'step': 1,
              'xp': 20,
              'status': 'committed',
              'activityKind': 'meal_snap',
              'photoCount': 1,
            },
          ],
          'water': 0,
          'cardDraw': {'committedCardId': 'c'},
        },
      };
    final cache = await newCache();
    await cache.write('u1', jsonEncode(s));
    final cloud = FakeCloud();
    final v = V();
    final auth = AppAuthController(
      gateway: FakeGateway('u1'),
      cache: cache,
      surface: AppSurface.mobile,
      progressStore: (_) => cloud,
      mealVerifier: (_) => v,
    );
    auth.start();
    for (var i = 0; i < 50 && auth.stage != AuthStage.ready; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(auth.stage, AuthStage.ready);
    auth.wellness!.recordMeal(photoCaptured: true, checkId: 'k1');
    await auth.progress!.syncNow();
    expect(auth.wellness!.pendingMealChecks, hasLength(1));
    // Opening the app asks right away; nothing decided yet.
    await auth.pollMeals();
    expect(auth.wellness!.quests.single['status'], 'committed');
    v.verdicts = {'k1': 'approved'};
    await auth.pollMeals();
    expect(auth.wellness!.quests.single['status'], 'completed');
    // The next sync keeps the decision; the cloud copy is not stale.
    await auth.wellness!.flush();
    await auth.progress!.syncNow();
    expect(auth.wellness!.quests.single['status'], 'completed');
    expect(
      (cloud.snapshot!.payload['mealCheckIns'] as List).single['verification'],
      'approved',
    );
  });
}
