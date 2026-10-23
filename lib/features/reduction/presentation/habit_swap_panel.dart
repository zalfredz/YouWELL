import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/utils/date_key.dart';
import 'package:youwell/core/utils/date_label.dart';
import 'package:youwell/features/reduction/domain/reduction_policy.dart';
import 'package:youwell/features/reduction/presentation/reduction_widgets.dart';
import 'package:youwell/features/reduction/presentation/swap_setup_flow.dart';

/// Habit Swap when a craving starts: (product) → activities → "Saya akan
/// coba" → "Saya sudah mencoba" → outcome now or later. No countdown. An
/// open moment survives closing the page and is shown again on return.
class HabitSwapPanel extends StatefulWidget {
  const HabitSwapPanel({
    super.key,
    required this.controller,
    this.product,
    this.outcomeFor,
  });
  final WellnessController controller;

  /// Preselected from "Saya ingin merokok/vape" on Home.
  final String? product;

  /// Opens straight on "Setelah mencoba, apa yang terjadi?" for this moment
  /// (from "Saya sudah mencoba" on Home).
  final String? outcomeFor;

  @override
  State<HabitSwapPanel> createState() => _HabitSwapPanelState();
}

class _HabitSwapPanelState extends State<HabitSwapPanel> {
  String? _product, _outcomeFor;
  bool _editing = false;
  final _activities = <String>{};
  final _custom = <String>[];

  WellnessController get c => widget.controller;
  List<String> get _products => productsFor(c.nicotineProduct);

