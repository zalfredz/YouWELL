import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/utils/date_key.dart';
import 'package:youwell/features/reduction/domain/reduction_policy.dart';
import 'package:youwell/features/reduction/presentation/reduction_widgets.dart';

const _monthNames = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];
const _units = {'cigarette': 'batang', 'vape': 'sesi'};

/// Daily totals as a tap counter over a month calendar. An empty day stays
/// unknown (dashed), never zero; only a saved total counts. No XP.
class ReductionDiary extends StatefulWidget {
  const ReductionDiary({super.key, required this.controller});
  final WellnessController controller;
  @override
  State<ReductionDiary> createState() => _ReductionDiaryState();
}

class _ReductionDiaryState extends State<ReductionDiary> {
  late String _day = c.today;
  late DateTime _month = _monthOf(c.today);

  /// Counts changed since the selected day was loaded; empty = as saved.
  final _draft = <String, int>{};
  WellnessController get c => widget.controller;

  String get _start =>
      dayKey(c.uatProgram?.firstDay ?? DateTime.parse(c.today));
  static DateTime _monthOf(String key) {
    final date = DateTime.parse(key);
    return DateTime(date.year, date.month);
  }

  bool _open(String key) =>
      key.compareTo(_start) >= 0 && key.compareTo(c.today) <= 0;

  /// The product(s) of the selected day: its saved choice, else the user's.
  String get _product =>
      c.nicotineDay(_day)?['product']?.toString() ?? c.nicotineProduct ?? '';

  int _count(String product) =>
      _draft[product] ??
      ((c.nicotineDay(_day)?[product] as num?)?.toInt() ?? 0);

  void _pick(String key) => setState(() {
    _day = key;
    _draft.clear();
  });

  void _change(String product, int by) =>
      setState(() => _draft[product] = (_count(product) + by).clamp(0, 99));

  void _save() {
    final products = productsFor(_product);
    final saved = c.saveNicotineDay(
      day: _day,
      product: _product,
      cigarettes: products.contains('cigarette') ? _count('cigarette') : null,
      vapeSessions: products.contains('vape') ? _count('vape') : null,
    );
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum tersimpan. Coba lagi.')),
      );
      return;
    }
    setState(_draft.clear);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final products = productsFor(_product);
    final row = c.nicotineDay(_day);
    final saved = row != null && _draft.isEmpty;
    final label = _day == c.today ? 'hari ini' : shortDay(_day);
    final allZero = products.every((p) => _count(p) == 0);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${nicotineProductLabels[_product] ?? ''} · '
                '${_day == c.today ? 'Hari ini' : shortDay(_day)}',
                style: TextStyle(
                  color: colors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.selected,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event_available_rounded,
                    size: 16,
                    color: colors.text,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${c.nicotineDays.length} hari tercatat',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: colors.reduction.withValues(alpha: .3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.reduction.withValues(alpha: .25),
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              if (products.length == 1)
                _BigCounter(
                  product: products.single,
                  count: _count(products.single),
                  onChange: (by) => _change(products.single, by),
                )
              else ...[
                for (final product in products)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RowCounter(
                      product: product,
                      count: _count(product),
                      onChange: (by) => _change(product, by),
                    ),
                  ),
                Text(
                  'Dua angka terpisah. Sesi vape tidak disamakan dengan batang.',
                  style: TextStyle(color: colors.muted, fontSize: 12.5),
                ),
              ],
              const SizedBox(height: 12),
              if (saved)
                SizedBox(
                  height: 48,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_rounded, color: colors.success),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          allZero
                              ? 'Tercatat: ${products.length > 1 ? 'tanpa rokok dan vape' : '0 ${_units[products.single]}'}. Mantap!'
                              : 'Tercatat: ${[for (final p in products) '${_count(p)} ${_units[p]}'].join(' · ')}',
                          style: TextStyle(
                            color: colors.success,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: products.isEmpty ? null : _save,
                    child: Text('Simpan total $label'),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _MonthCalendar(
          controller: c,
          month: _month,
          selected: _day,
          isOpen: _open,
          canGoBack: _month.isAfter(_monthOf(_start)),
          canGoForward: _month.isBefore(_monthOf(c.today)),
          onMonth: (month) => setState(() => _month = month),
          onPick: _pick,
        ),
      ],
    );
  }
}

/// "15 Okt" for a day key.
String shortDay(String key) {
  final date = DateTime.parse(key);
  return '${date.day} ${_monthNames[date.month - 1].substring(0, 3)}';
}

Color _productColor(AppColors colors, String product) =>
    product == 'vape' ? colors.energy : colors.reduction;

/// One product: a big number between round − and + buttons.
class _BigCounter extends StatelessWidget {
  const _BigCounter({
    required this.product,
    required this.count,
    required this.onChange,
  });
  final String product;
  final int count;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final unit = _units[product]!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CountButton(
          size: 64,
          plus: false,
          color: _productColor(colors, product),
          label: 'Kurangi satu $unit',
          onTap: count > 0 ? () => onChange(-1) : null,
        ),
        SizedBox(
          width: 130,
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 72,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: _productColor(colors, product),
                ),
              ),
              Text(
                unit,
                style: TextStyle(
                  color: colors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        CountButton(
          size: 64,
          plus: true,
          color: _productColor(colors, product),
          label: 'Tambah satu $unit',
          onTap: count < 99 ? () => onChange(1) : null,
        ),
      ],
    );
  }
}

