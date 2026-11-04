import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_theme.dart';
import 'package:youwell/data/models/wellness_snapshot.dart';
import 'package:youwell/features/companion/domain/companion_rewards.dart';
import 'package:youwell/features/companion/presentation/companion_page.dart';

/// Reward colours after every accessory: Samudra Lv 10, Sakura Lv 12,
/// Mentari Lv 14, stored as `profile.companion` like the onboarding colour.
WellnessController atLevel(int level) => WellnessController(
  saved: jsonEncode(
    createEmptyWellnessState()
      ..['profile'] = {
        'alias': 'preview',
        'path': 'wellness',
        'pace': 2,
        'companion': 'plant',
        'started': '2026-10-24',
      }
      ..['levelFloor'] = level,
  ),
  clock: () => DateTime(2026, 11, 4, 9),
);

void main() {
  test('A reward colour is worn only once its level is reached', () {
    final c = atLevel(9)..setCompanionColor('ocean');
    expect(c.profile!['companion'], 'plant');

    final reached = atLevel(10)..setCompanionColor('ocean');
    expect(reached.profile!['companion'], 'ocean');
    reached.setCompanionColor('sakura');
    expect(reached.profile!['companion'], 'ocean', reason: 'Sakura is Lv 12');
    reached.setCompanionColor('cat');
    expect(reached.profile!['companion'], 'cat', reason: 'base colours stay');
    reached.setCompanionColor('unknown');
    expect(reached.profile!['companion'], 'cat');
  });

  test('Colours come after the last accessory and are not accessories', () {
    final colors = companionUnlocks.where((item) => item.color).toList();
    expect(colors.map((item) => (item.id, item.level)), [
      ('ocean', 10),
      ('sakura', 12),
      ('sun', 14),
    ]);
    final lastOther = companionUnlocks
        .where((item) => !item.color)
        .map((item) => item.level)
        .reduce((a, b) => a > b ? a : b);
    expect(colors.every((item) => item.level > lastOther), isTrue);
    final c = atLevel(14)..equipCompanion('ocean', background: false);
    expect(c.companionAccessory, 'none');
  });

  testWidgets('Companion page: wear Samudra, preview locked Mentari', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = atLevel(12)..setReduceMotion(true);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CompanionPage(controller: c),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Warna Welli'), findsOneWidget);
    for (final name in ['Daun', 'Senja', 'Langit', 'Samudra', 'Sakura']) {
      expect(find.text(name), findsOneWidget);
    }

    await tester.tap(find.text('Samudra'));
    await tester.pumpAndSettle();
    expect(c.profile!['companion'], 'ocean');

    await tester.ensureVisible(find.text('Mentari'));
    await tester.tap(find.text('Mentari'));
    await tester.pumpAndSettle();
    expect(c.profile!['companion'], 'ocean', reason: 'Mentari is Lv 14');
    expect(find.text('Pratinjau: Warna Mentari'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
