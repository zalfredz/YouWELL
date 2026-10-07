import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/companion/domain/companion_rewards.dart';
import 'package:youwell/features/companion/presentation/mobile_companion.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';

class CompanionPage extends StatelessWidget {
  const CompanionPage({super.key, required this.controller});
  final WellnessController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final c = context.colors;
      final text = Theme.of(context).textTheme;
      final kind = controller.profile?['companion']?.toString() ?? 'plant';
      final level = controller.level;
      final stage = companionStage(level);
      final inLevel = controller.xp % 100;
      final items = [
        const CompanionUnlock('none', 'Tanpa aksesori', 1, false),
        const CompanionUnlock('natural', 'Latar alami', 1, true),
        ...companionUnlocks,
      ];
      return Scaffold(
        appBar: AppBar(title: const Text('Teman kecilmu')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Center(child: MobileCompanion(controller: controller, size: 240)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  companionStageName(kind, stage),
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 10),
                LevelBadge(level, size: 44),
              ],
            ),
            const SizedBox(height: 10),
            XpBar(value: inLevel / 100),
            const SizedBox(height: 4),
            Text(
              '${100 - inLevel} XP lagi ke Level ${level + 1}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 24),
            const SectionTitle('Jalur tumbuh', icon: Icons.spa_rounded),
            SizedBox(
              height: 128,
              child: Row(
                children: [
                  for (var step = 1; step <= 5; step++)
                    Expanded(
                      child: _StageStep(
                        kind: kind,
                        step: step,
                        reached: step <= stage,
                        current: step == stage,
                        unlockLevel: const [1, 2, 4, 7, 10][step - 1],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const SectionTitle(
              'Lemari hadiah',
              icon: Icons.card_giftcard_rounded,
            ),
            Text(
              'Hadiah terbuka dari level. Ketuk untuk memakai.',
              style: TextStyle(color: c.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 156,
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                final unlocked = level >= item.level;
                final worn =
                    (item.background
                        ? controller.companionBackground
                        : controller.companionAccessory) ==
                    item.id;
                return _RewardTile(
                  label: item.label,
                  unlocked: unlocked,
                  worn: worn,
                  unlockLevel: item.level,
                  preview: CompanionPreview(
                    kind: kind,
                    stage: stage,
                    accessory: item.background
                        ? controller.companionAccessory
                        : item.id,
                    background: item.background
                        ? item.id
                        : controller.companionBackground,
                  ),
                  onTap: unlocked
                      ? () => controller.equipCompanion(
                          item.id,
                          background: item.background,
                        )
                      : null,
                );
              },
            ),
          ],
        ),
      );
    },
  );
}

class _StageStep extends StatelessWidget {
  const _StageStep({
    required this.kind,
    required this.step,
    required this.reached,
    required this.current,
    required this.unlockLevel,
  });
  final String kind;
  final int step, unlockLevel;
  final bool reached, current;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label:
          '${companionStageName(kind, step)}, ${reached ? 'tercapai' : 'terbuka di level $unlockLevel'}',
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.card,
              border: Border.all(
                color: current ? c.xp : c.border,
                width: current ? 3 : 1.5,
              ),
            ),
            child: Opacity(
              opacity: reached ? 1 : .3,
              child: CompanionPreview(kind: kind, stage: step, size: 56),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            companionStageName(kind, step),
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: reached ? c.text : c.muted,
            ),
          ),
          Text(
            reached ? (current ? 'Sekarang' : 'Tercapai') : 'Lv $unlockLevel',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: current ? c.onXp : c.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({
    required this.label,
    required this.unlocked,
    required this.worn,
    required this.unlockLevel,
    required this.preview,
    required this.onTap,
  });
  final String label;
  final bool unlocked, worn;
  final int unlockLevel;
  final Widget preview;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: unlocked,
      selected: worn,
      label: unlocked
          ? '$label${worn ? ', sedang dipakai' : ''}'
          : '$label, terbuka di level $unlockLevel',
      child: GameCard(
        onTap: onTap,
        color: worn ? c.xpSoft : c.card,
        borderColor: worn ? c.xp : null,
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Opacity(opacity: unlocked ? 1 : .35, child: preview),
                if (!unlocked)
                  Icon(Icons.lock_rounded, color: c.text, size: 26),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              !unlocked
                  ? 'Level $unlockLevel'
                  : worn
                  ? 'Dipakai'
                  : 'Pakai',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: worn ? c.onXp : c.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
