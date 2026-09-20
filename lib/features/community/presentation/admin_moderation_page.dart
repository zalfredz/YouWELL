import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';

class AdminModerationPage extends StatelessWidget {
  const AdminModerationPage({super.key, required this.controller});
  final WellnessController controller;

  @override
  Widget build(BuildContext context) {
    final queue = controller.moderationQueue;
    final reports = controller.communityReports;
    return ListView(
      padding: const EdgeInsets.all(30),
      children: [
        const Text(
          'Community Admin',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          'Prototype lokal. Role dan audit log server ditambahkan bersama Auth.',
          style: TextStyle(color: appMuted),
        ),
        const SizedBox(height: 24),
        _Summary(pending: queue.length, reports: reports.length),
        const SizedBox(height: 24),
        const Text(
          'Pending posts',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (queue.isEmpty)
          const _Empty(message: 'Tidak ada post yang menunggu review.'),
        ...queue.map(
          (post) => _ModerationCard(controller: controller, post: post),
        ),
        const SizedBox(height: 24),
        const Text(
          'Reports',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (reports.isEmpty) const _Empty(message: 'Tidak ada laporan aktif.'),
        ...reports.map(
          (report) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: appSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: appBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.flag_outlined, color: appAccentAmber),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${report['reason']} • ${report['postId']}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () => controller.resolveCommunityReport(
                    report['id'].toString(),
                  ),
                  child: const Text('Selesaikan'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.pending, required this.reports});
  final int pending, reports;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _Number(value: '$pending', label: 'Pending'),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _Number(value: '$reports', label: 'Reports'),
      ),
    ],
  );
}

class _Number extends StatelessWidget {
  const _Number({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: appSurface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: appBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: appAccent,
            fontSize: 32,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(label, style: const TextStyle(color: appMuted)),
      ],
    ),
  );
}

class _ModerationCard extends StatelessWidget {
  const _ModerationCard({required this.controller, required this.post});
  final WellnessController controller;
  final Map<String, dynamic> post;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: appSurface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: appBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '@${post['alias']}',
          style: const TextStyle(color: appAccent, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text(post['text'].toString(), style: const TextStyle(height: 1.5)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          children: [
            FilledButton.icon(
              onPressed: () => controller.moderateCommunityPost(
                post['id'].toString(),
                'approved',
              ),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Approve'),
            ),
            OutlinedButton.icon(
              onPressed: () => controller.moderateCommunityPost(
                post['id'].toString(),
                'rejected',
                note: 'Tidak sesuai panduan komunitas.',
              ),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Reject'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: appSurface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: appBorder),
    ),
    child: Text(message, style: const TextStyle(color: appMuted)),
  );
}
