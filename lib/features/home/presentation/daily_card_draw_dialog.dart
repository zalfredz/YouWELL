import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';

class DailyCardDrawDialog extends StatefulWidget {
  const DailyCardDrawDialog({super.key, required this.controller});
  final WellnessController controller;
  @override
  State<DailyCardDrawDialog> createState() => _DailyCardDrawDialogState();
}

class _DailyCardDrawDialogState extends State<DailyCardDrawDialog> {
  late PageController _pages;
  late int _index;

  @override
  void initState() {
    super.initState();
    widget.controller.drawDailyCards();
    _index = widget.controller.dailyDeckStartIndex;
    _pages = PageController(initialPage: _index, viewportFraction: .72);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _reveal() {
    final card = widget.controller.dailyDrawCards[_index];
    if (widget.controller.passedDailyCardIds.contains(card['id'])) return;
    widget.controller.selectDailyCard(card['id'].toString());
    setState(() {});
  }

  void _another() {
    if (!widget.controller.chooseAnotherDailyCard()) return;
    final cards = widget.controller.dailyDrawCards;
    final next =
        List.generate(
          cards.length,
          (i) => (_index + i + 1) % cards.length,
        ).firstWhere(
          (i) => !widget.controller.passedDailyCardIds.contains(cards[i]['id']),
        );
    setState(() => _index = next);
    _pages.animateToPage(
      next,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.controller.dailyDrawCards;
    final selected = widget.controller.selectedDailyCard;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    'Bonus Card',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  if (selected != null)
                    tag(
                      '${widget.controller.dailyCardSwitchesRemaining} ganti',
                    ),
                  if (widget.controller.hasCommittedDailyCard)
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Swipe, pilih, lalu buka.',
                  style: TextStyle(color: appMuted),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: cards.length,
                  onPageChanged: selected == null
                      ? (value) => setState(() => _index = value)
                      : null,
                  physics: selected == null
                      ? const BouncingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    final revealed = selected?['id'] == card['id'];
                    final passed = widget.controller.passedDailyCardIds
                        .contains(card['id']);
                    return AnimatedScale(
                      scale: index == _index ? 1 : .88,
                      duration: const Duration(milliseconds: 220),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 12,
                        ),
                        child: _CollectibleCard(
                          card: card,
                          revealed: revealed,
                          disabled: passed,
                          onTap: index == _index && selected == null
                              ? _reveal
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (selected == null)
                Text(
                  '${_index + 1} / ${cards.length}',
                  style: const TextStyle(color: appMuted),
                )
              else ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (widget.controller.canChooseAnotherDailyCard)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _another,
                          child: const Text('Pilih lain'),
                        ),
                      ),
                    if (widget.controller.canChooseAnotherDailyCard)
                      const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          if (widget.controller.commitDailyCardPack()) {
                            Navigator.pop(context);
                          }
                        },
                        child: const Text('Ambil card'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectibleCard extends StatelessWidget {
  const _CollectibleCard({
    required this.card,
    required this.revealed,
    required this.disabled,
    required this.onTap,
  });
  final Map<String, dynamic> card;
  final bool revealed, disabled;
  final VoidCallback? onTap;

  static const colors = [
    (Color(0xffb8f34b), Color(0xff21351d)),
    (Color(0xff77d7e5), Color(0xff17343a)),
    (Color(0xffffc875), Color(0xff473313)),
    (Color(0xffb69cff), Color(0xff2b2147)),
    (Color(0xffff91ad), Color(0xff48232d)),
  ];

  @override
  Widget build(BuildContext context) {
    final palette =
        colors[((card['cardStyle'] as num?)?.toInt() ?? 0) % colors.length];
    return Material(
      color: disabled ? appRaised : palette.$1,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withValues(alpha: .7),
              width: 4,
            ),
            boxShadow: disabled
                ? null
                : [
                    BoxShadow(
                      color: palette.$1.withValues(alpha: .22),
                      blurRadius: 26,
                    ),
                  ],
          ),
          child: disabled
              ? const Center(
                  child: Icon(
                    Icons.lock_outline_rounded,
                    color: appMuted,
                    size: 46,
                  ),
                )
              : revealed
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _icon(card['category'].toString()),
                      size: 62,
                      color: palette.$2,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      card['title'].toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.$2,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      card['description'].toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.$2.withValues(alpha: .78),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      '${card['durationMinutes']} MIN  •  +${card['xp']} XP',
                      style: TextStyle(
                        color: palette.$2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 72,
                      color: palette.$2,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'YOUWELL',
                      style: TextStyle(
                        color: palette.$2,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'TAP TO REVEAL',
                      style: TextStyle(
                        color: palette.$2.withValues(alpha: .7),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  IconData _icon(String category) => switch (category) {
    'Body' => Icons.directions_walk_rounded,
    'Energy' => Icons.bolt_rounded,
    'Reduction' => Icons.air_rounded,
    _ => Icons.auto_awesome_rounded,
  };
}

Widget tag(String text) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  decoration: BoxDecoration(
    color: const Color(0xff203a32),
    borderRadius: BorderRadius.circular(99),
  ),
  child: Text(
    text,
    style: const TextStyle(
      color: appAccent,
      fontSize: 12,
      fontWeight: FontWeight.w800,
    ),
  ),
);
