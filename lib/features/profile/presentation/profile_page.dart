import 'package:youwell/core/config/app_environment.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/platform/platform.dart' as platform;
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/profile/presentation/edit_profile_sheet.dart';
import 'package:youwell/features/support/presentation/support_card.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.controller});
  final WellnessController controller;
  @override
  Widget build(BuildContext context) {
    final s = controller;
    final badges = [
      ('🌱', 'Langkah pertama', s.xp >= 20),
      ('🌿', 'Satu hari tuntas', s.completedDays.isNotEmpty),
      ('🔥', '7 hari beruntun', s.streak >= 7),
      (
        '💧',
        'Mulai terhidrasi',
        s.days.values.any((d) => (d['water'] ?? 0) > 0),
      ),
      ('👟', 'Mulai bergerak', s.activities.isNotEmpty),
      ('💛', 'Ruang untuk rasa', s.moods.isNotEmpty),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 100),
      children: [
        sectionHead(
          'Ruang milikmu.',
          'Atur ritme, identitas, dan data pribadimu.',
        ),
        panel([
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xffe4ecdd),
                child: Text(
                  s.profile!['alias'].toString()[0].toUpperCase(),
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title(s.profile!['alias'], size: 24),
                    caption('Bersama YouWell sejak ${s.profile!['started']}'),
                  ],
                ),
              ),
              TextButton(
                onPressed: () =>
                    sheet(context, EditProfileSheet(controller: s)),
                child: const Text('Edit'),
              ),
            ],
          ),
          gap(),
          tag(s.reduction ? 'PATH • HABIT SWAP' : 'PATH • WELLNESS'),
          gap(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Jalur kurangi rokok / vape'),
            subtitle: const Text(
              'Mengubah pool misi berikutnya dan statistik craving.',
            ),
            value: s.reduction,
            onChanged: (v) {
              s.switchPath(v);
              toast(
                context,
                'Jalur diperbarui. Kartu yang sudah dibuka tetap tersimpan sampai akhir hari.',
              );
            },
          ),
          caption(
            'Buddy direset saat pindah jalur agar pasangan berikutnya sesuai jalur baru.',
          ),
        ]),
        panel([
          title('Lencana perjalanan', size: 22),
          gap(18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: badges
                .map(
                  (b) => Container(
                    width: 150,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: b.$3 ? const Color(0xffedf2e5) : cream,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        Text(
                          b.$3 ? b.$1 : '🔒',
                          style: const TextStyle(fontSize: 26),
                        ),
                        gap(8),
                        Text(
                          b.$2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                        caption(b.$3 ? 'Terbuka' : 'Belum terbuka'),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ]),
        panel([
          title('Privasi & kontrol data', size: 22),
          gap(),
          caption(
            'Profil ini bersifat lokal pada browser dan origin yang sama. Catatan mood dan foto makanan tidak dibagikan. Micro-Vent tidak disimpan. Perangkat bersama dapat diakses orang lain; hapus data saat selesai bila diperlukan.',
          ),
          gap(),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: () => platform.download(
                  'youwell-data-${s.today}.json',
                  utf8.encode(s.export()),
                  'application/json',
                ),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Ekspor data JSON'),
              ),
              TextButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Hapus semua data lokal?'),
                      content: const Text(
                        'Profil, catatan, foto, dan progres di browser ini akan dihapus. Ekspor dahulu jika ingin menyimpannya.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Batal'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Ya, hapus data'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) await s.reset();
                },
                child: const Text('Hapus data & mulai ulang'),
              ),
            ],
          ),
        ]),
        if (AppEnvironment.showPreviewTools)
          panel([
            title('Uji alur moderasi', size: 22),
            gap(8),
            caption(
              'Buka dashboard terpisah untuk menyetujui atau menolak kiriman lokal. Preview ini belum memiliki autentikasi admin.',
            ),
            gap(),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/moderator'),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Buka moderator preview'),
            ),
          ]),
        if (AppEnvironment.showPreviewTools)
          panel([
            tag('COBA PERJALANAN • PREVIEW'),
            gap(12),
            title('Simulasikan pergantian hari', size: 22),
            gap(8),
            caption(
                'Tanggal aplikasi: ${s.today}. Majukan tanggal untuk mencoba kartu baru, adaptasi, dan freeze tanpa menunggu. Tanggal perangkat tidak berubah. Reset data untuk kembali ke tanggal sebenarnya.'),
            gap(),
            Wrap(spacing: 10, runSpacing: 10, children: [
              OutlinedButton(
                  onPressed: () {
                    s.advancePreviewDays(1);
                    toast(context,
                        'Tanggal preview: ${s.today}. Buka kartu baru di Home.');
                  },
                  child: const Text('Maju 1 hari')),
              OutlinedButton(
                  onPressed: () {
                    s.advancePreviewDays(2);
                    toast(context,
                        'Tanggal preview: ${s.today}. Kemarin terlewat; coba freeze jika ada streak.');
                  },
                  child: const Text('Lewati 1 hari (+2)')),
            ]),
          ]),
        const SupportCard(),
      ],
    );
  }
}
