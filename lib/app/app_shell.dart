import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/home/presentation/daily_card_draw_dialog.dart';
import 'package:youwell/features/home/presentation/home_page.dart';
import 'package:youwell/features/profile/presentation/profile_page.dart';
import 'package:youwell/features/progress/presentation/progress_page.dart';
import 'package:youwell/features/reset/presentation/reset_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});
  final WellnessController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  bool _drawing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.prepareToday();
      _openDailyDraw();
    });
  }

  Future<void> _openDailyDraw() async {
    if (!mounted || _drawing || !widget.controller.needsDailyCardDraw) return;
    _drawing = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DailyCardDrawDialog(controller: widget.controller),
    );
    _drawing = false;
  }

  void _openProfile() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ProfilePage(controller: widget.controller),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(controller: widget.controller, onOpenDraw: _openDailyDraw),
      ResetPage(controller: widget.controller),
      ProgressPage(controller: widget.controller),
    ];
    const labels = ['Hari ini', 'Reset', 'Progress'];
    const icons = [
      Icons.home_rounded,
      Icons.bolt_rounded,
      Icons.insights_rounded,
    ];
    final alias = widget.controller.profile!['alias'].toString();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 14, 8),
              child: Row(
                children: [
                  const Text(
                    'youwell.',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  if (widget.controller.needsDailyCardDraw)
                    IconButton(
                      tooltip: 'Ambil bonus hari ini',
                      onPressed: _openDailyDraw,
                      icon: const Icon(Icons.style_rounded, color: appAccent),
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
                        backgroundColor: appRaised,
                        child: Text(
                          alias[0].toUpperCase(),
                          style: const TextStyle(
                            color: appAccent,
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
              child: IndexedStack(index: _tab, children: pages),
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
    );
  }
}
