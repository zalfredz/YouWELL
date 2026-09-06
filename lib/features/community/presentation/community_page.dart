import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/utils/date_key.dart';
import 'package:youwell/features/community/data/demo_posts.dart';
import 'package:youwell/features/community/presentation/post_composer_sheet.dart';
import 'package:youwell/features/community/presentation/report_content_sheet.dart';
import 'package:youwell/features/community/presentation/widgets/vibe_map_painter.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key, required this.controller});
  final WellnessController controller;
  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  String tab = 'Wall';
  @override
  Widget build(BuildContext context) {
    final s = widget.controller;
    final posts = [
      ...s.posts.reversed,
      ...demoPosts,
    ].where((p) => p['room'] == tab && !s.isReported(p['id'].toString()));
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 100),
      children: [
        sectionHead(
          'Tumbuh bareng.',
          'Dukungan kecil bisa membuat hari seseorang lebih baik.',
        ),
        panel([
          tag('KOMUNITAS SIMULASI'),
          gap(8),
          caption(
            'Profil contoh dan interaksi hanya di browser ini. Kirimanmu belum dikirim ke pengguna lain. Kamu bisa mencoba antrean moderasi di Profil.',
          ),
        ], color: const Color(0xffedf1e6)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              [
                    'Wall',
                    'BurnoutSekolah',
                    'RunningAndFit',
                    'BebasVapeTogether',
                    'Squad & Buddy',
                    'Vibe Map',
                  ]
                  .map(
                    (t) => ChoiceChip(
                      label: Text(t),
                      selected: tab == t,
                      onSelected: (_) => setState(() => tab = t),
                    ),
                  )
                  .toList(),
        ),
        gap(20),
        if (tab == 'Squad & Buddy') ...[
          panel([
            tag('SQUAD QUEST • MINGGU INI'),
            gap(12),
            title('Langkah bareng, terasa ringan.', size: 24),
            gap(8),
            caption(
              'Target bersama 20 km. Empat anggota contoh + kamu. Kontribusimu berasal dari aktivitas jalan/lari minggu kalender ini.',
            ),
            gap(),
            if (!s.hasSquad)
              FilledButton(
                onPressed: () {
                  s.joinSquad();
                },
                child: const Text('Gabung squad contoh'),
              )
            else ...[
              Builder(
                builder: (context) {
                  final monday = dayKey(
                    s.now.subtract(Duration(days: s.now.weekday - 1)),
                  );
                  final mine = s.activities
                      .where(
                        (r) =>
                            r['day'].toString().compareTo(monday) >= 0 &&
                            ['Jalan', 'Lari'].contains(r['type']),
                      )
                      .fold(0.0, (sum, r) => sum + (r['km'] as num));
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      meter(
                        (8 + mine) / 20,
                        'Tim Tumbuh · 5/5 anggota',
                        '${(8 + mine).toStringAsFixed(1)} / 20 km',
                      ),
                      ...[
                        'langitpagi · 3 km',
                        'ruangteduh · 2 km',
                        'daunkecil · 2 km',
                        'awanbiru · 1 km',
                        '${s.profile!['alias']} (kamu) · ${mine.toStringAsFixed(1)} km',
                      ].map(
                        (t) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Text(t),
                        ),
                      ),
                      if (8 + mine >= 20) tag('🏅 Target bersama tercapai!'),
                      gap(),
                      TextButton(
                        onPressed: () {
                          s.leaveSquad();
                        },
                        child: const Text('Keluar squad'),
                      ),
                    ],
                  );
                },
              ),
            ],
          ]),
          panel([
            title('Satu teman, satu semangat.', size: 23),
            gap(8),
            caption(
              'Buddy contoh dipilih dari jalur yang sama. Hanya alias dan streak yang ditampilkan.',
            ),
            gap(),
            if (s.buddy == null)
              FilledButton.icon(
                onPressed: () {
                  s.matchBuddy();
                },
                icon: const Icon(Icons.people_outline),
                label: const Text('Temukan buddy contoh'),
              )
            else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.spa)),
                title: Text(s.buddy!['alias']),
                subtitle: Text(
                  '${s.buddy!['streak']} hari streak · ${s.reduction ? 'Habit swap' : 'Wellness'}',
                ),
              ),
              Wrap(
                spacing: 8,
                children: ['Semangat!', 'Kamu bisa!', 'High five']
                    .map(
                      (t) => FilterChip(
                        label: Text(t),
                        selected: s.hasReaction('buddy-$t'),
                        onSelected: (_) => s.react('buddy-$t'),
                      ),
                    )
                    .toList(),
              ),
              TextButton(
                onPressed: () {
                  s.endBuddy();
                },
                child: const Text('Akhiri pasangan'),
              ),
            ],
          ]),
        ] else if (tab == 'Vibe Map') ...[
          panel([
            title('Kamu tidak sendirian.', size: 23),
            gap(8),
            caption(
              'Peta ilustratif • seluruh angka berikut adalah data contoh. Mood pribadimu tidak ditambahkan ke agregat publik pada preview.',
            ),
            gap(24),
            AspectRatio(
              aspectRatio: 2.2,
              child: LayoutBuilder(
                builder: (context, b) => Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: VibeMapPainter()),
                    ),
                    ...[
                      (.15, .30, 'Medan', '🙂', 18),
                      (.35, .62, 'Jakarta', '😐', 42),
                      (.43, .76, 'Bandung', '🙂', 26),
                      (.56, .73, 'Surabaya', '😊', 22),
                      (.72, .49, 'Makassar', '😐', 16),
                    ].map(
                      (p) => Positioned(
                        left: b.maxWidth * p.$1 - 26,
                        top: b.maxHeight * p.$2 - 20,
                        child: Tooltip(
                          message: '${p.$3}: ${p.$5} pengguna contoh',
                          child: InkWell(
                            onTap: () => toast(
                              context,
                              '${p.$3} · ${p.$5} pengguna contoh · mood ${p.$4}',
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Text(p.$4),
                                  Text(
                                    p.$3,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            gap(),
            caption(
              'Desain produksi: agregat wilayah dengan minimal 10 pengguna berbeda; tanpa koordinat presisi atau catatan pribadi.',
            ),
          ]),
        ] else ...[
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () =>
                  sheet(context, PostComposerSheet(controller: s, room: tab)),
              icon: const Icon(Icons.add),
              label: Text(
                tab == 'Wall' ? 'Bagikan pencapaian' : 'Tulis di ruang ini',
              ),
            ),
          ),
          gap(),
          if (posts.isEmpty)
            panel([
              caption(
                'Belum ada kiriman di ruang ini. Cerita kecilmu boleh menjadi awal.',
              ),
            ]),
          ...posts.map(
            (p) => panel([
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xffe4ecdd),
                    child: Text(p['alias'].toString()[0].toUpperCase()),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      p['alias'].toString(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  tag(
                    p['status'] == 'pending'
                        ? 'Sedang ditinjau'
                        : p['status'] == 'rejected'
                        ? 'Perlu diubah'
                        : '#$tab',
                  ),
                ],
              ),
              gap(),
              Text(
                p['body'].toString(),
                style: const TextStyle(fontSize: 16, height: 1.6),
              ),
              gap(),
              if (p['status'] == 'approved')
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...[
                      '👏 Semangat!',
                      '🌿 Relate banget',
                      '💛 Terus tumbuh',
                    ].map(
                      (r) => FilterChip(
                        label: Text(r),
                        selected: s.hasReaction('${p['id']}-$r'),
                        onSelected: (_) => s.react('${p['id']}-$r'),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Laporkan dan sembunyikan',
                      onPressed: () => sheet(
                        context,
                        ReportContentSheet(
                          controller: s,
                          post: p['id'].toString(),
                        ),
                      ),
                      icon: const Icon(Icons.flag_outlined),
                    ),
                  ],
                )
              else
                caption(
                  p['note']?.toString() ??
                      'Hanya terlihat olehmu. Buka dashboard moderator preview untuk meninjau.',
                ),
              if (!p['id'].toString().startsWith('seed-'))
                TextButton(
                  onPressed: () => s.deletePost(p['id'].toString()),
                  child: const Text('Hapus kirimanku'),
                ),
            ]),
          ),
        ],
      ],
    );
  }
}
