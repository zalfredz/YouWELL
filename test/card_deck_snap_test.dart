import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/features/home/presentation/daily_card_draw_dialog.dart';

import 'support/sim.dart';

/// A wheel or trackpad scroll must never leave the deck between two cards.
void main() {
  testWidgets('A scroll that stops mid-way settles on the nearest card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sim = Sim();
    await sim.start(pace: 1);
    sim.controller.setReduceMotion(true);
    await tester.pumpWidget(
      MaterialApp(
        home: DailyCardDrawDialog(
          controller: sim.controller,
          mobileExperience: true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    final pageView = find.byType(PageView);
    final controller = tester.widget<PageView>(pageView).controller!;
    final start = controller.page!;
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(tester.getCenter(pageView));
    // A third of a card width: on its own this would stop between cards.
    await tester.sendEventToBinding(pointer.scroll(const Offset(60, 0)));
    await tester.pump();
    expect(controller.page! - controller.page!.round(), isNot(0));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(controller.page, controller.page!.roundToDouble());
    expect((controller.page! - start).abs(), lessThanOrEqualTo(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
