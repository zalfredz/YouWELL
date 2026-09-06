import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/utils/date_key.dart';
import 'package:youwell/features/activity/presentation/activity_entry_sheet.dart';
import 'package:youwell/features/nutrition/presentation/meal_entry_sheet.dart';
import 'package:youwell/features/nutrition/presentation/nutrition_targets_sheet.dart';
import 'package:youwell/features/recap/presentation/recap_sheet.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key, required this.controller});
  final WellnessController controller;
  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  int period = 7;
  @override
  Widget build(BuildContext context) {
    final s = widget.controller;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 100),
      children: [
        sectionHead(
          'Setiap langkah berarti.',
          'Lihat progresmu, tanpa membandingkan dengan siapa pun.',
        ),
        Wrap(
          spacing: 8,
          children: [1, 7, 30]
              .map(
                (p) => ChoiceChip(
                  label: Text({1: 'Hari ini', 7: '7 hari', 30: '30 hari'}[p]!),
                  selected: period == p,
                  onSelected: (_) => setState(() => period = p),
                ),
              )
              .toList(),
        ),
        gap(20),
        Wrap(
          spacing: 14,
          runSpacing: 12,
          children: [
            stat(
              'Misi selesai',
              '${(s.compliance(period) * 100).round()}%',
              Icons.task_alt,
            ),
            stat(
              'Jarak bergerak',
              '${s.total('activities', 'km', period: period).toStringAsFixed(1)} km',
              Icons.directions_walk,
            ),
            stat(
              'Waktu aktif',
              '${s.total('activities', 'minutes', period: period).round()} mnt',
              Icons.timer_outlined,
            ),
            if (s.reduction)
              stat(
                'Estimasi hemat',
                'Rp ${s.savings(period).round()}',
                Icons.savings_outlined,
              ),
          ],
        ),
        gap(22),
        panel([
          title('Ritme penyelesaian', size: 21),
          gap(18),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(period == 1 ? 1 : period, (i) {
                final key = dayKey(
                  s.now.subtract(
                    Duration(days: (period == 1 ? 1 : period) - 1 - i),
                  ),
                );
                final q = (s.days[key]?['quests'] ?? []) as List;
                final rate = q.isEmpty
                    ? 0.0
                    : q.where((v) => v['done'] == true).length / q.length;
                return Expanded(
                  child: Tooltip(
                    message: '$key · ${(rate * 100).round()}%',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: 8 + rate * 65,
                            decoration: BoxDecoration(
                              color: key == s.today
                                  ? green
                                  : const Color(0xffb6caa8),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          gap(6),
                          if (period <= 7)
                            Text(
                              key.substring(8),
                              style: const TextStyle(
                                fontSize: 11,
                                color: muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          gap(12),
          caption(
            'Persentase dari misi yang dibuka. Hari tanpa kartu tidak dihitung.',
          ),
        ]),
        panel([
          Row(
            children: [
              Expanded(child: title('Asupan hari ini', size: 22)),
              IconButton(
                tooltip: 'Atur target',
                onPressed: () =>
                    sheet(context, NutritionTargetsSheet(controller: s)),
                icon: const Icon(Icons.tune),
              ),
            ],
          ),
          caption('Target pribadi bisa diubah; angka ini bukan resep medis.'),
          meter(
            s.water / (s.profile!['waterGoal'] as num),
            'Air',
            '${s.water.round()} / ${s.profile!['waterGoal']} ml',
          ),
          meter(
            s.total('meals', 'kcal') / (s.profile!['kcalGoal'] as num),
            'Energi',
            '${s.total('meals', 'kcal').round()} / ${s.profile!['kcalGoal']} kkal',
          ),
          meter(
            s.total('meals', 'protein') / (s.profile!['proteinGoal'] as num),
            'Protein',
            '${s.total('meals', 'protein').round()} / ${s.profile!['proteinGoal']} g',
          ),
          caption(
            'Karbohidrat tercatat: ${s.total('meals', 'carbs').round()} g',
          ),
          gap(),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.tonalIcon(
                onPressed: s.addWater,
                icon: const Icon(Icons.water_drop_outlined),
                label: const Text('+ 250 ml air'),
              ),
              FilledButton.icon(
                onPressed: () => sheet(context, MealEntrySheet(controller: s)),
                icon: const Icon(Icons.add),
                label: const Text('Catat makanan'),
              ),
            ],
          ),
        ]),
        panel([
          title('Nutrition log', size: 21),
          gap(),
          if (s.meals.isEmpty)
            caption(
              'Belum ada makanan tercatat. Foto bersifat privat di perangkat ini.',
            ),
          ...s.meals.reversed.take(12).map(
                (r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: r['photo'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            base64Decode(r['photo'].toString().split(',').last),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(Icons.restaurant, color: green),
                  title: Text('${r['name']} · ${r['servings']} porsi'),
                  subtitle: Text(
                    '${r['day']} · ${(r['kcal'] as num).round()} kkal · P ${(r['protein'] as num).round()}g · K ${(r['carbs'] as num).round()}g',
                  ),
                  trailing: IconButton(
                    tooltip: 'Hapus makanan',
                    onPressed: () => s.deleteMeal(r['id']),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ),
        ]),
        panel([
          Row(
            children: [
              Expanded(child: title('Aktivitas fisik', size: 21)),
              TextButton(
                onPressed: () =>
                    sheet(context, ActivityEntrySheet(controller: s)),
                child: const Text('+ Catat'),
              ),
            ],
          ),
          if (s.activities.isEmpty)
            caption('Jalan, lari, atau gerak ringan. Semua usaha berarti.'),
          ...s.activities.reversed.take(10).map(
                (r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.directions_walk, color: green),
                  title: Text('${r['type']} · ${r['km']} km'),
                  subtitle: Text('${r['day']} · ${r['minutes']} menit'),
                  trailing: IconButton(
                    tooltip: 'Hapus aktivitas',
                    onPressed: () => s.deleteActivity(r['id']),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ),
        ]),
        panel([
          title('Riwayat companion', size: 21),
          gap(),
          Text(
            'Level ${s.level} · ${s.xp} XP · ${s.completedDays.length} hari tuntas',
          ),
          gap(12),
          if (s.completedDays.isEmpty)
            caption(
              'Selesaikan seluruh misi harian untuk menumbuhkan companion.',
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: s.completedDays.reversed
                .take(30)
                .map((d) => tag('🌱 $d'))
                .toList(),
          ),
          gap(12),
          caption(
            '${s.frozenDays.length} hari dilindungi freeze. Companion tetap bersamamu.',
          ),
        ]),
        if (s.reduction)
          panel([
            title('Kenali pola craving', size: 21),
            gap(8),
            caption(
              'Pola berdasarkan catatanmu, bukan diagnosis. Estimasi hemat hanya dari sesi selesai yang kamu konfirmasi tidak berujung merokok.',
            ),
            gap(),
            ...['Stres', 'Setelah makan', 'Teman', 'Bosan', 'Lainnya'].map((t) {
              final all = s.cravings
                  .where(
                    (r) =>
                        r['day'].toString().compareTo(
                              dayKey(
                                  s.now.subtract(Duration(days: period - 1))),
                            ) >=
                        0,
                  )
                  .toList();
              final n = all.where((r) => r['trigger'] == t).length;
              return meter(all.isEmpty ? 0 : n / all.length, t, '$n kali');
            }),
            ...s.cravings.reversed.take(8).map(
                  (r) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${r['trigger']} · ${r['success'] == true ? 'Jeda selesai' : 'Sesi dihentikan'}',
                    ),
                    subtitle: Text(
                      '${r['day']} ${r['time'].toString().substring(11, 16)} · ${r['seconds']} detik',
                    ),
                  ),
                ),
          ]),
        panel([
          title('Perasaan yang tercatat', size: 21),
          gap(),
          if (s.moods.isEmpty)
            caption('Check-in pertamamu bisa dimulai dari Home.'),
          ...s.moods.reversed.take(7).map(
                (r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${[
                      '😔',
                      '😕',
                      '😐',
                      '🙂',
                      '😊'
                    ][(r['mood'] as int) - 1]}  ${r['day']}',
                  ),
                  subtitle: Text(
                    '${(r['tags'] as List).join(' · ')}${r['note'].toString().isEmpty ? '' : '\n${r['note']}'}',
                  ),
                ),
              ),
        ]),
        panel([
          tag('YOUR LITTLE WRAPPED'),
          gap(12),
          title('Perjalananmu layak dirayakan.', size: 22),
          gap(8),
          caption(
            'Unduh kartu recap tanpa catatan privat. Bisa dibagikan ke Story.',
          ),
          gap(),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton(
                onPressed: () =>
                    sheet(context, RecapSheet(controller: s, period: 7)),
                child: const Text('Recap mingguan'),
              ),
              OutlinedButton(
                onPressed: () =>
                    sheet(context, RecapSheet(controller: s, period: 30)),
                child: const Text('Recap bulanan'),
              ),
            ],
          ),
        ], color: const Color(0xffe4ecdd)),
      ],
    );
  }

  Widget stat(String name, String value, IconData icon) => SizedBox(
        width: 190,
        child: panel([
          Icon(icon, color: green),
          gap(12),
          title(value, size: 28),
          caption(name),
        ]),
      );
}
