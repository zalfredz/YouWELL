import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/platform/platform.dart' as platform;
import 'package:youwell/shared/widgets/ui_helpers.dart';
import 'package:youwell/shared/widgets/wellness_companion.dart';

class RecapSheet extends StatefulWidget {
  const RecapSheet({super.key, required this.controller, required this.period});
  final WellnessController controller;
  final int period;
  @override
  State<RecapSheet> createState() => _RecapSheetState();
}

class _RecapSheetState extends State<RecapSheet> {
  final imageKey = GlobalKey();
  bool exporting = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.controller;
    return Column(
      children: [
        RepaintBoundary(
          key: imageKey,
          child: Container(
            width: 340,
            padding: const EdgeInsets.all(28),
            color: const Color(0xffe4ecdd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title('youwell.', size: 28),
                gap(24),
                tag('${widget.period} HARI TERAKHIR'),
                gap(20),
                title('Aku tumbuh.\nSedikit demi\nsedikit.', size: 36),
                Center(
                  child: WellnessCompanion(
                    kind: s.profile!['companion'],
                    level: s.level,
                  ),
                ),
                Text(
                  '${(s.compliance(widget.period) * 100).round()}% misi selesai\n${s.total('activities', 'km', period: widget.period).toStringAsFixed(1)} km bergerak\n${s.streak} hari streak saat ini${s.reduction ? '\nRp ${s.savings(widget.period).round()} estimasi hemat' : ''}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.8,
                  ),
                ),
                gap(20),
                caption('${s.today} · little steps, better days'),
              ],
            ),
          ),
        ),
        gap(),
        FilledButton.icon(
          onPressed: exporting
              ? null
              : () async {
                  setState(() => exporting = true);
                  try {
                    final b = imageKey.currentContext!.findRenderObject()
                        as RenderRepaintBoundary;
                    final im = await b.toImage(pixelRatio: 3);
                    final bytes = await im.toByteData(
                      format: ui.ImageByteFormat.png,
                    );
                    platform.download(
                      'youwell-recap-${s.today}.png',
                      bytes!.buffer.asUint8List(),
                      'image/png',
                    );
                    im.dispose();
                  } catch (_) {
                    if (context.mounted) {
                      toast(
                        context,
                        'Ekspor belum berhasil. Coba lagi setelah kartu tampil.',
                      );
                    }
                  }
                  if (mounted) setState(() => exporting = false);
                },
          icon: const Icon(Icons.download_outlined),
          label: const Text('Unduh kartu PNG'),
        ),
      ],
    );
  }
}
