import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/utils/date_key.dart';
import 'package:youwell/features/mood/presentation/mood_check_in_sheet.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';
import 'package:youwell/shared/widgets/wellness_companion.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.controller, required this.onStats});
  final WellnessController controller;
  final VoidCallback onStats;
  @override
  Widget build(BuildContext context) {
    final done = controller.quests.where((q) => q['done'] == true).length;
    final frozen =
        controller.frozenDays.contains(
          dayKey(controller.now.subtract(const Duration(days: 1))),
        ) &&
        !controller.completedDays.contains(controller.today);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 100),
      children: [
        sectionHead(
          'Hai, ${controller.profile!['alias']} ☀',
          '${controller.today} · Hari yang baik dimulai dari satu langkah kecil.${controller.dayOffset > 0 ? ' (Tanggal simulasi)' : ''}',
        ),
        LayoutBuilder(
          builder: (c, b) {
            final primary = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: title('Langkah hari ini', size: 22)),
                    tag('$done / ${controller.quests.length} selesai'),
                  ],
                ),
                gap(12),
                if (controller.quests.isEmpty)
                  panel([
                    const Icon(Icons.style_rounded, color: appAccent, size: 30),
                    gap(10),
                    title('Daily Draw siap.', size: 21),
                    gap(6),
                    caption(
                      'Pilih satu paket challenge dari pop-up kartu. Kamu bisa membukanya dari ikon kartu di kanan atas kapan saja hari ini.',
                    ),
                  ])
                else ...[
                  meter(
                    done / controller.quests.length,
                    'Progres harian',
                    '${(done / controller.quests.length * 100).round()}%',
                  ),
                  gap(8),
                  ...controller.quests.map(
                    (q) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: appRaised,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: appSurface,
                          child: Icon(
                            {
                              'Gerak': Icons.directions_walk,
                              'Nutrisi': Icons.restaurant_outlined,
                              'Mental': Icons.favorite_border,
                              'Habit swap': Icons.air,
                              'Sosial': Icons.people_outline,
                            }[q['category']],
                            color: appAccent,
                          ),
                        ),
                        title: Text(
                          q['title'],
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            decoration: q['done'] == true
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: Text(
                          '${q['category']} · +20 XP',
                          style: const TextStyle(fontSize: 12, color: appMuted),
                        ),
                        trailing: IconButton(
                          tooltip: q['status'] == 'completed'
                              ? 'Sudah selesai'
                              : q['status'] == 'committed'
                              ? 'Tandai selesai'
                              : 'Commit challenge',
                          onPressed: q['status'] == 'completed'
                              ? null
                              : q['status'] == 'committed'
                              ? () => controller.completeCard(q['id'])
                              : () => controller.commitCard(q['id']),
                          icon: Icon(
                            q['status'] == 'completed'
                                ? Icons.check_circle
                                : q['status'] == 'committed'
                                ? Icons.lock_outline
                                : Icons.circle_outlined,
                            color: appAccent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                gap(),
                panel([
                  Row(
                    children: [
                      const Icon(Icons.favorite_border, color: appAccent),
                      const SizedBox(width: 10),
                      Expanded(child: title('Apa kabarmu hari ini?', size: 19)),
                    ],
                  ),
                  gap(8),
                  caption('Luangkan 30 detik untuk mendengarkan diri sendiri.'),
                  gap(12),
                  OutlinedButton(
                    onPressed: () => sheet(
                      context,
                      MoodCheckInSheet(controller: controller),
                    ),
                    child: const Text('Check-in perasaan'),
                  ),
                ]),
              ],
            );
            final side = Column(
              children: [
                panel([
                  Row(
                    children: [
                      Expanded(child: title('Teman tumbuhmu', size: 19)),
                      tag('LV ${controller.level}'),
                    ],
                  ),
                  Center(
                    child: WellnessCompanion(
                      kind: controller.profile!['companion'],
                      level: controller.level,
                      frozen: frozen,
                    ),
                  ),
                  Center(
                    child: Text(
                      frozen
                          ? 'Aku istirahat dulu, ya.'
                          : done == controller.quests.length && done > 0
                          ? 'Kita tumbuh bersama hari ini!'
                          : controller.streak == 0
                          ? 'Senang kamu ada di sini.'
                          : 'Satu langkah lagi. Aku temani.',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  gap(10),
                  meter(
                    (controller.xp % 100) / 100,
                    '${controller.xp} XP',
                    '${100 - controller.xp % 100} XP ke level berikutnya',
                  ),
                ]),
                panel([
                  title('Jaga ritmemu', size: 20),
                  gap(18),
                  Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department_outlined,
                        color: Color(0xffc57b48),
                        size: 30,
                      ),
                      const SizedBox(width: 12),
                      title('${controller.streak}', size: 32),
                      const SizedBox(width: 8),
                      Expanded(child: caption('hari streak misi')),
                    ],
                  ),
                  gap(),
                  caption(
                    'Streak bertambah setelah semua misi sehari selesai.',
                  ),
                  gap(),
                  OutlinedButton.icon(
                    onPressed: () {
                      toast(
                        context,
                        controller.freeze()
                            ? 'Freeze dipakai. Companion beristirahat, streak terlindungi.'
                            : 'Freeze bisa dipakai jika tepat kemarin terlewat dan sebelumnya ada streak.',
                      );
                    },
                    icon: const Icon(Icons.ac_unit),
                    label: Text('Gunakan freeze · ${controller.tokens} token'),
                  ),
                  gap(8),
                  caption('1 token awal. Dapat tambahan tiap 7 hari tuntas.'),
                ]),
                panel([
                  title('Tubuhmu butuh jeda?', size: 18),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mode low-impact'),
                    subtitle: const Text('Sakit / cedera'),
                    value: controller.profile?['lowImpact'] == true,
                    onChanged: (v) {
                      controller.setLowImpact(v);
                    },
                  ),
                  caption(
                    'Misi berikutnya menyesuaikan kemampuan dan penyelesaian minggu ini.',
                  ),
                  gap(8),
                  TextButton(
                    onPressed: onStats,
                    child: const Text('Lihat perjalananmu →'),
                  ),
                ]),
              ],
            );
            return b.maxWidth > 740
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: primary),
                      const SizedBox(width: 24),
                      Expanded(flex: 3, child: side),
                    ],
                  )
                : Column(children: [primary, side]);
          },
        ),
      ],
    );
  }
}
