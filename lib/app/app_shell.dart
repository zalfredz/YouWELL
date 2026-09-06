import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/community/presentation/community_page.dart';
import 'package:youwell/features/home/presentation/home_page.dart';
import 'package:youwell/features/profile/presentation/profile_page.dart';
import 'package:youwell/features/relief/presentation/relief_menu_sheet.dart';
import 'package:youwell/features/statistics/presentation/statistics_page.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});
  final WellnessController controller;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int tab = 0;
  late Timer clock;
  @override
  void initState() {
    super.initState();
    clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = kIsWeb || MediaQuery.sizeOf(context).width >= 1000;
    final pages = [
      HomePage(
        controller: widget.controller,
        onStats: () => setState(() => tab = 1),
      ),
      StatisticsPage(controller: widget.controller),
      CommunityPage(controller: widget.controller),
      ProfilePage(controller: widget.controller),
    ];
    final labels = ['Hari ini', 'Statistik', 'Komunitas', 'Profil'];
    final icons = [
      Icons.grid_view_rounded,
      Icons.bar_chart_rounded,
      Icons.people_outline_rounded,
      Icons.person_outline_rounded,
    ];
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              Container(
                width: 235,
                padding: const EdgeInsets.fromLTRB(22, 30, 22, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    right: BorderSide(color: ink.withValues(alpha: .06)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.spa, color: green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: title('youwell.', size: 30),
                          ),
                        ),
                      ],
                    ),
                    gap(8),
                    caption('a little better, every day'),
                    gap(44),
                    ...List.generate(
                      4,
                      (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          selected: tab == i,
                          selectedTileColor: const Color(0xffedf2e9),
                          leading: Icon(
                            icons[i],
                            color: tab == i ? green : muted,
                          ),
                          title: Text(labels[i]),
                          onTap: () => setState(() => tab = i),
                        ),
                      ),
                    ),
                    const Spacer(),
                    panel([
                      const Icon(Icons.wb_sunny_outlined, color: green),
                      gap(),
                      const Text(
                        'Pelan juga\ntetap berjalan.',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      gap(8),
                      caption('Kamu tidak perlu sempurna untuk memulai.'),
                    ], color: cream),
                    tag('PREVIEW • DATA LOKAL'),
                  ],
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 36 : 20,
                      vertical: 18,
                    ),
                    color: cream,
                    child: Row(
                      children: [
                        if (!wide)
                          title('youwell.', size: 23)
                        else
                          caption(
                            'YOUR WELLNESS SPACE  /  ${labels[tab].toUpperCase()}',
                          ),
                        const Spacer(),
                        if (!wide) tag('LOKAL'),
                        const SizedBox(width: 10),
                        CircleAvatar(
                          backgroundColor: const Color(0xffe5eddf),
                          child: Text(
                            widget.controller.profile!['alias']
                                .toString()[0]
                                .toUpperCase(),
                            style: const TextStyle(color: green),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.controller.storageError != null)
                    MaterialBanner(
                      content: Text(widget.controller.storageError!),
                      actions: [
                        TextButton(
                          onPressed: () => setState(() => tab = 3),
                          child: const Text('Kontrol data'),
                        ),
                      ],
                    ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1160),
                        child: pages[tab],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (v) => setState(() => tab = v),
              destinations: List.generate(
                4,
                (i) => NavigationDestination(
                  icon: Icon(icons[i]),
                  label: labels[i],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            sheet(context, ReliefMenuSheet(controller: widget.controller)),
        backgroundColor: ink,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Ambil jeda'),
      ),
    );
  }
}
