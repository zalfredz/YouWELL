import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/utils/date_label.dart';
import 'package:youwell/features/reduction/domain/reduction_policy.dart';
import 'package:youwell/features/reduction/presentation/reduction_widgets.dart';

String _unit(String product) => product == 'cigarette' ? 'batang' : 'sesi';

/// "4,6" with an Indonesian decimal comma.
String _number(double value) => value
    .toStringAsFixed(value == value.roundToDouble() ? 0 : 1)
    .replaceAll('.', ',');

Color _productColor(AppColors colors, String product) =>
    product == 'vape' ? colors.energy : colors.reduction;

/// Weeks, tries, weekly averages, an optional limit and the latest moments.
/// Numbers come from the user's own records; rises are shown neutrally.
class ReductionProgress extends StatelessWidget {
  const ReductionProgress({super.key, required this.controller});
  final WellnessController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final colors = context.colors;
    final program = c.uatProgram!;
    final products = [
      for (final product in ['cigarette', 'vape'])
        if (productsFor(c.nicotineProduct).contains(product) ||
            c.nicotineDays.any((row) => row[product] is num))
          product,
    ];
    final tried = c.habitSwaps.where(isSwapAttempt).length;
    final skipped = c.habitSwaps
        .where((row) => row['outcome'] == 'skipped')
        .length;
    final week = program.week;
    final canSetLimit = !c.studyPeriodComplete && week > 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                c.studyPeriodComplete
                    ? 'Rekap 4 minggu'
                    : 'Minggu $week dari 4',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (!c.studyPeriodComplete)
              Text(
                'Hari ${program.dayNumber}',
                style: TextStyle(
                  color: colors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _JourneyBar(
          day: c.studyPeriodComplete ? 28 : program.dayNumber,
          color: colors.reduction,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: StatTile(
                value: '$tried',
                label: 'kegiatan dicoba',
                color: colors.reduction,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                value: '$skipped',
                label: 'momen terlewati',
                color: colors.success,
              ),
            ),
          ],
        ),
        for (final product in products) ...[
          const SizedBox(height: 16),
          _WeeklyChart(
            controller: c,
            product: product,
            titled: products.length > 1,
          ),
        ],
        if (canSetLimit)
          for (final product in productsFor(c.nicotineProduct)) ...[
            const SizedBox(height: 16),
            c.consumptionWeek(1).comparableFor(product)
                ? _LimitCard(
                    key: ValueKey('limit-$week-$product'),
                    controller: c,
                    product: product,
                  )
                : _Card(
                    child: Text(
                      'Catat minimal 4 hari di Minggu 1 untuk memilih batas '
                      '${nicotineProductLabels[product]!.toLowerCase()}.',
                      style: TextStyle(color: colors.muted),
                    ),
                  ),
          ],
        const SizedBox(height: 16),
        _MomentList(rows: c.habitSwaps.reversed.take(12).toList(), now: c.now),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: context.colors.border, width: 2),
    ),
    child: child,
  );
}

