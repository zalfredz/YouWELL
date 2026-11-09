import 'package:flutter/material.dart';
import 'package:youwell/application/research_overview.dart';
import 'package:youwell/application/study_dashboard.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/progress/domain/research_store.dart';

/// "Analisis studi" in the researcher dashboard: study summary, wellness
/// and smoking/vaping charts, participant detail and data quality, with the
/// interpretation limits written on screen (brief of 4 Nov 2026).
class StudyPeriodView extends StatefulWidget {
  const StudyPeriodView({
    super.key,
    required this.people,
    required this.now,
    required this.onDownload,
  });
  final List<ParticipantOverview> people;
  final DateTime now;
  final void Function(String name, String csv) onDownload;

  @override
  State<StudyPeriodView> createState() => _StudyPeriodViewState();
}

class _Metric {
  const _Metric(this.label, this.value, this.max, {this.unit = ''});
  final String label, unit;
  final num? Function(StudyWeek week) value;

  /// Bar scale; null scales to the largest value shown.
  final num? max;
}

final _wellnessMetrics = [
  _Metric('Hari aktif', (w) => w.activeDays, 7, unit: ' hari'),
  _Metric(
    'Misi inti selesai',
    (w) => w.coreRate == null ? null : (w.coreRate! * 100).round(),
    100,
    unit: '%',
  ),
  for (final MapEntry(:key, :value) in targetCategories.entries)
    _Metric(
      'Target ${value.toLowerCase()}',
      (w) => w.targetDays(key),
      7,
      unit: ' hari',
    ),
  _Metric('Sesi gerak', (w) => w.workouts, null),
  _Metric('Foto makan disetujui', (w) => w.mealApproved, null),
];

/// For every participant, whatever the path: engagement only.
final _allMetrics = [
  _wellnessMetrics[0],
  _wellnessMetrics[1],
  _Metric('Jumlah misi inti selesai', (w) => w.coreDone, null),
];

