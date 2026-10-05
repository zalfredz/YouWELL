import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/app/youwell_app.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/features/home/presentation/home_page.dart';
import 'package:youwell/shared/widgets/wellness_companion.dart';

void main() {
  for (final mode in ['light', 'dark']) {
    testWidgets(
      'Enabled reduction path is discoverable and usable in $mode mode',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = WellnessController();
        await controller.setup({
          'alias': 'preview',
          'path': 'wellness',
          'pace': 1,
          'companion': 'plant',
        });
        controller.selectDailyCard(
          controller.dailyDrawCards.first['id'].toString(),
        );
        controller.commitDailyCardPack();
        final plan = controller.quests;
        await controller.setThemePreference(mode);
        await tester.pumpWidget(YouWellApp(controller: controller));
        await tester.pumpAndSettle();
        expect(find.text('Kurangi rokok / vape'), findsNothing);

        final profile = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Buka profil',
        );
        await tester.tap(profile);
        await tester.pumpAndSettle();
        final preference = find.widgetWithText(
          SwitchListTile,
          'Jalur kurangi rokok / vape',
        );
        await tester.ensureVisible(preference);
        await tester.tap(preference);
        await tester.pumpAndSettle();
        expect(controller.reduction, isTrue);
        expect(find.text('Buka bantuan rokok / vape'), findsOneWidget);
        expect(
          WellnessController(saved: controller.export()).reduction,
          isTrue,
        );
        expect(controller.quests, plan);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Kurangi rokok / vape'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Kurangi rokok / vape')).dy,
          greaterThan(tester.getBottomLeft(find.byType(WellnessCompanion)).dy),
        );
        await tester.ensureVisible(find.text('Buka bantuan rokok / vape'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Buka bantuan rokok / vape'));
        await tester.pumpAndSettle();
        expect(find.text('Bantuan rokok / vape'), findsOneWidget);
        expect(find.text('05:00'), findsOneWidget);
        await tester.tap(find.text('Mulai'));
        await tester.pump(const Duration(minutes: 5));
        await tester.pumpAndSettle();
        expect(controller.delayedToday, 1);
        expect(find.text('Jeda selesai dan sudah dicatat.'), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('1 jeda selesai hari ini'), findsOneWidget);
        controller.switchPath(false);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(HomePage),
            matching: find.text('Kurangi rokok / vape'),
          ),
          findsNothing,
        );
        expect(controller.habitDelays, hasLength(1));
        expect(controller.quests, plan);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
