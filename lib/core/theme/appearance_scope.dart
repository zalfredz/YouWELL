import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';

class AppearanceScope extends InheritedNotifier<WellnessController> {
  const AppearanceScope({
    super.key,
    required WellnessController controller,
    required super.child,
  }) : super(notifier: controller);
  static WellnessController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppearanceScope>()!.notifier!;
}

class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({super.key});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: dark ? 'Ganti ke light mode' : 'Ganti ke dark mode',
      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () => AppearanceScope.of(
        context,
      ).setThemePreference(dark ? 'light' : 'dark'),
    );
  }
}
