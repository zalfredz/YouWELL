import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youwell/app/web_experience_gate.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/platform/platform.dart' as platform;
import 'package:youwell/core/utils/date_key.dart';
import 'package:youwell/features/home/presentation/daily_card_draw_dialog.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';
import 'package:youwell/shared/widgets/wellness_companion.dart';

const _bg = Color(0xff0d0e11);
const _panel = Color(0xff16181d);
const _raised = Color(0xff1c1f25);
const _line = Color(0xff2a2d34);
const _text = Color(0xfff1f3f5);
const _muted = Color(0xff9298a3);
const _green = Color(0xff78e3b1);
const _cyan = Color(0xff77d7e5);
const _amber = Color(0xffffc875);

/// Desktop dashboard with the same data controller as mobile, tuned for focus.
class WebWorkspacePage extends StatefulWidget {
  const WebWorkspacePage({
    super.key,
    required this.controller,
    this.isAdmin = false,
  });
  final WellnessController controller;
  final bool isAdmin;

  @override
  State<WebWorkspacePage> createState() => _WebWorkspacePageState();
}

class _WebWorkspacePageState extends State<WebWorkspacePage> {
  int _tab = 0;
  bool _showCompanion = true;
  bool _minimizeCompanion = false;
  bool _isPresentingDailyDraw = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _presentDailyDraw());
  }

  Future<void> _presentDailyDraw() async {
    if (!mounted ||
        _isPresentingDailyDraw ||
        !widget.controller.needsDailyCardDraw) {
      return;
    }
    _isPresentingDailyDraw = true;
    final committed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DailyCardDrawDialog(controller: widget.controller),
    );
    _isPresentingDailyDraw = false;
    if (!mounted || committed != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Card committed. Challenge ini terkunci untuk hari ini.'),
      ),
    );
  }

  Future<void> _openProfile() => showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: _bg,
          insetPadding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: _SettingsPage(controller: widget.controller),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    tooltip: 'Tutup profile',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: _muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) => WebWorkspaceGate(
          onReturnToLanding: () =>
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
          child: _Dashboard(
            controller: widget.controller,
            isAdmin: widget.isAdmin,
            tab: _tab,
            onTab: (value) => setState(() => _tab = value),
            onOpenDailyDraw: _presentDailyDraw,
            onOpenProfile: _openProfile,
            showCompanion: _showCompanion,
            minimized: _minimizeCompanion,
            setCompanion: ({bool? open, bool? minimized}) => setState(() {
              _showCompanion = open ?? _showCompanion;
              _minimizeCompanion = minimized ?? _minimizeCompanion;
            }),
          ),
        ),
      );
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({
    required this.controller,
    required this.isAdmin,
    required this.tab,
    required this.onTab,
    required this.onOpenDailyDraw,
    required this.onOpenProfile,
    required this.showCompanion,
    required this.minimized,
    required this.setCompanion,
  });
  final WellnessController controller;
  final bool isAdmin;
  final int tab;
  final ValueChanged<int> onTab;
  final Future<void> Function() onOpenDailyDraw;
  final Future<void> Function() onOpenProfile;
  final bool showCompanion;
  final bool minimized;
  final void Function({bool? open, bool? minimized}) setCompanion;

  @override
  Widget build(BuildContext context) {
    final nav = <_NavItem>[
      const _NavItem('Home', Icons.home_outlined),
      const _NavItem('Focus & Craving', Icons.timer_outlined),
      const _NavItem('Squad & Community', Icons.groups_2_outlined),
      if (isAdmin)
        const _NavItem('Community Admin', Icons.admin_panel_settings_outlined),
    ];
    void openCompanion() => setCompanion(open: true, minimized: false);
    final pages = <Widget>[
      _TodayPage(
        controller: controller,
        onTab: onTab,
        onOpenDailyDraw: onOpenDailyDraw,
      ),
      _AnalyticsPage(controller: controller, openCompanion: openCompanion),
      _CommunityHubPage(controller: controller),
      if (isAdmin) _AdminPage(controller: controller),
    ];
    final safeTab = tab.clamp(0, nav.length - 1);
    final alias = controller.profile?['alias']?.toString() ?? 'Y';
    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: _bg,
        colorScheme: const ColorScheme.dark(primary: _green, secondary: _cyan),
        dividerColor: _line,
      ),
      child: Scaffold(
        body: Row(
          children: [
            _Sidebar(nav: nav, current: safeTab, onTab: onTab, admin: isAdmin),
            Expanded(
              child: Stack(
                children: [
                  Column(
                    children: [
                      _Header(
                        section: nav[safeTab].label,
                        alias: alias,
                        onSettings: onOpenProfile,
                      ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: KeyedSubtree(
                            key: ValueKey(safeTab),
                            child: pages[safeTab],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    right: 20,
                    bottom: 20,
                    child: showCompanion
                        ? _Companion(
                            controller: controller,
                            minimized: minimized,
                            onMinimize: () => setCompanion(minimized: true),
                            onExpand: () => setCompanion(minimized: false),
                            onClose: () => setCompanion(open: false),
                          )
                        : FilledButton.icon(
                            onPressed: openCompanion,
                            icon: const _Dot(),
                            label: const Text('Open Companion'),
                            style: _greenButton,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.nav,
    required this.current,
    required this.onTab,
    required this.admin,
  });
  final List<_NavItem> nav;
  final int current;
  final ValueChanged<int> onTab;
  final bool admin;

  @override
  Widget build(BuildContext context) => Container(
        width: 244,
        decoration: const BoxDecoration(
          color: Color(0xff101216),
          border: Border(right: BorderSide(color: _line)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 21, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  _Mark(),
                  SizedBox(width: 9),
                  Text(
                    'YouWell.MD',
                    style: TextStyle(
                      color: _text,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 8, 11, 28),
              child: Text(
                admin ? 'ADMIN WORKSPACE' : 'PERSONAL WORKSPACE',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            ...List.generate(nav.length, (index) {
              final selected = index == current;
              return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onTab(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xff20242a)
                          : Colors.transparent,
                      border: selected
                          ? Border.all(color: const Color(0xff323741))
                          : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          nav[index].icon,
                          size: 18,
                          color: selected ? _green : _muted,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            nav[index].label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected ? _text : _muted,
                              fontSize: 13,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const Spacer(),
            const _Card(
              padding: 12,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.phone_iphone_rounded, color: _cyan, size: 17),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Log foto dan check-in cepat tersedia di mobile.',
                      style:
                          TextStyle(color: _muted, fontSize: 11, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.section,
    required this.alias,
    required this.onSettings,
  });
  final String section;
  final String alias;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: const BoxDecoration(
          color: Color(0xff101216),
          border: Border(bottom: BorderSide(color: _line)),
        ),
        child: Row(
          children: [
            const Text('Workspace',
                style: TextStyle(color: _muted, fontSize: 13)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.chevron_right_rounded, color: _muted, size: 17),
            ),
            Text(
              section,
              style: const TextStyle(
                color: _text,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            const _Dot(),
            const SizedBox(width: 7),
            const Text(
              'Local preview',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(width: 18),
            Tooltip(
              message: 'Buka settings',
              child: InkWell(
                onTap: onSettings,
                borderRadius: BorderRadius.circular(20),
                child: CircleAvatar(
                  radius: 15,
                  backgroundColor: const Color(0xff233a35),
                  foregroundColor: _green,
                  child: Text(
                    alias.isEmpty ? 'Y' : alias.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _Scroll extends StatelessWidget {
  const _Scroll({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Scrollbar(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 30, 32, 110),
          child: child,
        ),
      );
}

class _TodayPage extends StatelessWidget {
  const _TodayPage({
    required this.controller,
    required this.onTab,
    required this.onOpenDailyDraw,
  });
  final WellnessController controller;
  final ValueChanged<int> onTab;
  final Future<void> Function() onOpenDailyDraw;

  @override
  Widget build(BuildContext context) {
    final alias = controller.profile?['alias']?.toString() ?? 'teman';
    return _Scroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Good ${_greeting()}, $alias.',
            style: const TextStyle(
              color: _text,
              fontSize: 31,
              fontWeight: FontWeight.w800,
              letterSpacing: -.9,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Satu langkah kecil cukup untuk mengubah arah hari ini.',
            style: TextStyle(color: _muted, fontSize: 14),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, box) {
              final tasks = _DailyCardSystem(
                controller: controller,
                onOpenDailyDraw: onOpenDailyDraw,
              );
              final companion = _CompanionShowcase(controller: controller);
              final compliance = _WeeklyComplianceCard(
                controller: controller,
                onAnalytics: () => onTab(1),
              );
              final rewards = _RewardsCard(controller: controller);
              final desk = _QuickDeskHabits(
                controller: controller,
                onFocus: () => onTab(1),
              );
              if (box.maxWidth < 1040) {
                return Column(children: [
                  companion,
                  const SizedBox(height: 18),
                  tasks,
                  const SizedBox(height: 18),
                  compliance,
                  const SizedBox(height: 18),
                  rewards,
                  const SizedBox(height: 18),
                  desk,
                ]);
              }
              return Column(children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 4, child: companion),
                  const SizedBox(width: 22),
                  Expanded(flex: 8, child: tasks),
                ]),
                const SizedBox(height: 22),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 5, child: compliance),
                  const SizedBox(width: 22),
                  Expanded(flex: 3, child: rewards),
                  const SizedBox(width: 22),
                  Expanded(flex: 4, child: desk),
                ]),
              ]);
            },
          ),
        ],
      ),
    );
  }

  String _greeting() => DateTime.now().hour < 11
      ? 'morning'
      : DateTime.now().hour < 17
          ? 'afternoon'
          : 'evening';
}

class _DailyCardSystem extends StatelessWidget {
  const _DailyCardSystem({
    required this.controller,
    required this.onOpenDailyDraw,
  });
  final WellnessController controller;
  final Future<void> Function() onOpenDailyDraw;

  @override
  Widget build(BuildContext context) {
    final drawCards = controller.dailyDrawCards;
    final committed = controller.committedCards;
    final completed = controller.completedCards;
    final selected = controller.selectedDailyCard;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Card Draw',
                      style: TextStyle(
                        color: _text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Pilih kartu yang terasa realistis, lalu commit untuk menguncinya hari ini.',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _Pill('${drawCards.length} cards', _cyan),
            ],
          ),
          const SizedBox(height: 18),
          if (drawCards.isEmpty)
            _EmptyDailyDraw(onOpenDailyDraw: onOpenDailyDraw)
          else ...[
            if (selected != null && !controller.hasCommittedDailyCard)
              _DailyCard(controller: controller, card: selected)
            else if (!controller.hasCommittedDailyCard)
              _EmptyDailyDraw(onOpenDailyDraw: onOpenDailyDraw),
            if (committed.isNotEmpty || completed.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Today’s Progress',
                      style: TextStyle(
                        color: _text,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _Pill(
                    '${completed.length} / ${committed.length + completed.length} complete',
                    _green,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: controller.dailyProgress,
                minHeight: 7,
                color: _green,
                backgroundColor: _raised,
                borderRadius: BorderRadius.circular(9),
              ),
              const SizedBox(height: 12),
              ...[...committed, ...completed].map(
                (card) => _CommittedCard(controller: controller, card: card),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _EmptyDailyDraw extends StatelessWidget {
  const _EmptyDailyDraw({required this.onOpenDailyDraw});

  final Future<void> Function() onOpenDailyDraw;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.style_outlined, color: _cyan, size: 31),
              const SizedBox(height: 10),
              const Text(
                'Kartu harianmu belum dipilih.',
                style: TextStyle(color: _text, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 5),
              const Text(
                'Swipe lima kartu tertutup; satu kartu berisi 3–5 task hari ini.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onOpenDailyDraw,
                icon: const Icon(Icons.auto_awesome_rounded, size: 17),
                label: const Text('Open Daily Draw'),
                style: _greenButton,
              ),
            ],
          ),
        ),
      );
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.controller, required this.card});
  final WellnessController controller;
  final Map<String, dynamic> card;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xff191c21),
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Pill('${card['taskCount']} tasks', _cyan),
                const Spacer(),
                Text(
                  '+${card['xp']} XP total',
                  style: const TextStyle(
                    color: _green,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              card['title'].toString(),
              style: const TextStyle(
                color: _text,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              card['description'].toString(),
              style: const TextStyle(color: _muted, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                const Text('Satu paket untuk progres hari ini.',
                    style: TextStyle(color: _muted, fontSize: 12)),
                const Spacer(),
                FilledButton(
                  onPressed: () => _commit(context),
                  style: _greenButton,
                  child: const Text('Commit pack'),
                ),
              ],
            ),
          ],
        ),
      );

  void _commit(BuildContext context) {
    if (!controller.commitDailyCardPack()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Card committed. Challenge ini terkunci untuk hari ini.'),
      ),
    );
  }
}

class _CommittedCard extends StatelessWidget {
  const _CommittedCard({required this.controller, required this.card});
  final WellnessController controller;
  final Map<String, dynamic> card;

  @override
  Widget build(BuildContext context) {
    final completed = card['status'] == 'completed';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: completed ? const Color(0xff17241f) : _raised,
        border: Border.all(color: completed ? const Color(0xff2c4a3c) : _line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            completed ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
            color: completed ? _green : _amber,
            size: 21,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card['title'].toString(),
                  style: TextStyle(
                    color: completed ? _muted : _text,
                    fontWeight: FontWeight.w700,
                    decoration: completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  completed
                      ? '+${card['xp']} XP earned'
                      : 'Committed • locked for today',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (completed)
            const _Pill('Completed', _green)
          else
            FilledButton(
              onPressed: () => _complete(context),
              style: _greenButton,
              child: const Text('Complete'),
            ),
        ],
      ),
    );
  }

  void _complete(BuildContext context) {
    if (!controller.completeCard(card['id'].toString())) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Completed! +${card['xp']} XP added to your progress.'),
      ),
    );
  }
}

class _WeeklyComplianceCard extends StatelessWidget {
  const _WeeklyComplianceCard({
    required this.controller,
    required this.onAnalytics,
  });
  final WellnessController controller;
  final VoidCallback onAnalytics;
  @override
  Widget build(BuildContext context) => _Card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Weekly Compliance',
              style: TextStyle(
                  color: _text, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${(controller.compliance(7) * 100).round()}%',
                style: const TextStyle(
                    color: _green,
                    fontSize: 42,
                    height: .9,
                    fontWeight: FontWeight.w800)),
            const Padding(
              padding: EdgeInsets.only(left: 8, bottom: 3),
              child: Text('7 hari terakhir',
                  style: TextStyle(color: _muted, fontSize: 11)),
            ),
          ]),
          const SizedBox(height: 18),
          SizedBox(height: 120, child: _Bars(controller: controller)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onAnalytics,
            icon: const Icon(Icons.timer_outlined, size: 16),
            label: const Text('Buka Focus & Craving'),
          ),
        ]),
      );
}

