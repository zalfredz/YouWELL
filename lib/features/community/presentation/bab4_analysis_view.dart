import 'package:flutter/material.dart';
import 'package:youwell/application/bab4_report.dart';
import 'package:youwell/application/research_overview.dart';
import 'package:youwell/application/study_dashboard.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/progress/domain/research_store.dart';

/// Researcher dashboard, "BAB 4": four analyses (Semua, Wellness, Rokok,
/// Vape) laid out in the order of the results chapter. App logs describe
/// engagement and support triangulation; they do not measure effectiveness.
class Bab4AnalysisView extends StatefulWidget {
  const Bab4AnalysisView({
    super.key,
    required this.people,
    required this.now,
    required this.onDownload,
  });
  final List<ParticipantOverview> people;
  final DateTime now;
  final void Function(String name, String csv) onDownload;

  @override
  State<Bab4AnalysisView> createState() => _Bab4AnalysisViewState();
}

class _Bab4AnalysisViewState extends State<Bab4AnalysisView> {
  String _group = 'all';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final people = [
      for (final person in widget.people)
        ?StudyParticipant.from(person, now: widget.now),
    ]..sort((a, b) => compareParticipantCodes(a.code, b.code));
    if (people.isEmpty) {
      return Text(
        'Belum ada peserta studi. Tambahkan kode di Kelola peserta.',
        style: TextStyle(color: c.muted),
      );
    }
    final shown = bab4Members(people, _group);
    final noProduct = reductionWithoutProduct(people);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final MapEntry(:key, :value) in bab4Groups.entries)
              ChoiceChip(
                label: Text('$value (n = ${bab4Members(people, key).length})'),
                selected: _group == key,
                showCheckmark: false,
                onSelected: (_) => setState(() => _group = key),
              ),
          ],
        ),
        if ((_group == 'rokok' || _group == 'vape') && noProduct.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${noProduct.map((p) => p.code).join(', ')} (jalur rokok/vape) '
              'belum mencatat konsumsi, jadi belum masuk kelompok Rokok '
              'atau Vape.',
              style: TextStyle(color: c.amber),
            ),
          ),
        const SizedBox(height: 20),
        if (shown.isEmpty)
          Text(
            'Belum ada peserta di kelompok ini.',
            style: TextStyle(color: c.muted),
          )
        else ...[
          _Section(
            title: 'Keterlibatan minggu 4',
            subtitle:
                'Aktif = membuka aplikasi atau menyelesaikan minimal 1 '
                'aktivitas dalam minggu itu (kriteria 3).',
            child: _Criterion(people: shown, all: _group == 'all'),
          ),
          _Section(
            title: 'Keterlibatan per minggu',
            subtitle:
                'Rata-rata per peserta yang sudah mencapai minggu itu. '
                '* = minggu masih berjalan untuk sebagian peserta.',
            child: _EngagementTable(people: shown),
          ),
          if (_group == 'all')
            _Section(
              title: 'Perbandingan jalur (eksploratif)',
              subtitle:
                  'Wellness n = 4 dan rokok/vape n = 6 menurut rencana; '
                  'perbedaan tidak digeneralisasi.',
              child: _PathTable(people: people),
            ),
          if (_group == 'wellness') ...[
            _Section(
              title: 'Target per pilar',
              subtitle:
                  'Rata-rata hari target tercapai per peserta (dari 7) per '
                  'minggu.',
              child: _PillarTable(people: shown),
            ),
            _Section(
              title: 'Level misi',
              subtitle:
                  'Level di akhir minggu pertama ke akhir minggu terakhir yang '
                  'tercatat. Naik bertahap = tantangan bertahap (graded tasks).',
              child: _LevelTable(people: shown),
            ),
            _Section(
              title: 'Pola harian',
              subtitle:
                  'Satu baris per peserta, satu kotak per hari studi. Makin '
                  'gelap, makin banyak misi inti selesai.',
              child: _Heatmap(people: shown),
            ),
          ],
          if (_group == 'rokok' || _group == 'vape') ...[
            _Section(
              title: 'Habit Swap per minggu',
              subtitle:
                  'Per peserta: momen dicoba · berakhir tidak jadi · tetap '
                  'memakai ${_group == 'rokok' ? 'rokok' : 'vape'}.',
              child: _SwapTable(people: shown, type: _group),
            ),
            _Section(
              title: 'Konsumsi yang dicatat peserta',
              subtitle:
                  'Rata-rata ${_unit(_group)} per hari tercatat (hari '
                  'tercatat/7). Disajikan sebagai self-monitoring, bukan bukti '
                  'pengurangan. Perubahan dihitung dari minggu 1 ke minggu '
                  'terakhir yang punya minimal 4 hari tercatat.',
              child: _UsageTable(people: shown, type: _group),
            ),
          ],
          _Section(
            title: 'Rekap log pemakaian (Lampiran A.5)',
            subtitle: 'Per peserta per minggu.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: () => widget.onDownload(
                    'youwell-a5-log-$_group.csv',
                    toCsv(a5CsvColumns, a5CsvRows(shown)),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Unduh A.5 (CSV)'),
                ),
                const SizedBox(height: 12),
                _A5Table(people: shown),
              ],
            ),
          ),
          _Section(
            title: 'Kualitas data',
            child: _Quality(people: shown),
          ),
          _Section(
            title: 'Triangulasi di BAB 4',
            child: Text(switch (_group) {
              'wellness' =>
                'Bandingkan dengan skor R3 (tantangan sesuai kemampuan), '
                    'R4 (membantu menjalankan kebiasaan sehat), dan wawancara.',
              'rokok' || 'vape' =>
                'Bandingkan Habit Swap dengan T3, catatan konsumsi dengan T1 '
                    '(kesadaran pola), dan wawancara no. 6.',
              _ =>
                'Bandingkan keterlibatan dengan skor B1–B4 (niat penggunaan '
                    'berkelanjutan) dan wawancara no. 7 (alasan lanjut atau '
                    'berhenti).',
            }, style: TextStyle(color: c.muted)),
          ),
        ],
      ],
    );
  }
}

