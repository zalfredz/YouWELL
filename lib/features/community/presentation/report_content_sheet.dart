import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';

class ReportContentSheet extends StatefulWidget {
  const ReportContentSheet(
      {super.key, required this.controller, required this.post});
  final WellnessController controller;
  final String post;
  @override
  State<ReportContentSheet> createState() => _ReportContentSheetState();
}

class _ReportContentSheetState extends State<ReportContentSheet> {
  String reason = 'Data pribadi';
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title('Laporkan kiriman'),
          gap(),
          DropdownButtonFormField<String>(
            initialValue: reason,
            items: [
              'Data pribadi',
              'Tidak nyaman / perundungan',
              'Promosi',
              'Lainnya',
            ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (r) => reason = r!,
          ),
          gap(),
          FilledButton(
            onPressed: () {
              widget.controller
                  .reportContent({'post': widget.post, 'reason': reason});
              Navigator.pop(context);
              toast(
                context,
                'Kiriman disembunyikan. Laporan tercatat di dashboard lokal.',
              );
            },
            child: const Text('Laporkan & sembunyikan'),
          ),
        ],
      );
}
