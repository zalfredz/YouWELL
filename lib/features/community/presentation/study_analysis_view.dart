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
  _Metric('Hari aktif', (w) => w.activeDays, 7, unit: ' hr'),
  _Metric(
    'Misi inti selesai',
    (w) => w.coreRate == null ? null : (w.coreRate! * 100).round(),
    100,
    unit: '%',
  ),
  for (final MapEntry(:key, :value) in targetCategories.entries)
    _Metric(
      key == 'Energy'
          ? 'Target tidur tercapai'
          : 'Target ${value.toLowerCase()}',
      (w) => w.targetDays(key),
      7,
      unit: ' hr',
    ),
  _Metric('Sesi gerak', (w) => w.workouts, null),
  _Metric('Foto makan disetujui', (w) => w.mealApproved, null),
];

class _StudyAnalysisViewState extends State<StudyAnalysisView> {
  bool _includeAdmin = true;
  int _metric = 0;
  String? _detail;

  List<StudyParticipant> get _people => [
    for (final person in widget.people)
      ?StudyParticipant.from(
        person,
        now: widget.now,
        includeAdmin: _includeAdmin,
      ),
  ]..sort((a, b) => compareParticipantCodes(a.code, b.code));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final people = _people;
    final summary = StudySummary(people);
    if (people.isEmpty) {
      return Text(
        'Belum ada peserta berkode P1–P10. Beri kode di tab "Kelola kode & '
        'unduhan".',
        style: TextStyle(color: c.muted),
      );
    }
    final wellness = people.where((p) => !p.reduction).toList();
    final reduction = people.where((p) => p.reduction).toList();
    final detail =
        people.where((p) => p.code == _detail).firstOrNull ?? people.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Limits(),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChip(
              selected: _includeAdmin,
              onSelected: (value) => setState(() => _includeAdmin = value),
              label: const Text('Sertakan data intervensi admin'),
            ),
            OutlinedButton.icon(
              onPressed: () => widget.onDownload(
                _includeAdmin
                    ? 'youwell-dashboard-studi.csv'
                    : 'youwell-dashboard-studi-tanpa-admin.csv',
                toCsv(
                  dashboardCsvColumns,
                  dashboardCsvRows(people, includeAdmin: _includeAdmin),
                ),
              ),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Unduh data grafik (CSV)'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _includeAdmin
              ? 'Angka termasuk ${summary.adminItems} isian admin di '
                    '${summary.adminPeople} peserta. Matikan untuk melihat '
                    'apakah kesimpulan berubah.'
              : 'Isian admin tidak dihitung. CSV mengikuti pilihan ini.',
          style: TextStyle(color: c.muted, fontSize: 12.5),
        ),
        const SizedBox(height: 28),
        _Section(
          title: 'A. Ringkasan studi',
          child: _SummaryTiles(summary: summary),
        ),
        _Section(
          title: 'B. Jalur wellness',
          subtitle:
              'Minggu 1–4 per peserta. Tanda bintang: minggu masih berjalan. '
              '"Target tidur tercapai" berarti misi tidur selesai, bukan tidur '
              'membaik; foto disetujui berarti ada foto makanan/minuman, '
              'bukan mutu gizinya.',
          child: wellness.isEmpty
              ? Text(
                  'Belum ada peserta berkode di jalur wellness.',
                  style: TextStyle(color: c.muted),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (i, metric) in _wellnessMetrics.indexed)
                          ChoiceChip(
                            label: Text(metric.label),
                            selected: _metric == i,
                            onSelected: (_) => setState(() => _metric = i),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _WeekGrid(
                      people: wellness,
                      metric: _wellnessMetrics[_metric],
                    ),
                  ],
                ),
        ),
        _Section(
          title: 'C. Jalur rokok/vape',
          subtitle:
              'Rokok (batang) dan vape (sesi) dipisah dan tidak dijumlah. '
              'Rata-rata = total yang dikonfirmasi ÷ hari yang dicatat. Minggu '
              'dibandingkan dengan minggu 1 hanya bila keduanya punya minimal '
              '4 hari tercatat. Hari kosong bukan nol.',
          child: reduction.isEmpty
              ? Text(
                  'Belum ada peserta berkode di jalur rokok/vape.',
                  style: TextStyle(color: c.muted),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final p in reduction)
                      if (p.types.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            '${p.code}: belum ada total harian tercatat.',
                            style: TextStyle(color: c.muted),
                          ),
                        )
                      else
                        for (final type in p.types)
                          _UsageBlock(participant: p, type: type),
                  ],
                ),
        ),
        _Section(
          title: 'D. Detail peserta dan kualitas data',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
        ),
      ],
    );
  }
}

String _number(num value, {int digits = 1}) => value is int
    ? '$value'
    : value.toStringAsFixed(digits).replaceAll('.', ',');

