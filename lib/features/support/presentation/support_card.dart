import 'package:flutter/material.dart';
import 'package:youwell/core/platform/platform.dart' as platform;
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';

class SupportCard extends StatelessWidget {
  const SupportCard({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => panel([
        Text(
          compact
              ? 'Butuh bantuan lebih lanjut?'
              : 'Kamu layak mendapat dukungan sekarang.',
          style: const TextStyle(fontWeight: FontWeight.w700, color: ink),
        ),
        if (!compact) ...[
          gap(8),
          const Text(
            'Kalau kamu merasa tidak aman atau ingin menyakiti diri, hubungi orang yang kamu percaya dan minta ditemani. Jika ada bahaya langsung, segera cari pertolongan darurat atau IGD terdekat.',
          ),
        ],
        gap(8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => platform.openLink('https://www.healing119.id'),
              child: const Text('Healing119 • bantuan Indonesia'),
            ),
            if (!compact) const Text('Telepon 119 ekstensi 8'),
          ],
        ),
        if (!compact)
          caption(
            'Sumber: Kementerian Kesehatan. Jika layanan tidak tersambung, hubungi orang tepercaya atau fasilitas kesehatan terdekat.',
          ),
      ], color: const Color(0xfffff0df));
}