String _unit(String type) => type == 'vape' ? 'sesi' : 'batang';

String _number(num value, {int digits = 1}) => value is int
    ? '$value'
    : value.toStringAsFixed(digits).replaceAll('.', ',');

String _week(EngagementWeek w) => 'Minggu ${w.week}${w.provisional ? '*' : ''}';

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Text(
              subtitle!,
              style: TextStyle(color: context.colors.muted),
            ),
          ),
        ],
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

/// A scrollable table with a bold first column.
class _Table extends StatelessWidget {
  const _Table({required this.columns, required this.rows});
  final List<String> columns;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      headingRowHeight: 48,
      dataRowMinHeight: 40,
      dataRowMaxHeight: double.infinity,
      columns: [
        for (final column in columns)
          DataColumn(
            label: Text(
              column,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
      ],
      rows: [
        for (final row in rows)
          DataRow(
            cells: [
              for (final (i, cell) in row.indexed)
                DataCell(
                  Text(
                    cell,
                    style: i == 0
                        ? const TextStyle(fontWeight: FontWeight.w700)
                        : null,
                  ),
                ),
            ],
          ),
      ],
    ),
  );
}

class _Criterion extends StatelessWidget {
  const _Criterion({required this.people, required this.all});
  final List<StudyParticipant> people;
  final bool all;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = criterion3(people);
    final (label, color) = !all
        ? (null, c.muted)
        : switch (r.met) {
            true => ('Tercapai', c.success),
            false => ('Belum tercapai', c.amber),
            null => ('Belum final', c.muted),
          };
    final waiting = r.total - r.reached;
    final notes = [
      if (all)
        'Target: minimal $engagementTarget dari $plannedParticipants peserta.',
      if (waiting > 0) '$waiting peserta belum mencapai minggu 4.',
      if (r.reached > 0 && r.provisional && waiting < r.total)
        'Minggu 4 masih berjalan untuk sebagian peserta.',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${r.active} dari ${r.total} peserta aktif di minggu 4',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            if (label != null)
              Chip(
                label: Text(label),
                side: BorderSide(color: color),
                labelStyle: TextStyle(color: color),
              ),
          ],
        ),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(notes.join(' '), style: TextStyle(color: c.muted)),
        ],
      ],
    );
  }
}

class _EngagementTable extends StatelessWidget {
  const _EngagementTable({required this.people});
  final List<StudyParticipant> people;

  @override
  Widget build(BuildContext context) {
    final weeks = engagementByWeek(people);
    String mean(double? v) => v == null ? '–' : _number(v);
    return _Table(
      columns: ['', for (final w in weeks) _week(w)],
      rows: [
        [
          'Peserta aktif',
          for (final w in weeks) w.n == 0 ? '–' : '${w.active}/${w.n}',
        ],
        ['Hari aktif (dari 7)', for (final w in weeks) mean(w.activeDays)],
        [
          'Hari membuka aplikasi (dari 7)',
          for (final w in weeks) mean(w.openedDays),
        ],
        ['Core Quest selesai', for (final w in weeks) mean(w.coreDone)],
      ],
    );
  }
}

class _PathTable extends StatelessWidget {
  const _PathTable({required this.people});
  final List<StudyParticipant> people;

