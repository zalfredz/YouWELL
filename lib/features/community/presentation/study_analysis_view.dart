import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youwell/application/research_overview.dart';
import 'package:youwell/application/study_dashboard.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/progress/domain/research_store.dart';

/// "Analisis studi" in the researcher dashboard, laid out as a week report
/// for checkpoint presentations: key findings, a metric × Week 1–4 table
/// with n, a chart per metric, progress per participant, smoking/vaping per
/// participant and the daily detail (brief of 4 Nov 2026, weeks 6 Nov).
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

/// Which participants the week table, chart and progress table show.
const _groups = {
  'all': 'Semua',
  'wellness': 'Wellness',
  'reduction': 'Rokok/vape',
};

class _StudyAnalysisViewState extends State<StudyAnalysisView> {
  String _group = 'all';
  int _chartRow = 0;
  String? _detail, _usageParticipant;

  List<StudyParticipant> _of(List<StudyParticipant> people, String group) =>
      switch (group) {
        'wellness' => people.where((p) => !p.reduction).toList(),
        'reduction' => people.where((p) => p.reduction).toList(),
        _ => people,
      };

  /// Highlights and the week table as plain text for slides.
  String _slideText(
    List<String> highlights,
    List<WeekRow> rows,
    String group,
  ) => [
    'Temuan utama YouWELL',
    for (final line in highlights) '- $line',
    '',
    'Ringkasan per week (${_groups[group]}; n = peserta dengan week selesai)',
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
    'Week = 7 hari sejak peserta mulai (Week 1 = hari 1–7). Angka '
        'keterlibatan dan laporan peserta, bukan ukuran kesehatan atau '
        'perbandingan sebelum–sesudah.',
  ].join('\n');

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
    final summary = StudySummary(people);
    final reduction = people.where((p) => p.reduction).toList();
    final group = _of(people, _group).isEmpty ? 'all' : _group;
    final shown = _of(people, group);
    final rows = weekReport(shown);
    final chartRow = rows[_chartRow.clamp(0, rows.length - 1)];
    final highlights = weekHighlights(people, widget.now);
    final detail =
        people.where((p) => p.code == _detail).firstOrNull ?? people.first;
    final usage =
        reduction.where((p) => p.code == _usageParticipant).firstOrNull ??
        reduction.firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: _slideText(highlights, rows, group)),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Temuan dan tabel week disalin. Tempel ke slide atau '
                        'dokumen.',
                      ),
                    ),
                  );
              },
              icon: const Icon(Icons.content_copy_rounded, size: 18),
              label: const Text('Salin untuk slide'),
            ),
            OutlinedButton.icon(
              onPressed: () => widget.onDownload(
                'youwell-ringkasan-week.csv',
                toCsv(
                  weekReportCsvColumns,
                  weekReportCsvRows(weekReport(people)),
                ),
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
        const SizedBox(height: 10),
        Text(
          'Week = 7 hari sejak peserta mulai (Week 1 = hari 1–7, Week 2 = '
          'hari 8–14), bukan minggu kalender. Angka kelompok hanya memakai '
          'week yang sudah selesai; n = jumlah peserta di balik angka itu.',
          style: TextStyle(color: c.muted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        _SummaryTiles(summary: summary),
        const SizedBox(height: 24),
        _Section(
          title: 'Temuan utama',
          subtitle: 'Disusun otomatis dari tabel di bawah.',
          child: _Highlights(lines: highlights),
        ),
        _Section(
          title: 'Ringkasan per week',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final MapEntry(:key, :value) in _groups.entries)
                    ChoiceChip(
                      label: Text('$value (${_of(people, key).length})'),
                      selected: group == key,
                      showCheckmark: false,
                      onSelected: _of(people, key).isEmpty
                          ? null
                          : (_) => setState(() => _group = key),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _WeekTable(rows: rows),
            ],
          ),
        ),
        _Section(
          title: 'Grafik per week',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButton<int>(
                isExpanded: true,
                value: rows.indexOf(chartRow),
                items: [
                  for (final (i, row) in rows.indexed)
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                        '${row.group}: ${row.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _chartRow = value!),
              ),
              const SizedBox(height: 12),
              _WeekRowChart(row: chartRow),
            ],
          ),
        ),
        _Section(
          title: 'Progres per peserta',
          subtitle:
              'Hari aktif per week (dari 7 hari). * = week masih berjalan.',
          child: _ProgressTable(people: shown),
        ),
        if (reduction.isNotEmpty)
          _Section(
            title: 'Rokok/vape per peserta',
            subtitle:
                'Rata-rata per hari yang dicatat, dengan cakupan hari. '
                'Perbandingan hanya bila Week 1 dan week pembanding punya '
                'minimal 4 hari tercatat. Rokok (batang) dan vape (sesi) '
                'tidak dijumlah.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _UsageTable(people: reduction),
                if (usage != null)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    expandedAlignment: Alignment.centerLeft,
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    title: const Text('Grafik harian per peserta'),
                    children: [
                      DropdownButton<String>(
                        value: usage.code,
                        items: [
                          for (final p in reduction)
                            DropdownMenuItem(
                              value: p.code,
                              child: Text(p.code),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _usageParticipant = value),
                      ),
                      const SizedBox(height: 12),
                      if (usage.types.isEmpty)
                        Text(
                          'Belum ada konsumsi yang dicatat.',
                          style: TextStyle(color: c.muted),
                        )
                      else
                        for (final type in usage.types)
                          _UsageBlock(participant: usage, type: type),
                    ],
                  ),
              ],
            ),
          ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          expandedAlignment: Alignment.centerLeft,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: const Text('Detail harian peserta'),
          subtitle: Text('${people.length} peserta · catatan 28 hari'),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in people)
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
      ],
    );
  }
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

