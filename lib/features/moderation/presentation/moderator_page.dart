import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/features/moderation/domain/content_filter.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';

class ModeratorPage extends StatelessWidget {
  const ModeratorPage({super.key, required this.controller});
  final WellnessController controller;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('YouWell • Moderator preview')),
    body: AnimatedBuilder(
      animation: controller,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          panel([
            tag('SIMULASI LOKAL • BUKAN AKSES ADMIN PRODUKSI'),
            gap(),
            caption(
              'Dashboard ini hanya meninjau kiriman di browser yang sama. Autentikasi moderator dan AI belum dihubungkan.',
            ),
          ]),
          title('Antrean tinjauan'),
          gap(),
          if (controller.posts.where((p) => p['status'] == 'pending').isEmpty)
            caption('Tidak ada kiriman menunggu.'),
          ...controller.posts
              .where((p) => p['status'] == 'pending')
              .map(
                (p) => panel([
                  Text('@${p['alias']} · #${p['room']}'),
                  gap(),
                  Text(p['body']),
                  gap(),
                  Wrap(
                    spacing: 12,
                    children: [
                      FilledButton(
                        onPressed: () {
                          final reason = moderationReason(p['body']);
                          if (reason != null) {
                            toast(context, reason);
                            return;
                          }
                          controller.updatePost(
                            p['id'],
                            'approved',
                            'Ditinjau pada preview lokal',
                          );
                        },
                        child: const Text('Setujui'),
                      ),
                      OutlinedButton(
                        onPressed: () => controller.updatePost(
                          p['id'],
                          'rejected',
                          'Moderator meminta cerita diubah agar lebih aman dan suportif.',
                        ),
                        child: const Text('Tolak'),
                      ),
                    ],
                  ),
                ]),
              ),
          gap(),
          title('Laporan konten'),
          gap(),
          ...controller.reports.map(
            (r) => panel([
              Text('${r['reason']} · ${r['post']}'),
              caption(r['day']),
              TextButton(
                onPressed: () => controller.resolveReport(r['id']),
                child: const Text('Pulihkan kiriman & tutup laporan'),
              ),
            ]),
          ),
        ],
      ),
    ),
  );
}