  @override
  void initState() {
    super.initState();
    _outcomeFor = widget.outcomeFor;
    _product = _products.length == 1
        ? _products.single
        : _products.contains(widget.product)
        ? widget.product
        : null;
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  /// Each step ends on Home: the activity happens away from the app, and
  /// Home is where the user comes back to.
  void _backHome(String message) {
    final messenger = ScaffoldMessenger.of(context);
    // pop, not maybePop: the result screen blocks only the user's own back.
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _start() {
    final active = c.activeSwapMoment;
    if (active != null) return;
    final started = c.startSwapMoment(
      product: _product!,
      activities: [..._activities],
      customActivities: _custom,
    );
    if (!started) return _snack('Pilih minimal satu kegiatan dulu.');
    setState(() {
      _activities.clear();
      _custom.clear();
    });
    _backHome(
      'Momen dimulai. Coba kegiatannya dulu, lalu tekan '
      '"Saya sudah mencoba" di Home.',
    );
  }

  Future<void> _addCustom() async {
    final text = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tulis kegiatan sendiri'),
        content: TextField(
          controller: text,
          autofocus: true,
          maxLength: maxCustomSwapText,
          decoration: const InputDecoration(hintText: 'Misalnya: cuci muka'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, text.text),
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
    text.dispose();
    final clean = cleanCustom([value ?? '']);
    if (clean.isNotEmpty && !_custom.contains(clean.single)) {
      setState(() => _custom.add(clean.single));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_products.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(22),
        child: Text(
          'Pilih dulu yang kamu gunakan: rokok, vape, atau keduanya.',
        ),
      );
    }
    final needing = c.productsNeedingSetup;
    if (_editing || needing.isNotEmpty) {
      return SwapSetupFlow(
        key: ValueKey('setup-$_editing-${needing.join()}'),
        controller: c,
        products: _editing ? _products : needing,
        editing: _editing,
        onDone: () => setState(() => _editing = false),
      );
    }
    if (_outcomeFor case final id?) {
      final row = c.habitSwaps.where((row) => row['id'] == id).firstOrNull;
      if (row != null) {
        return _OutcomeView(
          controller: c,
          row: row,
          onDone: (message) {
            setState(() => _outcomeFor = null);
            _backHome(message ?? 'Tercatat.');
          },
        );
      }
    }
    if (c.activeSwapMoment case final moment?) {
      return _ActiveMomentView(
        controller: c,
        moment: moment,
        onTried: (id) => setState(() => _outcomeFor = id),
        onLater: () => _backHome(
          'Momen tetap tersimpan. Tekan "Saya sudah mencoba" di Home '
          'setelah selesai.',
        ),
        onCancel: () => setState(() {}),
      );
    }
    return _startView(context);
  }

  Widget _startView(BuildContext context) {
    final colors = context.colors;
    final pending = c.swapsAwaitingOutcome;
    final product = _product;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        for (final row in pending.reversed.take(2))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PendingBanner(
              text: 'Hasil momen ${_timeOf(row, c.now)} belum diisi',
              onTap: () => setState(() => _outcomeFor = row['id'].toString()),
            ),
          ),
        if (product == null) ...[
          Text(
            'Sekarang ingin apa?',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          for (final option in _products)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ChoiceTile(
                horizontal: true,
                icon: Icons.local_fire_department_outlined,
                label: cravingLabel(option),
                selected: false,
                color: option == 'vape' ? colors.energy : colors.reduction,
                onTap: () => setState(() => _product = option),
              ),
            ),
        ] else
          ..._activityPicker(context, product),
        const SizedBox(height: 18),
        _TodaySummary(controller: c),
        const SizedBox(height: 6),
        Center(
          child: TextButton.icon(
            onPressed: () => setState(() => _editing = true),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: Text(
              _products.any((p) => c.swapSetup(p) == null)
                  ? 'Siapkan pemicu & kegiatan'
                  : 'Ubah pemicu & kegiatan',
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _activityPicker(BuildContext context, String product) {
    final colors = context.colors;
    final color = product == 'vape' ? colors.energy : colors.reduction;
    final setup = c.swapSetup(product);
    final mine = ((setup?['activities'] as List?) ?? const []).cast<String>();
    final myCustom = ((setup?['customActivities'] as List?) ?? const [])
        .cast<String>();
    final others = suggestedSwaps(
      lowImpact: c.profile?['lowImpact'] == true,
      product: product,
      history: c.habitSwaps.where((row) {
        final from = shiftDayKey(c.today, -6);
        return row['day'].toString().compareTo(from) >= 0;
      }).toList(),
    ).where((key) => !mine.contains(key)).toList();
    final newCustom = _custom.where((t) => !myCustom.contains(t)).toList();
    final count = _activities.length + _custom.length;
    Widget known(String key, {bool personal = false}) => ChoiceTile(
      icon: activityIcon(key),
      label: swapActivityLabels[key]!,
      badge: personal ? 'Pilihanmu' : null,
      selected: _activities.contains(key),
      color: color,
      onTap: () => setState(
        () => _activities.contains(key)
            ? _activities.remove(key)
            : _activities.add(key),
      ),
    );
    Widget custom(String text, {bool personal = false}) => ChoiceTile(
      icon: Icons.star_outline_rounded,
      label: text,
      badge: personal ? 'Pilihanmu' : null,
      selected: _custom.contains(text),
      color: color,
      onTap: () => setState(
        () => _custom.contains(text) ? _custom.remove(text) : _custom.add(text),
      ),
    );
    return [
      if (_products.length > 1)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() {
              _product = null;
              _activities.clear();
            }),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Ganti'),
          ),
        ),
      Text(
        cravingLabel(product),
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
      Text(
        'Coba satu kegiatan dulu',
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 14),
      // A fixed height fits the icon and two lines on any phone width.
      GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 128,
        ),
        children: [
          for (final key in mine) known(key, personal: true),
          for (final text in myCustom) custom(text, personal: true),
          for (final key in others) known(key),
          for (final text in newCustom) custom(text),
          ChoiceTile(
            icon: Icons.edit_outlined,
            label: 'Tulis sendiri',
            selected: false,
            dashed: true,
            color: color,
            onTap: _addCustom,
          ),
        ],
      ),
      const SizedBox(height: 16),
      _BigButton(
        label: count == 0 ? 'Pilih satu kegiatan' : 'Saya akan coba ($count)',
        onTap: count == 0 ? null : _start,
      ),
    ];
  }
}

/// "Hasil momen … belum diisi" with a quick way in.
class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: colors.reduction.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.reduction.withValues(alpha: .45)),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, color: colors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          TextButton(onPressed: onTap, child: const Text('Isi hasil')),
        ],
      ),
    );
  }
}

