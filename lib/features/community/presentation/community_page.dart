import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key, required this.controller});
  final WellnessController controller;
  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  int _section = 0;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(22, 12, 22, 42),
    children: [
      const Text(
        'Community',
        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 4),
      const Text(
        'Dukungan ringan dengan identitas alias.',
        style: TextStyle(color: appMuted),
      ),
      const SizedBox(height: 20),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 0, label: Text('Wall')),
            ButtonSegment(value: 1, label: Text('Squad')),
            ButtonSegment(value: 2, label: Text('Vibe')),
            ButtonSegment(value: 3, label: Text('Buddy')),
          ],
          selected: {_section},
          onSelectionChanged: (value) => setState(() => _section = value.first),
        ),
      ),
      const SizedBox(height: 18),
      if (_section == 0) _Wall(controller: widget.controller),
      if (_section == 1) _Squad(controller: widget.controller),
      if (_section == 2) const _VibeMap(),
      if (_section == 3) _Buddy(controller: widget.controller),
    ],
  );
}

class _Wall extends StatelessWidget {
  const _Wall({required this.controller});
  final WellnessController controller;

  Future<void> _compose(BuildContext context) async {
    final text = TextEditingController();
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Bagikan small win'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Post masuk ke antrean admin sebelum tampil.',
                style: TextStyle(color: appMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: text,
                maxLength: 180,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Hari ini aku berhasil…',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  controller.submitCommunityPost(text.text);
                  Navigator.pop(dialogContext);
                } catch (_) {
                  setDialogState(() => error = 'Tulis 3–180 karakter.');
                }
              },
              child: const Text('Kirim untuk review'),
            ),
          ],
        ),
      ),
    );
    text.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => _compose(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Bagikan progres'),
        ),
      ),
      const SizedBox(height: 14),
      ...controller.approvedCommunityPosts.map(
        (post) => _PostCard(controller: controller, post: post),
      ),
      if (controller.moderationQueue.any(
        (post) => post['alias'] == controller.profile?['alias'],
      ))
        const _InfoCard(
          icon: Icons.schedule_rounded,
          title: 'Post kamu sedang direview',
          detail: 'Admin akan memilih apakah post aman untuk Wall.',
        ),
    ],
  );
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.controller, required this.post});
  final WellnessController controller;
  final Map<String, dynamic> post;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: appSurface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: appBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xff203a32),
              child: Text(
                post['alias'].toString()[0].toUpperCase(),
                style: const TextStyle(color: appAccent),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '@${post['alias']}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Laporkan post',
              onSelected: (reason) =>
                  controller.reportCommunityPost(post['id'], reason),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'unsafe', child: Text('Tidak aman')),
                PopupMenuItem(value: 'spam', child: Text('Spam')),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(post['text'].toString(), style: const TextStyle(height: 1.5)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          children: ['👏', '🌱', '✨'].map((reaction) {
            final active = controller.hasCommunityReaction(
              post['id'],
              reaction,
            );
            return ActionChip(
              backgroundColor: active ? const Color(0xff203a32) : appRaised,
              side: BorderSide(color: active ? appAccent : appBorder),
              label: Text(reaction),
              onPressed: () =>
                  controller.reactToCommunityPost(post['id'], reaction),
            );
          }).toList(),
        ),
      ],
    ),
  );
}

class _Squad extends StatelessWidget {
  const _Squad({required this.controller});
  final WellnessController controller;

  @override
  Widget build(BuildContext context) {
    final squad = controller.squad;
    if (squad == null) {
      return _InfoCard(
        icon: Icons.groups_2_outlined,
        title: 'Cari squad kecilmu',
        detail: 'Jaga kebiasaan bersama 3–5 alias dengan satu target mingguan.',
        action: FilledButton.icon(
          onPressed: controller.joinSquad,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Gabung demo squad'),
        ),
      );
    }
    final progress = (squad['progress'] as num).toInt();
    final goal = (squad['goal'] as num).toInt();
    final members = (squad['members'] as List).map((item) => item.toString());
    return _InfoCard(
      icon: Icons.groups_2_rounded,
      title: squad['name'].toString(),
      detail: '$progress / $goal langkah selesai minggu ini',
      action: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: progress / goal,
            minHeight: 8,
            borderRadius: BorderRadius.circular(99),
            color: appAccent,
            backgroundColor: appRaised,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: members
                .map(
                  (alias) => Chip(
                    avatar: CircleAvatar(child: Text(alias[0].toUpperCase())),
                    label: Text(alias),
                  ),
                )
                .toList(),
          ),
          TextButton(
            onPressed: controller.leaveSquad,
            child: const Text('Keluar dari demo squad'),
          ),
        ],
      ),
    );
  }
}

class _VibeMap extends StatelessWidget {
  const _VibeMap();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        height: 260,
        decoration: BoxDecoration(
          color: const Color(0xff101d1a),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: appBorder),
        ),
        child: const Stack(
          children: [
            _VibeDot(left: .15, top: .25, size: 72, color: appAccentCyan),
            _VibeDot(left: .55, top: .18, size: 96, color: appAccent),
            _VibeDot(left: .38, top: .60, size: 64, color: appAccentAmber),
            _VibeDot(left: .72, top: .63, size: 54, color: Color(0xffb69cff)),
            Center(
              child: Text(
                'Collective Vibe\nDEMO DATA',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'Agregat anonim untuk rasa kebersamaan. Lokasi presisi tidak ditampilkan.',
        style: TextStyle(color: appMuted, height: 1.5),
      ),
    ],
  );
}

class _VibeDot extends StatelessWidget {
  const _VibeDot({
    required this.left,
    required this.top,
    required this.size,
    required this.color,
  });
  final double left, top, size;
  final Color color;
  @override
  Widget build(BuildContext context) => Positioned(
    left: left * 300,
    top: top * 210,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: .18),
        border: Border.all(color: color.withValues(alpha: .65), width: 2),
      ),
    ),
  );
}

class _Buddy extends StatelessWidget {
  const _Buddy({required this.controller});
  final WellnessController controller;
  @override
  Widget build(BuildContext context) {
    final buddy = controller.buddy;
    return _InfoCard(
      icon: Icons.handshake_outlined,
      title: buddy == null ? 'Accountability Buddy' : '@${buddy['alias']}',
      detail: buddy == null
          ? 'Pasangan alias dengan jalur serupa untuk saling mengingatkan.'
          : '${buddy['activeDays']} hari aktif • jalur ${buddy['path']}',
      action: buddy == null
          ? FilledButton(
              onPressed: controller.matchBuddy,
              child: const Text('Cari demo buddy'),
            )
          : OutlinedButton(
              onPressed: controller.endBuddy,
              child: const Text('Akhiri pairing demo'),
            ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.detail,
    this.action,
  });
  final IconData icon;
  final String title, detail;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: appSurface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: appBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: appAccent, size: 30),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(detail, style: const TextStyle(color: appMuted, height: 1.5)),
        if (action != null) ...[const SizedBox(height: 18), action!],
      ],
    ),
  );
}