class _RewardsCard extends StatelessWidget {
  const _RewardsCard({required this.controller});

  final WellnessController controller;

  @override
  Widget build(BuildContext context) => _Card(
        tint: const Color(0xff162927),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.auto_awesome_rounded, color: _amber, size: 28),
          const SizedBox(height: 15),
          const Text('Today’s rewards',
              style: TextStyle(color: _text, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${controller.dailyXp} XP earned',
              style: const TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(height: 16),
          _Pill('${controller.streak} day streak', _green),
        ]),
      );
}

class _QuickDeskHabits extends StatelessWidget {
  const _QuickDeskHabits({required this.controller, required this.onFocus});

  final WellnessController controller;
  final VoidCallback onFocus;

  @override
  Widget build(BuildContext context) => _Card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Quick desk reset',
              style: TextStyle(color: _text, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${controller.water.round()} ml water logged today',
              style: const TextStyle(color: _muted, fontSize: 11)),
          const SizedBox(height: 13),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.tonalIcon(
              onPressed: () {
                controller.addWater();
                toast(context, 'Water reset logged: +250 ml.');
              },
              icon: const Icon(Icons.water_drop_outlined, size: 16),
              label: const Text('+250 ml'),
            ),
            OutlinedButton.icon(
              onPressed: onFocus,
              icon: const Icon(Icons.self_improvement_rounded, size: 16),
              label: const Text('60 sec reset'),
            ),
          ]),
        ]),
      );
}