/// The green game-style main button of these screens.
class _BigButton extends StatelessWidget {
  const _BigButton({required this.label, required this.onTap, this.icon});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 54,
    child: FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon ?? Icons.arrow_forward_rounded),
      label: Text(
        label,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
      ),
    ),
  );
}

/// "Hari ini 14.10", "Kemarin 20.00" or "Kam, 30 Okt 09.40".
String _timeOf(Map row, DateTime now) {
  final day = dayLabel(row['day'].toString(), now);
  final time = DateTime.tryParse(
    (row['startedAt'] ?? row['time'] ?? '').toString(),
  );
  if (time == null) return day;
  final hh = time.hour.toString().padLeft(2, '0');
  final mm = time.minute.toString().padLeft(2, '0');
  return '$day $hh.$mm';
}

/// The open moment: what was picked, then "Saya sudah mencoba".
class _ActiveMomentView extends StatefulWidget {
  const _ActiveMomentView({
    required this.controller,
    required this.moment,
    required this.onTried,
    required this.onLater,
    required this.onCancel,
  });
  final WellnessController controller;
  final Map<String, dynamic> moment;
  final ValueChanged<String> onTried;
  final VoidCallback onLater, onCancel;

  @override
  State<_ActiveMomentView> createState() => _ActiveMomentViewState();
}

class _ActiveMomentViewState extends State<_ActiveMomentView> {
  final _triggers = <String>{};
  final _customTriggers = <String>{};

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Batalkan momen ini?'),
        content: const Text(
          'Pakai ini jika momen dimulai tidak sengaja. Tidak ada yang dicatat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Tidak'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Batalkan momen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    widget.controller.cancelSwapMoment();
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final c = widget.controller;
    final product = widget.moment['product'].toString();
    final setup = c.swapSetup(product);
    final mine = ((setup?['triggers'] as List?) ?? const []).cast<String>();
    final myCustom = ((setup?['customTriggers'] as List?) ?? const [])
        .cast<String>();
    final triggerChoices = [
      ...mine,
      ...triggersFor(product).where((key) => !mine.contains(key)),
    ];
    final color = product == 'vape' ? colors.energy : colors.reduction;
    final keys = {
      ...((widget.moment['activities'] as List?) ?? const []).cast<String>(),
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Text(
          '${cravingLabel(product)} · mulai ${_timeOf({'day': c.today, ...widget.moment}, c.now).split(' ').last}',
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
        Text(
          'Sedang mencoba',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 14),
        for (final key in keys)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ChoiceTile(
              horizontal: true,
              icon: activityIcon(key),
              label: swapActivityLabels[key] ?? key,
              selected: true,
              color: color,
              onTap: () {},
            ),
          ),
        for (final text
            in ((widget.moment['customActivities'] as List?) ?? const [])
                .cast<String>())
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ChoiceTile(
              horizontal: true,
              icon: Icons.star_outline_rounded,
              label: text,
              selected: true,
              color: color,
              onTap: () {},
            ),
          ),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text(
              'Pemicunya tadi (opsional)',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final key in triggerChoices)
                    FilterChip(
                      label: Text(reductionTriggerLabels[key]!),
                      selected: _triggers.contains(key),
                      onSelected: (on) => setState(
                        () => on ? _triggers.add(key) : _triggers.remove(key),
                      ),
                    ),
                  for (final text in myCustom)
                    FilterChip(
                      label: Text(text),
                      selected: _customTriggers.contains(text),
                      onSelected: (on) => setState(
                        () => on
                            ? _customTriggers.add(text)
                            : _customTriggers.remove(text),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _BigButton(
          icon: Icons.check_rounded,
          label: 'Saya sudah mencoba',
          onTap: () {
            final id = c.reportSwapTried(
              triggers: [..._triggers],
              customTriggers: [..._customTriggers],
            );
            if (id != null) widget.onTried(id);
          },
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: widget.onLater,
          child: const Text('Kembali ke Home'),
        ),
        const SizedBox(height: 4),
        TextButton(onPressed: _cancel, child: const Text('Batalkan momen ini')),
      ],
    );
  }
}

