import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/types/json_map.dart';

/// Shared mobile/web draw ritual: spin, swipe, reveal, then commit one pack.
class DailyCardDrawDialog extends StatefulWidget {
  const DailyCardDrawDialog({super.key, required this.controller});
  final WellnessController controller;

  @override
  State<DailyCardDrawDialog> createState() => _DailyCardDrawDialogState();
}

class _DailyCardDrawDialogState extends State<DailyCardDrawDialog> {
  @override
  void initState() {
    super.initState();
    widget.controller.drawDailyCards();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final compact = MediaQuery.sizeOf(context).width < 600;
      return Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 32,
          vertical: compact ? 20 : 32,
        ),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 820,
            maxHeight: compact ? 650 : 700,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: appCanvas,
              border: Border.all(color: appBorder),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 40,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: _DrawStage(
                controller: widget.controller,
                onClose: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _DrawStage extends StatelessWidget {
  const _DrawStage({required this.controller, required this.onClose});
  final WellnessController controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final selected = controller.selectedDailyCard;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 18 : 28,
        compact ? 16 : 24,
        compact ? 18 : 28,
        compact ? 18 : 26,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Daily Card Draw',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
              ),
              _Pill(label: '${controller.dailyCardSwitchesRemaining}x ganti'),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Nanti saja',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, color: appMuted),
              ),
            ],
          ),
          const Text(
            'Satu kartu, 3–5 quest. Swipe lalu buka.',
            style: TextStyle(color: appMuted),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: selected == null
                ? _SpinningDeck(
                    key: ValueKey(
                      '${controller.dailyDeckStartIndex}-${controller.passedDailyCardIds.length}',
                    ),
                    cards: controller.dailyDrawCards,
                    passedIds: controller.passedDailyCardIds,
                    initialIndex: controller.dailyDeckStartIndex,
                    onSelect: controller.selectDailyCard,
                  )
                : _FlipReveal(
                    key: ValueKey(selected['id']),
                    card: selected,
                    canChange: controller.canChooseAnotherDailyCard,
                    changesLeft: controller.dailyCardSwitchesRemaining,
                    onChange: controller.chooseAnotherDailyCard,
                    onCommit: () {
                      if (controller.commitDailyCardPack()) onClose();
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SpinningDeck extends StatefulWidget {
  const _SpinningDeck({
    super.key,
    required this.cards,
    required this.passedIds,
    required this.initialIndex,
    required this.onSelect,
  });
  final List<JsonMap> cards;
  final List<String> passedIds;
  final int initialIndex;
  final ValueChanged<String> onSelect;

  @override
  State<_SpinningDeck> createState() => _SpinningDeckState();
}

class _SpinningDeckState extends State<_SpinningDeck> {
  static const _basePage = 500;
  final math.Random _random = math.Random();
  late final PageController _pages;
  late final int _startPage;
  late int _page;
  bool _spinning = true;

  @override
  void initState() {
    super.initState();
    _startPage = _basePage + widget.initialIndex;
    _page = _startPage;
    _pages = PageController(initialPage: _startPage, viewportFraction: .48);
    WidgetsBinding.instance.addPostFrameCallback((_) => _spin());
  }

  Future<void> _spin() async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted || !_pages.hasClients) return;
    final availableIndices = [
      for (var index = 0; index < widget.cards.length; index++)
        if (!widget.passedIds.contains(widget.cards[index]['id'])) index,
    ];
    if (availableIndices.isEmpty) {
      setState(() => _spinning = false);
      return;
    }
    final destination =
        availableIndices[_random.nextInt(availableIndices.length)];
    final deckLength = widget.cards.length;
    final fullTurns = 2 + _random.nextInt(2);
    final offset = (destination - (_startPage % deckLength)) % deckLength;
    await _pages.animateToPage(
      _startPage + fullTurns * deckLength + offset,
      duration: const Duration(milliseconds: 1450),
      curve: Curves.easeInOutCubicEmphasized,
    );
    if (mounted) setState(() => _spinning = false);
  }

  void _choose(int physicalIndex) {
    if (_spinning || physicalIndex != _page) return;
    final card = widget.cards[physicalIndex % widget.cards.length];
    if (widget.passedIds.contains(card['id'])) return;
    widget.onSelect(card['id'].toString());
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SizedBox(
              height: compact ? 350 : 390,
              child: MouseRegion(
                cursor: _spinning
                    ? SystemMouseCursors.wait
                    : SystemMouseCursors.grab,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: const {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                      PointerDeviceKind.stylus,
                    },
                  ),
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: 1000,
                    physics: _spinning
                        ? const NeverScrollableScrollPhysics()
                        : const BouncingScrollPhysics(),
                    onPageChanged: (value) => setState(() => _page = value),
                    itemBuilder: (context, physicalIndex) {
                      final index = physicalIndex % widget.cards.length;
                      return _CardBack(
                        index: index,
                        centered: physicalIndex == _page,
                        passed: widget.passedIds.contains(
                          widget.cards[index]['id'],
                        ),
                        compact: compact,
                        onTap: () => _choose(physicalIndex),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            _spinning
                ? 'Mengocok deck…'
                : '${_page % widget.cards.length + 1} / ${widget.cards.length}  •  Tap kartu tengah',
            key: ValueKey(_spinning),
            style: TextStyle(
              color: _spinning ? appAccent : appMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({
    required this.index,
    required this.centered,
    required this.passed,
    required this.compact,
    required this.onTap,
  });
  final int index;
  final bool centered, passed, compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _palettes[index % _palettes.length];
    return Center(
      child: AnimatedScale(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        scale: centered ? 1 : .74,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: passed
              ? centered
                    ? .78
                    : .58
              : centered
              ? 1
              : .5,
          child: GestureDetector(
            onTap: centered && !passed ? onTap : null,
            child: ColorFiltered(
              colorFilter: passed
                  ? const ColorFilter.matrix([
                      .2126,
                      .7152,
                      .0722,
                      0,
                      0,
                      .2126,
                      .7152,
                      .0722,
                      0,
                      0,
                      .2126,
                      .7152,
                      .0722,
                      0,
                      0,
                      0,
                      0,
                      0,
                      1,
                      0,
                    ])
                  : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
              child: Container(
                width: compact ? 190 : 220,
                height: compact ? 310 : 350,
                decoration: _cardDecoration(palette, centered),
                child: Stack(
                  children: [
                    Positioned(
                      left: -38,
                      top: 58,
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .2),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      top: 16,
                      child: Text(
                        'YOUWELL',
                        style: TextStyle(
                          color: palette.ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 16,
                      top: 16,
                      child: Text(
                        '0${index + 1}',
                        style: TextStyle(
                          color: palette.ink.withValues(alpha: .6),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Center(child: _CardMascot(palette: palette)),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 18,
                      child: Column(
                        children: [
                          Text(
                            passed ? 'SUDAH DILEWATI' : 'MYSTERY',
                            style: TextStyle(
                              color: palette.ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            passed
                                ? 'TIDAK BISA DIPILIH'
                                : centered
                                ? 'TAP TO REVEAL'
                                : 'SWIPE DECK',
                            style: TextStyle(
                              color: palette.ink.withValues(alpha: .7),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardMascot extends StatelessWidget {
  const _CardMascot({required this.palette});
  final _Palette palette;
  @override
  Widget build(BuildContext context) => Container(
    width: 118,
    height: 126,
    decoration: BoxDecoration(
      color: palette.character,
      border: Border.all(color: Colors.white.withValues(alpha: .8), width: 3),
      borderRadius: BorderRadius.circular(44),
      boxShadow: [
        BoxShadow(
          color: palette.ink.withValues(alpha: .22),
          blurRadius: 10,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned(left: 26, top: 28, child: _Eye(color: palette.ink)),
        Positioned(right: 26, top: 28, child: _Eye(color: palette.ink)),
        Center(
          child: Icon(
            Icons.auto_awesome_rounded,
            size: 45,
            color: Colors.white.withValues(alpha: .88),
          ),
        ),
      ],
    ),
  );
}

class _Eye extends StatelessWidget {
  const _Eye({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 12,
    height: 18,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(9),
    ),
  );
}

class _FlipReveal extends StatelessWidget {
  const _FlipReveal({
    super.key,
    required this.card,
    required this.canChange,
    required this.changesLeft,
    required this.onChange,
    required this.onCommit,
  });
  final JsonMap card;
  final bool canChange;
  final int changesLeft;
  final VoidCallback onChange, onCommit;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    duration: const Duration(milliseconds: 760),
    curve: Curves.easeInOutCubic,
    tween: Tween(begin: 0, end: 1),
    builder: (context, progress, _) {
      final front = progress >= .5;
      final angle = front ? math.pi * (1 - progress) : math.pi * progress;
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .0014)
          ..rotateY(angle),
        child: front
            ? _CardFront(
                card: card,
                canChange: canChange,
                changesLeft: changesLeft,
                onChange: onChange,
                onCommit: onCommit,
              )
            : _RevealBack(palette: _paletteFor(card)),
      );
    },
  );
}

class _RevealBack extends StatelessWidget {
  const _RevealBack({required this.palette});
  final _Palette palette;
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 300,
      height: 410,
      decoration: _cardDecoration(palette, true),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.style_rounded, size: 58, color: palette.ink),
            const SizedBox(height: 16),
            Text(
              'REVEALING…',
              style: TextStyle(
                color: palette.ink,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CardFront extends StatelessWidget {
  const _CardFront({
    required this.card,
    required this.canChange,
    required this.changesLeft,
    required this.onChange,
    required this.onCommit,
  });
  final JsonMap card;
  final bool canChange;
  final int changesLeft;
  final VoidCallback onChange, onCommit;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(card);
    final tasks = card['tasks'] is List
        ? (card['tasks'] as List)
              .whereType<Map>()
              .map((task) => Map<String, dynamic>.from(task))
              .toList()
        : [card];
    final difficulty = (card['difficulty'] as num?)?.toInt() ?? 1;
    final difficultyLabel = switch (difficulty) {
      2 => 'Seimbang',
      3 => 'Lebih aktif',
      _ => 'Ringan',
    };
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [palette.dark.withValues(alpha: .5), appSurface],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: palette.light.withValues(alpha: .75)),
              boxShadow: [
                BoxShadow(
                  color: palette.dark.withValues(alpha: .32),
                  blurRadius: 30,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: palette.light,
                  child: Icon(
                    Icons.style_rounded,
                    color: palette.ink,
                    size: 29,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  card['title'].toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: appText,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${tasks.length} quest  •  $difficultyLabel',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: appMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                for (final task in tasks) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: appCanvas.withValues(alpha: .75),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: palette.light.withValues(alpha: .35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _categoryIcon(task['category'].toString()),
                          color: palette.light,
                          size: 19,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            task['title'].toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: appText,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '+${task['xp']} XP',
                          style: TextStyle(
                            color: palette.light,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                const SizedBox(height: 8),
                _Pill(
                  label:
                      '${card['durationMinutes']} MIN TOTAL  •  +${card['xp']} XP',
                  color: palette.light,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onCommit,
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.light,
                      foregroundColor: palette.ink,
                    ),
                    icon: const Icon(Icons.lock_rounded),
                    label: Text('Ambil ${tasks.length} quest'),
                  ),
                ),
                if (canChange) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: onChange,
                    child: Text('Pilih kartu lain ($changesLeft tersisa)'),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Kesempatan ganti habis. Ambil kartu ini.',
                    style: TextStyle(color: appMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.color = appAccent});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .13),
      border: Border.all(color: color.withValues(alpha: .45)),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
    ),
  );
}

class _Palette {
  const _Palette(this.light, this.dark, this.character, this.ink);
  final Color light, dark, character, ink;
}

const _palettes = [
  _Palette(
    Color(0xffd9ff6f),
    Color(0xff9ee53b),
    Color(0xff9167ed),
    Color(0xff27351c),
  ),
  _Palette(
    Color(0xff98f3ff),
    Color(0xff4bcbe0),
    Color(0xffff8cab),
    Color(0xff12373e),
  ),
  _Palette(
    Color(0xffffd782),
    Color(0xffffa94b),
    Color(0xff60bf96),
    Color(0xff553315),
  ),
  _Palette(
    Color(0xffffb6d5),
    Color(0xffff79ad),
    Color(0xff6d77e9),
    Color(0xff4a1831),
  ),
  _Palette(
    Color(0xffc9bdff),
    Color(0xff9681ef),
    Color(0xffffd76b),
    Color(0xff28204d),
  ),
];

_Palette _paletteFor(JsonMap card) =>
    _palettes[((card['cardStyle'] as num?)?.toInt() ?? 0) % _palettes.length];

BoxDecoration _cardDecoration(_Palette palette, bool active) => BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [palette.light, palette.dark],
  ),
  border: Border.all(color: Colors.white.withValues(alpha: .88), width: 4),
  borderRadius: BorderRadius.circular(22),
  boxShadow: [
    BoxShadow(
      color: palette.dark.withValues(alpha: active ? .48 : .15),
      blurRadius: active ? 28 : 10,
      offset: const Offset(0, 10),
    ),
  ],
);

IconData _categoryIcon(String category) => switch (category) {
  'Body' => Icons.directions_walk_rounded,
  'Energy' => Icons.bolt_rounded,
  'Reduction' => Icons.air_rounded,
  _ => Icons.auto_awesome_rounded,
};
