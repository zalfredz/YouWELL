import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/platform/platform.dart' as platform;
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/activity/data/meal_photo_store.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.controller});
  final WellnessController controller;

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile!;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil & Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 36),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: appSurface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: appBorder),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xff203a32),
                  child: Text(
                    profile['alias'].toString()[0].toUpperCase(),
                    style: const TextStyle(
                      color: appAccent,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile['alias'].toString(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Level ${controller.level}  •  ${controller.xp} XP',
                        style: const TextStyle(color: appMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _Section(
            title: 'Preferensi',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Jalur kurangi rokok / vape'),
                subtitle: const Text('Menambahkan challenge habit swap.'),
                value: controller.reduction,
                onChanged: controller.switchPath,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mode low-impact'),
                subtitle: const Text('Gerakan berikutnya dibuat lebih ringan.'),
                value: profile['lowImpact'] == true,
                onChanged: controller.setLowImpact,
              ),
            ],
          ),
          _Section(
            title: 'Data lokal',
            children: [
              const Text(
                'Belum ada akun atau cloud sync. Data hanya tersimpan di perangkat ini.',
                style: TextStyle(color: appMuted, height: 1.5),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => platform.download(
                  'youwell-${controller.today}.json',
                  utf8.encode(controller.export()),
                  'application/json',
                ),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Ekspor data'),
              ),
              TextButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Mulai ulang?'),
                      content: const Text(
                        'Profil dan seluruh progress lokal akan dihapus.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Batal'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Hapus'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await MealPhotoStore.clear();
                    await controller.reset();
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Hapus data & mulai ulang'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: appSurface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: appBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    ),
  );
}
