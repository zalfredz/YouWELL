import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youwell/application/research_overview.dart';
import 'package:youwell/application/study_dashboard.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/progress/domain/research_store.dart';
import 'study_period_view.dart';

/// "Analisis studi" in the researcher dashboard, kept to one screen: four
/// key numbers, up to three conclusions, two charts with how to read them,
/// and a short table per participant. Everything else (all metrics, change
/// per participant, daily detail, downloads) sits under "Data lengkap".
class StudyAnalysisView extends StatefulWidget {
  const StudyAnalysisView({
    super.key,
    required this.people,
    required this.now,
    required this.onDownload,
  });
  final List<ParticipantOverview> people;
  final DateTime now;
  final void Function(String name, String csv) onDownload;

  @override
  State<StudyAnalysisView> createState() => _StudyAnalysisViewState();
}

/// The whole report is shown for one of these groups. Rokok and Vape come
/// from the daily totals a participant logged (the product choice itself
/// stays on the phone); someone using both is in both.
const _groups = {
  'all': 'Semua',
  'wellness': 'Wellness',
  'rokok': 'Rokok',
  'vape': 'Vape',
};

class _StudyAnalysisViewState extends State<StudyAnalysisView> {
  bool _byPeriod = false;
  String _group = 'all';
  String? _detail, _usageParticipant;

  static List<StudyParticipant> _of(
    List<StudyParticipant> people,
    String group,
  ) => switch (group) {
    'wellness' => people.where((p) => !p.reduction).toList(),
    'rokok' || 'vape' =>
      people.where((p) => p.reduction && p.types.contains(group)).toList(),
    _ => people,
  };

  static List<String> _products(String group) =>
      group == 'rokok' || group == 'vape' ? [group] : usageTypes;

  /// Highlights and the week table as plain text for slides.
  String _slideText(
    List<String> conclusions,
    List<WeekRow> rows,
    String group,
  ) => [
    'YouWELL: ${_groups[group]}',
    for (final line in conclusions) '- $line',
    '',
    ['Metrik', for (var w = 1; w <= 4; w++) 'Week $w'].join('\t'),
    for (final row in rows)
      [
        row.label,
        for (final cell in row.cells)
          cell.value == null
              ? formatWeekValue(row, cell)
              : '${formatWeekValue(row, cell)} (n=${cell.n})',
      ].join('\t'),
    '',
    'Week = 7 hari sejak peserta mulai. n = peserta dengan week selesai.',
  ].join('\n');