class _CompanionShowcase extends StatelessWidget {
  const _CompanionShowcase({required this.controller});

  final WellnessController controller;

  @override
  Widget build(BuildContext context) {
    final kind = controller.profile?['companion']?.toString() ?? 'plant';
    final name =
        {'plant': 'Mori', 'cat': 'Milo', 'cloud': 'Awan'}[kind] ?? 'Companion';
    final dialogue = controller.streak == 0
        ? 'Senang kamu kembali. Kita mulai dari satu langkah kecil, ya.'
        : controller.dailyProgress >= 1
            ? 'Hari ini kita hebat. Aku ikut tumbuh karena kamu.'
            : 'Satu task lagi juga berarti. Aku temani dari sini.';
    return _Card(
      tint: const Color(0xff172421),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text('$name, your companion',
                  style: const TextStyle(
                      color: _text,
                      fontSize: 17,
                      fontWeight: FontWeight.w800))),
          _Pill('LV ${controller.level}', _green),
        ]),
        const SizedBox(height: 3),
        Text('${controller.streak} day streak',
            style: const TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: 7),
        Center(
          child: SizedBox(
            width: 210,
            height: 175,
            child: FittedBox(
              child: WellnessCompanion(kind: kind, level: controller.level),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xff202e2a),
            border: Border.all(color: const Color(0xff315043)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(dialogue,
              style: const TextStyle(color: _text, fontSize: 12, height: 1.45)),
        ),
        const SizedBox(height: 15),
        Row(children: [
          const Text('Level progress',
              style: TextStyle(color: _muted, fontSize: 11)),
          const Spacer(),
          Text('${controller.xp % 100} / 100 XP',
              style: const TextStyle(color: _green, fontSize: 11)),
        ]),
        const SizedBox(height: 7),
        LinearProgressIndicator(
          value: (controller.xp % 100) / 100,
          minHeight: 7,
          color: _green,
          backgroundColor: _raised,
          borderRadius: BorderRadius.circular(8),
        ),
      ]),
    );
  }
}