class _SummaryTiles extends StatelessWidget {
  const _SummaryTiles({required this.summary});
  final StudySummary summary;

  @override
  Widget build(BuildContext context) {
    final four = summary.weekFour;
    final people = summary.people;
    final wellness = people.where((p) => !p.reduction).length;
    int finished(int week) => people
        .where((p) => p.weeks.length >= week && p.weeks[week - 1].complete)
        .length;
    final completeness = summary.completeness;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 4
            : constraints.maxWidth >= 300
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: width,
              child: _Tile(
                '${people.length}',
                'Peserta studi',
                note:
                    '$wellness wellness · ${people.length - wellness} rokok/vape',
              ),
            ),
            SizedBox(
              width: width,
              child: _Tile(
                '${finished(1)} · ${finished(2)}',
                'Selesai Week 1 · Week 2',
                note: 'sudah melewati 7 dan 14 hari',
              ),
            ),
            SizedBox(
              width: width,
              child: _Tile(
                completeness == null ? '–' : '${(completeness * 100).round()}%',
                'Hari berisi data',
                note: '${summary.adminItems} isian dipulihkan admin',
              ),
            ),
            SizedBox(
              width: width,
              child: _Tile(
                four.reached == 0 ? '–' : '${four.active} dari ${four.reached}',
                'Aktif di Week 4',
                note: four.reached == 0
                    ? 'kriteria ≥ 6 dari 10; belum ada yang sampai'
                    : four.provisional
                    ? 'sementara · kriteria ≥ 6 dari 10'
                    : 'kriteria ≥ 6 dari 10',
                highlight: !four.provisional && four.active >= 6,
              ),
            ),
          ],
        );
      },
    );
  }
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

