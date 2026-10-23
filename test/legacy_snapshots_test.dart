// Opens progress snapshots saved by app versions that UAT participants have
// installed (144cad3, cfbcbd1), with quests that were later removed, and
// checks that this code migrates them, keeps playing for five days, syncs,
// and renders every main screen. Add a folder per newly deployed version.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/app/youwell_app.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/config/app_mode.dart';
import 'package:youwell/features/home/presentation/daily_card_draw_dialog.dart';
import 'package:youwell/features/reduction/presentation/reduction_support_page.dart';
import 'package:youwell/features/sync/domain/cloud_progress.dart';

const root = 'test/fixtures/legacy_snapshots';

void finish(WellnessController c, Map<String, dynamic> task) {
  final now = c.now;
  switch (task['activityKind']) {
    case 'walk' || 'run':
      final meters = (task['targetMeters'] as num?)?.toInt() ?? 0;
      c.recordWorkout(
        kind: task['activityKind'],
        seconds: task['timed'] == true
            ? (task['durationMinutes'] as int) * 60
            : (meters / 5000 * 3600).round() + 60,
        meters: meters,
      );
    case 'water':
      while (c.water < (task['waterMl'] as num)) {
        c.addWater();
      }
    case 'meal_snap':
      for (var i = 0; i < ((task['photoCount'] as num?) ?? 1); i++) {
        c.recordMeal(photoPath: '/tmp/m$i.jpg');
      }
    case 'habit_swap':
      final product = c.nicotineProduct == 'vape' ? 'vape' : 'cigarette';
      c.startSwapMoment(product: product, activities: ['walk']);
      final id = c.reportSwapTried();
      if (id != null) c.recordSwapOutcome(id, 'skipped');
    case 'sleep':
      c.recordSleep(
        bedAt: DateTime(now.year, now.month, now.day - 1, 22, 30),
        wakeAt: DateTime(now.year, now.month, now.day, 5, 30),
      );
    default:
      c.completeCard(task['id'].toString());
  }
}

void main() {
  final files = [
    for (final dir in Directory(root).listSync().whereType<Directory>())
      ...dir.listSync().whereType<File>(),
  ]..sort((a, b) => a.path.compareTo(b.path));

  test('there are snapshots', () => expect(files, hasLength(18)));

  for (final file in files) {
    final name = file.path
        .split('/')
        .reversed
        .take(2)
        .toList()
        .reversed
        .join('/');
    testWidgets('legacy $name', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final raw = file.readAsStringSync();
      final before = jsonDecode(raw) as Map<String, dynamic>;
      var now = DateTime(2026, 10, 23, 21);
      final c = WellnessController(saved: raw, clock: () => now);
      expect(c.storageError, isNull, reason: 'snapshot must load');

      // Open old quests became the new ones; finished history is untouched.
      final today = c.days[c.today] as Map?;
      for (final task in ((today?['quests'] ?? const []) as List).cast<Map>()) {
        if (task['status'] == 'completed') continue;
        expect(task['catalogId'], isNot('screen-break'));
        if (task['ladder'] == 'Energy') {
          expect(task['activityKind'], 'sleep');
          expect(task['bedBefore'], isNotNull);
        }
      }
      final oldDone = [
        for (final day in (before['days'] as Map).values)
          for (final task in ((day as Map)['quests'] ?? const []) as List)
            if ((task as Map)['status'] == 'completed') task['id'],
      ];
      final stillDone = [
        for (final day in c.days.values)
          for (final task in ((day as Map)['quests'] ?? const []) as List)
            if ((task as Map)['status'] == 'completed') task['id'],
      ];
      expect(stillDone.toSet().containsAll(oldDone), isTrue);
      final xp = c.xp;
      expect(xp, greaterThanOrEqualTo((before['xp'] as num?) ?? 0));

      // Finish today's open quests, then live five more days.
      c.enableMobileRewards();
      if (c.needsDailyCardDraw) {
        c.selectDailyCard(c.dailyDrawCards.first['id'].toString());
        c.commitDailyCardPack();
      }
      for (final task in [...c.coreQuests]) {
        if (task['status'] != 'completed') finish(c, task);
      }
      for (var day = 0; day < 5; day++) {
        now = now.add(const Duration(days: 1));
        c.prepareToday();
        expect(c.dailyDrawCards, isNotEmpty);
        c.selectDailyCard(c.dailyDrawCards[day % 5]['id'].toString());
        expect(c.commitDailyCardPack(), isTrue);
        for (final task in [...c.coreQuests]) {
          finish(c, task);
        }
        expect(
          c.coreQuests.every((t) => t['status'] == 'completed'),
          isTrue,
          reason:
              'day $day: ${c.coreQuests.where((t) => t['status'] != 'completed').map((t) => t['title'])}',
        );
        if (c.canDrawBonusCard) {
          c.drawBonusCard();
          for (final task in [...c.bonusQuests]) {
            finish(c, task);
          }
        }
      }
      expect(c.xp, greaterThan(xp));
      for (var week = 1; week <= 4; week++) {
        c.researchSummary(week).toJson();
      }
      // Cloud round trip and a restart keep everything readable.
      final payload = CloudProgress.project(c.export());
      // Mirrors private.youwell_cloud_fields_safe on the server.
      const banned = {
        'photopath',
        'photo',
        'image',
        'bytes',
        'base64',
        'latitude',
        'longitude',
        'coordinates',
        'route',
        'note',
        'noteeditedat',
        'email',
        'user_id',
        'researchparticipation',
        'participant_code',
        'access_token',
        'refresh_token',
        'product',
        'trigger',
        'outcome',
        'activity',
        'eventid',
        'cigarette',
        'vape',
        'nicotinedays',
        'reductionsettings',
        'reductionplans',
        'reductiontargets',
      };
      void scan(Object? value) {
        if (value is Map) {
          for (final entry in value.entries) {
            expect(
              banned,
              isNot(contains(entry.key.toString().toLowerCase())),
              reason: 'server would reject key \${entry.key}',
            );
            scan(entry.value);
          }
        } else if (value is List) {
          value.forEach(scan);
        }
      }

      scan(payload);
      final applied = CloudProgress.apply(payload, c.export());
      expect(
        WellnessController(saved: applied, clock: () => now).storageError,
        isNull,
      );
      final restarted = WellnessController(saved: c.export(), clock: () => now);
      expect(restarted.xp, c.xp);

      // Every main screen renders.
      c.setReduceMotion(true);
      await tester.pumpWidget(
        YouWellApp(controller: c, surface: AppSurface.mobile),
      );
      await tester.pumpAndSettle();
      for (var tab = 1; tab < 4; tab++) {
        await tester.tap(find.byType(NavigationDestination).at(tab));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byType(NavigationDestination).at(0));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Buka profil',
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      now = now.add(const Duration(days: 1));
      c.prepareToday();
      await tester.pumpWidget(
        MaterialApp(
          home: DailyCardDrawDialog(controller: c, mobileExperience: true),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      if (c.reduction) {
        for (var tab = 0; tab < 3; tab++) {
          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey(tab),
              home: ReductionSupportPage(controller: c, initialTab: tab),
            ),
          );
          await tester.pumpAndSettle();
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