class _StudyPeriodViewState extends State<StudyPeriodView> {
  int _metric = 0, _allMetric = 0;
  String _path = 'all';
  String? _detail, _usageParticipant;
  StudyPeriod _period = (from: 1, to: 4);

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
    final wellness = people.where((p) => !p.reduction).toList();
    final reduction = people.where((p) => p.reduction).toList();
    final detail =
        people.where((p) => p.code == _detail).firstOrNull ?? people.first;
    final usage =
        reduction.where((p) => p.code == _usageParticipant).firstOrNull ??
        reduction.firstOrNull;
    final path = _path == 'all'
        ? 'all'
        : wellness.isEmpty
        ? 'reduction'
        : reduction.isEmpty
        ? 'wellness'
        : _path;
    final period = _period;
    final weeks = [for (var w = period.from; w <= period.to; w++) w];
    final slug =
        'm${period.from}${period.to == period.from ? '' : '-${period.to}'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // One filter row above everything it scopes.
        Text(
          'Periode analisis',
          style: TextStyle(color: c.muted, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in studyPeriods)
              ChoiceChip(
                label: Text(periodLabel(p)),
                selected: p == period,
                showCheckmark: false,
                onSelected: (_) => setState(() => _period = p),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => widget.onDownload(
                'youwell-ringkasan-$slug.csv',
                toCsv(periodCsvColumns, periodCsvRows(people, period)),
              ),
              icon: const Icon(Icons.table_chart_outlined, size: 18),
              label: const Text('Unduh ringkasan periode'),
            ),
            OutlinedButton.icon(
              onPressed: () => widget.onDownload(
                'youwell-dashboard-studi-$slug.csv',
                toCsv(dashboardCsvColumns, [
                  for (final row in dashboardCsvRows(people))
                    if (weeks.contains(row['week'])) row,
                ]),
              ),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Unduh CSV'),
            ),
            TextButton.icon(
              onPressed: () => _showDataInfo(context),
              icon: const Icon(Icons.info_outline_rounded, size: 18),
              label: const Text('Tentang data'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SummaryTiles(summary: summary, period: period),
        const SizedBox(height: 24),
        _Section(
          title: 'Status kriteria proposal',
          subtitle:
              'Hanya kriteria yang bersumber dari data aplikasi. Kriteria lain '
              'dinilai dari kuesioner, tugas UAT, dan wawancara.',
          child: _CriteriaCard(people: people, period: period),
        ),
        _Section(
          title: 'Keaktifan per minggu',
          subtitle:
              'Persentase peserta yang aktif (membuka aplikasi atau '
              'menyelesaikan minimal 1 aktivitas) per jalur. '
              '* berarti minggu masih berjalan untuk sebagian peserta.',
          // Bars stay close enough to compare on a wide screen.
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 200.0 + 140 * weeks.length),
            child: _PathWeeklyChart(people: people, weeks: weeks),
          ),
        ),
        _Section(
          title: 'Pola harian',
          subtitle:
              'Satu baris per peserta, satu kotak per hari studi. Makin gelap, '
              'makin banyak misi inti yang selesai hari itu.',
          child: _Heatmap(people: people, period: period),
        ),
        _Section(
          title: 'Ringkasan ${periodLabel(period).toLowerCase()} per jalur',
          subtitle:
              'Nilai per peserta dijumlah selama periode, lalu dirangkum. '
              'Hanya peserta yang sudah menyelesaikan seluruh periode yang masuk '
              'rata-rata.',
          child: _PeriodTable(people: people, period: period),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text('Semua (${people.length})'),
              selected: path == 'all',
              showCheckmark: false,
              onSelected: (_) => setState(() => _path = 'all'),
            ),
            ChoiceChip(
              label: Text('Wellness (${wellness.length})'),
              selected: path == 'wellness',
              showCheckmark: false,
              onSelected: wellness.isEmpty
                  ? null
                  : (_) => setState(() => _path = 'wellness'),
            ),
            ChoiceChip(
              label: Text('Rokok/vape (${reduction.length})'),
              selected: path == 'reduction',
              showCheckmark: false,
              onSelected: reduction.isEmpty
                  ? null
                  : (_) => setState(() => _path = 'reduction'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (path == 'all') ...[
          DropdownButton<int>(
            isExpanded: true,
            value: _allMetric,
            items: [
              for (final (i, metric) in _allMetrics.indexed)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    metric.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _allMetric = value!),
          ),
          const SizedBox(height: 12),
          _WellnessChart(
            people: people,
            metric: _allMetrics[_allMetric],
            weeks: weeks,
          ),
          const SizedBox(height: 20),
          const Text(
            'Progres per peserta',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Semua jalur dalam satu tabel. Perubahan rokok/vape: minggu 1 '
            'dibanding minggu terakhir yang punya minimal 4 hari tercatat; '
            '* berarti minggu itu masih berjalan.',
            style: TextStyle(color: c.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          _ProgressTable(people: people),
        ] else if (path == 'wellness') ...[
          DropdownButton<int>(
            isExpanded: true,
            value: _metric,
            items: [
              for (final (i, metric) in _wellnessMetrics.indexed)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    metric.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _metric = value!),
          ),
          const SizedBox(height: 12),
          _WellnessChart(
            people: wellness,
            metric: _wellnessMetrics[_metric],
            weeks: weeks,
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            expandedAlignment: Alignment.centerLeft,
            title: const Text('Angka per peserta'),
            children: [
              _WeekGrid(
                people: wellness,
                metric: _wellnessMetrics[_metric],
                weeks: weeks,
              ),
            ],
          ),
        ] else if (usage != null) ...[
          DropdownButton<String>(
            value: usage.code,
            items: [
              for (final p in reduction)
                DropdownMenuItem(value: p.code, child: Text(p.code)),
            ],
            onChanged: (value) => setState(() => _usageParticipant = value),
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
        const SizedBox(height: 20),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          expandedAlignment: Alignment.centerLeft,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: const Text('Detail peserta'),
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
        'Rata-rata wellness memakai minggu yang selesai. Tanda * berarti minggu berjalan. '
        'Perbandingan konsumsi memerlukan minimal 4 hari tercatat pada kedua minggu. '
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
  const _SummaryTiles({required this.summary, required this.period});
  final StudySummary summary;
  final StudyPeriod period;

  @override
  Widget build(BuildContext context) {
    final people = summary.people;
    final stats = PeriodStats(people, period);
    final last = stats.activeInWeek(period.to);
    final wellness = people.where((p) => !p.reduction).length;
    final active = stats.activeDays, rate = stats.coreRate;
    final n =
        'n=${stats.complete.length}'
        '${stats.running > 0 ? ' · ${stats.running} masih berjalan' : ''}';
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
                    'Wellness $wellness · Rokok/vape ${people.length - wellness}',
              ),
            ),
            SizedBox(
              width: width,
              child: _Tile(
                last.reached == 0 ? '–' : '${last.active}/${last.reached}',
                'Aktif di minggu ${period.to}',
                note: last.reached == 0
                    ? 'Belum ada yang mencapai minggu ${period.to}'
                    : last.provisional
                    ? 'Sementara, minggu masih berjalan'
                    : '${(last.active / last.reached * 100).round()}% peserta',
              ),
            ),
            SizedBox(
              width: width,
              child: _Tile(
                active.mean == null ? '–' : _number(active.mean!),
                'Hari aktif per peserta',
                note: active.mean == null
                    ? 'Belum ada yang menyelesaikan ${periodLabel(period).toLowerCase()}'
                    : 'dari ${(period.to - period.from + 1) * 7} hari · $n',
              ),
            ),
            SizedBox(
              width: width,
              child: _Tile(
                rate == null ? '–' : '${(rate * 100).round()}%',
                'Misi inti selesai',
                note: rate == null
                    ? 'Belum ada periode yang selesai'
                    : 'dari misi yang diambil · $n',
              ),
            ),
          ],
        );
      },
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

class _WellnessChart extends StatelessWidget {
  const _WellnessChart({
    required this.people,
    required this.metric,
    required this.weeks,
  });
  final List<StudyParticipant> people;
  final _Metric metric;

  /// Study weeks (1–4) of the chosen period.
  final List<int> weeks;

  @override
  Widget build(BuildContext context) => _WeeklyBars(
    color: context.colors.accent,
    max: metric.max,
    unit: metric.unit,
    points: [for (final w in weeks) _point(w - 1)],
  );

  _WeekPoint _point(int week) {
    final values = [
      for (final p in people)
        if (week < p.weeks.length && p.weeks[week].complete)
          ?metric.value(p.weeks[week]),
    ];
    final running = people
        .where((p) => week < p.weeks.length && !p.weeks[week].complete)
        .length;
    return (
      label: 'Minggu ${week + 1}',
      value: values.isEmpty
          ? null
          : values.fold<num>(0, (sum, v) => sum + v) / values.length,
      detail: [
        'n=${values.length}',
        if (running > 0) '$running berjalan',
      ].join(' · '),
      // Only a week nobody finished yet reads "berjalan" instead of "–".
      running: values.isEmpty && running > 0,
    );
  }
}

/// Participants × weeks; each cell shows the number with a thin bar, and
/// the last row the group mean of the weeks reached.
class _WeekGrid extends StatelessWidget {
  const _WeekGrid({
    required this.people,
    required this.metric,
    required this.weeks,
  });
  final List<StudyParticipant> people;
  final _Metric metric;
  final List<int> weeks;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    num? value(StudyParticipant p, int week) =>
        week < p.weeks.length ? metric.value(p.weeks[week]) : null;
    final observed = [
      for (final p in people)
        for (final w in weeks) ?value(p, w - 1),
    ];
    final scale =
        metric.max ??
        (observed.isEmpty ? 1 : observed.reduce((a, b) => a > b ? a : b));
    // Completed weeks only: a running week would pull the mean down just
    // because it is not over yet.
    ({double? mean, int n, int running}) groupMean(int week) {
      final values = [
        for (final p in people)
          if (week < p.weeks.length && p.weeks[week].complete) ?value(p, week),
      ];
      return (
        mean: values.isEmpty
            ? null
            : values.fold<num>(0, (a, b) => a + b) / values.length,
        n: values.length,
        running: people
            .where((p) => week < p.weeks.length && !p.weeks[week].complete)
            .length,
      );
    }

    Widget cell(num? v, {bool running = false, bool bold = false}) => SizedBox(
      width: 150,
      child: v == null
          ? Text('–', style: TextStyle(color: c.muted))
          : Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(
                    '${_number(v)}${metric.unit}${running ? '*' : ''}',
                    style: TextStyle(
                      color: c.text,
                      fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: scale == 0 ? 0 : (v / scale).clamp(0, 1),
                      minHeight: 8,
                      color: c.accent,
                      backgroundColor: c.raised,
                    ),
                  ),
                ),
              ],
            ),
    );

    Widget meanCell(int week) {
      final g = groupMean(week);
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          cell(g.mean, bold: true),
          Text(
            [
              'n=${g.n}',
              if (g.running > 0) '${g.running} masih berjalan',
            ].join(' · '),
            style: TextStyle(color: c.muted, fontSize: 11.5),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: const TextStyle(fontWeight: FontWeight.w900),
        dataRowMaxHeight: 60,
        columns: [
          const DataColumn(label: Text('Kode')),
          for (final w in weeks) DataColumn(label: Text('Minggu $w')),
        ],
        rows: [
          for (final p in people)
            DataRow(
              cells: [
                DataCell(Text(p.code)),
                for (final week in weeks)
                  DataCell(
                    cell(
                      value(p, week - 1),
                      running:
                          week <= p.weeks.length && !p.weeks[week - 1].complete,
                    ),
                  ),
              ],
            ),
          DataRow(
            color: WidgetStatePropertyAll(c.raised),
            cells: [
              const DataCell(
                Text(
                  'Rata-rata',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              for (final w in weeks) DataCell(meanCell(w - 1)),
            ],
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
                  label: 'Minggu ${i + 1}',
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
              '${p.weeks.last.complete ? '' : ' (sementara, minggu ${p.weeks.length} masih berjalan)'}',
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
    final note = day?.measurementNote;
    final message = day == null
        ? 'Hari $number: belum berjalan'
        : [
            'Hari $number (${day.day})',
            value == null ? 'tidak dicatat' : '$value $unit',
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

/// Every coded participant on one row: engagement, level, and for the
/// smoking/vaping path the change since week 1 per product.
class _ProgressTable extends StatelessWidget {
  const _ProgressTable({required this.people});
  final List<StudyParticipant> people;

  static String _usage(StudyParticipant p) {
    if (!p.reduction) return '–';
    if (p.types.isEmpty) return 'belum dicatat';
    return [
      for (final type in p.types)
        () {
          final weeks = [for (final w in p.weeks) w.usage(type)];
          // The latest week that can be compared with week 1.
          final index = weeks.lastIndexWhere((u) => u.comparable);
          final change = index > 0
              ? usageChange(weeks.first, weeks[index])
              : null;
          if (change == null) return '$type: data belum cukup';
          final running = !p.weeks[index].complete;
          return '$type ${_number(weeks.first.mean!)} ke '
              '${_number(weeks[index].mean!)} · '
              '${_UsageBlock._changeText(index, weeks.first, weeks[index])}'
              '${running ? '*' : ''}';
        }(),
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: const TextStyle(fontWeight: FontWeight.w900),
        dataRowMaxHeight: 64,
        columnSpacing: 28,
        columns: const [
          DataColumn(label: Text('Kode')),
          DataColumn(label: Text('Jalur')),
          DataColumn(label: Text('Hari')),
          DataColumn(label: Text('Hari aktif'), numeric: true),
          DataColumn(label: Text('Misi inti')),
          DataColumn(label: Text('Minggu aktif')),
          DataColumn(label: Text('Level · XP')),
          DataColumn(label: Text('Rokok/vape')),
          DataColumn(label: Text('Sinkron')),
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
                    Text(p.finished ? 'Selesai' : '${p.elapsed}/$studyDays'),
                  ),
                  DataCell(Text('${p.days.where((d) => d.active).length}')),
                  DataCell(
                    Text(
                      total == 0
                          ? '–'
                          : '$done/$total (${(done / total * 100).round()}%)',
                    ),
                  ),
                  DataCell(
                    Semantics(
                      label: [
                        for (var w = 0; w < 4; w++)
                          'minggu ${w + 1} ${w >= p.weeks.length
                              ? 'belum'
                              : p.weeks[w].activeDays > 0
                              ? 'aktif'
                              : 'tidak aktif'}',
                      ].join(', '),
                      excludeSemantics: true,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var w = 0; w < 4; w++)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                w >= p.weeks.length
                                    ? Icons.remove_rounded
                                    : p.weeks[w].activeDays > 0
                                    ? Icons.circle
                                    : Icons.circle_outlined,
                                size: 14,
                                color:
                                    w < p.weeks.length &&
                                        p.weeks[w].activeDays > 0
                                    ? c.success
                                    : c.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  DataCell(Text('${p.source.level} · ${p.source.xp}')),
                  DataCell(Text(_usage(p))),
                  DataCell(Text(_sync(p.lastSync))),
                ],
              );
            }(),
        ],
      ),
    );
  }
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

// ---------------------------------------------------------------------------
// Period analysis (checkpoint and Bab IV): criteria, weekly activity per path,
// the daily heatmap, and the descriptive table.

bool _dark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

/// Path identity, validated for colour-vision deficiency on both surfaces.
Color _pathColor(BuildContext context, {required bool reduction}) =>
    _dark(context)
    ? (reduction ? const Color(0xffd96a2a) : const Color(0xff5b93e8))
    : (reduction ? const Color(0xffd9590f) : const Color(0xff2f6fd0));

/// Heatmap steps 1–3 (one hue, light to dark); level 0 is the neutral cell.
Color _heat(BuildContext context, int level) {
  const light = [Color(0xff93b1e6), Color(0xff4f84d8), Color(0xff1f4f9e)];
  const dark = [Color(0xff4a6db0), Color(0xff76a4f0), Color(0xffc3daff)];
  return level == 0
      ? context.colors.raised
      : (_dark(context) ? dark : light)[level - 1];
}

const _levelLabels = [
  'Tanpa data',
  'Dibuka, tanpa misi inti',
  'Sebagian misi inti',
  'Semua misi inti',
];

enum _State { met, notMet, provisional, pending }

class _CriteriaCard extends StatelessWidget {
  const _CriteriaCard({required this.people, required this.period});
  final List<StudyParticipant> people;
  final StudyPeriod period;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final all = PeriodStats(people, period);
    final four = all.activeInWeek(4);
    final check = all.activeInWeek(period.to);
    final wellness = people.where((p) => !p.reduction).length;
    final reduction = people.where((p) => p.reduction).toList();
    int product(String name) =>
        reduction.where((p) => p.product == name).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CriterionRow(
            title: 'Keterlibatan minggu 4',
            detail: four.reached == 0
                ? 'Target: minimal $engagementTarget dari $plannedParticipants '
                      'peserta aktif di minggu 4. Belum ada peserta yang '
                      'mencapai minggu 4.'
                : '${four.active} dari ${four.reached} peserta yang mencapai '
                      'minggu 4 aktif. Target: minimal $engagementTarget dari '
                      '$plannedParticipants.',
            state: four.reached == 0
                ? _State.pending
                : four.provisional
                ? _State.provisional
                : four.active >= engagementTarget
                ? _State.met
                : _State.notMet,
          ),
          if (period.to < 4)
            _CriterionRow(
              title: 'Indikasi checkpoint minggu ${period.to}',
              detail: check.reached == 0
                  ? 'Belum ada peserta yang mencapai minggu ${period.to}.'
                  : '${check.active} dari ${check.reached} peserta aktif '
                        '(${(check.active / check.reached * 100).round()}%). '
                        'Acuan 60% mengikuti target minggu 4; ini indikasi, '
                        'bukan kriteria.',
              state: check.reached == 0
                  ? _State.pending
                  : check.provisional
                  ? _State.provisional
                  : check.active / check.reached >= .6
                  ? _State.met
                  : _State.notMet,
            ),
          _CriterionRow(
            title: 'Komposisi sampel UAT',
            detail:
                'Wellness $wellness/$plannedWellness · Rokok/vape '
                '${reduction.length}/$plannedReduction (rokok ${product('rokok')}, '
                'vape ${product('vape')}, keduanya ${product('keduanya')}'
                '${product('belum dicatat') > 0 ? ', belum mencatat ${product('belum dicatat')}' : ''}). '
                'Rencana: 4 wellness, 3 perokok, 3 pengguna vape.',
            state:
                wellness == plannedWellness &&
                    reduction.length == plannedReduction
                ? _State.met
                : _State.notMet,
            metLabel: 'Sesuai rencana',
            notMetLabel: 'Berbeda dari rencana',
          ),
        ],
      ),
    );
  }
}

class _CriterionRow extends StatelessWidget {
  const _CriterionRow({
    required this.title,
    required this.detail,
    required this.state,
    this.metLabel = 'Tercapai',
    this.notMetLabel = 'Belum tercapai',
  });
  final String title, detail, metLabel, notMetLabel;
  final _State state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Status always pairs an icon and a word with its colour.
    final (icon, color, label) = switch (state) {
      _State.met => (Icons.check_circle_rounded, c.success, metLabel),
      _State.notMet => (Icons.error_outline_rounded, c.amber, notMetLabel),
      _State.provisional => (Icons.schedule_rounded, c.muted, 'Sementara'),
      _State.pending => (
        Icons.help_outline_rounded,
        c.muted,
        'Belum bisa dinilai',
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        color: c.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(detail, style: TextStyle(color: c.muted, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grouped bars: share of each path's participants active per week, with a
/// 60% reference line. Labels carry "active/reached" so no value hides in
/// a tooltip.
class _PathWeeklyChart extends StatelessWidget {
  const _PathWeeklyChart({required this.people, required this.weeks});
  final List<StudyParticipant> people;
  final List<int> weeks;

  static const _plot = 150.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final groups = [
      for (final reduction in [false, true])
        if (people.any((p) => p.reduction == reduction))
          (
            reduction: reduction,
            stats: PeriodStats(people.where((p) => p.reduction == reduction), (
              from: 1,
              to: 4,
            )),
          ),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              for (final g in groups)
                _Key(
                  color: _pathColor(context, reduction: g.reduction),
                  label: g.reduction ? 'Rokok/vape' : 'Wellness',
                ),
              _Key(color: c.muted, label: 'acuan 60%', line: true),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            // Room for the value label above the tallest bar.
            height: _plot + 48,
            child: Stack(
              children: [
                // Solid hairline reference, drawn behind the bars.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: _plot * .6,
                  child: Container(height: 1, color: c.muted),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final week in weeks)
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final g in groups)
                              _bar(
                                context,
                                g.reduction,
                                g.stats.activeInWeek(week),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final week in weeks)
                Expanded(
                  child: Text(
                    'Minggu $week'
                    '${people.any((p) => p.weeks.length >= week && !p.weeks[week - 1].complete) ? '*' : ''}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: c.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bar(
    BuildContext context,
    bool reduction,
    ({int active, int reached, bool provisional}) value,
  ) {
    final c = context.colors;
    final share = value.reached == 0 ? null : value.active / value.reached;
    final label = share == null ? '–' : '${value.active}/${value.reached}';
    return Tooltip(
      message:
          '${reduction ? 'Rokok/vape' : 'Wellness'}: '
          '${share == null ? 'belum ada peserta di minggu ini' : '${value.active} dari ${value.reached} aktif (${(share * 100).round()}%)'}'
          '${value.provisional ? ' · sementara' : ''}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: SizedBox(
          width: 36,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: c.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 24,
                height: share == null
                    ? 0
                    : share == 0
                    ? 2
                    : _plot * share,
                decoration: BoxDecoration(
                  color: _pathColor(context, reduction: reduction),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Participants × study days of the period. Empty days are neutral, days not
/// reached yet are blank, and the last row is the share active per day.
class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.people, required this.period});
  final List<StudyParticipant> people;
  final StudyPeriod period;

  static const _cell = 22.0, _gap = 2.0, _name = 92.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final first = (period.from - 1) * 7 + 1, last = period.to * 7;
    final numbers = [for (var n = first; n <= last; n++) n];
    StudyDay? on(StudyParticipant p, int number) =>
        number <= p.days.length ? p.days[number - 1] : null;
    Widget box(Widget child, {double width = _cell}) => Padding(
      padding: const EdgeInsets.all(_gap / 2),
      child: SizedBox(width: width, height: _cell, child: child),
    );
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
                  box(Text('Hari', style: small), width: _name),
                  for (final n in numbers)
                    box(
                      Center(
                        child: Text(
                          n == first || (n - 1) % 7 == 0 || n % 7 == 0
                              ? '$n'
                              : '',
                          style: small,
                        ),
                      ),
                    ),
                  box(Text('Aktif', style: small), width: 48),
                ],
              ),
              for (final p in people)
                Row(
                  children: [
                    box(
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _pathColor(
                                context,
                                reduction: p.reduction,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${p.code} ${p.reduction ? 'R' : 'W'}',
                            style: TextStyle(
                              color: c.text,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                      width: _name,
                    ),
                    for (final n in numbers)
                      box(_cellFor(context, p, on(p, n), n)),
                    box(
                      Text(
                        () {
                          final days = [for (final n in numbers) ?on(p, n)];
                          return days.isEmpty
                              ? '–'
                              : '${days.where((d) => d.active).length}/${days.length}';
                        }(),
                        style: TextStyle(
                          color: c.text,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      width: 48,
                    ),
                  ],
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  box(Text('% aktif', style: small), width: _name),
                  for (final n in numbers) box(_shareFor(context, n, on)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            for (var level = 0; level < 4; level++)
              _Key(color: _heat(context, level), label: _levelLabels[level]),
            _Key(color: c.text, label: 'perubahan cara ukur', line: true),
            Text('W wellness · R rokok/vape', style: small),
          ],
        ),
      ],
    );
  }

  Widget _cellFor(
    BuildContext context,
    StudyParticipant p,
    StudyDay? day,
    int number,
  ) {
    final c = context.colors;
    if (day == null) {
      return Tooltip(
        message: '${p.code} · hari $number belum berjalan',
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );
    }
    final level = dayLevel(day);
    return Tooltip(
      message: [
        '${p.code} · hari $number (${day.day})',
        _levelLabels[level],
        if (day.coreTotal > 0) 'misi inti ${day.coreDone}/${day.coreTotal}',
        if (day.swaps > 0) 'Habit Swap ${day.swaps}',
        ?day.measurementNote,
      ].join('\n'),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _heat(context, level),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          if (day.measurementNote != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 2, color: c.text),
            ),
        ],
      ),
    );
  }

  /// Share of participants active that day, as a small bar on a neutral
  /// track; the exact count is in the tooltip and the "Aktif" column.
  Widget _shareFor(
    BuildContext context,
    int number,
    StudyDay? Function(StudyParticipant, int) on,
  ) {
    final days = [for (final p in people) ?on(p, number)];
    if (days.isEmpty) return const SizedBox.shrink();
    final active = days.where((d) => d.active).length;
    final share = active / days.length;
    return Tooltip(
      message:
          'Hari $number: $active dari ${days.length} peserta aktif '
          '(${(share * 100).round()}%)',
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: 14,
          height: share == 0 ? 2 : _cell * share,
          decoration: BoxDecoration(
            color: _heat(context, 2),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ),
      ),
    );
  }
}

/// Report-ready descriptive table: one column per group, one row per
/// measure, each cell "mean ± SD (min–max)" over completed participants.
class _PeriodTable extends StatelessWidget {
  const _PeriodTable({required this.people, required this.period});
  final List<StudyParticipant> people;
  final StudyPeriod period;

  static String _describe(Describe d) {
    if (d.mean == null) return '–';
    final sd = d.sd == null ? '' : ' ± ${_number(d.sd!)}';
    return '${_number(d.mean!)}$sd (${_number(d.min!)}–${_number(d.max!)})';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final groups = [
      ('Semua', PeriodStats(people, period)),
      ('Wellness', PeriodStats(people.where((p) => !p.reduction), period)),
      ('Rokok/vape', PeriodStats(people.where((p) => p.reduction), period)),
    ];
    String last(PeriodStats s) {
      final v = s.activeInWeek(period.to);
      if (v.reached == 0) return '–';
      return '${v.active}/${v.reached} '
          '(${(v.active / v.reached * 100).round()}%)${v.provisional ? '*' : ''}';
    }

    final rows = <(String, String Function(PeriodStats, int))>[
      (
        'Peserta (selesai periode)',
        (s, _) =>
            '${s.people.length} (${s.complete.length})'
            '${s.running > 0 ? ' · ${s.running} berjalan' : ''}',
      ),
      ('Hari aktif per peserta', (s, _) => _describe(s.activeDays)),
      ('Misi inti selesai per peserta', (s, _) => _describe(s.coreDone)),
      (
        'Misi inti selesai dari yang diambil',
        (s, _) => s.coreRate == null ? '–' : '${(s.coreRate! * 100).round()}%',
      ),
      ('Sesi gerak per peserta', (s, _) => _describe(s.workouts)),
      (
        'Habit Swap per peserta',
        // Wellness has no Habit Swap, so its zeros must not dilute "Semua".
        (s, i) => i == 2 ? _describe(s.swaps) : 'hanya rokok/vape',
      ),
      ('Peserta aktif di minggu ${period.to}', (s, _) => last(s)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingTextStyle: const TextStyle(fontWeight: FontWeight.w900),
            columnSpacing: 32,
            columns: [
              DataColumn(label: Text(periodLabel(period))),
              for (final (name, _) in groups) DataColumn(label: Text(name)),
            ],
            rows: [
              for (final (label, value) in rows)
                DataRow(
                  cells: [
                    DataCell(Text(label)),
                    for (final (i, (_, stats)) in groups.indexed)
                      DataCell(Text(value(stats, i))),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Format: rata-rata ± simpangan baku (min–maks). * minggu masih '
          'berjalan. Angka sama dengan "Unduh ringkasan periode".',
          style: TextStyle(color: c.muted, fontSize: 12),
        ),
      ],
    );
  }
}
