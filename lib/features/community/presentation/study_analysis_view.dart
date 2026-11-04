import 'package:flutter/material.dart';
import 'package:youwell/application/research_overview.dart';
import 'package:youwell/application/study_dashboard.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/progress/domain/research_store.dart';

/// "Analisis studi" in the researcher dashboard: study summary, wellness
/// and smoking/vaping charts, participant detail and data quality, with the
/// interpretation limits written on screen (brief of 4 Nov 2026).
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

class _StudyAnalysisViewState extends State<StudyAnalysisView> {
  int _metric = 0;
  String _path = 'wellness';
  String? _detail, _usageParticipant;

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
    final path = wellness.isEmpty
        ? 'reduction'
        : reduction.isEmpty
        ? 'wellness'
        : _path;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => widget.onDownload(
                'youwell-dashboard-studi.csv',
                toCsv(dashboardCsvColumns, dashboardCsvRows(people)),
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
        _SummaryTiles(summary: summary),
        const SizedBox(height: 24),
        _Section(
          title: 'Keaktifan selama 4 minggu',
          subtitle: 'Peserta aktif per minggu',
          child: _WeeklyBars(
            points: [
              for (var w = 0; w < 4; w++)
                (
                  label: 'Minggu ${w + 1}',
                  value: summary.reached(w + 1) == 0
                      ? null
                      : people
                            .where(
                              (p) =>
                                  w < p.weeks.length &&
                                  p.weeks[w].activeDays > 0,
                            )
                            .length,
                  detail: '${summary.reached(w + 1)} peserta',
                  running: people.any(
                    (p) => w < p.weeks.length && !p.weeks[w].complete,
                  ),
                ),
            ],
            max: people.length,
            color: c.accent,
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
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
        if (path == 'wellness') ...[
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
          _WellnessChart(people: wellness, metric: _wellnessMetrics[_metric]),
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            expandedAlignment: Alignment.centerLeft,
            title: const Text('Angka per peserta'),
            children: [
              _WeekGrid(people: wellness, metric: _wellnessMetrics[_metric]),
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
        'Koreksi admin memulihkan catatan peserta dan selalu masuk dalam grafik serta CSV. '
        'Riwayat koreksi tersedia pada detail peserta.\n\n'
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
  const _SummaryTiles({required this.summary});
  final StudySummary summary;

  @override
  Widget build(BuildContext context) {
    final four = summary.weekFour;
    final missions = summary.people.fold(
      0,
      (sum, p) => sum + p.weeks.fold(0, (sum, w) => sum + w.coreDone),
    );
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
              child: _Tile('${summary.people.length}', 'Peserta studi'),
            ),
            SizedBox(
              width: width,
              child: _Tile(
                four.reached == 0 ? '–' : '${four.active}',
                'Aktif minggu 4',
                note: four.reached == 0
                    ? 'Belum ada yang mencapai minggu 4'
                    : four.provisional
                    ? 'Sementara · target 6/10'
                    : 'Target 6/10',
                highlight: !four.provisional && four.active >= 6,
              ),
            ),
            SizedBox(
              width: width,
              child: _Tile('$missions', 'Misi inti selesai'),
            ),
            SizedBox(
              width: width,
              child: _Tile(
                '${summary.people.where((p) => p.finished).length}',
                'Selesai 28 hari',
              ),
            ),
          ],
        );
      },
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

class _WellnessChart extends StatelessWidget {
  const _WellnessChart({required this.people, required this.metric});
  final List<StudyParticipant> people;
  final _Metric metric;

  @override
  Widget build(BuildContext context) => _WeeklyBars(
    color: context.colors.accent,
    max: metric.max,
    unit: metric.unit,
    points: [for (var w = 0; w < 4; w++) _point(w)],
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
  const _WeekGrid({required this.people, required this.metric});
  final List<StudyParticipant> people;
  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    num? value(StudyParticipant p, int week) =>
        week < p.weeks.length ? metric.value(p.weeks[week]) : null;
    final observed = [
      for (final p in people)
        for (var w = 0; w < 4; w++) ?value(p, w),
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
          for (var w = 1; w <= 4; w++) DataColumn(label: Text('Minggu $w')),
        ],
        rows: [
          for (final p in people)
            DataRow(
              cells: [
                DataCell(Text(p.code)),
                for (var w = 0; w < 4; w++)
                  DataCell(
                    cell(
                      value(p, w),
                      running: w < p.weeks.length && !p.weeks[w].complete,
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
              for (var w = 0; w < 4; w++) DataCell(meanCell(w)),
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
