import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/theme/appearance_scope.dart';
import 'package:youwell/features/activity/presentation/activity_page.dart';
import 'package:youwell/features/community/presentation/community_page.dart';
import 'package:youwell/features/home/presentation/daily_card_draw_dialog.dart';
import 'package:youwell/features/home/presentation/home_page.dart';
import 'package:youwell/features/profile/presentation/profile_page.dart';
import 'package:youwell/features/progress/presentation/progress_page.dart';
import 'package:youwell/features/reset/presentation/reset_page.dart';
import 'package:youwell/features/companion/presentation/mobile_reward_host.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});
  final WellnessController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _tab = 0;
  bool _drawing = false;
  late String _day = widget.controller.today;
  Timer? _dayWatcher;
  final _companionTarget = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.controller.enableMobileRewards();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startDay());
    // Catch midnight while the app stays open in the foreground.
    _dayWatcher = Timer.periodic(const Duration(minutes: 1), (_) {
      if (widget.controller.today != _day) _startDay();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dayWatcher?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _startDay();
  }

  void _startDay() {
    if (!mounted) return;
    _day = widget.controller.today;
    widget.controller.prepareToday();
    _openDailyDraw();
  }

  Future<void> _openDailyDraw() async {
    if (!mounted || _drawing || !widget.controller.needsDailyCardDraw) return;
    _drawing = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DailyCardDrawDialog(
        controller: widget.controller,
        mobileExperience: true,
      ),
    );
    _drawing = false;
  }

  void _openProfile() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          ProfilePage(controller: widget.controller, mobileExperience: true),
    ),
  );

  void _openReset({bool delay = false}) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AnimatedBuilder(
        animation: widget.controller,
        builder: (_, _) => Scaffold(
          appBar: AppBar(title: const Text('Ambil jeda')),
          body: ResetPage(
            controller: widget.controller,
            initialMode: delay ? 'delay' : 'reset',
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        controller: widget.controller,
        companionKey: _companionTarget,
        onOpenDraw: _openDailyDraw,
        onOpenReset: () => _openReset(),
        onOpenActivity: () => setState(() => _tab = 1),
      ),
      ActivityPage(controller: widget.controller),
      ProgressPage(controller: widget.controller),
      CommunityPage(controller: widget.controller),
    ];
    const labels = ['Hari ini', 'Aktivitas', 'Perjalanan', 'Komunitas'];
    const icons = [
      Icons.home_rounded,
      Icons.directions_run_rounded,
      Icons.route_rounded,
      Icons.people_alt_outlined,
    ];
    final alias = widget.controller.profile!['alias'].toString();
    return MobileRewardHost(
      controller: widget.controller,
      target: _companionTarget,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 14, 8),
                child: Row(
                  children: [
                    const Text(
                      'youwell',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    const ThemeModeButton(),
                    if (widget.controller.needsDailyCardDraw)
                      IconButton(
                        tooltip: 'Ambil kartu hari ini',
                        onPressed: _openDailyDraw,
                        icon: Icon(
                          Icons.style_rounded,
                          color: context.colors.accent,
                        ),
                      ),
                    const SizedBox(width: 4),
                    Semantics(
                      button: true,
                      label: 'Buka profil',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(40),
                        onTap: _openProfile,
                        child: CircleAvatar(
                          radius: 21,
                          backgroundColor: context.colors.raised,
                          child: Text(
                            alias[0].toUpperCase(),
                            style: TextStyle(
                              color: context.colors.accent,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: _tab,
                  children: [
                    for (final (index, page) in pages.indexed)
                      TickerMode(enabled: index == _tab, child: page),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (value) => setState(() => _tab = value),
          destinations: List.generate(
            labels.length,
            (index) => NavigationDestination(
              icon: Icon(icons[index]),
              label: labels[index],
            ),
          ),
        ),
      ),
    );
  }
}
