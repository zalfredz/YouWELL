import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youwell/app/web_experience_gate.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/platform/platform.dart' as platform;
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/utils/date_key.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';

/// Desktop companion for tasks, relief, insight and lightweight community use.
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
  int tab = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.draw();
  }

  Future<void> _joinWebApp() async {
    await widget.controller.setup({
      'alias': 'web_guest',
      'path': 'wellness',
      'fitness': 1,
      'lowImpact': false,
      'companion': 'plant',
      'cost': 0,
      'waterGoal': 2000,
      'kcalGoal': 2000,
      'proteinGoal': 60,
    });
    widget.controller.draw();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => WebWorkspaceGate(
    onReturnToLanding: () =>
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
    child: widget.controller.profile == null
        ? _JoinAccess(onJoin: _joinWebApp, isAdmin: widget.isAdmin)
        : _WorkspaceShell(
            controller: widget.controller,
            isAdmin: widget.isAdmin,
            tab: tab,
            onSelect: (value) => setState(() => tab = value),
          ),
  );
}

class _JoinAccess extends StatelessWidget {
  const _JoinAccess({required this.onJoin, required this.isAdmin});
  final Future<void> Function() onJoin;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: cream,
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(42),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              tag(isAdmin ? 'YOUWELL WEB • ADMIN' : 'YOUWELL WEB APP'),
              gap(22),
              const Icon(Icons.desk_rounded, size: 46, color: green),
              gap(20),
              title(
                isAdmin
                    ? 'Masuk ke\nCommunity Admin.'
                    : 'Join YouWell\ndi browser.',
                size: 42,
              ),
              gap(14),
              const Text(
                'YouWell Web menyatukan ruang fokus, insight, dan komunitas untuk layar besar. Login Google akan menyambungkan akun yang sama dengan aplikasi mobile.',
                style: TextStyle(color: muted, fontSize: 16, height: 1.6),
              ),
              gap(28),
              FilledButton.icon(
                onPressed: () async => onJoin(),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(isAdmin ? 'Masuk sebagai admin' : 'Join Us!'),
              ),
              gap(12),
              caption(
                'Mode pengembangan saat ini membuat akun lokal sementara. Supabase akan menggantikannya saat autentikasi diaktifkan.',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _WorkspaceShell extends StatelessWidget {
  const _WorkspaceShell({
    required this.controller,
    required this.isAdmin,
    required this.tab,
    required this.onSelect,
  });

  final WellnessController controller;
  final bool isAdmin;
  final int tab;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _TodayView(controller: controller),
      _ReliefRoom(controller: controller),
      _InsightsView(controller: controller),
      _CommunityView(controller: controller),
      if (isAdmin) _CommunityAdminView(controller: controller),
    ];
    final labels = [
      'Hari ini',
      'Relief room',
      'Insights',
      'Komunitas',
      if (isAdmin) 'Community Admin',
    ];
    final icons = [
      Icons.wb_sunny_outlined,
      Icons.air_rounded,
      Icons.insights_rounded,
      Icons.groups_rounded,
      if (isAdmin) Icons.admin_panel_settings_outlined,
    ];

    return Scaffold(
      backgroundColor: cream,
      body: Row(
        children: [
          Container(
            width: 244,
            padding: const EdgeInsets.fromLTRB(22, 26, 18, 20),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.spa_rounded, color: green),
                    SizedBox(width: 8),
                    Text(
                      'youwell.',
                      style: TextStyle(
                        color: ink,
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
                gap(8),
                caption(isAdmin ? 'YOUWELL WEB • ADMIN' : 'YOUWELL WEB APP'),
                gap(34),
                ...List.generate(
                  labels.length,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      selected: tab == index,
                      selectedTileColor: const Color(0xffe5eddf),
                      leading: Icon(
                        icons[index],
                        color: tab == index ? green : muted,
                      ),
                      title: Text(labels[index]),
                      onTap: () => onSelect(index),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cream,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.phone_iphone_rounded, color: green),
                      SizedBox(height: 9),
                      Text(
                        'Buat, foto, dan check-in cepat tetap lebih nyaman di aplikasi mobile.',
                        style: TextStyle(
                          color: muted,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                gap(12),
                tag(isAdmin ? 'ADMIN ACCOUNT' : 'MEMBER ACCOUNT'),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(34, 22, 34, 16),
                  child: Row(
                    children: [
                      Text(
                        'YOUR SPACE  /  ${labels[tab].toUpperCase()}',
                        style: const TextStyle(
                          color: muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const Spacer(),
                      CircleAvatar(
                        backgroundColor: const Color(0xffe2edda),
                        foregroundColor: green,
                        child: Text(
                          controller.profile!['alias']
                              .toString()
                              .substring(0, 1)
                              .toUpperCase(),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: pages[tab],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayView extends StatelessWidget {
  const _TodayView({required this.controller});
  final WellnessController controller;

  @override
  Widget build(BuildContext context) {
    final completed = controller.quests
        .where((quest) => quest['done'] == true)
        .length;
    return ListView(
      key: const ValueKey('today'),
      padding: const EdgeInsets.fromLTRB(34, 10, 34, 34),
      children: [
        const Text(
          'Hari yang pelan\ntetap berarti.',
          style: TextStyle(
            color: ink,
            fontSize: 39,
            height: 1.04,
            letterSpacing: -1.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        gap(8),
        const Text(
          'Centang yang bisa kamu lakukan dari laptop. Aktivitas fisik dan foto dilanjutkan di aplikasi.',
          style: TextStyle(color: muted, height: 1.5),
        ),
        gap(25),
        Row(
          children: [
            _MiniMetric(
              label: 'Misi selesai',
              value: '$completed / ${controller.quests.length}',
              icon: Icons.task_alt_rounded,
            ),
            const SizedBox(width: 12),
            _MiniMetric(
              label: 'Streak',
              value: '${controller.streak} hari',
              icon: Icons.local_fire_department_outlined,
            ),
            const SizedBox(width: 12),
            _MiniMetric(
              label: 'Companion',
              value: 'Lv ${controller.level}',
              icon: Icons.spa_outlined,
            ),
          ],
        ),
        gap(28),
        const Text(
          'Quick checklist',
          style: TextStyle(
            color: ink,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        gap(12),
        ...controller.quests.map(
          (quest) => _QuestTile(controller: controller, quest: quest),
        ),
        gap(12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xffe2edda),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: green),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Web menyimpan check-in, journaling, dan habit swap. Log makan dengan foto atau aktivitas fisik dibuat lewat mobile.',
                  style: TextStyle(color: ink, fontSize: 13, height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: green),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(label, style: const TextStyle(color: muted, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _QuestTile extends StatelessWidget {
  const _QuestTile({required this.controller, required this.quest});
  final WellnessController controller;
  final Map<String, dynamic> quest;

  bool get _isMobileAction =>
      quest['category'] == 'Gerak' || quest['category'] == 'Nutrisi';

  @override
  Widget build(BuildContext context) {
    final complete = quest['done'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(18, 13, 12, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            complete ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: complete ? green : muted,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quest['title'].toString(),
                  style: TextStyle(
                    color: complete ? muted : ink,
                    decoration: complete ? TextDecoration.lineThrough : null,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  quest['category'].toString(),
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (complete)
            const Icon(Icons.done_rounded, color: green)
          else if (_isMobileAction)
            OutlinedButton(
              onPressed: () => toast(
                context,
                'Aktivitas ini dilanjutkan di aplikasi mobile.',
              ),
              child: const Text('Di aplikasi'),
            )
          else
            FilledButton(
              onPressed: () => controller.complete(quest['id'].toString()),
              child: const Text('Selesai'),
            ),
        ],
      ),
    );
  }
}

class _ReliefRoom extends StatefulWidget {
  const _ReliefRoom({required this.controller});
  final WellnessController controller;

  @override
  State<_ReliefRoom> createState() => _ReliefRoomState();
}

class _ReliefRoomState extends State<_ReliefRoom> {
  Timer? timer;
  DateTime? deadline;
  int duration = 300;
  int remaining = 300;
  String sound = 'rain';
  bool playing = false;

  void _start() {
    platform.sound(sound);
    deadline = DateTime.now().add(Duration(seconds: duration));
    setState(() {
      playing = true;
      remaining = duration;
    });
    timer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      final seconds =
          (deadline!.difference(DateTime.now()).inMilliseconds / 1000)
              .ceil()
              .clamp(0, duration);
      if (!mounted) return;
      setState(() => remaining = seconds);
      if (seconds == 0) _stop(finished: true);
    });
  }

  void _stop({bool finished = false}) {
    timer?.cancel();
    platform.sound('stop');
    if (finished) {
      widget.controller.recordCraving({
        'trigger': 'Stres',
        'seconds': duration,
        'success': true,
        'avoided': false,
        'cost': 0,
      });
    }
    if (mounted) setState(() => playing = false);
  }

  @override
  void dispose() {
    timer?.cancel();
    platform.sound('stop');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('relief'),
    padding: const EdgeInsets.fromLTRB(34, 10, 34, 34),
    child: Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff183d32), Color(0xff2e6e54)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -90,
            top: -80,
            child: _Glow(size: 310, color: const Color(0x337fd1a3)),
          ),
          Positioned(
            left: -100,
            bottom: -130,
            child: _Glow(size: 360, color: const Color(0x2272cfc7)),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(42),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  children: [
                    const Text(
                      'RELIEF ROOM',
                      style: TextStyle(
                        color: Color(0xffb8d9ad),
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      playing
                          ? 'Tarik napas.\nLepaskan perlahan.'
                          : 'Beri dirimu\nsedikit ruang.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        height: 1.05,
                        letterSpacing: -1.4,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 30),
                    AnimatedContainer(
                      duration: const Duration(seconds: 4),
                      curve: Curves.easeInOut,
                      width: playing && remaining % 8 < 4 ? 230 : 170,
                      height: playing && remaining % 8 < 4 ? 230 : 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xffdceacb).withValues(alpha: .88),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x5578ba8f),
                            blurRadius: 48,
                            spreadRadius: 12,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          playing
                              ? '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}'
                              : '${duration ~/ 60} min',
                          style: const TextStyle(
                            color: ink,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      playing
                          ? (remaining % 8 < 4
                                ? 'Tarik napas perlahan'
                                : 'Hembuskan perlahan')
                          : 'Pilih suara, pilih durasi, lalu cukup hadir.',
                      style: const TextStyle(
                        color: Color(0xffe1eee2),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 26),
                    if (!playing) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [300, 600]
                            .map(
                              (value) => ChoiceChip(
                                label: Text('${value ~/ 60} menit'),
                                selected: duration == value,
                                onSelected: (_) => setState(() {
                                  duration = value;
                                  remaining = value;
                                }),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children:
                            {
                                  'rain': '🌧 Hujan lembut',
                                  'ambient': '♫ Ambient tones',
                                  'breathing': '◯ Panduan napas',
                                }.entries
                                .map(
                                  (entry) => ChoiceChip(
                                    label: Text(entry.value),
                                    selected: sound == entry.key,
                                    onSelected: (_) =>
                                        setState(() => sound = entry.key),
                                  ),
                                )
                                .toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                    FilledButton.icon(
                      onPressed: playing ? _stop : _start,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: ink,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                      ),
                      icon: Icon(
                        playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      ),
                      label: Text(
                        playing ? 'Akhiri sesi' : 'Mulai relaxation mode',
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Audio berjalan setelah kamu menekan tombol putar. Kamu boleh berhenti kapan saja.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xffb7cfbb),
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _InsightsView extends StatelessWidget {
  const _InsightsView({required this.controller});
  final WellnessController controller;

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      7,
      (index) => dayKey(controller.now.subtract(Duration(days: 6 - index))),
    );
    return ListView(
      key: const ValueKey('insights'),
      padding: const EdgeInsets.fromLTRB(34, 10, 34, 34),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lihat ritmemu.',
                    style: TextStyle(
                      color: ink,
                      fontSize: 39,
                      letterSpacing: -1.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 7),
                  Text(
                    'Angka adalah petunjuk, bukan penilaian.',
                    style: TextStyle(color: muted),
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.pushNamed(context, '/recap'),
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('Buka Wrapped'),
            ),
          ],
        ),
        gap(26),
        Row(
          children: [
            Expanded(
              child: _InsightStat(
                label: 'Compliance',
                value: '${(controller.compliance(7) * 100).round()}%',
                detail: '7 hari terakhir',
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _InsightStat(
                label: 'Streak',
                value: '${controller.streak}',
                detail: 'hari bertumbuh',
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _InsightStat(
                label: 'Companion',
                value: 'Lv ${controller.level}',
                detail: '${controller.xp} XP terkumpul',
              ),
            ),
          ],
        ),
        gap(20),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Compliance rate',
                style: TextStyle(
                  color: ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Satu minggu terakhir',
                style: TextStyle(color: muted, fontSize: 13),
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 170,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: days.map((day) {
                    final quests =
                        (controller.days[day]?['quests'] ?? []) as List;
                    final completed = quests
                        .where((quest) => quest['done'] == true)
                        .length;
                    final rate = quests.isEmpty
                        ? 0.08
                        : completed / quests.length;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: 18 + 110 * rate,
                              decoration: BoxDecoration(
                                color: day == controller.today
                                    ? green
                                    : const Color(0xffb8cba9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              day.substring(8),
                              style: const TextStyle(
                                color: muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        gap(20),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xfffff0e4),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xffb66738),
                size: 35,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Weekly Wrapped',
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Bagikan versi ringkas tanpa catatan pribadi.',
                      style: TextStyle(color: muted),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/recap'),
                      child: const Text('Lihat halaman publik →'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InsightStat extends StatelessWidget {
  const _InsightStat({
    required this.label,
    required this.value,
    required this.detail,
  });
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: ink,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(detail, style: const TextStyle(color: muted, fontSize: 11)),
      ],
    ),
  );
}

class _CommunityView extends StatelessWidget {
  const _CommunityView({required this.controller});
  final WellnessController controller;

  @override
  Widget build(BuildContext context) {
    final approved = controller.posts
        .where((post) => post['status'] == 'approved')
        .take(3)
        .toList();
    final posts = approved.isEmpty
        ? [
            {
              'id': 'web-wall-1',
              'alias': 'daunpagi',
              'body':
                  'Hari ini cuma sempat minum air dan tarik napas. Ternyata itu sudah cukup.',
              'room': 'Wall',
            },
            {
              'id': 'web-wall-2',
              'alias': 'jeda_sore',
              'body':
                  'Semangat buat yang sedang menunda satu craving. Kita lewati pelan-pelan.',
              'room': 'Wall',
            },
          ]
        : approved;
    return ListView(
      key: const ValueKey('community'),
      padding: const EdgeInsets.fromLTRB(34, 10, 34, 34),
      children: [
        const Text(
          'Tumbuh bersama,\ntanpa ramai-ramai.',
          style: TextStyle(
            color: ink,
            fontSize: 39,
            height: 1.04,
            letterSpacing: -1.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        gap(8),
        const Text(
          'Di web kamu bisa membaca dan memberi dukungan singkat. Menulis cerita dan mengunggah foto tetap di mobile.',
          style: TextStyle(color: muted, height: 1.5),
        ),
        gap(24),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.groups_rounded,
                color: Color(0xffb8d9ad),
                size: 38,
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Squad Quest minggu ini',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '183 dari 250 langkah kecil telah dirayakan bersama.',
                      style: TextStyle(color: Color(0xffd5e4d4), height: 1.4),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: () => toast(
                  context,
                  'Dukunganmu sudah ditambahkan ke Squad Quest.',
                ),
                child: const Text('Beri semangat'),
              ),
            ],
          ),
        ),
        gap(24),
        const Text(
          'Encouragement wall',
          style: TextStyle(
            color: ink,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        gap(12),
        ...posts.map((post) => _WallPost(controller: controller, post: post)),
      ],
    );
  }
}

class _WallPost extends StatelessWidget {
  const _WallPost({required this.controller, required this.post});
  final WellnessController controller;
  final Map<String, dynamic> post;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xffe2edda),
              foregroundColor: green,
              child: Text(
                post['alias'].toString().substring(0, 1).toUpperCase(),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '@${post['alias']}',
              style: const TextStyle(color: ink, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            const Text('Wall', style: TextStyle(color: muted, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          post['body'].toString(),
          style: const TextStyle(color: ink, height: 1.55),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          children: ['👏', '💛', '🌿'].map((emoji) {
            final reactionId = '${post['id']}-$emoji';
            return FilterChip(
              label: Text(emoji),
              selected: controller.hasReaction(reactionId),
              onSelected: (_) => controller.react(reactionId),
            );
          }).toList(),
        ),
      ],
    ),
  );
}

/// The only extra web-app menu for moderators and admins.
class _CommunityAdminView extends StatelessWidget {
  const _CommunityAdminView({required this.controller});
  final WellnessController controller;

  @override
  Widget build(BuildContext context) {
    final pending = controller.posts
        .where((post) => post['status'] == 'pending')
        .toList();
    return ListView(
      key: const ValueKey('community-admin'),
      padding: const EdgeInsets.fromLTRB(34, 10, 34, 34),
      children: [
        const Text(
          'Community\nAdmin.',
          style: TextStyle(
            color: ink,
            fontSize: 39,
            height: 1.04,
            letterSpacing: -1.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        gap(8),
        const Text(
          'Keputusan tayang selalu dibuat manusia. Gunakan ruang ini untuk menerima atau menolak post yang menunggu review.',
          style: TextStyle(color: muted, height: 1.5),
        ),
        gap(22),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xfffff0e4),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(Icons.person_search_rounded, color: Color(0xffb66738)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${pending.length} post menunggu keputusan manual. Sistem otomatis nanti hanya membantu memberi sinyal, bukan memutuskan.',
                  style: const TextStyle(color: ink, height: 1.45),
                ),
              ),
            ],
          ),
        ),
        gap(24),
        const Text(
          'Antrean post',
          style: TextStyle(
            color: ink,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        gap(12),
        if (pending.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Tidak ada post yang menunggu. Setelah Supabase tersambung, post dari aplikasi mobile akan masuk ke antrean ini.',
              style: TextStyle(color: muted, height: 1.55),
            ),
          ),
        ...pending.map(
          (post) => _ModerationPostCard(controller: controller, post: post),
        ),
        gap(24),
        const Text(
          'Laporan konten',
          style: TextStyle(
            color: ink,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        gap(12),
        if (controller.reports.isEmpty)
          caption('Belum ada laporan yang perlu ditinjau.'),
        ...controller.reports.map(
          (report) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.flag_outlined, color: muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${report['reason']} • ${report['post']}',
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      controller.resolveReport(report['id'].toString()),
                  child: const Text('Tutup'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ModerationPostCard extends StatelessWidget {
  const _ModerationPostCard({required this.controller, required this.post});
  final WellnessController controller;
  final Map<String, dynamic> post;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xffe2edda),
              foregroundColor: green,
              child: Text(
                post['alias'].toString().substring(0, 1).toUpperCase(),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '@${post['alias']}',
              style: const TextStyle(color: ink, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            tag('MENUNGGU REVIEW', color: const Color(0xffb66738)),
          ],
        ),
        gap(14),
        Text(
          post['body'].toString(),
          style: const TextStyle(color: ink, fontSize: 16, height: 1.55),
        ),
        gap(18),
        Wrap(
          spacing: 10,
          children: [
            FilledButton.icon(
              onPressed: () => controller.updatePost(
                post['id'].toString(),
                'approved',
                'Disetujui melalui Community Admin.',
              ),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Setujui'),
            ),
            OutlinedButton.icon(
              onPressed: () => controller.updatePost(
                post['id'].toString(),
                'rejected',
                'Post tidak ditayangkan setelah tinjauan manual.',
              ),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Tolak'),
            ),
          ],
        ),
      ],
    ),
  );
}