/// "Setelah mencoba, apa yang terjadi?" in the words of the moment's product.
class _OutcomeView extends StatefulWidget {
  const _OutcomeView({
    required this.controller,
    required this.row,
    required this.onDone,
  });
  final WellnessController controller;
  final Map<String, dynamic> row;

  /// Called with a message to show, or null.
  final ValueChanged<String?> onDone;

  @override
  State<_OutcomeView> createState() => _OutcomeViewState();
}

class _OutcomeViewState extends State<_OutcomeView> {
  String? _outcome, _used;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final colors = context.colors;
    final product = widget.row['product'].toString();
    final both = productsFor(c.nicotineProduct).length > 1;
    final mission = c.quests
        .where(
          (task) =>
              task['activityKind'] == 'habit_swap' &&
              task['status'] == 'completed',
        )
        .firstOrNull;
    final styles = {
      'skipped': (Icons.check_rounded, colors.success),
      'used': (Icons.remove_rounded, colors.cyan),
    };
    // A result must be chosen: back is blocked until one is saved.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Pilih salah satu hasil dulu ya.')),
          );
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colors.xpSoft,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, size: 18, color: colors.onXp),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      mission == null
                          ? 'Kegiatan tercatat'
                          : '+${mission['xp']} XP · Misi Habit Swap selesai',
                      style: TextStyle(
                        color: colors.onXp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Kamu sudah mencoba: ${activityNames(widget.row).join(', ')}',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.muted, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Setelah mencoba, apa yang terjadi?',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          for (final option in const ['skipped', 'used'])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ChoiceTile(
                horizontal: true,
                icon: styles[option]!.$1,
                label: outcomeLabel(option, product),
                selected: _outcome == option,
                color: styles[option]!.$2,
                onTap: () => setState(() {
                  _outcome = option;
                  _used = option == 'used' ? product : null;
                }),
              ),
            ),
          if (_outcome == 'used' && both) ...[
            const Text(
              'Yang akhirnya dipakai',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final kind in const ['cigarette', 'vape'])
                  ChoiceChip(
                    label: Text(nicotineProductLabels[kind]!),
                    selected: _used == kind,
                    onSelected: (_) => setState(() => _used = kind),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Apa pun hasilnya, mencoba tetap dihitung.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.muted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          _BigButton(
            icon: Icons.check_rounded,
            label: 'Simpan hasil',
            onTap: _outcome == null
                ? null
                : () {
                    c.recordSwapOutcome(
                      widget.row['id'].toString(),
                      _outcome!,
                      usedProduct: _outcome == 'used' ? _used : null,
                    );
                    widget.onDone(
                      _outcome == 'skipped'
                          ? 'Tercatat. Momen ini terlewati.'
                          : 'Tercatat. Mencoba tetap berarti.',
                    );
                  },
          ),
        ],
      ),
    );
  }
}

/// Tries today and the day's confirmed total, kept as two separate facts.
class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.controller});
  final WellnessController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final c = controller;
    final free = c.dayWithoutUse(c.today);
    return Row(
      children: [
        Expanded(
          child: StatTile(
            value: '${c.swapAttemptsToday.length}×',
            label: 'dicoba hari ini',
            color: colors.reduction,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatTile(
            value: switch (free) {
              null => '?',
              true => '0',
              false => '',
            },
            icon: free == false ? Icons.check_rounded : null,
            label: switch (free) {
              null => 'total hari ini belum dicatat',
              true => 'total hari ini',
              false => 'total hari ini tercatat',
            },
            color: free == true ? colors.success : colors.muted,
            dashed: free == null,
          ),
        ),
      ],
    );
  }
}
