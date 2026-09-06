import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/relief/presentation/craving_timer_sheet.dart';
import 'package:youwell/features/relief/presentation/micro_vent_sheet.dart';
import 'package:youwell/features/relief/presentation/soundscape_sheet.dart';
import 'package:youwell/features/support/presentation/support_card.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';

class ReliefMenuSheet extends StatelessWidget {
  const ReliefMenuSheet({super.key, required this.controller});
  final WellnessController controller;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title('Ada ruang untuk jeda.'),
          gap(8),
          caption('Pilih yang kamu butuhkan saat ini.'),
          gap(20),
          if (controller.reduction)
            ListTile(
              leading: const Icon(Icons.air, color: green),
              title: const Text('Lagi pengen ngerokok / vape'),
              subtitle: const Text('Delay timer & latihan napas'),
              onTap: () {
                Navigator.pop(context);
                sheet(context, CravingTimerSheet(controller: controller));
              },
            ),
          ListTile(
            leading:
                const Icon(Icons.local_fire_department_outlined, color: green),
            title: const Text('Lagi stres / overwhelmed'),
            subtitle: const Text('Lepaskan lewat Micro-Vent'),
            onTap: () {
              Navigator.pop(context);
              sheet(context, const MicroVentSheet());
            },
          ),
          ListTile(
            leading: const Icon(Icons.headphones, color: green),
            title: const Text('Dengarkan yang menenangkan'),
            subtitle: const Text('Soundscape & napas 1–3 menit'),
            onTap: () {
              Navigator.pop(context);
              sheet(context, const SoundscapeSheet());
            },
          ),
          gap(),
          const SupportCard(compact: true),
        ],
      );
}
