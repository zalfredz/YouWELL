import 'package:flutter/material.dart';
import 'package:youwell/app/web_experience_gate.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/community/presentation/admin_moderation_page.dart';
import 'package:youwell/features/community/presentation/community_page.dart';
import 'package:youwell/features/home/presentation/daily_card_draw_dialog.dart';
import 'package:youwell/features/profile/presentation/profile_page.dart';
import 'package:youwell/features/web/presentation/pomodoro_page.dart';
import 'package:youwell/shared/widgets/wellness_companion.dart';

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
  bool _drawing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.prepareToday();
    });
  }

  Future<void> _draw() async {
    if (_drawing || !widget.controller.needsDailyCardDraw) return;
    _drawing = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DailyCardDrawDialog(controller: widget.controller),
    );
    _drawing = false;
  }

  void _profile() => showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
        child: ProfilePage(controller: widget.controller),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final sections = [
      'Home',
      'Focus Station',
      'Progress',
      'Community',
      if (widget.isAdmin) 'Community Admin',
    ];
    final pages = <Widget>[
      _WebHome(controller: widget.controller, onDraw: _draw),
      WebPomodoroPage(controller: widget.controller),
      _WebProgress(controller: widget.controller),
      Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: CommunityPage(controller: widget.controller),
        ),
      ),
      if (widget.isAdmin) AdminModerationPage(controller: widget.controller),
    ];
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => WebWorkspaceGate(
        onReturnToLanding: () =>
            Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false),
        child: Theme(
          data: ThemeData.dark(useMaterial3: true).copyWith(
            scaffoldBackgroundColor: appCanvas,
            colorScheme: const ColorScheme.dark(
              primary: appAccent,
              secondary: appAccentCyan,
              surface: appSurface,
            ),
          ),
          child: Scaffold(
            body: Row(
              children: [
                _Sidebar(
                  tab: _tab,
                  isAdmin: widget.isAdmin,
                  onTab: (value) => setState(() => _tab = value),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _Header(
                        section: sections[_tab],
                        alias: widget.controller.profile!['alias'].toString(),
                        onProfile: _profile,
                      ),
                      Expanded(
                        child: IndexedStack(index: _tab, children: pages),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.tab,
    required this.isAdmin,
    required this.onTab,
  });
  final int tab;
  final bool isAdmin;
  final ValueChanged<int> onTab;
  @override
  Widget build(BuildContext context) => Container(
    width: 240,
    padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
    decoration: const BoxDecoration(
      color: Color(0xff111317),
      border: Border(right: BorderSide(color: appBorder)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'youwell.',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          'BETTER LIFE WORKSPACE',
          style: TextStyle(color: appMuted, fontSize: 10, letterSpacing: 1.2),
        ),
        const SizedBox(height: 34),
        ...[
          ('Home', Icons.home_outlined),
          ('Focus Station', Icons.timer_outlined),
          ('Progress', Icons.insights_outlined),
          ('Community', Icons.groups_2_outlined),
          if (isAdmin) ('Community Admin', Icons.admin_panel_settings_outlined),
        ].indexed.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              selected: tab == entry.$1,
              selectedTileColor: appRaised,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: Icon(
                entry.$2.$2,
                color: tab == entry.$1 ? appAccent : appMuted,
              ),
              title: Text(entry.$2.$1),
              onTap: () => onTab(entry.$1),
            ),
          ),
        ),
        const Spacer(),
        const Text(
          'Local development\nAuth & sync belum aktif',
          style: TextStyle(color: appMuted, fontSize: 12, height: 1.5),
        ),
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.section,
    required this.alias,
    required this.onProfile,
  });
  final String section, alias;
  final VoidCallback onProfile;
  @override
  Widget build(BuildContext context) => Container(
    height: 72,
    padding: const EdgeInsets.symmetric(horizontal: 30),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: appBorder)),
    ),
    child: Row(
      children: [
        Text(section, style: const TextStyle(fontWeight: FontWeight.w800)),
        const Spacer(),
        const Text(
          'LOCAL',
          style: TextStyle(
            color: appAccent,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 14),
        InkWell(
          onTap: onProfile,
          borderRadius: BorderRadius.circular(40),
          child: CircleAvatar(
            backgroundColor: appRaised,
            child: Text(
              alias[0].toUpperCase(),
              style: const TextStyle(color: appAccent),
            ),
          ),
        ),
      ],
    ),
  );
}

