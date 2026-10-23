import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/features/activity/domain/meal_verifier.dart';
import 'package:youwell/features/community/presentation/admin_meal_page.dart';

class _FakeVerifier implements MealVerifier {
  final queued = [
    MealReview(
      id: 'a',
      alias: 'daunpagi',
      createdAt: DateTime.now().subtract(const Duration(minutes: 35)),
    ),
  ];
  final reviewed = <String, bool>{};
  var aiRuns = 0;

  @override
  Future<List<MealReview>> queue() async => [...queued];
  @override
  Future<List<MealDecision>> recent() async => [
    for (final entry in reviewed.entries)
      MealDecision(
        id: entry.key,
        alias: 'daunpagi',
        approved: entry.value,
        byAi: false,
        reviewedAt: DateTime.now(),
      ),
  ];
  @override
  Future<void> review(String id, {required bool approve}) async {
    queued.removeWhere((item) => item.id == id);
    reviewed[id] = approve;
  }

  @override
  Future<void> checkAllOverdue() async => aiRuns++;
  @override
  Future<void> checkOverdue() async {}
  @override
  Future<Map<String, String>> decisions() async => {};
  @override
  Future<void> submit(String clientId, Uint8List png) async {}
}

void main() {
  testWidgets('Admin approves a waiting meal photo', (tester) async {
    tester.view.physicalSize = const Size(1100, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final verifier = _FakeVerifier();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminMealPage(verifier: verifier)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('@daunpagi'), findsOneWidget);
    expect(find.textContaining('AI dalam 2 jam'), findsOneWidget);
    expect(verifier.aiRuns, 0, reason: 'nothing is past 3 hours yet');

    await tester.tap(find.text('Setujui'));
    await tester.pumpAndSettle();
    expect(verifier.reviewed, {'a': true});
    expect(find.text('Tidak ada foto yang menunggu.'), findsOneWidget);

    await tester.tap(find.text('Sudah diputuskan'));
    await tester.pumpAndSettle();
    expect(find.text('@daunpagi · Disetujui'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
