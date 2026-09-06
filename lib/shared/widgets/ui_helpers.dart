import 'package:flutter/material.dart';
import 'package:youwell/core/theme/app_colors.dart';

void toast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
Future<T?> sheet<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 620),
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          child: child,
        ),
      ),
    );
Widget title(String text, {double size = 26}) => Text(
  text,
  style: TextStyle(
    color: ink,
    fontSize: size,
    fontWeight: FontWeight.w800,
    letterSpacing: -.7,
  ),
);
Widget caption(String text) =>
    Text(text, style: const TextStyle(color: muted, fontSize: 13, height: 1.5));
Widget gap([double size = 16]) => SizedBox(height: size);
Widget panel(List<Widget> children, {Color color = Colors.white}) => Container(
  padding: const EdgeInsets.all(22),
  margin: const EdgeInsets.only(bottom: 16),
  decoration: BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: ink.withValues(alpha: .06)),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: children,
  ),
);
Widget tag(String text, {Color color = green}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
  decoration: BoxDecoration(
    color: color.withValues(alpha: .1),
    borderRadius: BorderRadius.circular(30),
  ),
  child: Text(
    text,
    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
  ),
);
Widget sectionHead(String heading, String sub) => Padding(
  padding: const EdgeInsets.only(bottom: 22),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [title(heading, size: 32), gap(5), caption(sub)],
  ),
);
Widget meter(double value, String label, String detail) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 10),
  child: Column(
    children: [
      Row(
        children: [
          Expanded(child: Text(label)),
          Flexible(
            child: Text(
              detail,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, color: muted),
            ),
          ),
        ],
      ),
      gap(8),
      ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LinearProgressIndicator(
          value: value.clamp(0, 1),
          minHeight: 8,
          backgroundColor: cream,
          color: green,
        ),
      ),
    ],
  ),
);