  /// At most three short sentences: engagement, missions or use, data.
  static List<String> _conclusions(
    List<WeekRow> rows,
    List<UsageOutcome> outcomes,
    String group,
    StudySummary summary,
  ) {
    WeekRow row(String label) => rows.firstWhere((r) => r.label == label);
    final days = row('Rata-rata hari aktif');
    final missions = row('Misi inti selesai');
    final done = [
      for (var w = 0; w < 4; w++)
        if (days.cells[w].value != null) w,
    ];
    String n(double v) => _number(v);
    final lines = <String>[];
    if (done.isEmpty) {
      lines.add('Belum ada week yang selesai, jadi belum ada angka kelompok.');
    } else if (done.length == 1) {
      final w = done.single;
      lines.add(
        'Week ${w + 1}: peserta aktif rata-rata '
        '${n(days.cells[w].value!)} dari 7 hari.',
      );
    } else {
      final a = done.first, b = done.last;
      final x = days.cells[a].value!, y = days.cells[b].value!;
      lines.add(
        'Keaktifan Week ${a + 1} ke Week ${b + 1}: ${n(x)} ke ${n(y)} hari '
        'dari 7 (${(y - x).abs() < .05
            ? 'tetap'
            : y > x
            ? 'naik'
            : 'turun'}).',
      );
    }
    final product = group == 'rokok' || group == 'vape' ? group : null;
    if (product != null) {
      final m = median([
        for (final o in outcomes)
          if (o.change?.percent case final p?) p * 100,
      ]);
      final down = outcomes.where((o) => o.category.startsWith('Turun')).length;
      final compared = outcomes.where((o) => o.change != null).length;
      lines.add(
        compared == 0
            ? '${product == 'rokok' ? 'Rokok' : 'Vape'}: data belum cukup '
                  'untuk dibandingkan (perlu Week 2 selesai, ≥ 4 hari '
                  'tercatat).'
            : '${product == 'rokok' ? 'Rokok' : 'Vape'}: $down dari '
                  '$compared peserta turun ≥ 20% sejak Week 1'
                  '${m == null ? '' : ' (median ${m > 0 ? '+' : ''}${m.round()}%)'}.',
      );
      // Habit Swap results of the completed weeks, pooled.
      var skipped = 0, used = 0;
      for (final p in summary.people) {
        for (final w in p.weeks.where((w) => w.complete)) {
          final r = w.swapResult(product);
          skipped += r.skipped;
          used += r.used;
        }
      }
      if (skipped + used > 0) {
        lines.add(
          'Habit Swap: ${(skipped / (skipped + used) * 100).round()}% momen '
          'tidak jadi ${product == 'rokok' ? 'merokok' : 'vape'} '
          '($skipped dari ${skipped + used} momen yang hasilnya dipilih).',
        );
      }
    } else if (done.isNotEmpty) {
      final a = done.first, b = done.last;
      final x = missions.cells[a].value, y = missions.cells[b].value;
      if (x != null && y != null) {
        lines.add(
          a == b
              ? 'Misi inti selesai ${x.round()}%.'
              : 'Misi inti selesai ${x.round()}% ke ${y.round()}%.',
        );
      }
    }
    if (summary.adminItems > 0) {
      lines.add(
        '${summary.adminItems} isian dipulihkan admin '
        '(${summary.adminPeople} peserta).',
      );
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final reportPicker = SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: false, label: Text('Ringkasan studi')),
        ButtonSegment(value: true, label: Text('Analisis periode')),
      ],
      selected: {_byPeriod},
      onSelectionChanged: (value) => setState(() => _byPeriod = value.single),
    );
    if (_byPeriod) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          reportPicker,
          const SizedBox(height: 16),
          StudyPeriodView(
            people: widget.people,
            now: widget.now,
            onDownload: widget.onDownload,
          ),
        ],
      );
    }
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
    final group = _of(people, _group).isEmpty ? 'all' : _group;
    final shown = _of(people, group);
    final products = _products(group);
    final product = products.length == 1 ? products.single : null;
    final reduction = shown.where((p) => p.reduction).toList();
    final outcomes = usageOutcomes(reduction, products: products);
    final rows = weekReport(shown, products: products);
    final summary = StudySummary(shown);
    final conclusions = _conclusions(rows, outcomes, group, summary);
    WeekRow row(String label) => rows.firstWhere((r) => r.label == label);
    final daysRow = row('Rata-rata hari aktif');
    final missionRow = row('Misi inti selesai');
    final usageRow = product == null
        ? null
        : rows
              .where((r) => r.label == 'Rata-rata $product per hari tercatat')
              .firstOrNull;
    final last = [
      for (var w = 0; w < 4; w++)
        if (daysRow.cells[w].value != null) w,
    ].lastOrNull;
    final m = median([
      for (final o in outcomes)
        if (o.change?.percent case final p?) p * 100,
    ]);
    final detail =
        shown.where((p) => p.code == _detail).firstOrNull ?? shown.first;
    final usage =
        reduction.where((p) => p.code == _usageParticipant).firstOrNull ??
        reduction.firstOrNull;
    final suffix = group == 'all' ? '' : '-$group';
    final unit = product == 'vape' ? 'sesi' : 'batang';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        reportPicker,
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final MapEntry(:key, :value) in _groups.entries)
              ChoiceChip(
                label: Text('$value (${_of(people, key).length})'),
                selected: group == key,
                showCheckmark: false,
                onSelected: _of(people, key).isEmpty
                    ? null
                    : (_) => setState(() {
                        _group = key;
                        _usageParticipant = null;
                        _detail = null;
                      }),
              ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: _slideText(conclusions, rows, group)),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(content: Text('Disalin untuk slide.')),
                  );
              },
              icon: const Icon(Icons.content_copy_rounded, size: 18),
              label: const Text('Salin untuk slide'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 760 ? 4 : 2;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            Widget tile(String value, String label, String note) => SizedBox(
              width: width,
              child: _Tile(value, label, note: note),
            );
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                tile('${shown.length}', 'Peserta', _groups[group]!),
                tile(
                  last == null
                      ? '–'
                      : '${row('Peserta aktif (≥ 1 hari)').cells[last].value!.round()}'
                            ' dari ${daysRow.cells[last].n}',
                  'Peserta aktif',
                  last == null ? 'belum ada week selesai' : 'Week ${last + 1}',
                ),
                tile(
                  last == null
                      ? '–'
                      : '${_number(daysRow.cells[last].value!)} / 7',
                  'Hari aktif rata-rata',
                  last == null ? '' : 'Week ${last + 1}',
                ),
                if (product == null)
                  tile(
                    last == null || missionRow.cells[last].value == null
                        ? '–'
                        : '${missionRow.cells[last].value!.round()}%',
                    'Misi inti selesai',
                    last == null ? '' : 'Week ${last + 1}',
                  )
                else
                  tile(
                    m == null ? '–' : '${m > 0 ? '+' : ''}${m.round()}%',
                    'Perubahan $product',
                    'median, Week 1 ke week terakhir',
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        _Section(
          title: 'Kesimpulan',
          child: _Highlights(lines: conclusions),
        ),
        _Section(
          title: 'Keaktifan per week',
          subtitle:
              'Cara baca: rata-rata hari peserta memakai aplikasi (dari 7). '
              'Makin tinggi, makin rutin.',
          child: _WeekRowChart(row: daysRow),
        ),
        if (usageRow != null)
          _Section(
            title:
                '${product == 'rokok' ? 'Rokok' : 'Vape'} per hari, per week',
            subtitle:
                'Cara baca: rata-rata $unit per hari yang dicatat. Turun = '
                'pemakaian berkurang selama ikut YouWELL (laporan peserta, '
                'bukan bukti efektivitas).',
            child: _WeekRowChart(row: usageRow),
          )
        else
          _Section(
            title: 'Misi inti selesai per week',
            subtitle:
                'Cara baca: persentase misi harian yang diselesaikan. Turun '
                'bisa berarti misi terlalu berat atau peserta mulai jarang.',
            child: _WeekRowChart(row: missionRow),
          ),
        _Section(
          title: 'Per peserta',
          subtitle: 'Hari aktif per week (dari 7). * = week belum selesai.',
          child: _SimpleTable(people: shown, product: product),
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          expandedAlignment: Alignment.centerLeft,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: const Text(
            'Data lengkap',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: const Text('Tabel semua metrik, detail harian, unduhan'),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => widget.onDownload(
                    'youwell-ringkasan-week$suffix.csv',
                    toCsv(weekReportCsvColumns, weekReportCsvRows(rows)),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Unduh tabel week (CSV)'),
                ),
                OutlinedButton.icon(
                  onPressed: () => widget.onDownload(
                    'youwell-dashboard-studi.csv',
                    toCsv(dashboardCsvColumns, dashboardCsvRows(people)),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Unduh data per peserta (CSV)'),
                ),
                TextButton.icon(
                  onPressed: () => _showDataInfo(context),
                  icon: const Icon(Icons.info_outline_rounded, size: 18),
                  label: const Text('Tentang data'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Semua metrik per week',
              child: _WeekTable(rows: rows),
            ),
            if (product != null)
              _Section(
                title: product == 'rokok'
                    ? 'Seluruh perokok'
                    : 'Seluruh pengguna vape',
                child: _GroupUsage(
                  people: reduction,
                  type: product,
                  outcomes: outcomes,
                ),
              ),
            if (reduction.isNotEmpty)
              _Section(
                title: 'Perubahan konsumsi per peserta',
                child: _UsageOutcomes(
                  outcomes: outcomes,
                  fileSuffix: suffix,
                  onDownload: widget.onDownload,
                ),
              ),
            if (usage != null && usage.types.any(products.contains))
              _Section(
                title: 'Grafik harian satu peserta',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButton<String>(
                      value: usage.code,
                      items: [
                        for (final p in reduction)
                          DropdownMenuItem(value: p.code, child: Text(p.code)),
                      ],
                      onChanged: (value) =>
                          setState(() => _usageParticipant = value),
                    ),
                    for (final type in usage.types)
                      if (products.contains(type))
                        _UsageBlock(participant: usage, type: type),
                  ],
                ),
              ),
            _Section(
              title: 'Detail harian',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in shown)
                        ChoiceChip(
                          label: Text(p.code),
                          selected: p == detail,
                          onSelected: (_) => setState(() => _detail = p.code),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _DetailTable(participant: detail),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One row per participant: active days per week and, for one product,
/// the change since Week 1.
class _SimpleTable extends StatelessWidget {
  const _SimpleTable({required this.people, this.product});
  final List<StudyParticipant> people;
  final String? product;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      headingTextStyle: const TextStyle(fontWeight: FontWeight.w900),
      columnSpacing: 32,
      columns: [
        const DataColumn(label: Text('Kode')),
        for (var w = 1; w <= 4; w++)
          DataColumn(label: Text('Week $w'), numeric: true),
        DataColumn(
          label: Text(product == null ? 'Misi inti' : 'Perubahan $product'),
        ),
        if (product != null)
          const DataColumn(label: Text('Habit Swap tidak jadi')),
      ],
      rows: [
        for (final p in people)
          DataRow(
            cells: [
              DataCell(Text(p.code)),
              for (var w = 0; w < 4; w++)
                DataCell(
                  Text(
                    w >= p.weeks.length
                        ? '–'
                        : '${p.weeks[w].activeDays}'
                              '${p.weeks[w].complete ? '' : '*'}',
                  ),
                ),
              DataCell(
                Text(() {
                  if (product == null) {
                    final done = p.weeks.fold(0, (s, w) => s + w.coreDone);
                    final total = p.weeks.fold(0, (s, w) => s + w.coreTotal);
                    return total == 0
                        ? '–'
                        : '${(done / total * 100).round()}%';
                  }
                  final o = UsageOutcome(p, product!);
                  final percent = o.change?.percent;
                  return o.change == null
                      ? 'belum cukup data'
                      : percent == null
                      ? 'dari 0'
                      : '${percent > 0 ? '+' : ''}${(percent * 100).round()}%';
                }()),
              ),
              if (product != null)
                DataCell(
                  Text(() {
                    var skipped = 0, used = 0;
                    for (final w in p.weeks) {
                      final r = w.swapResult(product!);
                      skipped += r.skipped;
                      used += r.used;
                    }
                    return skipped + used == 0
                        ? '–'
                        : '$skipped dari ${skipped + used} momen';
                  }()),
                ),
            ],
          ),
      ],
    ),
  );
}

void _showDataInfo(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Tentang data'),
    content: const SingleChildScrollView(
      child: Text(
        'Log 28 hari mendukung evaluasi penerimaan dan pengalaman penggunaan YouWELL. '
        'Skor kuesioner, hasil UAT, dan wawancara berasal dari instrumen penelitian terpisah.\n\n'
        'Koreksi admin memulihkan catatan peserta dan selalu masuk dalam grafik serta CSV. '
        'Riwayat koreksi tersedia pada detail peserta.\n\n'
        'Week = 7 hari sejak peserta mulai (Week 1 = hari 1–7), bukan minggu kalender. '
        'Angka kelompok memakai week yang sudah selesai; n = jumlah peserta. Tanda * '
        'berarti week itu masih berjalan. '
        'Perbandingan konsumsi memerlukan minimal 4 hari tercatat pada kedua week. '
        'Hari kosong tidak dianggap nol; rokok dan vape memakai satuan terpisah.\n\n'
        'Target tercapai berarti misinya selesai. Target istirahat adalah misi tidur '
        '(23 Okt–4 Nov) lalu Hibernasi (mulai 5 Nov). Foto makan disetujui bukan '
        'penilaian gizi. '
        'Grafik konsumsi menunjukkan perubahan selama pemakaian.\n\n'
        'Penanda grafik: 23 Okt, aturan tidur dan foto makan berubah; '
        '27 Okt, total rokok/vape mulai tersinkron; 5 Nov, misi Istirahat '
        'menjadi Hibernasi.',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Tutup'),
      ),
    ],
  ),
);

String _number(num value, {int digits = 1}) => value is int
    ? '$value'
    : value.toStringAsFixed(digits).replaceAll('.', ',');

String _sync(DateTime? time) {
  if (time == null) return 'belum';
  final t = time.toLocal();
  return '${t.day}/${t.month} ${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}

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
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
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
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

/// Key findings, one sentence each.
class _Highlights extends StatelessWidget {
  const _Highlights({required this.lines});
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 10),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: c.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      line,
                      style: TextStyle(color: c.text, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Metric × Week 1–4 with n under each number; group names as row headers.
class _WeekTable extends StatelessWidget {
  const _WeekTable({required this.rows});
  final List<WeekRow> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    String? lastGroup;
    final tableRows = <DataRow>[];
    for (final row in rows) {
      if (row.group != lastGroup) {
        lastGroup = row.group;
        tableRows.add(
          DataRow(
            color: WidgetStatePropertyAll(c.raised),
            cells: [
              DataCell(
                Text(
                  row.group,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              for (var w = 0; w < 4; w++) const DataCell(SizedBox.shrink()),
            ],
          ),
        );
      }
      tableRows.add(
        DataRow(
          cells: [
            DataCell(
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.label),
                    if (row.note != null)
                      Text(
                        row.note!,
                        style: TextStyle(color: c.muted, fontSize: 11.5),
                      ),
                  ],
                ),
              ),
            ),
            for (final cell in row.cells)
              DataCell(
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatWeekValue(row, cell),
                      style: TextStyle(
                        color: cell.value == null ? c.muted : c.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (cell.n > 0 || cell.running > 0)
                      Text(
                        [
                          if (cell.n > 0 && !row.count) 'n=${cell.n}',
                          if (cell.running > 0) '${cell.running} berjalan',
                        ].join(' · '),
                        style: TextStyle(color: c.muted, fontSize: 11.5),
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: const TextStyle(fontWeight: FontWeight.w900),
        headingRowHeight: 64,
        dataRowMinHeight: 44,
        // Long metric names wrap; rows grow with them.
        dataRowMaxHeight: double.infinity,
        columnSpacing: 36,
        columns: [
          const DataColumn(label: Text('Metrik')),
          for (var w = 1; w <= 4; w++)
            DataColumn(
              label: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Week $w'),
                  Text(
                    'hari ${(w - 1) * 7 + 1}–${w * 7}',
                    style: TextStyle(
                      color: c.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
        rows: tableRows,
      ),
    );
  }
}

/// One week-table row as bars; a week nobody finished reads "berjalan".
class _WeekRowChart extends StatelessWidget {
  const _WeekRowChart({required this.row});
  final WeekRow row;

  @override
  Widget build(BuildContext context) {
    final cells = row.cells;
    final num? scale = row.count
        ? cells.fold<int>(1, (top, c) => c.n > top ? c.n : top)
        : row.unit == '%'
        ? 100
        : row.unit == ' dari 7 hari'
        ? 7
        : null;
    return _WeeklyBars(
      color: context.colors.accent,
      max: scale,
      unit: row.count ? '' : row.unit.replaceFirst(' dari 7 hari', ' hari'),
      points: [
        for (final (i, cell) in cells.indexed)
          (
            label: 'Week ${i + 1}',
            value: row.count ? cell.value?.round() : cell.value,
            detail: [
              if (row.count) 'dari ${cell.n} peserta' else 'n=${cell.n}',
              if (cell.running > 0) '${cell.running} berjalan',
            ].join(' · '),
            running: cell.value == null && cell.running > 0,
          ),
      ],
    );
  }
}

/// Everyone who logs one product: paired Week 1 vs comparison week, the
/// median change, zero days, and the group's mean per study day.
class _GroupUsage extends StatelessWidget {
  const _GroupUsage({
    required this.people,
    required this.type,
    required this.outcomes,
  });
  final List<StudyParticipant> people;
  final String type;
  final List<UsageOutcome> outcomes;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final unit = type == 'rokok' ? 'batang' : 'sesi';
    final color = type == 'rokok' ? c.reduction : c.cyan;
    final paired = pairedUsage(outcomes);
    final m = median([
      for (final o in outcomes)
        if (o.change?.percent case final p?) p * 100,
    ]);
    final daily = groupDailyUsage(people, type);
    final logged = people.fold(
      0,
      (sum, p) => sum + p.days.where((d) => d.usage.containsKey(type)).length,
    );
    final zero = people.fold(
      0,
      (sum, p) => sum + p.days.where((d) => d.usage[type] == 0).length,
    );
    final top = daily.fold<double>(
      1,
      (t, d) => (d.mean ?? 0) > t ? d.mean! : t,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _CountChip(
              text: '${people.length}',
              label: 'Peserta yang mencatat',
            ),
            _CountChip(
              text: paired.first == null
                  ? '–'
                  : '${_number(paired.first!)} ke ${_number(paired.last!)}',
              label: paired.n == 0
                  ? '$unit/hari, Week 1 ke pembanding'
                  : '$unit/hari, Week 1 ke pembanding (${paired.n} peserta sama)',
            ),
            _CountChip(
              text: m == null ? '–' : '${m > 0 ? '+' : ''}${m.round()}%',
              label: 'Median perubahan',
            ),
            _CountChip(
              text: '$zero dari $logged',
              label: 'Hari tercatat dengan total 0',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Rata-rata $unit per hari studi (semua peserta yang mencatat)',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final d in daily)
                Tooltip(
                  message: d.mean == null
                      ? 'Hari ${d.day}: belum ada catatan'
                      : 'Hari ${d.day}: rata-rata ${_number(d.mean!)} $unit '
                            '(${d.n} peserta mencatat)',
                  child: SizedBox(
                    width: 26,
                    height: 150,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (d.mean != null)
                          Container(
                            width: 16,
                            height: d.mean == 0 ? 2 : 110 * d.mean! / top,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: c.muted,
                              shape: BoxShape.circle,
                            ),
                          ),
                        SizedBox(
                          height: 20,
                          child: Text(
                            d.day == 1 || d.day % 7 == 0 ? '${d.day}' : '',
                            style: TextStyle(color: c.muted, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Text(
          'Sumbu bawah = hari studi tiap peserta (hari 1 = hari pertamanya). '
          'Arahkan kursor ke batang untuk melihat n.',
          style: TextStyle(color: c.muted, fontSize: 12.5),
        ),
      ],
    );
  }
}

/// Change categories per product, the median change, and one row per
/// participant and product.
class _UsageOutcomes extends StatelessWidget {
  const _UsageOutcomes({
    required this.outcomes,
    required this.onDownload,
    this.fileSuffix = '',
  });
  final List<UsageOutcome> outcomes;
  final String fileSuffix;
  final void Function(String name, String csv) onDownload;

  static String _week(UsageWeek? week, int zeroDays, String unit) =>
      week?.mean == null
      ? '–'
      : '${_number(week!.mean!)} $unit/hari · ${week.loggedDays} hari'
            '${zeroDays > 0 ? ' · $zeroDays hari nol' : ''}';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (outcomes.isEmpty) {
      return Text(
        'Belum ada total rokok/vape yang dicatat.',
        style: TextStyle(color: c.muted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (type, label) in const [
          ('rokok', 'Rokok'),
          ('vape', 'Vape'),
        ])
          if (outcomes.where((o) => o.type == type).toList() case final list
              when list.isNotEmpty) ...[
            Text(
              '$label (${list.length} peserta)',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final category in usageCategories)
                  _CountChip(
                    count: list.where((o) => o.category == category).length,
                    label: category,
                  ),
                () {
                  final m = median([
                    for (final o in list)
                      if (o.change?.percent case final p?) p * 100,
                  ]);
                  return _CountChip(
                    text: m == null ? '–' : '${m > 0 ? '+' : ''}${m.round()}%',
                    label: 'Median perubahan',
                  );
                }(),
              ],
            ),
            const SizedBox(height: 16),
          ],
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingTextStyle: const TextStyle(fontWeight: FontWeight.w900),
            columnSpacing: 24,
            columns: const [
              DataColumn(label: Text('Kode')),
              DataColumn(label: Text('Produk')),
              DataColumn(label: Text('Week 1')),
              DataColumn(label: Text('Pembanding')),
              DataColumn(label: Text('Perubahan')),
              DataColumn(label: Text('Kategori')),
              DataColumn(label: Text('Tren harian')),
            ],
            rows: [
              for (final o in outcomes)
                DataRow(
                  cells: [
                    DataCell(Text(o.participant.code)),
                    DataCell(Text(o.type == 'rokok' ? 'Rokok' : 'Vape')),
                    DataCell(Text(_week(o.first, o.firstZeroDays, o.unit))),
                    DataCell(
                      Text(
                        o.lastWeek == null
                            ? '–'
                            : 'Week ${o.lastWeek}: '
                                  '${_week(o.last, o.lastZeroDays, o.unit)}',
                      ),
                    ),
                    DataCell(
                      Text(
                        o.change == null
                            ? '–'
                            : _UsageBlock._changeText(
                                o.lastWeek! - 1,
                                o.first!,
                                o.last!,
                              ),
                      ),
                    ),
                    DataCell(
                      Text(
                        o.category,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    DataCell(
                      Text(
                        o.slopePerWeek == null
                            ? 'perlu ≥ 8 hari tercatat'
                            : '${o.slopePerWeek! > 0 ? '+' : ''}'
                                  '${_number(o.slopePerWeek!)} ${o.unit}/hari '
                                  'per week (${o.loggedDays} hari)',
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Kategori: turun ≥ 50%, turun 20–49%, stabil dalam ±20%, naik lebih '
          'dari 20%. Hari nol = total 0 yang dikonfirmasi peserta. Tren '
          'harian = kemiringan garis dari semua hari tercatat.',
          style: TextStyle(color: c.muted, fontSize: 12.5),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => onDownload(
            'youwell-perubahan-konsumsi$fileSuffix.csv',
            toCsv(usageOutcomeCsvColumns, usageOutcomeCsvRows(outcomes)),
          ),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Unduh perubahan konsumsi (CSV)'),
        ),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, this.count, this.text});
  final String label;
  final int? count;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text ?? '${count ?? 0}',
            style: TextStyle(
              color: c.text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(label, style: TextStyle(color: c.muted, fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.value, this.label, {this.note});
  final String value, label;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: 134),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: c.text,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(label, style: TextStyle(color: c.text)),
          if (note != null)
            Text(note!, style: TextStyle(color: c.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

typedef _WeekPoint = ({String label, num? value, String detail, bool running});

/// Four comparable weekly values. Empty weeks have no bar; explicit zeroes
/// retain a baseline mark. Counts and coverage stay next to the graphic.
class _WeeklyBars extends StatelessWidget {
  const _WeeklyBars({
    required this.points,
    required this.color,
    this.max,
    this.unit = '',
  });
  final List<_WeekPoint> points;
  final Color color;
  final num? max;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final scale =
        max ??
        points.fold<num>(1, (top, p) => (p.value ?? 0) > top ? p.value! : top);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final p in points)
            Expanded(
              child: Tooltip(
                message:
                    '${p.label}: ${p.value == null ? 'belum ada data' : '${_number(p.value!)}$unit'} · ${p.detail}${p.running ? ' · sementara' : ''}',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      p.value == null
                          ? (p.running ? 'berjalan' : '–')
                          : '${_number(p.value!)}$unit${p.running ? '*' : ''}',
                      style: TextStyle(
                        color: c.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 112,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: 34,
                          height: p.value == null
                              ? 0
                              : p.value == 0
                              ? 2
                              : 112 *
                                    (p.value! / (scale == 0 ? 1 : scale)).clamp(
                                      0,
                                      1,
                                    ),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      p.label,
                      style: TextStyle(
                        color: c.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      p.detail,
                      style: TextStyle(color: c.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One product of one participant: daily bars for days 1–28 (an empty day
/// is a dot, never a zero bar), measurement-change markers, and the weekly
/// means with their logged days.
class _UsageBlock extends StatelessWidget {
  const _UsageBlock({required this.participant, required this.type});
  final StudyParticipant participant;
  final String type;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = participant;
    final unit = type == 'rokok' ? 'batang' : 'sesi';
    final color = type == 'rokok' ? c.reduction : c.cyan;
    final weeks = [for (final w in p.weeks) w.usage(type)];
    final first = weeks.firstOrNull;
    final last = weeks.length > 1 ? weeks.last : null;
    final change = first != null && last != null
        ? usageChange(first, last)
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${p.code} · ${type == 'rokok' ? 'Rokok (batang/hari)' : 'Vape (sesi/hari)'}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          _DailyBars(days: p.days, type: type, color: color, unit: unit),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _Key(color: color, label: 'total tercatat'),
              _Key(color: c.muted, label: 'tidak dicatat', dot: true),
              _Key(color: c.text, label: 'perubahan cara ukur', line: true),
            ],
          ),
          const SizedBox(height: 12),
          _WeeklyBars(
            color: color,
            unit: '',
            points: [
              for (final (i, u) in weeks.indexed)
                (
                  label: 'Week ${i + 1}',
                  value: u.mean,
                  detail: '${u.loggedDays}/${p.weeks[i].days.length} hari',
                  running: !p.weeks[i].complete,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Rata-rata $unit/hari tercatat',
            style: TextStyle(color: c.muted, fontSize: 12),
          ),
          if (change != null) ...[
            const SizedBox(height: 8),
            Text(
              '${_number(first!.mean!)} ke ${_number(last!.mean!)} $unit/hari · '
              '${_changeText(weeks.length - 1, first, last)}'
              '${p.weeks.last.complete ? '' : ' (sementara, Week ${p.weeks.length} masih berjalan)'}',
              style: TextStyle(color: c.text, fontWeight: FontWeight.w800),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Habit Swap: ${[for (final w in p.weeks) 'M${w.week} ${w.swaps}×'].join(' · ')}',
            style: TextStyle(color: c.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  static String _changeText(int index, UsageWeek first, UsageWeek week) {
    if (index == 0) return 'acuan';
    final change = usageChange(first, week);
    if (change == null) return 'Data belum cukup';
    final diff = change.difference;
    final sign = diff > 0 ? '+' : '';
    final percent = change.percent;
    return percent == null
        ? 'selisih $sign${_number(diff)}'
        : '$sign${_number(diff)} ($sign${(percent * 100).round()}%)';
  }
}

class _DailyBars extends StatelessWidget {
  const _DailyBars({
    required this.days,
    required this.type,
    required this.color,
    required this.unit,
  });
  final List<StudyDay> days;
  final String type, unit;
  final Color color;

  static const _height = 120.0, _slot = 22.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final values = [for (final d in days) ?d.usage[type]];
    final top = values.isEmpty ? 1 : values.reduce((a, b) => a > b ? a : b);
    final scale = top == 0 ? 1 : top;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            height: _height + 20,
            width: 32,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$top', style: TextStyle(color: c.muted, fontSize: 11)),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    '0',
                    style: TextStyle(color: c.muted, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          for (var i = 0; i < studyDays; i++)
            _bar(context, i < days.length ? days[i] : null, i + 1, scale),
        ],
      ),
    );
  }

  Widget _bar(BuildContext context, StudyDay? day, int number, num scale) {
    final c = context.colors;
    final value = day?.usage[type];
    final byAdmin = day?.usageByAdmin.contains(type) ?? false;
    final note = day?.measurementNote;
    final message = day == null
        ? 'Hari $number: belum berjalan'
        : [
            'Hari $number (${day.day})',
            value == null
                ? 'tidak dicatat'
                : '$value $unit${byAdmin ? ' · koreksi admin' : ''}',
            ?note,
          ].join('\n');
    return Tooltip(
      message: message,
      child: SizedBox(
        width: _slot,
        height: _height + 20,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              height: _height,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  if (note != null)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 1.5, color: c.text),
                    ),
                  if (value != null)
                    Container(
                      width: 14,
                      height: value == 0 ? 2 : _height * value / scale,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    )
                  else if (day != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 1),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: c.muted,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 20,
              child: Text(
                number == 1 || number % 7 == 0 ? '$number' : '',
                style: TextStyle(color: c.muted, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.color,
    required this.label,
    this.dot = false,
    this.line = false,
  });
  final Color color;
  final String label;
  final bool dot, line;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: line ? 2 : (dot ? 6 : 12),
        height: line ? 14 : (dot ? 6 : 12),
        decoration: BoxDecoration(
          color: color,
          shape: dot ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: dot || line ? null : BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: context.colors.text, fontSize: 12.5)),
    ],
  );
}

/// The 28-day timeline of one participant with its data-quality flags.
class _DetailTable extends StatelessWidget {
  const _DetailTable({required this.participant});
  final StudyParticipant participant;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = participant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 6,
          children: [
            Text('Jalur studi: ${p.reduction ? 'rokok/vape' : 'wellness'}'),
            Text('Mulai: ${p.started}'),
            Text('Sinkron: ${_sync(p.lastSync)}'),
            Text('Koreksi admin: ${p.adminItems}'),
            Text('Hari berisi data: ${p.daysWithData}/${p.elapsed}'),
          ],
        ),
        if (!p.groupLocked || p.pathChanged)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: c.amber),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    p.pathChanged
                        ? 'Jalur di profil sekarang berbeda dari jalur saat '
                              'kode diberikan; dashboard memakai jalur saat '
                              'kode diberikan.'
                        : 'Jalur studi belum terkunci (kode diberikan sebelum '
                              'tahap 11); dashboard memakai jalur profil saat ini.',
                    style: TextStyle(color: c.amber),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingTextStyle: const TextStyle(fontWeight: FontWeight.w900),
            columns: const [
              DataColumn(label: Text('Hari')),
              DataColumn(label: Text('Tanggal')),
              DataColumn(label: Text('Dibuka')),
              DataColumn(label: Text('Misi inti')),
              DataColumn(label: Text('Target tercapai')),
              DataColumn(label: Text('Rokok')),
              DataColumn(label: Text('Vape')),
              DataColumn(label: Text('Habit Swap')),
              DataColumn(label: Text('Catatan')),
            ],
            rows: [
              for (final d in p.days)
                DataRow(
                  color: d.hasData
                      ? null
                      : WidgetStatePropertyAll(c.raised.withValues(alpha: .6)),
                  cells: [
                    DataCell(Text('${d.number}')),
                    DataCell(Text(d.day)),
                    DataCell(Text(d.opened ? 'ya' : '–')),
                    DataCell(
                      Text(
                        d.coreTotal == 0 ? '–' : '${d.coreDone}/${d.coreTotal}',
                      ),
                    ),
                    DataCell(
                      Text(
                        d.targets.isEmpty
                            ? '–'
                            : [
                                for (final MapEntry(:key, :value)
                                    in targetCategories.entries)
                                  if (d.targets.contains(key)) value,
                              ].join(', '),
                      ),
                    ),
                    for (final type in usageTypes)
                      DataCell(
                        Text(d.usage[type] == null ? '–' : '${d.usage[type]}'),
                      ),
                    DataCell(
                      Text(() {
                        var tried = d.swaps, skipped = 0, used = 0;
                        for (final r in d.swapResults.values) {
                          skipped += r.skipped;
                          used += r.used;
                        }
                        final fromResults = d.swapResults.values.fold(
                          0,
                          (sum, r) => sum + r.tried,
                        );
                        if (fromResults > tried) tried = fromResults;
                        if (tried == 0) return '–';
                        return [
                          '$tried dicoba',
                          if (skipped + used > 0)
                            '$skipped tidak jadi · $used tetap',
                          if (d.swapResultsByAdmin.isNotEmpty) '(admin)',
                        ].join(' · ');
                      }()),
                    ),
                    DataCell(
                      Text(
                        [
                          if (!d.hasData) 'tanpa data',
                          if (d.adminItems > 0)
                            'koreksi admin: ${d.adminItems}',
                          ?d.measurementNote,
                        ].join(' · '),
                        style: TextStyle(color: c.muted),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
