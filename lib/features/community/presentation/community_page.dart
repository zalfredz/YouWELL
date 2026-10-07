import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';

class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key, required this.controller});
  final WellnessController controller;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
    children: [
      Text(
        'Community',
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
      ),
      Text(
        'Saling semangati dengan alias. Tidak ada peringkat.',
        style: TextStyle(color: context.colors.muted),
      ),
      const SizedBox(height: 16),
      _Wall(controller: controller),
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
          title: const Text('Bagikan kemenangan kecil'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Post masuk ke antrean admin sebelum tampil.',
                style: TextStyle(color: context.colors.muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => text.text =
                      'Hari ini aku menyelesaikan '
                      '${controller.completedCards.length} misi dan sekarang '
                      'di Level ${controller.level}!',
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('Isi dengan progres hari ini'),
                ),
              ),
              TextField(
                controller: text,
                maxLength: maxCommunityPostLength,
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
                  setDialogState(
                    () => error = 'Tulis 3–$maxCommunityPostLength karakter.',
                  );
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
          detail: 'Moderator akan mengecek post sebelum tampil.',
        ),
    ],
  );
}

/// Stored reaction keys stay the same; they render as labelled icons.
const _reactions = [
  ('👏', Icons.celebration_rounded, 'Keren'),
  ('🌱', Icons.eco_rounded, 'Tumbuh'),
  ('✨', Icons.auto_awesome_rounded, 'Semangat'),
];

class _PostCard extends StatelessWidget {
  const _PostCard({required this.controller, required this.post});
  final WellnessController controller;
  final Map<String, dynamic> post;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GameCard(
        padding: const EdgeInsets.fromLTRB(16, 10, 6, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: c.selected,
                  child: Text(
                    post['alias'].toString()[0].toUpperCase(),
                    style: TextStyle(
                      color: c.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '@${post['alias']}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                if (post['sample'] == true) tag('contoh'),
                PopupMenuButton<String>(
                  tooltip: 'Laporkan post',
                  icon: Icon(Icons.more_vert_rounded, color: c.muted),
                  onSelected: (reason) {
                    final sent = controller.reportCommunityPost(
                      post['id'],
                      reason,
                    );
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(
                            sent
                                ? 'Terima kasih. Laporan dikirim ke moderator.'
                                : 'Post ini sudah kamu laporkan.',
                          ),
                        ),
                      );
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'unsafe', child: Text('Tidak aman')),
                    PopupMenuItem(value: 'spam', child: Text('Spam')),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 10, 12),
              child: Text(
                post['text'].toString(),
                style: const TextStyle(fontSize: 15.5, height: 1.5),
              ),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 8,
              children: [
                for (final (key, icon, label) in _reactions)
                  _ReactionButton(
                    icon: icon,
                    label: label,
                    active: controller.hasCommunityReaction(post['id'], key),
                    onTap: () =>
                        controller.reactToCommunityPost(post['id'], key),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: active,
      label: 'Reaksi $label',
      child: Material(
        color: active ? c.xpSoft : c.card,
        shape: StadiumBorder(
          side: BorderSide(
            color: active ? c.xp : c.border,
            width: active ? 2 : 1.5,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: SizedBox(
              height: 44,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 17, color: active ? c.onXp : c.muted),
                  const SizedBox(width: 5),
                  Text(
                    active ? '$label · 1' : label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: active ? c.onXp : c.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title, detail;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: context.colors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: context.colors.accent, size: 30),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          detail,
          style: TextStyle(color: context.colors.muted, height: 1.5),
        ),
      ],
    ),
  );
}
