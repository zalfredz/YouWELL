import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/types/json_map.dart';

const _background = Color(0xff0d0e11);
const _surface = Color(0xff171a20);
const _outline = Color(0xff30343d);
const _primaryText = Color(0xfff2f5f7);
const _secondaryText = Color(0xffa0a7b2);
const _mint = Color(0xff78e3b1);
const _aqua = Color(0xff77d7e5);

/// Daily entry ritual for the desktop workspace. It intentionally reveals
/// details only after a user selects a card from the curated deck.
class DailyCardDrawDialog extends StatefulWidget {
  const DailyCardDrawDialog({super.key, required this.controller});

  final WellnessController controller;

  @override
  State<DailyCardDrawDialog> createState() => _DailyCardDrawDialogState();
}

class _DailyCardDrawDialogState extends State<DailyCardDrawDialog> {
  bool _showDeck = false;

  @override
  void initState() {
    super.initState();
    _showDeck = widget.controller.hasDrawnDailyCards;
  }

  void _startDraw() {
    widget.controller.drawDailyCards();
    setState(() => _showDeck = true);
  }

  void _select(String id) {
    if (widget.controller.selectDailyCard(id)) setState(() {});
  }

  void _commit(JsonMap card) {
    if (!widget.controller.commitDailyCardPack()) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.all(32),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820, maxHeight: 660),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _background,
              border: Border.all(color: _outline),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 40,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AnimatedBuilder(
                animation: widget.controller,
                builder: (context, _) => _showDeck
                    ? _DeckStep(
                        controller: widget.controller,
                        onSelect: _select,
                        onBackToDeck: () {
                          widget.controller.chooseAnotherDailyCard();
                          setState(() {});
                        },
                        onCommit: _commit,
                        onClose: () => Navigator.of(context).pop(false),
                      )
                    : _WelcomeStep(
                        onStart: _startDraw,
                        onClose: () => Navigator.of(context).pop(false),
                      ),
              ),
            ),
          ),
        ),
      );
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onStart, required this.onClose});

  final VoidCallback onStart;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Nanti saja',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, color: _secondaryText),
              ),
            ),
            const Spacer(),
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xff19312a),
                border: Border.all(color: const Color(0xff326550)),
                boxShadow: const [
                  BoxShadow(color: Color(0x335ee2ad), blurRadius: 30),
                ],
              ),
              child: const Icon(Icons.style_rounded, color: _mint, size: 35),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your Daily Draw is ready',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _primaryText,
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            const SizedBox(
              width: 460,
              child: Text(
                'Swipe lima kartu yang sudah disesuaikan dengan ritmemu, lalu pilih satu. Tidak ada hadiah acak—hanya satu langkah yang realistis untuk hari ini.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _secondaryText, height: 1.5),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Open my cards'),
              style: FilledButton.styleFrom(
                backgroundColor: _mint,
                foregroundColor: const Color(0xff0b1a14),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
              ),
            ),
            const SizedBox(height: 13),
            TextButton(onPressed: onClose, child: const Text('Nanti saja')),
            const Spacer(),
            const Text(
              'Satu pilihan yang telah di-commit tidak dapat diganti hari ini.',
              style: TextStyle(color: _secondaryText, fontSize: 11),
            ),
          ],
        ),
      );
}

class _DeckStep extends StatelessWidget {
  const _DeckStep({
    required this.controller,
    required this.onSelect,
    required this.onBackToDeck,
    required this.onCommit,
    required this.onClose,
  });

