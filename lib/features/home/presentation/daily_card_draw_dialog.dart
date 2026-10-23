import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/types/json_map.dart';

/// Shared mobile/web draw ritual: spin, swipe, reveal, then commit one pack.
class DailyCardDrawDialog extends StatefulWidget {
  const DailyCardDrawDialog({
    super.key,
    required this.controller,
    this.mobileExperience = false,
  });
  final WellnessController controller;
  final bool mobileExperience;

  @override
  State<DailyCardDrawDialog> createState() => _DailyCardDrawDialogState();
}

class _DailyCardDrawDialogState extends State<DailyCardDrawDialog> {
  @override
  void initState() {
    super.initState();
    // Saving notifies listeners, so wait until this first frame is built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.drawDailyCards();
    });
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
              color: context.colors.canvas,
              border: Border.all(color: context.colors.border),
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
                mobileExperience: widget.mobileExperience,
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
  const _DrawStage({
    required this.controller,
    required this.onClose,
    required this.mobileExperience,
  });
  final WellnessController controller;
  final VoidCallback onClose;
  final bool mobileExperience;

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
              Expanded(
                child: Text(
                  mobileExperience ? 'Kartu hari ini' : 'Daily Card Draw',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                tooltip: 'Nanti saja',
                onPressed: onClose,
                icon: Icon(Icons.close_rounded, color: context.colors.muted),
              ),
            ],
          ),
          Text(
            mobileExperience
                ? 'Pilih 1 kartu berisi 3–5 misi.'
                : 'Satu kartu, 3–5 quest. Swipe lalu buka.',
            style: TextStyle(
              color: context.colors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: selected == null
                ? _SpinningDeck(
                    key: ValueKey(
                      '${controller.dailyDeckStartIndex}-${controller.passedDailyCardIds.length}-${controller.dailyPace}',
                    ),
                    cards: controller.dailyDrawCards,
                    passedIds: controller.passedDailyCardIds,
                    initialIndex: controller.dailyDeckStartIndex,
                    onSelect: controller.selectDailyCard,
                    reduceMotion:
                        mobileExperience &&
                        (controller.reduceMotion ||
                            MediaQuery.disableAnimationsOf(context)),
                  )
                : _FlipReveal(
                    key: ValueKey(selected['id']),
                    card: selected,
                    reduceMotion:
                        mobileExperience &&
                        (controller.reduceMotion ||
                            MediaQuery.disableAnimationsOf(context)),
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
    this.reduceMotion = false,
  });
  final List<JsonMap> cards;
  final List<String> passedIds;
  final int initialIndex;
  final ValueChanged<String> onSelect;
  final bool reduceMotion;

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
  Timer? _spinTimer, _settleTimer;

  /// Snaps to the nearest card once scrolling has been quiet briefly.
  void _settle() {
    _settleTimer?.cancel();
    _settleTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted || _spinning || !_pages.hasClients) return;
      final page = _pages.page;
      if (page == null) return;
      final nearest = page.round();
      if ((page - nearest).abs() < .01) return;
      _pages.animateToPage(
        nearest,
        duration: Duration(milliseconds: widget.reduceMotion ? 1 : 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _startPage = _basePage + widget.initialIndex;
    _page = _startPage;
    _pages = PageController(initialPage: _startPage, viewportFraction: .48);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _spinTimer = Timer(
        const Duration(milliseconds: 220),
        () => unawaited(_spin()),
      );
    });
  }

  Future<void> _spin() async {
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
    if (widget.reduceMotion) {
      _pages.jumpToPage(_startPage + offset);
    } else {
      await _pages.animateToPage(
        _startPage + fullTurns * deckLength + offset,
        duration: const Duration(milliseconds: 1450),
        curve: Curves.easeInOutCubicEmphasized,
      );
    }
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
    _spinTimer?.cancel();
    _settleTimer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final current = widget.cards.isEmpty ? 0 : _page % widget.cards.length;
    final glow = _palettes[current % _palettes.length].dark;
    return Stack(
      children: [
        // A soft glow in the centred card's colour, easing between cards.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: .9,
                  colors: [
                    glow.withValues(alpha: dark ? .30 : .22),
                    glow.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
        Column(
          children: [
            Expanded(
              child: Center(
                child: SizedBox(
                  height: compact ? 360 : 400,
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
                      // Wheel and trackpad scrolls do not snap on their own,
                      // so every scroll ends on the nearest card.
                      child: NotificationListener<ScrollEndNotification>(
                        onNotification: (_) {
                          _settle();
                          return false;
                        },
                        child: PageView.builder(
                          controller: _pages,
                          itemCount: 1000,
                          physics: _spinning
                              ? const NeverScrollableScrollPhysics()
                              : const BouncingScrollPhysics(),
                          onPageChanged: (value) =>
                              setState(() => _page = value),
                          itemBuilder: (context, physicalIndex) {
                            final index = physicalIndex % widget.cards.length;
                            // Follows the finger: size, tilt and fade come
                            // from the live page position, not a snap.
                            return AnimatedBuilder(
                              animation: _pages,
                              builder: (context, child) {
                                final page =
                                    _pages.hasClients &&
                                        _pages.position.haveDimensions
                                    ? _pages.page ?? _page.toDouble()
                                    : _page.toDouble();
                                final delta = (physicalIndex - page).clamp(
                                  -2.0,
                                  2.0,
                                );
                                final distance = delta.abs().clamp(0.0, 1.0);
                                return Opacity(
                                  opacity: 1 - .45 * distance,
                                  child: Transform(
                                    alignment: Alignment.bottomCenter,
                                    transform: Matrix4.identity()
                                      ..translateByDouble(
                                        0,
                                        22 * distance,
                                        0,
                                        1,
                                      )
                                      ..rotateZ(delta * .09)
                                      ..scaleByDouble(
                                        1 - .2 * distance,
                                        1 - .2 * distance,
                                        1,
                                        1,
                                      ),
                                    child: child,
                                  ),
                                );
                              },
                              child: _CardBack(
                                index: index,
                                centered: physicalIndex == _page && !_spinning,
                                passed: widget.passedIds.contains(
                                  widget.cards[index]['id'],
                                ),
                                compact: compact,
                                onTap: () => _choose(physicalIndex),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 22,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _spinning
                    ? Text(
                        'Mengocok kartu…',
                        key: const ValueKey('spin'),
                        style: TextStyle(
                          color: context.colors.muted,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : Row(
                        key: const ValueKey('dots'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < widget.cards.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == current ? 22 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: i == current
                                    ? _palettes[i % _palettes.length].dark
                                    : context.colors.muted.withValues(
                                        alpha:
                                            widget.passedIds.contains(
                                              widget.cards[i]['id'],
                                            )
                                            ? .15
                                            : .35,
                                      ),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ],
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: GestureDetector(
        onTap: centered && !passed ? onTap : null,
        child: ColorFiltered(
          colorFilter: passed
              ? const ColorFilter.matrix([
                  .2126, .7152, .0722, 0, 0, //
                  .2126, .7152, .0722, 0, 0, //
                  .2126, .7152, .0722, 0, 0, //
                  0, 0, 0, .7, 0,
                ])
              : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
          child: Container(
            width: compact ? 196 : 226,
            height: compact ? 318 : 358,
            decoration: _cardDecoration(palette, centered, dark: dark),
            child: Stack(
              children: [
                // Two soft bubbles for depth.
                Positioned(
                  left: -40,
                  top: 50,
                  child: _Bubble(size: 130, alpha: .22),
                ),
                Positioned(
                  right: -30,
                  bottom: 70,
                  child: _Bubble(size: 90, alpha: .16),
                ),
                Positioned(
                  left: 16,
                  top: 16,
                  child: Text(
                    'YOUWELL',
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 12,
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
                      color: palette.ink.withValues(alpha: .7),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Center(child: _CardMascot(palette: palette)),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 22,
                  child: Text(
                    passed ? 'SUDAH DILEWATI' : 'KARTU MISI',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.alpha});
  final double size, alpha;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: alpha),
      shape: BoxShape.circle,
    ),
  );
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
      border: Border.all(color: Colors.white, width: 3),
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
            color: palette.dark,
          ),
        ),
      ],
    ),
  );
}

class _Eye extends StatelessWidget {
  const _Eye({required this.color});
  final Color? color;
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
    this.reduceMotion = false,
  });
  final JsonMap card;
  final bool canChange;
  final int changesLeft;
  final VoidCallback onChange, onCommit;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    duration: Duration(milliseconds: reduceMotion ? 0 : 680),
    curve: Curves.easeInOutCubic,
    tween: Tween(begin: 0, end: 1),
    builder: (context, progress, _) {
      final front = progress >= .5;
      final angle = front ? math.pi * (1 - progress) : math.pi * progress;
      // Lifts towards the viewer mid-turn, then settles.
      final lift = 1 + .06 * math.sin(progress * math.pi);
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .0014)
          ..rotateY(angle)
          ..scaleByDouble(lift, lift, 1, 1),
        child: front
            ? _CardFront(
                card: card,
                canChange: canChange,
                changesLeft: changesLeft,
                onChange: onChange,
                onCommit: onCommit,
                animate: !reduceMotion,
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
      decoration: _cardDecoration(
        palette,
        true,
        dark: Theme.of(context).brightness == Brightness.dark,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.style_rounded, size: 58, color: palette.ink),
            const SizedBox(height: 16),
            Text(
              'MEMBUKA…',
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
    this.animate = true,
  });
  final JsonMap card;
  final bool canChange;
  final int changesLeft;
  final VoidCallback onChange, onCommit;
  final bool animate;

  /// Rows slide in one after another (40 ms apart) once the card is open.
  Widget _stagger(int index, Widget child) => !animate
      ? child
      : TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 320 + 40 * index),
          curve: Interval(
            (40 * index) / (320 + 40 * index),
            1,
            curve: Curves.easeOutCubic,
          ),
          child: child,
          builder: (context, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(
              offset: Offset(0, 12 * (1 - v)),
              child: child,
            ),
          ),
        );

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(card);
    final tasks = card['tasks'] is List
        ? (card['tasks'] as List)
              .whereType<Map>()
              .map((task) => Map<String, dynamic>.from(task))
              .toList()
        : [card];
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(24),
            // Tinted with the card's own colour, fading into the surface.
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  palette.dark.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? .28
                        : .22,
                  ),
                  context.colors.surface,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: palette.dark.withValues(alpha: .6),
                width: 2,
              ),
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
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [palette.light, palette.dark],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: palette.dark.withValues(alpha: .4),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: palette.ink,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 14),
                for (final (taskIndex, task) in tasks.indexed) ...[
                  _stagger(
                    taskIndex,
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.canvas.withValues(alpha: .75),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: palette.light.withValues(alpha: .35),
                        ),
                      ),
                      // Long titles wrap to two lines instead of being cut.
                      child: Row(
                        children: [
                          Icon(
                            questIcon(task),
                            color: context.colors.accent,
                            size: 19,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              task['title'].toString(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.colors.text,
                                fontSize: 13,
                                height: 1.25,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '+${task['xp']} XP',
                            style: TextStyle(
                              color: context.colors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onCommit,
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.dark,
                      foregroundColor: palette.ink,
                    ),
                    icon: const Icon(Icons.rocket_launch_rounded),
                    label: const Text('Mulai misi'),
                  ),
                ),
                // Small, under the main button; gone once used.
                if (canChange)
                  TextButton(
                    onPressed: onChange,
                    style: TextButton.styleFrom(
                      foregroundColor: context.colors.muted,
                      // From the theme, so it keeps the app font.
                      textStyle: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                    child: Text('Pilih kartu lain ($changesLeft)'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Palette {
  const _Palette(this.light, this.dark, this.character, this.ink);
  final Color light, dark, character, ink;
}

// Bright gradients (light → deep) with a dark ink that keeps text at
// 4.5:1 or better on both ends; they read well on light and dark canvases.
const _palettes = [
  // Sunny
  _Palette(
    Color(0xffffe066),
    Color(0xffff922b),
    Colors.white,
    Color(0xff3b2200),
  ),
  // Mint
  _Palette(
    Color(0xff96f2d7),
    Color(0xff20c997),
    Colors.white,
    Color(0xff053b2c),
  ),
  // Sky
  _Palette(
    Color(0xffa5d8ff),
    Color(0xff4dabf7),
    Colors.white,
    Color(0xff0b2545),
  ),
  // Bubblegum
  _Palette(
    Color(0xffffc9de),
    Color(0xfff783ac),
    Colors.white,
    Color(0xff4a0d2a),
  ),
  // Grape
  _Palette(
    Color(0xffd0bfff),
    Color(0xff9775fa),
    Colors.white,
    Color(0xff1f0f4d),
  ),
];

_Palette _paletteFor(JsonMap card) =>
    _palettes[((card['cardStyle'] as num?)?.toInt() ?? 0) % _palettes.length];

BoxDecoration _cardDecoration(
  _Palette palette,
  bool active, {
  bool dark = false,
}) => BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [palette.light, palette.dark],
  ),
  // A softer rim in dark mode so the card glows instead of glaring.
  border: Border.all(
    color: Colors.white.withValues(alpha: dark ? .45 : .9),
    width: 4,
  ),
  borderRadius: BorderRadius.circular(24),
  boxShadow: [
    BoxShadow(
      color: palette.dark.withValues(alpha: active ? (dark ? .55 : .45) : .12),
      blurRadius: active ? 30 : 10,
      offset: const Offset(0, 12),
    ),
  ],
);
