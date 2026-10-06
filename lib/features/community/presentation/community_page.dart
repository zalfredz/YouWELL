import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';

class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key, required this.controller});
  final WellnessController controller;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(22, 12, 22, 42),
    children: [
      const Text(
        'Community',
        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 4),
      Text(
        'Dukungan ringan dengan identitas alias.',
        style: TextStyle(color: context.colors.muted),
      ),
      const SizedBox(height: 20),
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

class _PostCard extends StatelessWidget {
  const _PostCard({required this.controller, required this.post});
  final WellnessController controller;
  final Map<String, dynamic> post;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: context.colors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: context.colors.selected,
              child: Text(
                post['alias'].toString()[0].toUpperCase(),
                style: TextStyle(color: context.colors.accent),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '@${post['alias']}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            if (post['sample'] == true) tag('contoh'),
            PopupMenuButton<String>(
              tooltip: 'Laporkan post',
              onSelected: (reason) {
                final sent = controller.reportCommunityPost(post['id'], reason);
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
              backgroundColor: active
                  ? context.colors.selected
                  : context.colors.raised,
              side: BorderSide(
                color: active ? context.colors.accent : context.colors.border,
              ),
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
