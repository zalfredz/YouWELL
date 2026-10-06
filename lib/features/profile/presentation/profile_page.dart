import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/platform/platform.dart' as platform;
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/theme/appearance_scope.dart';
import 'package:youwell/features/activity/data/meal_photo_store.dart';
import 'package:youwell/features/reduction/presentation/reduction_support_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.controller,
    this.mobileExperience = false,
  });
  final WellnessController controller;
  final bool mobileExperience;

  Future<void> _researchConsent(BuildContext context) async {
    String? code = controller.researchParticipation?['code']?.toString();
    var agreed = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Ringkasan UAT opsional'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ringkasan berisi jumlah hari dibuka, aktivitas, quest, tingkat tangga, Delay Craving, dan Habit Swap. Tidak menyertakan alias, teks pribadi, foto, atau lokasi. Belum dikirim otomatis; ekspor dan bagikan hanya jika kamu setuju.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: code,
                  decoration: const InputDecoration(
                    labelText: 'Kode dari peneliti',
                  ),
                  items: [
                    for (var i = 1; i <= 10; i++)
                      DropdownMenuItem(value: 'P$i', child: Text('P$i')),
                  ],
                  onChanged: (value) => update(() => code = value),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Saya setuju menyiapkan ringkasan ini.'),
                  value: agreed,
                  onChanged: (value) => update(() => agreed = value == true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: agreed && code != null
                  ? () {
                      controller.setResearchParticipation(code, consent: true);
                      Navigator.pop(dialogContext);
                    }
                  : null,
              child: const Text('Simpan persetujuan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _switchPath(BuildContext context, bool enabled) async {
    if (!enabled || controller.profile?['reductionConsent'] == true) {
      controller.switchPath(enabled);
      return;
    }
    final agreed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          controller.quitFraming
              ? 'Aktifkan jalur berhenti rokok / vape?'
              : 'Aktifkan jalur kurangi rokok / vape?',
        ),
        content: const Text(
          'Catatan Delay Craving & Habit Swap akan disimpan untuk fitur ini. '
          'Ini data pribadi yang sensitif dan bisa dihapus kapan saja dari '
          'Profil.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Setuju & aktifkan'),
          ),
        ],
      ),
    );
    if (agreed == true) controller.switchPath(true, consent: true);
  }

  @override
  Widget build(BuildContext context) {
    final appearance = AppearanceScope.of(context);
    final profile = controller.profile!;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil & Pengaturan')),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 36),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: context.colors.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: context.colors.selected,
                    child: Text(
                      profile['alias'].toString()[0].toUpperCase(),
                      style: TextStyle(
                        color: context.colors.accent,
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
                          style: TextStyle(color: context.colors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _Section(
              title: 'Tampilan',
              children: [
                Text(
                  'Pilih tema atau ikuti pengaturan perangkat.',
                  style: TextStyle(color: context.colors.muted),
                ),
                const SizedBox(height: 14),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'system', label: Text('Sistem')),
                    ButtonSegment(value: 'light', label: Text('Terang')),
                    ButtonSegment(value: 'dark', label: Text('Gelap')),
                  ],
                  selected: {appearance.themePreference},
                  onSelectionChanged: (selection) =>
                      appearance.setThemePreference(selection.first),
                ),
              ],
            ),
            if (mobileExperience)
              _Section(
                title: 'Animasi & getaran',
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Kurangi animasi'),
                    subtitle: const Text(
                      'Reward tetap terlihat tanpa gerakan.',
                    ),
                    value: controller.reduceMotion,
                    onChanged: controller.setReduceMotion,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Getaran ringan'),
                    value: controller.haptics,
                    onChanged: controller.setHaptics,
                  ),
                ],
              ),
            _Section(
              title: 'Preferensi',
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Jalur ${controller.reductionLabel.toLowerCase()}',
                  ),
                  subtitle: Text(
                    controller.reduction
                        ? 'Aktif. Delay Craving & Habit Swap ada di bawah companion di Hari ini.'
                        : 'Tampilkan Delay Craving & Habit Swap di Hari ini dan tambahkan quest-nya ke kartu harian.',
                  ),
                  value: controller.reduction,
                  onChanged: (value) => _switchPath(context, value),
                ),
                if (controller.reduction) ...[
                  FilledButton.icon(
                    onPressed: () => openReductionSupport(context, controller),
                    icon: const Icon(Icons.smoke_free_rounded),
                    label: const Text('Buka Delay Craving & Habit Swap'),
                  ),
                  const SizedBox(height: 10),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mode aktivitas ringan (low-impact)'),
                  subtitle: const Text('Quest lari tidak akan muncul.'),
                  value: profile['lowImpact'] == true,
                  onChanged: controller.setLowImpact,
                ),
              ],
            ),
            if (mobileExperience)
              _Section(
                title: 'UAT opsional',
                children: [
                  Text(
                    controller.researchParticipation == null
                        ? 'Tetap bisa memakai aplikasi tanpa ikut penelitian.'
                        : 'Kode ${controller.researchParticipation!['code']} · hanya ringkasan angka',
                    style: TextStyle(color: context.colors.muted),
                  ),
                  TextButton(
                    onPressed: () => _researchConsent(context),
                    child: const Text('Atur persetujuan & kode'),
                  ),
                  if (controller.researchParticipation != null) ...[
                    OutlinedButton.icon(
                      onPressed: () => platform.download(
                        'youwell-uat-summary.json',
                        utf8.encode(controller.exportResearchSummary()),
                        'application/json',
                      ),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Ekspor ringkasan UAT'),
                    ),
                    TextButton(
                      onPressed: () => controller.setResearchParticipation(
                        null,
                        consent: false,
                      ),
                      child: const Text('Tarik persetujuan lokal'),
                    ),
                    Text(
                      'Tidak menarik salinan yang sudah kamu bagikan ke peneliti.',
                      style: TextStyle(
                        color: context.colors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            _Section(
              title: 'Data lokal',
              children: [
                Text(
                  'Belum ada akun atau cloud sync. Data hanya tersimpan di perangkat ini.',
                  style: TextStyle(color: context.colors.muted, height: 1.5),
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
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
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
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: context.colors.border),
    ),
    child: Material(
      type: MaterialType.transparency,
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
    ),
  );
}