/// One of two products: name and unit, then − count +.
class _RowCounter extends StatelessWidget {
  const _RowCounter({
    required this.product,
    required this.count,
    required this.onChange,
  });
  final String product;
  final int count;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final unit = _units[product]!;
    final color = _productColor(colors, product);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nicotineProductLabels[product]!,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                unit,
                style: TextStyle(
                  color: colors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        CountButton(
          size: 52,
          plus: false,
          color: color,
          label: 'Kurangi satu $unit ${nicotineProductLabels[product]}',
          onTap: count > 0 ? () => onChange(-1) : null,
        ),
        SizedBox(
          width: 60,
          child: Text(
            '$count',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 42,
              height: 1,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
        CountButton(
          size: 52,
          plus: true,
          color: color,
          label: 'Tambah satu $unit ${nicotineProductLabels[product]}',
          onTap: count < 99 ? () => onChange(1) : null,
        ),
      ],
    );
  }
}

/// A month of days: saved zero (green), saved count (soft orange, with
/// the numbers), not filled (dashed), outside the period (faded).
class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.controller,
    required this.month,
    required this.selected,
    required this.isOpen,
    required this.canGoBack,
    required this.canGoForward,
    required this.onMonth,
    required this.onPick,
  });
  final WellnessController controller;
  final DateTime month;
  final String selected;
  final bool Function(String) isOpen;
  final bool canGoBack, canGoForward;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final both = productsFor(controller.nicotineProduct).length > 1;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = DateTime(month.year, month.month).weekday - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Bulan sebelumnya',
                onPressed: canGoBack
                    ? () => onMonth(DateTime(month.year, month.month - 1))
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  '${_monthNames[month.month - 1]} ${month.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Bulan berikutnya',
                onPressed: canGoForward
                    ? () => onMonth(DateTime(month.year, month.month + 1))
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          Row(
            children: [
              for (final name in const [
                'Sen',
                'Sel',
                'Rab',
                'Kam',
                'Jum',
                'Sab',
                'Min',
              ])
                Expanded(
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: .86,
            children: [
              for (var i = 0; i < lead; i++) const SizedBox.shrink(),
              for (var d = 1; d <= days; d++)
                _DayCell(
                  dayKey: dayKey(DateTime(month.year, month.month, d)),
                  controller: controller,
                  selected: selected,
                  open: isOpen(dayKey(DateTime(month.year, month.month, d))),
                  both: both,
                  onPick: onPick,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _Legend(
                fill: colors.successSoft,
                border: colors.success,
                label: both ? 'Keduanya 0' : '0, sudah dicatat',
              ),
              _Legend(
                fill: colors.reduction.withValues(alpha: .12),
                border: colors.reduction.withValues(alpha: .5),
                label: 'Ada angka',
              ),
              _Legend(
                border: colors.muted.withValues(alpha: .55),
                dashed: true,
                label: 'Belum diisi',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.dayKey,
    required this.controller,
    required this.selected,
    required this.open,
    required this.both,
    required this.onPick,
  });
  final String dayKey;
  final WellnessController controller;
  final String selected;
  final bool open, both;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final row = controller.nicotineDay(dayKey);
    final products = productsFor(
      row?['product']?.toString() ?? controller.nicotineProduct,
    );
    final values = {
      for (final p in products)
        if (row?[p] is num) p: (row![p] as num).toInt(),
    };
    final saved = row != null && values.isNotEmpty;
    final zero = saved && values.values.every((v) => v == 0);
    final isToday = dayKey == controller.today;
    final isSelected = dayKey == selected;
    final day = int.parse(dayKey.substring(8));
    final fill = !open || !saved
        ? colors.surface
        : zero
        ? colors.successSoft
        : colors.reduction.withValues(alpha: .12);
    final borderColor = isSelected
        ? colors.text
        : !open
        ? Colors.transparent
        : !saved
        ? colors.border
        : zero
        ? colors.success
        : colors.reduction.withValues(alpha: .5);
    final mark = !saved
        ? ''
        : both
        ? [
            for (final p in products)
              '${p == 'vape' ? 'V' : 'R'}${values[p] ?? '–'}',
          ].join(' ')
        : '${values.values.first}';
    final semantic = !open
        ? '$day, di luar periode'
        : !saved
        ? '$day, belum diisi'
        : '$day, ${[for (final p in products) '${values[p] ?? 0} ${_units[p]}'].join(', ')}';
    return Semantics(
      button: open,
      selected: isSelected,
      label: semantic,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: open ? () => onPick(dayKey) : null,
        child: CustomPaint(
          foregroundPainter: !saved && open && !isSelected
              ? _DashedBorder(colors.muted.withValues(alpha: .55))
              : null,
          child: Container(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(14),
              border: saved || isSelected || !open
                  ? Border.all(color: borderColor, width: isSelected ? 3 : 2)
                  : null,
              boxShadow: isToday
                  ? [
                      BoxShadow(
                        color: colors.reduction,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: ExcludeSemantics(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$day',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: open
                          ? colors.text
                          : colors.muted.withValues(alpha: .5),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    child: Text(
                      mark,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: zero ? colors.success : colors.amber,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(14),
        ).deflate(1),
      );
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 7) {
        canvas.drawPath(metric.extractPath(d, d + 3.5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.label,
    required this.border,
    this.fill,
    this.dashed = false,
  });
  final String label;
  final Color border;
  final Color? fill;
  final bool dashed;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CustomPaint(
        foregroundPainter: dashed ? _DashedBorder(border) : null,
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(5),
            border: dashed ? null : Border.all(color: border, width: 2),
          ),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(
          color: context.colors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