  @override
  Widget build(BuildContext context) {
    List<String> row(String label, List<StudyParticipant> members) {
      final weeks = engagementByWeek(members);
      final all = [for (final w in weeks) ...w.reached];
      double? mean(int Function(StudyWeek w) v) => all.isEmpty
          ? null
          : all.fold<int>(0, (s, w) => s + v(w)) / all.length;
      return [
        '$label (n = ${members.length})',
        for (final w in weeks) w.n == 0 ? '–' : '${w.active}/${w.n}',
        mean((w) => w.activeDays) == null
            ? '–'
            : _number(mean((w) => w.activeDays)!),
        mean((w) => w.coreDone) == null
            ? '–'
            : _number(mean((w) => w.coreDone)!),
      ];
    }

    final weeks = engagementByWeek(people);
    return _Table(
      columns: [
        'Jalur',
        for (final w in weeks) 'Aktif ${_week(w)}',
        'Hari aktif / minggu',
        'Core Quest / minggu',
      ],
      rows: [
        row('Wellness', bab4Members(people, 'wellness')),
        row('Rokok/vape', people.where((p) => p.reduction).toList()),
      ],
    );
  }
}

class _PillarTable extends StatelessWidget {
  const _PillarTable({required this.people});
  final List<StudyParticipant> people;

  @override
  Widget build(BuildContext context) {
    final weeks = engagementByWeek(people);
    return _Table(
      columns: ['Pilar', for (final w in weeks) _week(w)],
      rows: [
        for (final MapEntry(:key, :value) in targetCategories.entries)
          [
            value,
            for (final w in weeks)
              w.n == 0
                  ? '–'
                  : _number(
                      w.reached.fold<int>(0, (s, x) => s + x.targetDays(key)) /
                          w.n,
                    ),
          ],
      ],
    );
  }
}

class _LevelTable extends StatelessWidget {
  const _LevelTable({required this.people});
  final List<StudyParticipant> people;

  @override
  Widget build(BuildContext context) => _Table(
    columns: ['Kode', ...targetCategories.values],
    rows: [
      for (final p in people)
        [
          p.code,
          for (final key in targetCategories.keys)
            switch (levelChange(p, key)) {
              null => '–',
              final l when l.first == l.last => '${l.first} (tetap)',
              final l => '${l.first} ke ${l.last}',
            },
        ],
    ],
  );
}

class _SwapTable extends StatelessWidget {
  const _SwapTable({required this.people, required this.type});
  final List<StudyParticipant> people;
  final String type;

  @override
  Widget build(BuildContext context) {
    final weeks = engagementByWeek(people);
    String cell(({int tried, int skipped, int used}) r) =>
        r.tried == 0 ? '–' : '${r.tried} · ${r.skipped} · ${r.used}';
    ({int tried, int skipped, int used}) add(
      ({int tried, int skipped, int used}) a,
      ({int tried, int skipped, int used}) b,
    ) => (
      tried: a.tried + b.tried,
      skipped: a.skipped + b.skipped,
      used: a.used + b.used,
    );
    const zero = (tried: 0, skipped: 0, used: 0);
    String share(({int tried, int skipped, int used}) r) =>
        r.skipped + r.used == 0
        ? '–'
        : '${(r.skipped / (r.skipped + r.used) * 100).round()}%';
    final totals = [
      for (final w in weeks)
        w.reached.map((x) => x.swapResult(type)).fold(zero, add),
    ];
    return _Table(
      columns: [
        'Kode',
        for (final w in weeks) _week(w),
        'Total',
        '% tidak jadi',
      ],
      rows: [
        for (final p in people)
          () {
            final per = [for (final w in p.weeks) w.swapResult(type)];
            final total = per.fold(zero, add);
            return [
              p.code,
              for (var i = 0; i < 4; i++) i < per.length ? cell(per[i]) : '',
              cell(total),
              share(total),
            ];
          }(),
        [
          'Semua',
          for (final t in totals) cell(t),
          cell(totals.fold(zero, add)),
          share(totals.fold(zero, add)),
        ],
      ],
    );
  }
}

class _UsageTable extends StatelessWidget {
  const _UsageTable({required this.people, required this.type});
  final List<StudyParticipant> people;
  final String type;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final weeks = engagementByWeek(people);
    final cases = [for (final p in people) UsageCase(p, type)];
    final m = medianUsageChange(cases);
    // The overall change appears once someone has finished the 28 days.
    final finished = cases.where((u) => u.participant.finished).length;
    String percent(double p) => '${p > 0 ? '+' : ''}${p.round()}%';
    String cell(UsageCase u, int i) {
      if (i >= u.weeks.length) return '';
      final week = u.weeks[i], days = u.participant.weeks[i].days.length;
      if (week.mean == null) return '– (0/$days)';
      final text = '${_number(week.mean!)} (${week.loggedDays}/$days)';
      return switch (u.weekPercent(i)) {
        null => text,
        final p => '$text\n${percent(p)} dari minggu 1',
      };
    }