class _AnalyticsPage extends StatelessWidget {
  const _AnalyticsPage({required this.controller, required this.openCompanion});
  final WellnessController controller;
  final VoidCallback openCompanion;
  @override
  Widget build(BuildContext context) => _Scroll(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Focus & Craving',
              style: TextStyle(
                color: _text,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -.9,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Ruang kecil untuk fokus, mengatur napas, dan memberi craving waktu untuk lewat.',
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, box) {
                final cards = [
                  _Metric(
                    'Compliance',
                    '${(controller.compliance(7) * 100).round()}%',
                    '7 hari terakhir',
                    _green,
                  ),
                  _Metric(
                    'Current streak',
                    '${controller.streak}',
                    'hari kecil yang terjaga',
                    _cyan,
                  ),
                  _Metric(
                    'Delay attempts',
                    '${controller.cravings.length}',
                    'tercatat di akunmu',
                    _amber,
                  ),
                ];
                return box.maxWidth < 700
                    ? Column(
                        children: cards
                            .map(
                              (card) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: card,
                              ),
                            )
                            .toList(),
                      )
                    : Row(
                        children: cards
                            .map(
                              (card) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: card,
                                ),
                              ),
                            )
                            .toList(),
                      );
              },
            ),
            const SizedBox(height: 16),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your weekly rhythm',
                    style: TextStyle(
                      color: _text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Ringkasan ringan agar kamu bisa fokus pada langkah berikutnya.',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(height: 190, child: _Bars(controller: controller)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Card(
              tint: const Color(0xff252018),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: _amber, size: 31),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Butuh jeda dari layar atau craving?',
                          style: TextStyle(
                            color: _text,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Buka reset tools untuk delay timer, napas, soundscape, atau micro-vent.',
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: openCompanion,
                    style: _greenButton,
                    child: const Text('Open reset tools'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.detail, this.color);
  final String label, value, detail;
  final Color color;
  @override
  Widget build(BuildContext context) => _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(detail, style: const TextStyle(color: _muted, fontSize: 11)),
          ],
        ),
      );
}

