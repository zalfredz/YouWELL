// Renders every page to PNG in ~/Downloads/YouWELL_Screenshots for review.
// Run: flutter test tool/capture_screens_test.dart (not part of the suite).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/app/youwell_app.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/config/app_mode.dart';
import 'package:youwell/core/theme/app_theme.dart';
import 'package:youwell/core/utils/date_key.dart';
import 'package:youwell/features/community/presentation/admin_shell.dart';
import 'package:youwell/features/home/presentation/daily_card_draw_dialog.dart';
import 'package:youwell/features/reduction/presentation/habit_swap_panel.dart';
import 'package:youwell/features/reduction/presentation/reduction_diary.dart';
import 'package:youwell/features/reduction/presentation/reduction_progress.dart';
import 'package:youwell/features/reduction/presentation/reduction_support_page.dart';
import 'package:youwell/features/reduction/presentation/swap_setup_flow.dart';

import '../test/support/sim.dart';

final out = '${Platform.environment['HOME']}/Downloads/YouWELL_Screenshots';
final shotKey = GlobalKey();
final failures = <String>[];

Future<void> loadFonts() async {
  final nunito = FontLoader('Nunito');
  for (final w in ['Regular', 'SemiBold', 'Bold', 'ExtraBold', 'Black']) {
    nunito.addFont(rootBundle.load('assets/fonts/Nunito-$w.ttf'));
  }
  await nunito.load();
  final sdk = Platform.environment['FLUTTER_ROOT'] ?? '/usr/local/share/flutter';
  final fonts = Directory('$sdk/bin/cache/artifacts/material_fonts');
  Future<ByteData> read(String name) async =>
      ByteData.sublistView(await File('${fonts.path}/$name').readAsBytes());
  await (FontLoader('MaterialIcons')
        ..addFont(read('MaterialIcons-Regular.otf')))
      .load();
  final roboto = FontLoader('Roboto');
  for (final f in ['Regular', 'Medium', 'Bold', 'Black']) {
    roboto.addFont(read('Roboto-$f.ttf'));
  }
  await roboto.load();
  // The admin theme asks for Arial, which tests do not ship; Roboto stands in.
  final arial = FontLoader('Arial');
  for (final f in ['Regular', 'Medium', 'Bold', 'Black']) {
    arial.addFont(read('Roboto-$f.ttf'));
  }
  await arial.load();
}

Widget frame(Widget child) => RepaintBoundary(key: shotKey, child: child);

void size(WidgetTester t, double w, double h, {double ratio = 3}) {
  t.view.physicalSize = Size(w * ratio, h * ratio);
  t.view.devicePixelRatio = ratio;
}

Future<void> snap(WidgetTester t, String folder, String name,
    {bool settle = true}) async {
  try {
    if (settle) {
      await t.pumpAndSettle(const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate, const Duration(seconds: 10));
    } else {
      await t.pump(const Duration(milliseconds: 600));
    }
    t.takeException();
    final boundary =
        shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await t.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: t.view.devicePixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('$out/$folder')..createSync(recursive: true);
      File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  } catch (error) {
    failures.add('$folder/$name: $error');
  }
}

Future<void> back(WidgetTester t) async {
  await t.state<NavigatorState>(find.byType(Navigator).last).maybePop();
  await t.pumpAndSettle();
}

Future<void> tapText(WidgetTester t, String text, {bool last = false}) async {
  final f = find.text(text);
  if (f.evaluate().isEmpty) {
    await t.scrollUntilVisible(f, 200,
        scrollable: find.byType(Scrollable).first);
  }
  final target = last ? f.last : f.first;
  await t.ensureVisible(target);
  await t.pumpAndSettle();
  await t.tap(target, warnIfMissed: false);
  await t.pumpAndSettle();
}

/// A wellness user ten days in, with finished days and some history.
Future<Sim> wellnessUser() async {
  final sim = Sim();
  sim.now = DateTime(2026, 10, 10, 20);
  await sim.start(pace: 2, ageGroup: '18-22');
  for (var day = 0; day < 10; day++) {
    sim.takeCard();
    for (final task in [...sim.controller.coreQuests]) {
      if (day == 9 && task == sim.controller.coreQuests.last) break;
      sim.finish(task);
    }
    if (day < 9) sim.nextDay();
  }
  sim.controller.setReduceMotion(true);
  return sim;
}

/// A reduction user with diary, setup and moments.
Future<Sim> reductionUser(String product) async {
  final sim = Sim();
  sim.now = DateTime(2026, 10, 10, 20);
  await sim.start(path: 'reduction', pace: 1, ageGroup: '18-22');
  final c = sim.controller..setNicotineProduct(product);
  c.saveSwapSetup('cigarette',
      triggers: ['after_meal', 'coffee'], activities: ['walk', 'water']);
  if (product == 'both') c.saveSwapSetup('vape', activities: ['music', 'hands']);
  for (var day = 0; day < 10; day++) {
    if (day % 4 != 3) {
      c.saveNicotineDay(
        day: c.today,
        product: product,
        cigarettes: day < 7 ? 6 - day % 2 : 4,
        vapeSessions: day < 7 ? 5 : 3,
      );
    }
    c.startSwapMoment(product: 'cigarette', activities: ['walk']);
    final id = c.reportSwapTried(triggers: ['coffee'])!;
    if (day != 9) c.recordSwapOutcome(id, day.isEven ? 'skipped' : 'used');
    if (day < 9) sim.nextDay();
  }
  c.setReduceMotion(true);
  return sim;
}

