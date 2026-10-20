import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/features/reduction/presentation/reduction_diary.dart';

import 'support/sim.dart';

Future<void> tapTimes(WidgetTester tester, String label, int times) async {
  for (var i = 0; i < times; i++) {
    await tester.tap(find.bySemanticsLabel(label));
    await tester.pump();
  }
}

void main() {
  testWidgets(
    'Daily totals are tapped in and saved; zero and correction persist '
    'without XP',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final sim = Sim();
      await sim.start(path: 'reduction');
      final c = sim.controller;
      c.setNicotineProduct('both');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ReductionDiary(controller: c)),
        ),
      );
      expect(c.nicotineDays, isEmpty);
      expect(find.bySemanticsLabel(RegExp('belum diisi')), findsWidgets);

      // Two separate counters; a vape session is never a cigarette.
      await tapTimes(tester, 'Tambah satu sesi Vape', 4);
      await tester.tap(find.text('Simpan total hari ini'));
      await tester.pump();
      expect(c.nicotineDay(c.today)!['cigarette'], 0);
      expect(c.nicotineDay(c.today)!['vape'], 4);
      expect(find.text('Tercatat: 0 batang · 4 sesi'), findsOneWidget);
      expect(c.xp, 0);

      // Correcting the same day keeps one record.
      await tapTimes(tester, 'Tambah satu batang Rokok', 3);
      await tester.tap(find.text('Simpan total hari ini'));
      await tester.pump();
      expect(c.nicotineDays, hasLength(1));
      expect(c.nicotineDay(c.today)!['cigarette'], 3);
      expect(c.xp, 0);
      expect(find.text('1 hari tercatat'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('A saved zero reads as a day without, in green', (tester) async {
    final sim = Sim();
    await sim.start(path: 'reduction');
    sim.controller.setNicotineProduct('cigarette');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ReductionDiary(controller: sim.controller)),
      ),
    );
    await tester.tap(find.text('Simpan total hari ini'));
    await tester.pump();
    expect(sim.controller.nicotineDay(sim.controller.today)!['cigarette'], 0);
    expect(find.text('Tercatat: 0 batang. Mantap!'), findsOneWidget);
    expect(sim.controller.dayWithoutUse(sim.controller.today), isTrue);
  });

  testWidgets('Vape-only diary counts sessions and never cigarettes', (
    tester,
  ) async {
    final sim = Sim();
    await sim.start(path: 'reduction');
    sim.controller.setNicotineProduct('vape');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ReductionDiary(controller: sim.controller)),
      ),
    );
    expect(find.bySemanticsLabel('Tambah satu sesi'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('batang')), findsNothing);
    expect(find.textContaining('batang'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
