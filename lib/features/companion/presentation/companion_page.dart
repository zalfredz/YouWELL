import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/companion/domain/companion_rewards.dart';
import 'package:youwell/features/companion/presentation/mobile_companion.dart';

class CompanionPage extends StatelessWidget {
  const CompanionPage({super.key, required this.controller});
  final WellnessController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final kind = controller.profile?['companion']?.toString() ?? 'plant';
      return Scaffold(
        appBar: AppBar(title: const Text('Teman kecilmu')),
        body: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Center(child: MobileCompanion(controller: controller, size: 300)),
            Text(
              '${companionStageName(kind, companionStage(controller.level))} · Level ${controller.level}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            const Text(
              'Perjalanan tumbuh',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 1; i <= 5; i++)
                  Chip(
                    avatar: Icon(
                      i <= companionStage(controller.level)
                          ? Icons.spa_rounded
                          : Icons.lock_outline,
                      size: 18,
                    ),
                    label: Text(companionStageName(kind, i)),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Lemari hadiah',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Tanpa aksesori'),
                  onPressed: () =>
                      controller.equipCompanion('none', background: false),
                ),
                ActionChip(
                  label: const Text('Latar alami'),
                  onPressed: () =>
                      controller.equipCompanion('natural', background: true),
                ),
              ],
            ),
            for (final item in companionUnlocks)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  controller.level >= item.level
                      ? (item.background
                            ? Icons.landscape_outlined
                            : Icons.auto_awesome_rounded)
                      : Icons.lock_outline,
                  color: context.colors.accent,
                ),
                title: Text(item.label),
                subtitle: Text(
                  controller.level >= item.level
                      ? (item.background
                            ? 'Latar companion'
                            : 'Aksesori companion')
                      : 'Terbuka di level ${item.level}',
                ),
                trailing: controller.level < item.level
                    ? null
                    : TextButton(
                        onPressed: () => controller.equipCompanion(
                          item.id,
                          background: item.background,
                        ),
                        child: Text(
                          (item.background
                                      ? controller.companionBackground
                                      : controller.companionAccessory) ==
                                  item.id
                              ? 'Dipakai'
                              : 'Pakai',
                        ),
                      ),
              ),
          ],
        ),
      );
    },
  );
}