String _sync(DateTime? time) {
  if (time == null) return 'belum';
  final t = time.toLocal();
  return '${t.day}/${t.month} ${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}

class _Limits extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const lines = [
      'Hari aktif, misi, XP, dan level mengukur keterlibatan dengan aplikasi, '
          'bukan kesehatan.',
      'Minggu 1 sudah minggu pemakaian aplikasi, bukan kondisi sebelum '
          'intervensi. Data ini tidak bisa menyebut YouWELL menurunkan '
          'konsumsi; untuk itu perlu kuesioner awal–akhir dan pembanding.',
      'Total rokok/vape adalah laporan peserta. Hari tanpa catatan bukan nol.',
      'Hasil tiap momen Habit Swap tidak disinkronkan, jadi tidak ada '
          'persentase berhasil menahan.',
      'Cara ukur berubah pada 23 Okt (misi tidur, verifikasi foto) dan 27 Okt '
          '(total rokok/vape tersinkron); lihat garis penanda di grafik.',
    ];
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
          Row(
            children: [
              Icon(Icons.rule_rounded, color: c.accent, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Batas tafsir',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $line', style: TextStyle(color: c.text)),
            ),
        ],
      ),
    );
  }
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
    final c = context.colors;
    final four = summary.weekFour;
    final completeness = summary.completeness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Tile('${summary.people.length}', 'Peserta berkode'),
            _Tile(
              [for (var w = 1; w <= 4; w++) summary.reached(w)].join(' / '),
              'Mencapai minggu 1 / 2 / 3 / 4',
            ),
            _Tile(
              completeness == null ? '–' : '${(completeness * 100).round()}%',
              'Kelengkapan catatan',
              note: 'hari berisi data ÷ hari studi berjalan',
            ),
            _Tile(
              _sync(summary.oldestSync),
              'Sinkron paling lama',
              note: 'terbaru ${_sync(summary.newestSync)}',
            ),
            _Tile(
              '${summary.adminItems}',
              'Isian diperbaiki admin',
              note: '${summary.adminPeople} peserta',
            ),
            _Tile(
              four.reached == 0 ? '–' : '${four.active}/${four.reached}',
              four.provisional
                  ? 'Aktif minggu ke-4 (sementara)'
                  : 'Aktif minggu ke-4 (akhir)',
              note: 'kriteria: ≥ 6 dari 10',
              highlight: !four.provisional && four.active >= 6,
            ),
          ],
        ),
        if (four.provisional)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Hasil kriteria minggu ke-4 masih sementara sampai semua peserta '
              'berkode menyelesaikan minggu ke-4.',
              style: TextStyle(color: c.muted, fontSize: 12.5),
            ),
          ),
      ],
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
      width: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight ? c.selected : c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: highlight ? c.accent : c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: c.text,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(label, style: TextStyle(color: c.text)),
          if (note != null)
            Text(note!, style: TextStyle(color: c.muted, fontSize: 12.5)),
        ],
      ),
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
    double? mean(int week) {
      final values = [for (final p in people) ?value(p, week)];
      return values.isEmpty
          ? null
          : values.fold<num>(0, (a, b) => a + b) / values.length;
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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: const TextStyle(fontWeight: FontWeight.w900),
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
              for (var w = 0; w < 4; w++) DataCell(cell(mean(w), bold: true)),
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
              _Key(color: color, label: 'dicatat peserta'),
              _Key(
                color: color.withValues(alpha: .35),
                label: 'diisi admin',
                outlined: color,
              ),
              _Key(color: c.muted, label: 'tidak dicatat', dot: true),
              _Key(color: c.text, label: 'perubahan cara ukur', line: true),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: const TextStyle(fontWeight: FontWeight.w900),
              columns: [
                const DataColumn(label: Text('')),
                for (final w in p.weeks)
                  DataColumn(
                    label: Text('Minggu ${w.week}${w.complete ? '' : '*'}'),
                  ),
              ],
              rows: [
                DataRow(
                  cells: [
                    const DataCell(Text('Rata-rata per hari tercatat')),
                    for (final u in weeks)
                      DataCell(
                        Text(
                          u.mean == null
                              ? '–'
                              : '${_number(u.mean!)} $unit · ${u.loggedDays}/7 hari',
                        ),
                      ),
                  ],
                ),
                DataRow(
                  cells: [
                    const DataCell(Text('Dibanding minggu 1')),
                    for (final (i, u) in weeks.indexed)
                      DataCell(Text(_changeText(i, first!, u))),
                  ],
                ),
                DataRow(
                  cells: [
                    const DataCell(Text('Habit Swap (konteks)')),
                    for (final w in p.weeks) DataCell(Text('${w.swaps}')),
                  ],
                ),
              ],
            ),
          ),
          if (change != null) ...[
            const SizedBox(height: 8),
            Text(
              'Pada peserta ${p.code}, rata-rata $type pada hari yang dicatat '
              'berubah dari ${_number(first!.mean!)} $unit di minggu 1 menjadi '
              '${_number(last!.mean!)} $unit di minggu ${weeks.length}. '
              'Cakupan catatan: ${first.loggedDays}/7 dan ${last.loggedDays}/7 '
              'hari.',
              style: TextStyle(color: c.text, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  static String _changeText(int index, UsageWeek first, UsageWeek week) {
    if (index == 0) return 'acuan';
    final change = usageChange(first, week);
    if (change == null) return 'tidak dibandingkan (< 4 hari)';
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
                : '$value $unit${byAdmin ? ' · diisi admin' : ''}',
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
                        color: byAdmin ? color.withValues(alpha: .35) : color,
                        border: byAdmin ? Border.all(color: color) : null,
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
    this.outlined,
    this.dot = false,
    this.line = false,
  });
  final Color color;
  final Color? outlined;
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
          border: outlined == null ? null : Border.all(color: outlined!),
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
            Text('Sinkron terakhir: ${_sync(p.lastSync)}'),
            Text(
              'Kelengkapan: ${p.daysWithData}/${p.elapsed} hari berisi data',
            ),
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
                        Text(
                          d.usage[type] == null
                              ? '–'
                              : '${d.usage[type]}'
                                    '${d.usageByAdmin.contains(type) ? ' (admin)' : ''}',
                        ),
                      ),
                    DataCell(Text(d.swaps == 0 ? '–' : '${d.swaps}')),
                    DataCell(
                      Text(
                        [
                          if (!d.hasData) 'tanpa data',
                          if (d.adminItems > 0)
                            'diperbaiki admin (${d.adminItems})',
                          ?d.measurementNote,
                        ].join(' · '),
                        style: TextStyle(
                          color: d.adminItems > 0 ? c.amber : c.muted,
                        ),
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