/// Four week segments, the current one filled up to today.
class _JourneyBar extends StatelessWidget {
  const _JourneyBar({required this.day, required this.color});
  final int day;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Hari $day dari 28',
    child: Row(
      children: [
        for (var week = 0; week < 4; week++) ...[
          if (week > 0) const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: ((day - week * 7) / 7).clamp(0.0, 1.0),
                minHeight: 10,
                color: color,
                backgroundColor: color.withValues(alpha: .18),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// Average per recorded day for weeks 1-4, values written on the bars.
class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({
    required this.controller,
    required this.product,
    required this.titled,
  });
  final WellnessController controller;
  final String product;
  final bool titled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = _productColor(colors, product);
    final c = controller;
    final current = c.studyPeriodComplete ? 4 : c.uatProgram!.week;
    final means = [
      for (var week = 1; week <= 4; week++)
        c.consumptionWeek(week).daysFor(product) > 0
            ? c.consumptionWeek(week).meanFor(product)
            : null,
    ];
    final top = [
      for (final mean in means) ?mean,
    ].fold<double>(1, (a, b) => b > a ? b : a);
    // The latest week that can be compared fairly with week 1.
    final baseline = c.consumptionWeek(1);
    int? compareWeek;
    for (var week = current; week > 1; week--) {
      if (c.consumptionWeek(week).comparableFor(product) &&
          baseline.comparableFor(product)) {
        compareWeek = week;
        break;
      }
    }
    final diff = compareWeek == null
        ? null
        : c.consumptionWeek(compareWeek).meanFor(product)! -
              baseline.meanFor(product)!;
    final summary = [
      for (var i = 0; i < 4; i++)
        'Minggu ${i + 1}: ${means[i] == null ? 'belum ada' : '${_number(means[i]!)} ${_unit(product)}'}',
    ].join('. ');
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titled
                ? '${nicotineProductLabels[product]} · rata-rata per hari'
                : 'Rata-rata per hari',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          Text(
            '${_unit(product)} · dari hari yang dicatat',
            style: TextStyle(color: colors.muted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Semantics(
            label: summary,
            child: ExcludeSemantics(
              child: SizedBox(
                height: 160,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 4; i++) ...[
                      if (i > 0) const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              means[i] == null ? '–' : _number(means[i]!),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (means[i] == null)
                              Container(
                                height: 14,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: colors.muted.withValues(alpha: .4),
                                    width: 2,
                                  ),
                                ),
                              )
                            else
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: means[i]! / top),
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, _) => Container(
                                  height: 6 + 100 * value,
                                  decoration: BoxDecoration(
                                    color: i + 1 == current
                                        ? color
                                        : color.withValues(alpha: .45),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(10),
                                      bottom: Radius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 6),
                            Text(
                              'Mg ${i + 1}',
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.lifestyle.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  diff == null
                      ? Icons.info_outline_rounded
                      : diff < 0
                      ? Icons.south_rounded
                      : diff > 0
                      ? Icons.north_rounded
                      : Icons.drag_handle_rounded,
                  size: 18,
                  color: colors.lifestyle,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    diff == null
                        ? 'Catat minimal 4 hari per minggu untuk membandingkan.'
                        : diff == 0
                        ? 'Sama dengan Minggu 1'
                        : '${_number(diff.abs())} ${_unit(product)} lebih '
                              '${diff < 0 ? 'sedikit' : 'banyak'} dari Minggu 1',
                    style: TextStyle(
                      color: colors.text,
                      fontWeight: FontWeight.w800,
                    ),
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

/// An optional daily limit for this week, set with − and +.
class _LimitCard extends StatefulWidget {
  const _LimitCard({
    super.key,
    required this.controller,
    required this.product,
  });
  final WellnessController controller;
  final String product;

  @override
  State<_LimitCard> createState() => _LimitCardState();
}

class _LimitCardState extends State<_LimitCard> {
  WellnessController get c => widget.controller;
  int get _max => c.consumptionWeek(1).meanFor(widget.product)!.ceil();
  int? get _saved =>
      (c.targetFor(c.uatProgram!.week, widget.product)?['limit'] as num?)
          ?.toInt();
  late int _limit = _saved ?? _max;

  void _set(int? limit) {
    if (!c.setReductionTarget(widget.product, limit)) return;
    setState(() {});
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            limit == null ? 'Tanpa batas minggu ini.' : 'Batas disimpan.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = _productColor(colors, widget.product);
    final unit = _unit(widget.product);
    final saved = _saved;
    return _Card(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  productsFor(c.nicotineProduct).length > 1
                      ? 'Batas ${nicotineProductLabels[widget.product]!.toLowerCase()} minggu ini'
                      : 'Batas minggu ini',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.raised,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  saved == null ? 'Opsional' : 'Dipakai: $saved',
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CountButton(
                size: 52,
                plus: false,
                color: color,
                label: 'Kurangi batas',
                onTap: _limit > 0 ? () => setState(() => _limit--) : null,
              ),
              SizedBox(
                width: 110,
                child: Column(
                  children: [
                    Text(
                      '$_limit',
                      style: TextStyle(
                        fontSize: 44,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                    Text(
                      '$unit/hari',
                      style: TextStyle(
                        color: colors.muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              CountButton(
                size: 52,
                plus: true,
                color: color,
                label: 'Tambah batas',
                onTap: _limit < _max ? () => setState(() => _limit++) : null,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _set(null),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Tanpa batas', maxLines: 1),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => _set(_limit),
                  child: const Text('Pakai batas ini'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The latest moments: activity, when, and a small outcome badge. Older
/// records without an outcome say so; nothing is guessed.
class _MomentList extends StatelessWidget {
  const _MomentList({required this.rows, required this.now});
  final List<Map<String, dynamic>> rows;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Momen terakhir',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          if (rows.isEmpty)
            Text(
              'Belum ada momen. Mulai dari tombol "Saya ingin …" di Home.',
              style: TextStyle(color: colors.muted),
            ),
          for (final row in rows) _MomentRow(row: row, now: now),
        ],
      ),
    );
  }
}

class _MomentRow extends StatelessWidget {
  const _MomentRow({required this.row, required this.now});
  final Map<String, dynamic> row;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final product = row['product']?.toString() ?? 'cigarette';
    final outcome = row['outcome']?.toString();
    final (label, color, icon) = switch (outcome) {
      'skipped' => ('Tidak jadi', colors.success, Icons.check_rounded),
      'used' => (
        'Tetap ${useVerb(row['usedProduct']?.toString() ?? product)}',
        colors.cyan,
        Icons.remove_rounded,
      ),
      'not_tried' => ('Belum mencoba', colors.muted, Icons.remove_rounded),
      _ when awaitingOutcome(row) => (
        'Isi hasil',
        colors.amber,
        Icons.schedule_rounded,
      ),
      _ => ('Tidak dicatat', colors.muted, Icons.remove_rounded),
    };
    final names = activityNames(row);
    final time = DateTime.tryParse(
      (row['startedAt'] ?? row['time'] ?? '').toString(),
    );
    final when = [
      dayLabel(row['day'].toString(), now),
      if (time != null)
        '${time.hour.toString().padLeft(2, '0')}.${time.minute.toString().padLeft(2, '0')}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              activityIcon((row['activity'] as String?) ?? ''),
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  names.isEmpty
                      ? (row['swap']?.toString() ?? 'Momen')
                      : names.join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  when,
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
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