    final medians = [
      for (var i = 1; i < 4; i++)
        median([for (final u in cases) ?u.weekPercent(i)]),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Table(
          columns: [
            'Kode',
            for (final w in weeks) _week(w),
            if (finished > 0) 'Perubahan 28 hari',
          ],
          rows: [
            for (final u in cases)
              [
                u.participant.code,
                for (var i = 0; i < 4; i++) cell(u, i),
                if (finished > 0)
                  !u.participant.finished
                      ? 'Belum 28 hari'
                      : switch (u.change) {
                          null => 'Data belum cukup',
                          final ch => [
                            'Minggu 1 ke ${ch.week}: '
                                '${ch.change.difference > 0 ? '+' : ''}'
                                '${_number(ch.change.difference)} '
                                '${_unit(type)}/hari',
                            if (ch.change.percent case final pct?)
                              '(${percent(pct * 100)})',
                          ].join(' '),
                        },
              ],
            [
              'Median',
              'acuan',
              for (final med in medians)
                med == null ? '–' : '${percent(med)} dari minggu 1',
              if (finished > 0) m == null ? '–' : percent(m),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          [
            'Persen = perubahan rata-rata per hari tercatat dibanding minggu 1; '
                'hanya untuk minggu yang sudah selesai dan minimal 4 hari '
                'tercatat di kedua minggu. Minus = berkurang.',
            if (finished == 0)
              'Kolom perubahan 28 hari muncul setelah ada peserta yang '
                  'menyelesaikan 28 hari.',
          ].join(' '),
          style: TextStyle(color: c.muted),
        ),
      ],
    );
  }
}

class _A5Table extends StatelessWidget {
  const _A5Table({required this.people});
  final List<StudyParticipant> people;

  @override
  Widget build(BuildContext context) => _Table(
    columns: const [
      'Kode',
      'Minggu',
      'Hari membuka aplikasi',
      'Core Quest selesai',
      'Habit Swap',
      'Status aktif',
    ],
    rows: [
      for (final row in a5Rows(people))
        [
          row.code,
          '${row.week.week}${row.week.complete ? '' : '*'}',
          '${row.opened}',
          '${row.coreDone}',
          row.swaps == null ? '–' : '${row.swaps}',
          row.status,
        ],
    ],
  );
}

class _Quality extends StatelessWidget {
  const _Quality({required this.people});
  final List<StudyParticipant> people;

  @override
  Widget build(BuildContext context) {
    final elapsed = people.fold(0, (s, p) => s + p.elapsed);
    final withData = people.fold(0, (s, p) => s + p.daysWithData);
    return Text(
      [
        'Hari berisi data: '
            '${elapsed == 0 ? '–' : '${(withData / elapsed * 100).round()}%'} '
            '($withData dari $elapsed hari studi).',
      ].join('\n'),
    );
  }
}

/// Days 1–28 per participant, darker for more core missions done.
class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.people});
  final List<StudyParticipant> people;

  static const _cell = 20.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Color heat(int level) => switch (level) {
      0 => c.border.withValues(alpha: .35),
      1 => c.accent.withValues(alpha: .25),
      2 => c.accent.withValues(alpha: .6),
      _ => c.accent,
    };
    const labels = [
      'tidak ada data',
      'aktif tanpa misi inti',
      'sebagian misi inti',
      'semua misi inti',
    ];
    final small = TextStyle(color: c.muted, fontSize: 11);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(width: 56),
                  for (var n = 1; n <= studyDays; n++)
                    SizedBox(
                      width: _cell + 2,
                      child: Text(
                        n == 1 || n % 7 == 0 ? '$n' : '',
                        style: small,
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
              for (final p in people)
                Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(
                        p.code,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    for (var n = 1; n <= studyDays; n++)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          1,
                          1,
                          n % 7 == 0 ? 5 : 1,
                          1,
                        ),
                        child: n > p.days.length
                            ? Container(
                                width: _cell,
                                height: _cell,
                                decoration: BoxDecoration(
                                  border: Border.all(color: c.border),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              )
                            : Tooltip(
                                message:
                                    '${p.code} · hari $n (${p.days[n - 1].day})\n'
                                    '${labels[dayLevel(p.days[n - 1])]}',
                                child: Container(
                                  width: _cell,
                                  height: _cell,
                                  decoration: BoxDecoration(
                                    color: heat(dayLevel(p.days[n - 1])),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (var level = 0; level < 4; level++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: heat(level),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(labels[level], style: small),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
