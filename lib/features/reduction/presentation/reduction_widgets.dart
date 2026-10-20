import 'package:flutter/material.dart';
import 'package:youwell/core/theme/app_colors.dart';

/// Icons for the Habit Swap activities; a custom one gets a star.
IconData activityIcon(String? key) => switch (key) {
  'walk' => Icons.directions_walk_rounded,
  'seated' => Icons.event_seat_outlined,
  'hands' => Icons.back_hand_outlined,
  'water' => Icons.local_drink_outlined,
  'breathing' => Icons.air_rounded,
  'music' => Icons.headphones_rounded,
  'contact' => Icons.chat_bubble_outline_rounded,
  _ => Icons.star_outline_rounded,
};

/// A chunky round − or + that presses down like a game key.
class CountButton extends StatefulWidget {
  const CountButton({
    super.key,
    required this.size,
    required this.plus,
    required this.color,
    required this.label,
    required this.onTap,
  });
  final double size;
  final bool plus;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  @override
  State<CountButton> createState() => _CountButtonState();
}

class _CountButtonState extends State<CountButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = widget.onTap != null;
    final fill = widget.plus ? widget.color : colors.raised;
    final edge = widget.plus
        ? Color.lerp(widget.color, Colors.black, .25)!
        : colors.border;
    final depth = _down ? 0.0 : 4.0;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                widget.onTap!();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: widget.size,
          height: widget.size,
          margin: EdgeInsets.only(top: 4 - depth),
          decoration: BoxDecoration(
            color: enabled ? fill : fill.withValues(alpha: .4),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: edge, offset: Offset(0, depth))],
          ),
          child: Icon(
            widget.plus ? Icons.add_rounded : Icons.remove_rounded,
            size: widget.size * .5,
            color: widget.plus ? Colors.white : colors.text,
          ),
        ),
      ),
    );
  }
}

/// A big selectable tile with an icon box; picked tiles fill with [color].
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    this.badge,
    this.dashed = false,
    this.horizontal = false,
  });
  final IconData icon;
  final String label;
  final bool selected, dashed, horizontal;
  final Color color;
  final VoidCallback onTap;

  /// A small label in the corner, e.g. "Pilihanmu".
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final soft = color.withValues(alpha: .12);
    final iconBox = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: selected ? color : (horizontal ? soft : colors.raised),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        icon,
        size: 24,
        color: selected ? Colors.white : (horizontal ? color : colors.muted),
      ),
    );
    // Grid tiles have a fixed height, so long custom labels are clipped.
    final text = Text(
      label,
      maxLines: horizontal ? null : 2,
      overflow: horizontal ? null : TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: horizontal ? 16 : 14,
        fontWeight: FontWeight.w800,
        height: 1.2,
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: BoxConstraints(minHeight: horizontal ? 70 : 92),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? soft : colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: dashed
                    ? colors.muted.withValues(alpha: .45)
                    : selected
                    ? color
                    : colors.border,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: selected ? color.withValues(alpha: .35) : colors.border,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (horizontal)
                  Row(
                    children: [
                      iconBox,
                      const SizedBox(width: 14),
                      Expanded(child: text),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [iconBox, const SizedBox(height: 10), text],
                  ),
                if (badge != null)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.reduction.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        badge!,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: colors.amber,
                        ),
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

/// A small number card: big value over a short label.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    required this.color,
    this.dashed = false,
  });
  final String value, label;
  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dashed
              ? colors.muted.withValues(alpha: .45)
              : color.withValues(alpha: .35),
          width: 2,
        ),
        boxShadow: dashed
            ? null
            : [
                BoxShadow(
                  color: color.withValues(alpha: .25),
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 30,
              height: 1,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: colors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