class _Bars extends StatelessWidget {
  const _Bars({required this.controller});
  final WellnessController controller;
  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      7,
      (i) => dayKey(controller.now.subtract(Duration(days: 6 - i))),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: days.map((day) {
        final quests = (controller.days[day]?['quests'] ?? []) as List;
        final completed = quests.where((item) => item['done'] == true).length;
        final rate = quests.isEmpty ? .08 : completed / quests.length;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: rate.clamp(.08, 1),
                      child: Container(
                        decoration: BoxDecoration(
                          color: day == controller.today
                              ? _green
                              : const Color(0xff3b414b),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  day.substring(8),
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// A compact desktop hub: shared progress on the left, lightweight reactions
/// on the right. Posting remains intentionally mobile-first.
class _CommunityHubPage extends StatelessWidget {
  const _CommunityHubPage({required this.controller});

  final WellnessController controller;

  @override
  Widget build(BuildContext context) {
    final stored = controller.posts
        .where((post) => post['status'] == 'approved')
        .take(2)
        .toList();
    final posts = stored.isEmpty
        ? const [
            {
              'id': 'wall-a',
              'alias': 'daunpagi',
              'body':
                  'Hari ini cuma sempat minum air dan tarik napas. Ternyata itu sudah cukup.',
            },
            {
              'id': 'wall-b',
              'alias': 'jeda_sore',
              'body':
                  'Semangat buat yang sedang menunda satu craving. Kita lewati pelan-pelan.',
            },
          ]
        : stored;
    return _Scroll(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Squad & Community',
            style: TextStyle(
                color: _text,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -.9)),
        const SizedBox(height: 7),
        const Text(
            'Pantau langkah bersama, beri reaksi singkat, lalu kembali fokus.',
            style: TextStyle(color: _muted)),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, box) {
          final squad = _Card(
            tint: const Color(0xff152420),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                _Mark(size: 35),
                SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('September reset',
                          style: TextStyle(
                              color: _text,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      SizedBox(height: 3),
                      Text('Squad momentum minggu ini',
                          style: TextStyle(color: _muted, fontSize: 12)),
                    ])),
                _Pill('Active', _green),
              ]),
              const SizedBox(height: 26),
              const Text('183 / 250 acts of care',
                  style: TextStyle(
                      color: _text, fontSize: 25, fontWeight: FontWeight.w800)),
              const SizedBox(height: 11),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const LinearProgressIndicator(
                    value: .732,
                    minHeight: 11,
                    color: _green,
                    backgroundColor: Color(0xff2a4039)),
              ),
              const SizedBox(height: 14),
              const Text(
                  'Task yang kamu selesaikan dan focus time squad sama-sama menambah progres.',
                  style: TextStyle(color: _muted, fontSize: 12, height: 1.45)),
            ]),
          );
          final wall =
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text('Encouragement Wall',
                  style: TextStyle(
                      color: _text, fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            ...posts.map((raw) => _WallCard(
                controller: controller, post: Map<String, dynamic>.from(raw))),
          ]);
          return box.maxWidth < 920
              ? Column(children: [squad, const SizedBox(height: 20), wall])
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 8, child: squad),
                  const SizedBox(width: 18),
                  Expanded(flex: 9, child: wall),
                ]);
        }),
      ]),
    );
  }
}

