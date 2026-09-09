import 'dart:math' as math;

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
const _gold = Color(0xffffc875);

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
    if (!widget.controller.commitCard(card['id'].toString())) return;
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
                          widget.controller.clearDailyCardSelection();
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
                'Pilih satu dari tiga kartu kecil yang sudah disesuaikan dengan ritmemu. Tidak ada hadiah acak—hanya satu langkah yang realistis untuk hari ini.',
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
              _DrawPill(label: '1 choice', color: _aqua),
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
                    cards: controller.dailyCards, onSelect: onSelect)
                : _FlipRevealCard(
                    card: selected,
                    onBackToDeck: onBackToDeck,
                    onCommit: () => onCommit(selected),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FaceDownDeck extends StatelessWidget {
  const _FaceDownDeck({required this.cards, required this.onSelect});

  final List<JsonMap> cards;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          const Spacer(),
          const Text(
            'Tap one card to reveal your challenge',
            style: TextStyle(
              color: _primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Kamu dapat kembali sebelum menekan Commit.',
            style: TextStyle(color: _secondaryText, fontSize: 12),
          ),
          const SizedBox(height: 32),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 18,
            runSpacing: 18,
            children: cards.indexed
                .map(
                  (entry) => _FaceDownCard(
                    index: entry.$1,
                    onTap: () => onSelect(entry.$2['id'].toString()),
                  ),
                )
                .toList(),
          ),
          const Spacer(flex: 2),
        ],
      );
}

class _FaceDownCard extends StatelessWidget {
  const _FaceDownCard({required this.index, required this.onTap});

  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accents = [_mint, _aqua, _gold];
    final accent = accents[index % accents.length];
    return Semantics(
      button: true,
      label: 'Pilih kartu ${index + 1}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 174,
          height: 242,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [const Color(0xff252b34), const Color(0xff171a20)],
            ),
            border: Border.all(color: accent.withValues(alpha: .45)),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: accent.withValues(alpha: .10), blurRadius: 20),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -26,
                right: -22,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 100,
                  color: accent.withValues(alpha: .13),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.style_rounded, size: 39, color: accent),
                    const SizedBox(height: 15),
                    const Text(
                      'DAILY CARD',
                      style: TextStyle(
                        color: _primaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Tap to reveal',
                      style: TextStyle(color: accent, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A physical-looking 3D turn replaces the previous cross-fade when a card
/// is revealed. The front is only painted after the card reaches its edge.
class _FlipRevealCard extends StatelessWidget {
  const _FlipRevealCard({
    required this.card,
    required this.onBackToDeck,
    required this.onCommit,
  });

  final JsonMap card;
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
                    onBackToDeck: onBackToDeck,
                    onCommit: onCommit,
                  )
                : const _RevealCardBack(),
          );
        },
      );
}

class _RevealCardBack extends StatelessWidget {
  const _RevealCardBack();

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 360,
          height: 300,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff29313a), Color(0xff16191e)],
            ),
            border: Border.all(color: _mint.withValues(alpha: .55)),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Color(0x335ee2ad), blurRadius: 30)
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
                  color: _mint.withValues(alpha: .12),
                ),
              ),
              const Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.style_rounded, size: 54, color: _mint),
                  SizedBox(height: 15),
                  Text(
                    'REVEALING…',
                    style: TextStyle(
                      color: _primaryText,
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
    required this.onBackToDeck,
    required this.onCommit,
  });

  final JsonMap card;
  final VoidCallback onBackToDeck;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    final difficulty = (card['difficulty'] as num).toInt();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 470),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surface,
            border: Border.all(color: _mint.withValues(alpha: .55)),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(color: Color(0x225ee2ad), blurRadius: 28),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DrawPill(label: 'YOUR DAILY CARD', color: _mint),
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
              const SizedBox(height: 22),
              Row(
                children: [
                  _DrawPill(label: card['category'].toString(), color: _aqua),
                  const Spacer(),
                  Text(
                    'Difficulty: ${'★' * difficulty}${'☆' * (3 - difficulty)}',
                    style: const TextStyle(color: _gold, fontSize: 12),
                  ),
                  const SizedBox(width: 13),
                  Text(
                    '+${card['xp']} XP',
                    style: const TextStyle(
                      color: _mint,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onCommit,
                  icon: const Icon(Icons.lock_rounded),
                  label: const Text('Commit this challenge'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _mint,
                    foregroundColor: const Color(0xff0b1a14),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: onBackToDeck,
                  child: const Text('Pilih kartu lain dulu'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