class _WebHome extends StatelessWidget {
  const _WebHome({required this.controller, required this.onDraw});
  final WellnessController controller;
  final VoidCallback onDraw;
  @override
  Widget build(BuildContext context) {
    final kind = controller.profile!['companion'].toString();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Good day, ${controller.profile!['alias']}.',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
          ),
          const Text(
            'Tiga langkah utama dan satu bonus untuk hari ini.',
            style: TextStyle(color: appMuted),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 7,
                child: _WebPanel(
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${const {'plant': 'Mori', 'cat': 'Milo', 'cloud': 'Awan'}[kind] ?? 'Mori'}, your companion',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      WellnessCompanion(
                        kind: kind,
                        level: controller.level,
                        size: 310,
                      ),
                      Text(
                        'Level ${controller.level}  •  ${controller.xp} XP',
                        style: const TextStyle(
                          color: appAccent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      LinearProgressIndicator(
                        value: (controller.xp % 100) / 100,
                        color: appAccent,
                        backgroundColor: appRaised,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 5,
                child: _WebPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "Today's steps",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (controller.needsDailyCardDraw)
                            TextButton.icon(
                              onPressed: onDraw,
                              icon: const Icon(Icons.auto_awesome_rounded),
                              label: const Text('Bonus card'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...controller.quests.map(
                        (task) => _WebTask(
                          task: task,
                          onDone: () =>
                              controller.completeCard(task['id'].toString()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _WebMetric(
                  title: 'Weekly progress',
                  value: '${(controller.compliance(7) * 100).round()}%',
                  detail: '${controller.activeDaysIn(7)} active days',
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _WebMetric(
                  title: 'Quick hydration',
                  value: '${controller.water.toInt()} ml',
                  detail: 'Goal ${controller.profile?['waterGoal'] ?? 2000} ml',
                  action: controller.addWater,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WebTask extends StatelessWidget {
  const _WebTask({required this.task, required this.onDone});
  final Map<String, dynamic> task;
  final VoidCallback onDone;
  @override
  Widget build(BuildContext context) {
    final done = task['status'] == 'completed';
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: appRaised,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.circle_outlined,
            color: appAccent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              task['title'].toString(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: done ? null : onDone,
            child: Text(done ? 'Done' : 'Complete'),
          ),
        ],
      ),
    );
  }
}

class _WebProgress extends StatelessWidget {
  const _WebProgress({required this.controller});
  final WellnessController controller;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Progress',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _WebMetric(
                title: 'Total XP',
                value: '${controller.xp}',
                detail: 'Level ${controller.level}',
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _WebMetric(
                title: 'Weekly completion',
                value: '${(controller.compliance(7) * 100).round()}%',
                detail: '${controller.activeDaysIn(7)} active days',
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _WebMetric(
                title: 'Focus today',
                value: '${controller.focusMinutesToday}m',
                detail: 'Across web and mobile',
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _WebPanel extends StatelessWidget {
  const _WebPanel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    height: 590,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: appSurface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: appBorder),
    ),
    child: child,
  );
}

class _WebMetric extends StatelessWidget {
  const _WebMetric({
    required this.title,
    required this.value,
    required this.detail,
    this.action,
  });
  final String title, value, detail;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: appSurface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: appBorder),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 32,
                  color: appAccent,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(detail, style: const TextStyle(color: appMuted)),
            ],
          ),
        ),
        if (action != null)
          FilledButton(onPressed: action, child: const Text('+250 ml')),
      ],
    ),
  );
}
