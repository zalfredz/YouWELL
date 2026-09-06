import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/features/moderation/domain/content_filter.dart';
import 'package:youwell/features/support/domain/crisis_detector.dart';
import 'package:youwell/features/support/presentation/support_card.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';

class PostComposerSheet extends StatefulWidget {
  const PostComposerSheet({
    super.key,
    required this.controller,
    required this.room,
  });
  final WellnessController controller;
  final String room;
  @override
  State<PostComposerSheet> createState() => _PostComposerSheetState();
}

class _PostComposerSheetState extends State<PostComposerSheet> {
  final body = TextEditingController();
  String? error;
  bool help = false;
  @override
  void dispose() {
    body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      title(
        widget.room == 'Wall' ? 'Rayakan langkah kecil' : '#${widget.room}',
      ),
      gap(8),
      caption(
        'Tanpa data pribadi, foto, promosi, atau kata kasar. Filter aturan lokal → antrean moderator. Belum memakai AI.',
      ),
      gap(),
      TextField(
        controller: body,
        maxLength: 1000,
        maxLines: 5,
        onChanged: (t) => setState(() => help = crisisSignal(t)),
        decoration: const InputDecoration(hintText: 'Hari ini aku...'),
      ),
      if (help) const SupportCard(),
      if (error != null)
        Text(error!, style: const TextStyle(color: Colors.deepOrange)),
      gap(),
      FilledButton(
        onPressed: () {
          final text = body.text.trim();
          final reason = moderationReason(text);
          if (text.isEmpty || reason != null) {
            setState(() => error = reason ?? 'Tulis cerita terlebih dahulu.');
            return;
          }
          widget.controller.submitPost({
            'alias': widget.controller.profile!['alias'],
            'room': widget.room,
            'body': text,
            'status': 'pending',
          });
          Navigator.pop(context);
          toast(context, 'Kiriman masuk antrean tinjauan lokal.');
        },
        child: const Text('Kirim untuk ditinjau'),
      ),
    ],
  );
}