  final WellnessController controller;
  final ValueChanged<String> onSelect;
  final VoidCallback onBackToDeck;
  final ValueChanged<JsonMap> onCommit;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedDailyCard;
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 25, 30, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Card Draw',
                      style: TextStyle(
                        color: _primaryText,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Pilih kartu yang paling mungkin kamu lakukan hari ini.',
                      style: TextStyle(color: _secondaryText, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _DrawPill(label: '2 switches', color: _aqua),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Tutup',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, color: _secondaryText),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Expanded(
            child: selected == null
                ? _FaceDownDeck(
                    cards: controller.dailyDrawCards,
                    passedCardIds: controller.passedDailyCardIds,
                    initialCardIndex: controller.dailyDeckStartIndex,
                    onSelect: onSelect,
                  )
                : _FlipRevealCard(
                    card: selected,
                    canChooseAnother: controller.canChooseAnotherDailyCard,
                    switchesRemaining: controller.dailyCardSwitchesRemaining,
                    onBackToDeck: onBackToDeck,
                    onCommit: () => onCommit(selected),
                  ),
          ),
        ],
      ),
    );
  }
}

/// An endlessly rotating deck. It completes one automatic cycle on entry,
/// then the user swipes or drags until the preferred card reaches the middle.
class _FaceDownDeck extends StatefulWidget {
  const _FaceDownDeck({
    required this.cards,
    required this.passedCardIds,
    required this.initialCardIndex,
    required this.onSelect,
  });

  final List<JsonMap> cards;
  final List<String> passedCardIds;
  final int initialCardIndex;
  final ValueChanged<String> onSelect;

  @override
  State<_FaceDownDeck> createState() => _FaceDownDeckState();
}

class _FaceDownDeckState extends State<_FaceDownDeck> {
  static const _startPage = 500;
  late final PageController _pageController;
  late final int _initialPage;
  late int _page;
  bool _isAutoSpinning = true;

  @override
  void initState() {
    super.initState();
    _initialPage = _startPage + widget.initialCardIndex;
    _page = _initialPage;
    _pageController = PageController(
      initialPage: _initialPage,
      viewportFraction: .47,
    );
    _spinDeckOnce();
  }

  Future<void> _spinDeckOnce() async {
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted || !_pageController.hasClients) return;
    await _pageController.animateToPage(
      _initialPage + widget.cards.length,
      duration: const Duration(milliseconds: 1150),
      curve: Curves.easeInOutCubic,
    );
    if (mounted) setState(() => _isAutoSpinning = false);
  }

  void _choose(int physicalIndex) {
    if (_isAutoSpinning || physicalIndex != _page) return;
    widget.onSelect(
        widget.cards[physicalIndex % widget.cards.length]['id'].toString());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          const Spacer(),
          Text(
            _isAutoSpinning
                ? 'Shuffling your daily cards…'
                : 'Putar deck, lalu pilih kartu di tengah',
            style: const TextStyle(
              color: _primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isAutoSpinning
                ? 'Menyiapkan lima challenge kecil untukmu.'
                : 'Swipe atau drag kartu ke kiri dan kanan sampai pilihanmu berada di tengah.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _secondaryText, fontSize: 12),
          ),
          const SizedBox(height: 25),
          SizedBox(
            height: 306,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
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
                  controller: _pageController,
                  onPageChanged: (value) => setState(() => _page = value),
                  itemCount: 1000,
                  itemBuilder: (context, physicalIndex) {
                    final cardIndex = physicalIndex % widget.cards.length;
                    return _CarouselCard(
                      index: cardIndex,
                      selected: physicalIndex == _page,
                      passed: widget.passedCardIds
                          .contains(widget.cards[cardIndex]['id'].toString()),
                      onTap: () => _choose(physicalIndex),
                    );
                  },
                ),
              ),
            ),
          ),
          Text(
            _isAutoSpinning
                ? 'Mixing deck'
                : 'Card ${_page % widget.cards.length + 1} of ${widget.cards.length}',
            style: const TextStyle(color: _secondaryText, fontSize: 12),
          ),
          const SizedBox(height: 13),
          Text(
            _isAutoSpinning
                ? 'Sebentar ya…'
                : 'Tap kartu tengah untuk membuka challenge-mu.',
            style: TextStyle(
              color: _isAutoSpinning ? _secondaryText : _mint,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
        ],
      );
}

