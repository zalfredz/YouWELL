import 'package:flutter/material.dart';
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
    caption(
      compact
          ? 'Cari orang yang kamu percaya dan minta ditemani.'
          : 'YouWell dapat membantu mengambil jeda, tetapi tidak menggantikan bantuan langsung dari orang atau tenaga profesional.',
    ),
  ], color: const Color(0xfffff0df));
}