void main() {
  setUpAll(loadFonts);
  tearDownAll(() {
    // ignore: avoid_print
    print(failures.isEmpty ? 'ALL OK' : 'FAILED:\n${failures.join('\n')}');
  });

  testWidgets('01 onboarding', (t) async {
    size(t, 390, 844);
    final c = WellnessController();
    await t.pumpWidget(frame(YouWellApp(controller: c, surface: AppSurface.mobile)));
    await snap(t, '01_Onboarding', '1_usia');
    await tapText(t, '18–22 tahun');
    await tapText(t, 'Lanjut');
    await tapText(t, 'Better Daily Rhythm');
    await snap(t, '01_Onboarding', '2_jalur');
    await tapText(t, 'Lanjut');
    await snap(t, '01_Onboarding', '3_tempo');
    await tapText(t, 'Lanjut');
    await snap(t, '01_Onboarding', '4_companion_alias');
  });

  testWidgets('01b onboarding reduction', (t) async {
    size(t, 390, 844);
    final c = WellnessController();
    await t.pumpWidget(frame(YouWellApp(controller: c, surface: AppSurface.mobile)));
    await t.pumpAndSettle();
    await tapText(t, '18–22 tahun');
    await tapText(t, 'Lanjut');
    await tapText(t, 'Berhenti rokok / vape');
    await snap(t, '01_Onboarding', '2b_jalur_rokok_vape');
  });

  testWidgets('02 home and card draw', (t) async {
    size(t, 390, 844);
    final sim = Sim();
    sim.now = DateTime(2026, 10, 10, 9);
    await sim.start(pace: 2, ageGroup: '18-22');
    sim.controller.setReduceMotion(true);
    await t.pumpWidget(frame(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.mobileLight,
      home: DailyCardDrawDialog(controller: sim.controller, mobileExperience: true),
    )));
    await snap(t, '03_Daily_Card_Draw', '1_pilih_kartu');
    try {
      await tapText(t, 'Buka rekomendasi · 4 misi');
      await snap(t, '03_Daily_Card_Draw', '2_kartu_terbuka');
    } catch (e) {
      failures.add('card open: $e');
    }

    final user = await wellnessUser();
    await t.pumpWidget(frame(YouWellApp(controller: user.controller, surface: AppSurface.mobile)));
    await snap(t, '02_Home', '1_home_atas');
    size(t, 390, 1700);
    await snap(t, '02_Home', '2_home_penuh');
    size(t, 390, 844);
    try {
      await t.tap(find.textContaining('siap naik level'));
      await t.pumpAndSettle();
      await snap(t, '02_Home', '4_siap_naik_level');
      await back(t);
    } catch (e) {
      failures.add('ladder sheet: $e');
    }
  });

  testWidgets('04-07 tabs', (t) async {
    final user = await wellnessUser();
    size(t, 390, 844);
    await t.pumpWidget(frame(YouWellApp(controller: user.controller, surface: AppSurface.mobile)));
    await t.pumpAndSettle();
    Future<void> tab(int i) async {
      await t.tap(find.byType(NavigationDestination).at(i));
      await t.pumpAndSettle();
    }
    await tab(1);
    await snap(t, '04_Aktivitas', '1_aktivitas');
    size(t, 390, 1400);
    await snap(t, '04_Aktivitas', '2_aktivitas_penuh');
    size(t, 390, 844);
    try {
      await tapText(t, 'Jalan atau lari');
      await snap(t, '04_Aktivitas', '3_jalan_lari');
      await back(t);
      await tapText(t, 'Meal Snap');
      await snap(t, '04_Aktivitas', '4_meal_snap');
      await back(t);
      await tapText(t, 'Riwayat aktivitas');
      await snap(t, '04_Aktivitas', '5_riwayat');
      await back(t);
    } catch (e) {
      failures.add('activity pages: $e');
    }
    await tab(2);
    await snap(t, '05_Perjalanan', '1_perjalanan');
    size(t, 390, 2200);
    await snap(t, '05_Perjalanan', '2_perjalanan_penuh');
    size(t, 390, 844);
    await tab(3);
    await snap(t, '06_Komunitas', '1_komunitas');
    try {
      await tapText(t, 'Bagikan progres');
      await snap(t, '06_Komunitas', '2_buat_post');
      await back(t);
    } catch (e) {
      failures.add('community compose: $e');
    }
    await tab(0);
    try {
      final profile = find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Buka profil');
      await t.tap(profile);
      await t.pumpAndSettle();
      await snap(t, '07_Profil', '1_profil');
      size(t, 390, 1700);
      await snap(t, '07_Profil', '2_profil_penuh');
      size(t, 390, 844);
      await back(t);
    } catch (e) {
      failures.add('profile: $e');
    }
    try {
      final gift = find.byIcon(Icons.card_giftcard_rounded);
      await t.ensureVisible(gift.first);
      await t.pumpAndSettle();
      await t.tap(gift.first);
      await t.pumpAndSettle();
    } catch (e) {
      failures.add('companion: $e');
    }
    await snap(t, '08_Companion', '1_companion');
    size(t, 390, 1800);
    await snap(t, '08_Companion', '2_companion_penuh');
  });

  for (final product in ['cigarette', 'both']) {
    final name = product == 'both' ? 'keduanya' : 'rokok';
    testWidgets('09 reduction $product', (t) async {
      size(t, 390, 844);
      final sim = await reductionUser(product);
      final c = sim.controller;
      final folder = '09_Rokok_Vape_$name';
      await t.pumpWidget(frame(YouWellApp(controller: c, surface: AppSurface.mobile)));
      await t.pumpAndSettle();
      size(t, 390, 1700);
      await snap(t, folder, '1_home');
      size(t, 390, 844);
      Future<void> page(Widget w, String file, {double h = 844}) async {
        size(t, 390, h);
        await t.pumpWidget(frame(MaterialApp(
      debugShowCheckedModeBanner: false,
          key: ValueKey(file),
          theme: AppTheme.mobileLight,
          home: Scaffold(appBar: AppBar(title: Text(c.reductionLabel)), body: w),
        )));
        await snap(t, folder, file);
      }
      await page(SwapSetupFlow(controller: c, products: productsOf(product)), '2_persiapan');
      await page(HabitSwapPanel(controller: c, product: product == 'both' ? null : product), '3_momen_mulai', h: 1000);
      if (product == 'both') {
        await page(HabitSwapPanel(controller: c, product: 'cigarette'), '3b_momen_pilih_kegiatan', h: 1000);
      }
      await page(HabitSwapPanel(controller: c, outcomeFor: c.swapsAwaitingOutcome.first['id']), '5_hasil');
      c.startSwapMoment(product: 'cigarette', activities: ['walk', 'water']);
      await page(HabitSwapPanel(controller: c), '4_sedang_mencoba');
      size(t, 390, 1500);
      await t.pumpWidget(frame(YouWellApp(controller: c, surface: AppSurface.mobile)));
      await t.pumpAndSettle();
      await snap(t, folder, '4b_home_sedang_mencoba');
      c.cancelSwapMoment();
      await page(ReductionDiary(controller: c), '6_catatan_harian', h: 1000);
      await page(ReductionProgress(controller: c), '7_progres', h: product == 'both' ? 2150 : 1650);
      await page(ReductionSupportPage(controller: c), '8_halaman_tab');
    });
  }

  testWidgets('10 celebration', (t) async {
    size(t, 390, 844);
    final sim = Sim();
    await sim.start(pace: 1);
    sim.controller.enableMobileRewards();
    sim.takeCard();
    await t.pumpWidget(frame(YouWellApp(controller: sim.controller, surface: AppSurface.mobile)));
    await t.pump(const Duration(seconds: 1));
    for (final task in [...sim.controller.coreQuests]) {
      sim.finish(task);
    }
    for (var n = 0; n < 40 && find.text('Kerja bagus!').evaluate().isEmpty; n++) {
      await t.pump(const Duration(milliseconds: 500));
    }
    await t.pump(const Duration(milliseconds: 3800));
    await snap(t, '02_Home', '3_hari_penuh_kerja_bagus', settle: false);
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('11 admin web', (t) async {
    size(t, 1280, 860, ratio: 2);
    final sim = Sim();
    await sim.start(pace: 1);
    final c = sim.controller;
    for (final text in ['Hari ini jalan sore 20 menit!', 'Minum air sudah 1,5 liter.', 'Tidur lebih awal semalam.']) {
      c.submitCommunityPost(text);
    }
    final posts = c.moderationQueue;
    c.moderateCommunityPost(posts.first['id'], 'approved');
    await t.pumpWidget(frame(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: AdminShell(controller: c),
    )));
    await snap(t, '11_Admin_Web', '1_community_menunggu');
    await tapText(t, 'Sudah tayang');
    await snap(t, '11_Admin_Web', '2_community_sudah_tayang');
    await tapText(t, 'Laporan (0)');
    await snap(t, '11_Admin_Web', '3_community_laporan');
    await t.tap(find.text('Dashboard peneliti'));
    await snap(t, '11_Admin_Web', '4_dashboard_peneliti');
  });
}

List<String> productsOf(String product) =>
    product == 'both' ? ['cigarette', 'vape'] : [product];

// Keeps the date helper import used by future edits.
String unusedDay() => dayKey(DateTime(2026));