class _CarouselCard extends StatelessWidget {
  const _CarouselCard({
    required this.index,
    required this.selected,
    required this.passed,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final bool passed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _cardPalettes[index % _cardPalettes.length];
    return Semantics(
      button: selected && !passed,
      label: passed
          ? 'Kartu sudah dilewati'
          : selected
              ? 'Buka kartu tengah'
              : 'Swipe untuk mengganti kartu',
      child: Center(
        child: AnimatedScale(
          duration: const Duration(milliseconds: 210),
          curve: Curves.easeOut,
          scale: selected ? 1 : .76,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: passed
                ? .22
                : selected
                    ? 1
                    : .48,
            child: GestureDetector(
              onTap: selected && !passed ? onTap : null,
              child: Container(
                width: 198,
                height: 282,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [palette.light, palette.dark],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .88),
                    width: 4,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color:
                          palette.dark.withValues(alpha: selected ? .48 : .15),
                      blurRadius: selected ? 27 : 9,
                      offset: const Offset(0, 9),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: -32,
                      top: 47,
                      child: Container(
                        width: 115,
                        height: 115,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .22),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 13,
                      top: 13,
                      child: Text(
                        '0${index + 1}',
                        style: TextStyle(
                          color: palette.ink.withValues(alpha: .55),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 15,
                      left: 15,
                      child: Text(
                        'YOUWELL.MD',
                        style: TextStyle(
                          color: palette.ink,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .8,
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 104,
                        height: 112,
                        decoration: BoxDecoration(
                          color: palette.character,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .8),
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(42),
                          boxShadow: [
                            BoxShadow(
                              color: palette.ink.withValues(alpha: .2),
                              blurRadius: 8,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Stack(children: [
                          Positioned(
                            top: 23,
                            left: 24,
                            child: _MascotEye(color: palette.ink),
                          ),
                          Positioned(
                            top: 23,
                            right: 24,
                            child: _MascotEye(color: palette.ink),
                          ),
                          Center(
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white.withValues(alpha: .85),
                              size: 41,
                            ),
                          ),
                        ]),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 15,
                      child: Column(children: [
                        Text(
                          'MYSTERY',
                          style: TextStyle(
                            color: palette.ink,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          passed
                              ? 'PASSED'
                              : selected
                                  ? 'TAP TO REVEAL'
                                  : 'SWIPE DECK',
                          style: TextStyle(
                            color: palette.ink.withValues(alpha: .72),
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .8,
                          ),
                        ),
                      ]),
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

class _MascotEye extends StatelessWidget {
  const _MascotEye({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 12,
        height: 18,
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      );
}

class _CardPalette {
  const _CardPalette(this.light, this.dark, this.character, this.ink);

  final Color light;
  final Color dark;
  final Color character;
  final Color ink;
}

const _cardPalettes = [
  _CardPalette(Color(0xffd9ff6f), Color(0xff9ee53b), Color(0xff9167ed),
      Color(0xff27351c)),
  _CardPalette(Color(0xff98f3ff), Color(0xff4bcbe0), Color(0xffff8cab),
      Color(0xff12373e)),
  _CardPalette(Color(0xffffd782), Color(0xffffa94b), Color(0xff60bf96),
      Color(0xff553315)),
  _CardPalette(Color(0xffffb6d5), Color(0xffff79ad), Color(0xff6d77e9),
      Color(0xff4a1831)),
  _CardPalette(Color(0xffc9bdff), Color(0xff9681ef), Color(0xffffd76b),
      Color(0xff28204d)),
];

_CardPalette _paletteFor(JsonMap card) {
  final rawStyle = card['cardStyle'];
  final style = rawStyle is num ? rawStyle.toInt() : 0;
  return _cardPalettes[style % _cardPalettes.length];
}

/// A physical-looking 3D turn replaces the previous cross-fade when a card
/// is revealed. The front is only painted after the card reaches its edge.
class _FlipRevealCard extends StatelessWidget {
  const _FlipRevealCard({
    required this.card,
    required this.canChooseAnother,
    required this.switchesRemaining,
    required this.onBackToDeck,
    required this.onCommit,
  });

  final JsonMap card;
  final bool canChooseAnother;
  final int switchesRemaining;
  final VoidCallback onBackToDeck;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 760),
        curve: Curves.easeInOutCubic,
        tween: Tween(begin: 0, end: 1),
        builder: (context, progress, _) {
          final showFront = progress >= .5;
          final angle =
              showFront ? math.pi * (1 - progress) : math.pi * progress;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .0014)
              ..rotateY(angle),
            child: showFront
                ? _RevealedCard(
                    card: card,
                    canChooseAnother: canChooseAnother,
                    switchesRemaining: switchesRemaining,
                    onBackToDeck: onBackToDeck,
                    onCommit: onCommit,
                  )
                : _RevealCardBack(palette: _paletteFor(card)),
          );
        },
      );
}

class _RevealCardBack extends StatelessWidget {
  const _RevealCardBack({required this.palette});

  final _CardPalette palette;

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 360,
          height: 300,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [palette.light, palette.dark],
            ),
            border: Border.all(
                color: Colors.white.withValues(alpha: .85), width: 3),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: palette.dark.withValues(alpha: .45), blurRadius: 30)
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -32,
                right: -18,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 130,
                  color: Colors.white.withValues(alpha: .20),
                ),
              ),
              Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.style_rounded, size: 54, color: palette.ink),
                  const SizedBox(height: 15),
                  Text(
                    'REVEALING…',
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      );
}

class _RevealedCard extends StatelessWidget {
  const _RevealedCard({
    required this.card,
    required this.canChooseAnother,
    required this.switchesRemaining,
    required this.onBackToDeck,
    required this.onCommit,
  });

  final JsonMap card;
  final bool canChooseAnother;
  final int switchesRemaining;
  final VoidCallback onBackToDeck;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(card);
    final tasks = ((card['tasks'] ?? []) as List)
        .map((task) => Map<String, dynamic>.from(task))
        .toList();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 470),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [palette.dark.withValues(alpha: .54), _surface],
            ),
            border: Border.all(color: palette.light.withValues(alpha: .78)),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: palette.dark.withValues(alpha: .32), blurRadius: 28),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DrawPill(label: 'YOUR DAILY CARD', color: palette.light),
              const SizedBox(height: 22),
              Text(
                card['title'].toString(),
                style: const TextStyle(
                  color: _primaryText,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                card['description'].toString(),
                style: const TextStyle(color: _secondaryText, height: 1.5),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _DrawPill(
                      label: '${tasks.length} TASKS', color: palette.character),
                  const Spacer(),
                  Text(
                    '+${card['xp']} XP total',
                    style: TextStyle(
                      color: palette.light,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...tasks.indexed.map(
                (entry) => _TaskPreviewRow(
                  task: entry.$2,
                  number: entry.$1 + 1,
                  color: palette.light,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onCommit,
                  icon: const Icon(Icons.lock_rounded),
                  label: Text('Commit ${tasks.length} tasks'),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.light,
                    foregroundColor: palette.ink,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (canChooseAnother)
                Center(
                  child: TextButton(
                    onPressed: onBackToDeck,
                    child: Text(
                      'Pilih kartu lain ($switchesRemaining switch tersisa)',
                    ),
                  ),
                )
              else
                const Center(
                  child: Text(
                    'Pilihan ketiga harus di-commit agar deck tetap fair.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _secondaryText, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskPreviewRow extends StatelessWidget {
  const _TaskPreviewRow({
    required this.task,
    required this.number,
    required this.color,
  });

  final JsonMap task;
  final int number;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .16),
          border: Border.all(color: Colors.white.withValues(alpha: .12)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Text('$number',
                style: const TextStyle(
                    color: _background,
                    fontSize: 10,
                    fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(task['title'].toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _primaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Text('+${task['xp']} XP',
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w800)),
        ]),
      );
}

class _DrawPill extends StatelessWidget {
  const _DrawPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          border: Border.all(color: color.withValues(alpha: .35)),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .5,
          ),
        ),
      );
}