class _WallCard extends StatelessWidget {
  const _WallCard({required this.controller, required this.post});
  final WellnessController controller;
  final Map<String, dynamic> post;
  @override
  Widget build(BuildContext context) {
    final alias = post['alias'].toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xff243a34),
                  foregroundColor: _green,
                  child: Text(
                    alias.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '@$alias',
                  style: const TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                const Text(
                  'Wall',
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              post['body'].toString(),
              style: const TextStyle(color: _text, height: 1.5),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 7,
              children: ['👏', '💛', '🌿'].map((emoji) {
                final id = '${post['id']}-$emoji';
                return FilterChip(
                  showCheckmark: false,
                  label: Text(emoji),
                  selected: controller.hasReaction(id),
                  selectedColor: const Color(0xff263e35),
                  backgroundColor: _raised,
                  side: const BorderSide(color: _line),
                  onSelected: (_) => controller.react(id),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.controller});
  final WellnessController controller;
  @override
  Widget build(BuildContext context) {
    final profile = controller.profile!;
    final alias = profile['alias'].toString();
    return _Scroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              color: _text,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Profil dan preferensi preview lokal.',
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 24),
          _Card(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 29,
                  backgroundColor: const Color(0xff243a34),
                  foregroundColor: _green,
                  child: Text(
                    alias.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@$alias',
                        style: const TextStyle(
                          color: _text,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Tersimpan pada browser ini',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const _Pill('Local', _green),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your journey',
                  style: TextStyle(color: _text, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                _Setting(
                  'Path',
                  profile['path'] == 'reduction'
                      ? 'Kurangi rokok / vape'
                      : 'Bangun kebiasaan baik',
                ),
                _Setting(
                  'Movement rhythm',
                  profile['lowImpact'] == true ? 'Low-impact' : 'Fleksibel',
                ),
                _Setting(
                  'Companion',
                  {
                        'plant': 'Mori',
                        'cat': 'Milo',
                        'cloud': 'Awan',
                      }[profile['companion']] ??
                      'YouWell companion',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Setting extends StatelessWidget {
  const _Setting(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            SizedBox(
              width: 145,
              child: Text(
                label,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style:
                    const TextStyle(color: _text, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

class _AdminPage extends StatelessWidget {
  const _AdminPage({required this.controller});
  final WellnessController controller;
  @override
  Widget build(BuildContext context) {
    final pending =
        controller.posts.where((post) => post['status'] == 'pending').toList();
    return _Scroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Community Admin',
            style: TextStyle(
              color: _text,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Keputusan publikasi selalu dibuat manusia.',
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 24),
          _Card(
            tint: const Color(0xff252018),
            child: Row(
              children: [
                const Icon(
                  Icons.person_search_outlined,
                  color: _amber,
                  size: 28,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    '${pending.length} post menunggu keputusan manual. AI hanya memberi sinyal, bukan menentukan hasil.',
                    style: const TextStyle(color: _text, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (pending.isEmpty)
            const _Card(
              child: _Empty(
                Icons.inbox_outlined,
                'Antrean aman untuk saat ini. Post mobile akan muncul di sini saat sinkronisasi komunitas ditambahkan.',
              ),
            ),
          ...pending.map(
            (post) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _Pill('Pending review', _amber),
                        const Spacer(),
                        Text(
                          '@${post['alias']}',
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    Text(
                      post['body'].toString(),
                      style: const TextStyle(color: _text, height: 1.5),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        FilledButton(
                          onPressed: () => controller.updatePost(
                            post['id'].toString(),
                            'approved',
                            'Approved by admin.',
                          ),
                          style: _greenButton,
                          child: const Text('Approve'),
                        ),
                        const SizedBox(width: 9),
                        OutlinedButton(
                          onPressed: () => controller.updatePost(
                            post['id'].toString(),
                            'rejected',
                            'Rejected by admin.',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xffffa6a6),
                            side: const BorderSide(color: Color(0xff5a3437)),
                          ),
                          child: const Text('Reject'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Companion extends StatefulWidget {
  const _Companion({
    required this.controller,
    required this.minimized,
    required this.onMinimize,
    required this.onExpand,
    required this.onClose,
  });
  final WellnessController controller;
  final bool minimized;
  final VoidCallback onMinimize, onExpand, onClose;
  @override
  State<_Companion> createState() => _CompanionState();
}

class _CompanionState extends State<_Companion> {
  final input = TextEditingController();
  final messages = <_Message>[
    const _Message(
      'Companion',
      'Aku di sini. Mau cerita singkat, atau kita beri craving ini waktu 5 menit?',
      false,
    ),
  ];
  Timer? timer;
  int remaining = 0, duration = 300;
  String sound = 'rain';
  bool get running => timer != null;
  @override
  void dispose() {
    timer?.cancel();
    input.dispose();
    platform.sound('stop');
    super.dispose();
  }

  void start([int seconds = 300]) {
    timer?.cancel();
    platform.sound(sound);
    setState(() {
      duration = seconds;
      remaining = seconds;
    });
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (remaining <= 1) {
        finish();
      } else {
        setState(() => remaining--);
      }
    });
  }

  void stop() {
    timer?.cancel();
    timer = null;
    platform.sound('stop');
    setState(() => remaining = 0);
  }

  void finish() {
    timer?.cancel();
    timer = null;
    platform.sound('stop');
    widget.controller.recordCraving({
      'trigger': 'Web Companion',
      'seconds': duration,
      'success': true,
      'avoided': false,
      'cost': 0,
    });
    setState(() {
      remaining = 0;
      messages.add(
        const _Message(
          'Companion',
          'Kamu berhasil memberi dirimu jeda. Itu sudah berarti.',
          false,
        ),
      );
    });
  }

  void send() {
    final text = input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      messages.add(_Message('You', text, true));
      messages.add(
        const _Message(
          'Companion',
          'Terima kasih sudah mengatakannya. Kita tidak perlu menyelesaikan semuanya sekarang—coba tarik napas sekali lagi.',
          false,
        ),
      );
      input.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.minimized) {
      return InkWell(
        onTap: widget.onExpand,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(12),
          decoration: _floating,
          child: const Row(
            children: [
              _Dot(),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'YouWell Companion',
                  style: TextStyle(color: _text, fontWeight: FontWeight.w800),
                ),
              ),
              Icon(Icons.expand_less_rounded, color: _muted),
            ],
          ),
        ),
      );
    }
    final time =
        '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}';
    return Container(
      width: 390,
      height: 510,
      decoration: _floating,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 13, 7, 11),
            child: Row(
              children: [
                const _Mark(size: 29),
                const SizedBox(width: 9),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YouWell Companion',
                        style: TextStyle(
                          color: _text,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Row(
                        children: [
                          _Dot(),
                          SizedBox(width: 5),
                          Text(
                            'Active & private',
                            style: TextStyle(color: _muted, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Minimize',
                  onPressed: widget.onMinimize,
                  icon: const Icon(
                    Icons.minimize_rounded,
                    color: _muted,
                    size: 19,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: widget.onClose,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: _muted,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                if (running) _Timer(time: time, sound: sound, onStop: stop),
                if (running) const SizedBox(height: 10),
                ...messages.map((message) => _Bubble(message)),
                const SizedBox(height: 8),
                const Text(
                  'Quick reset',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _Action(
                      Icons.timer_outlined,
                      'Delay 5 min',
                      () => start(300),
                    ),
                    _Action(
                      Icons.self_improvement_outlined,
                      'Breathe 10 min',
                      () => start(600),
                    ),
                    _Action(Icons.graphic_eq_rounded, 'Soundscape', pickSound),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 9, 9, 10),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Attachment segera hadir',
                  onPressed: () =>
                      toast(context, 'Attachment tersedia di aplikasi mobile.'),
                  icon: const Icon(
                    Icons.add_circle_outline_rounded,
                    color: _muted,
                    size: 19,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: input,
                    onSubmitted: (_) => send(),
                    style: const TextStyle(color: _text, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Tulis micro-vent…',
                      hintStyle: TextStyle(color: _muted),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Kirim',
                  onPressed: send,
                  icon: const Icon(
                    Icons.arrow_upward_rounded,
                    color: _green,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void pickSound() => showModalBottomSheet<void>(
        context: context,
        backgroundColor: _raised,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pilih soundscape',
                  style: TextStyle(
                    color: _text,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                ...{
                  'rain': 'Hujan',
                  'ambient': 'Ambient',
                  'breathing': 'Napas',
                }.entries.map(
                      (item) => ListTile(
                        leading: Icon(
                          item.key == sound
                              ? Icons.check_circle_rounded
                              : Icons.graphic_eq_rounded,
                          color: item.key == sound ? _green : _muted,
                        ),
                        title: Text(item.value,
                            style: const TextStyle(color: _text)),
                        onTap: () {
                          setState(() => sound = item.key);
                          Navigator.pop(context);
                        },
                      ),
                    ),
              ],
            ),
          ),
        ),
      );
}

class _Message {
  const _Message(this.sender, this.text, this.mine);
  final String sender, text;
  final bool mine;
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.message);
  final _Message message;
  @override
  Widget build(BuildContext context) => Align(
        alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          constraints: const BoxConstraints(maxWidth: 295),
          decoration: BoxDecoration(
            color: message.mine ? const Color(0xff204438) : _raised,
            border: Border.all(
              color: message.mine ? const Color(0xff356451) : _line,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.sender,
                style: TextStyle(
                  color: message.mine ? _green : _cyan,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                message.text,
                style:
                    const TextStyle(color: _text, fontSize: 12, height: 1.35),
              ),
            ],
          ),
        ),
      );
}

class _Timer extends StatelessWidget {
  const _Timer({required this.time, required this.sound, required this.onStop});
  final String time, sound;
  final VoidCallback onStop;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xff19342d),
          border: Border.all(color: const Color(0xff315545)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.self_improvement_rounded, color: _green),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delay in progress · $time',
                    style: const TextStyle(
                      color: _text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Soundscape: $sound',
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onStop, child: const Text('Stop')),
          ],
        ),
      );
}

class _Action extends StatelessWidget {
  const _Action(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ActionChip(
        avatar: Icon(icon, size: 15, color: _cyan),
        label: Text(label),
        onPressed: onTap,
        backgroundColor: _raised,
        side: const BorderSide(color: _line),
        labelStyle: const TextStyle(color: _text, fontSize: 11),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.tint, this.padding = 20});
  final Widget child;
  final Color? tint;
  final double padding;
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: tint ?? _panel,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: child,
      );
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .13),
          border: Border.all(color: color.withValues(alpha: .35)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700),
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty(this.icon, this.message);
  final IconData icon;
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            Icon(icon, color: _muted),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: _muted, height: 1.4),
              ),
            ),
          ],
        ),
      );
}

class _Mark extends StatelessWidget {
  const _Mark({this.size = 28});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xff1e3931),
          borderRadius: BorderRadius.circular(size * .32),
          border: Border.all(color: const Color(0xff345d4f)),
        ),
        child: Icon(Icons.spa_rounded, size: size * .6, color: _green),
      );
}

class _Dot extends StatelessWidget {
  const _Dot();
  @override
  Widget build(BuildContext context) => Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: _green,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Color(0xaa78e3b1), blurRadius: 8)],
        ),
      );
}

final _greenButton = FilledButton.styleFrom(
  backgroundColor: _green,
  foregroundColor: const Color(0xff10231b),
  textStyle: const TextStyle(fontWeight: FontWeight.w800),
);
final _floating = BoxDecoration(
  color: const Color(0xff131519),
  border: Border.all(color: const Color(0xff343840)),
  borderRadius: BorderRadius.circular(14),
  boxShadow: const [
    BoxShadow(color: Color(0x99000000), blurRadius: 34, offset: Offset(0, 14)),
    BoxShadow(color: Color(0x1f78e3b1), blurRadius: 22, spreadRadius: -4),
  ],
);