/// Every smoking/vaping participant and product: mean per logged day per
/// week with its coverage, and the change from Week 1.
class _UsageTable extends StatelessWidget {
  const _UsageTable({required this.people});
  final List<StudyParticipant> people;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rows = [
      for (final p in people)
        for (final type in p.types) (p, type),
    ];
    if (rows.isEmpty) {
      return Text(
        'Belum ada total rokok/vape yang dicatat.',
        style: TextStyle(color: c.muted),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: const TextStyle(fontWeight: FontWeight.w900),
        columnSpacing: 28,
        columns: [
          const DataColumn(label: Text('Kode')),
          const DataColumn(label: Text('Produk')),
          for (var w = 1; w <= 4; w++) DataColumn(label: Text('Week $w')),
          const DataColumn(label: Text('Week 1 ke week terakhir')),
        ],
        rows: [
          for (final (p, type) in rows)
            () {
              final unit = type == 'rokok' ? 'batang' : 'sesi';
              final weeks = [for (final w in p.weeks) w.usage(type)];
              final index = weeks.lastIndexWhere((u) => u.comparable);
              final change = index > 0
                  ? usageChange(weeks.first, weeks[index])
                  : null;
              return DataRow(
                cells: [
                  DataCell(Text(p.code)),
                  DataCell(
                    Text('${type == 'rokok' ? 'Rokok' : 'Vape'} ($unit)'),
                  ),
                  for (var w = 0; w < 4; w++)
                    DataCell(
                      Text(
                        w >= weeks.length
                            ? '–'
                            : weeks[w].mean == null
                            ? 'tidak dicatat'
                            : '${_number(weeks[w].mean!)} · '
                                  '${weeks[w].loggedDays}/${p.weeks[w].days.length} hari'
                                  '${p.weeks[w].complete ? '' : '*'}',
                      ),
                    ),
                  DataCell(
                    Text(
                      change == null
                          ? 'data belum cukup'
                          : 'Week ${index + 1}: '
                                '${_UsageBlock._changeText(index, weeks.first, weeks[index])}'
                                '${p.weeks[index].complete ? '' : ' (sementara)'}',
                    ),
                  ),
                ],
              );
            }(),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.value, this.label, {this.note, this.highlight = false});
  final String value, label;
  final String? note;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: 134),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight ? c.selected : c.surface,
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

/// Every participant on one row: active days per week, missions, level,
/// admin corrections and last sync.
class _ProgressTable extends StatelessWidget {
  const _ProgressTable({required this.people});
  final List<StudyParticipant> people;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      headingTextStyle: const TextStyle(fontWeight: FontWeight.w900),
      columnSpacing: 28,
      columns: [
        const DataColumn(label: Text('Kode')),
        const DataColumn(label: Text('Jalur')),
        const DataColumn(label: Text('Hari ke')),
        for (var w = 1; w <= 4; w++)
          DataColumn(label: Text('Week $w'), numeric: true),
        const DataColumn(label: Text('Misi inti')),
        const DataColumn(label: Text('Level · XP')),
        const DataColumn(label: Text('Koreksi admin'), numeric: true),
        const DataColumn(label: Text('Sinkron')),
      ],
      rows: [
        for (final p in people)
          () {
            final done = p.weeks.fold(0, (sum, w) => sum + w.coreDone);
            final total = p.weeks.fold(0, (sum, w) => sum + w.coreTotal);
            return DataRow(
              cells: [
                DataCell(Text(p.code)),
                DataCell(Text(p.reduction ? 'Rokok/vape' : 'Wellness')),
                DataCell(
                  Text(p.finished ? 'Selesai' : '${p.elapsed} dari $studyDays'),
                ),
                for (var w = 0; w < 4; w++)
                  DataCell(
                    Text(
                      w >= p.weeks.length
                          ? '–'
                          : '${p.weeks[w].activeDays}/${p.weeks[w].days.length}'
                                '${p.weeks[w].complete ? '' : '*'}',
                    ),
                  ),
                DataCell(
                  Text(
                    total == 0
                        ? '–'
                        : '$done/$total (${(done / total * 100).round()}%)',
                  ),
                ),
                DataCell(Text('${p.source.level} · ${p.source.xp}')),
                DataCell(Text('${p.adminItems}')),
                DataCell(Text(_sync(p.lastSync))),
              ],
            );
          }(),
      ],
    ),
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
                    DataCell(Text(d.swaps == 0 ? '–' : '${d.swaps}')),
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
