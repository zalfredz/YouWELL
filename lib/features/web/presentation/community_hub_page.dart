import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/platform/platform.dart' as platform;
import 'package:youwell/features/moderation/domain/content_filter.dart';
import 'package:youwell/features/support/domain/crisis_detector.dart';
import 'package:youwell/features/support/presentation/support_card.dart';

const _bg = Color(0xff0d0e11);
const _panel = Color(0xff16181d);
const _raised = Color(0xff1c1f25);
const _line = Color(0xff2a2d34);
const _text = Color(0xfff1f3f5);
const _muted = Color(0xff9298a3);
const _green = Color(0xff78e3b1);
const _cyan = Color(0xff77d7e5);
const _amber = Color(0xffffc875);

class WebCommunityHubPage extends StatefulWidget {
  const WebCommunityHubPage({super.key, required this.controller});
  final WellnessController controller;

  @override
  State<WebCommunityHubPage> createState() => _WebCommunityHubPageState();
}

class _WebCommunityHubPageState extends State<WebCommunityHubPage> {
  final _body = TextEditingController();
  String? _photo;
  String? _feedback;
  bool _needsHelp = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final result = await platform.pickPhoto();
    if (!mounted || result == null) return;
    setState(() {
      _photo = result;
      _feedback = null;
    });
  }

  void _submit() {
    final text = _body.text.trim();
    if (text.isEmpty && _photo == null) {
      setState(
          () => _feedback = 'Tulis pesan atau pilih foto terlebih dahulu.');
      return;
    }
    final reason = text.isEmpty ? null : moderationReason(text);
    if (reason != null) {
      setState(() => _feedback = reason);
      return;
    }
    widget.controller.submitPost({
      'alias': widget.controller.profile?['alias'] ?? 'teman',
      'room': 'Encouragement Wall',
      'body': text,
      if (_photo != null) 'photo': _photo,
      'status': 'pending',
      'note': 'Waiting for manual admin approval.',
    });
    setState(() {
      _body.clear();
      _photo = null;
      _needsHelp = false;
      _feedback = 'Post dikirim ke antrean admin dan belum tampil di publik.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final approved = widget.controller.posts
        .where((post) => post['status'] == 'approved')
        .toList()
        .reversed
        .toList();
    final pending = widget.controller.posts
        .where((post) => post['status'] == 'pending')
        .length;
    final mainFeed = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Composer(
          controller: _body,
          alias: widget.controller.profile?['alias']?.toString() ?? 'teman',
          photo: _photo,
          feedback: _feedback,
          needsHelp: _needsHelp,
          onChanged: (text) => setState(() => _needsHelp = crisisSignal(text)),
          onPhoto: _pickPhoto,
          onRemovePhoto: () => setState(() => _photo = null),
          onSubmit: _submit,
        ),
        const SizedBox(height: 14),
        if (approved.isEmpty)
          const _Panel(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 34),
              child: Column(children: [
                Icon(Icons.forum_outlined, color: _muted, size: 34),
                SizedBox(height: 12),
                Text('Belum ada post yang disetujui admin.',
                    style:
                        TextStyle(color: _text, fontWeight: FontWeight.w700)),
                SizedBox(height: 5),
                Text('Post yang lolos moderasi akan muncul di feed ini.',
                    style: TextStyle(color: _muted, fontSize: 12)),
              ]),
            ),
          )
        else
          ...approved.map(
            (post) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _FeedPost(controller: widget.controller, post: post),
            ),
          ),
      ],
    );
    final side = Column(children: [
      _SquadCard(controller: widget.controller),
      const SizedBox(height: 14),
      _Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.verified_user_outlined, color: _amber, size: 20),
            SizedBox(width: 9),
            Text('Moderation status',
                style: TextStyle(color: _text, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 12),
          Text('$pending post milik komunitas sedang menunggu admin.',
              style:
                  const TextStyle(color: _muted, fontSize: 12, height: 1.45)),
          const SizedBox(height: 10),
          const Text('Tidak ada post yang tayang otomatis.',
              style: TextStyle(
                  color: _green, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      ),
      const SizedBox(height: 14),
      const _Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.favorite_border_rounded, color: _cyan, size: 20),
            SizedBox(width: 9),
            Text('Community care',
                style: TextStyle(color: _text, fontWeight: FontWeight.w800)),
          ]),
          SizedBox(height: 12),
          Text(
              'Gunakan pseudonim, jaga privasi, dan beri dukungan tanpa menghakimi.',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.45)),
        ]),
      ),
    ]);
    return ColoredBox(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 56),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Squad & Community',
              style: TextStyle(
                  color: _text, fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          const Text(
              'Bagikan langkah kecil, lalu saling menguatkan dengan aman.',
              style: TextStyle(color: _muted)),
          const SizedBox(height: 20),
          LayoutBuilder(
              builder: (context, box) => box.maxWidth < 940
                  ? Column(
                      children: [mainFeed, const SizedBox(height: 18), side])
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Expanded(flex: 7, child: mainFeed),
                          const SizedBox(width: 18),
                          Expanded(flex: 3, child: side),
                        ])),
        ]),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.alias,
    required this.photo,
    required this.feedback,
    required this.needsHelp,
    required this.onChanged,
    required this.onPhoto,
    required this.onRemovePhoto,
    required this.onSubmit,
  });
  final TextEditingController controller;
  final String alias;
  final String? photo, feedback;
  final bool needsHelp;
  final ValueChanged<String> onChanged;
  final VoidCallback onPhoto, onRemovePhoto, onSubmit;

  @override
  Widget build(BuildContext context) => _Panel(
        padding: 18,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xff244038),
              foregroundColor: _green,
              child: Text(alias.isEmpty ? 'Y' : alias[0].toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                maxLength: 1000,
                maxLines: 4,
                onChanged: onChanged,
                style: const TextStyle(color: _text, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Apa langkah kecilmu hari ini?',
                  hintStyle: TextStyle(color: _muted),
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
            ),
          ]),
          if (photo != null) ...[
            const SizedBox(height: 10),
            Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _PostPhoto(source: photo!, height: 260),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filled(
                  onPressed: onRemovePhoto,
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ]),
          ],
          if (needsHelp) ...[
            const SizedBox(height: 10),
            const SupportCard(),
          ],
          if (feedback != null) ...[
            const SizedBox(height: 10),
            Text(feedback!,
                style: TextStyle(
                    color: feedback!.contains('antrean') ? _green : _amber,
                    fontSize: 12)),
          ],
          const Divider(color: _line, height: 24),
          Row(children: [
            TextButton.icon(
              onPressed: onPhoto,
              icon: const Icon(Icons.image_outlined, color: _cyan),
              label: const Text('Tambah foto'),
            ),
            const Spacer(),
            const Text('Admin approval required',
                style: TextStyle(color: _muted, fontSize: 11)),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: onSubmit,
              icon: const Icon(Icons.send_rounded, size: 17),
              label: const Text('Kirim'),
            ),
          ]),
        ]),
      );
}

class _FeedPost extends StatelessWidget {
  const _FeedPost({required this.controller, required this.post});
  final WellnessController controller;
  final Map<String, dynamic> post;

  @override
  Widget build(BuildContext context) {
    final alias = post['alias']?.toString() ?? 'teman';
    final body = post['body']?.toString() ?? '';
    final photo = post['photo']?.toString();
    return _Panel(
      padding: 18,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xff243a34),
            foregroundColor: _green,
            child: Text(alias.isEmpty ? 'Y' : alias[0].toUpperCase()),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('@$alias',
                  style: const TextStyle(
                      color: _text, fontWeight: FontWeight.w800)),
              const Text('Encouragement Wall · Approved',
                  style: TextStyle(color: _muted, fontSize: 10)),
            ]),
          ),
          const Icon(Icons.verified_rounded, color: _green, size: 18),
        ]),
        if (body.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(body,
              style: const TextStyle(color: _text, fontSize: 15, height: 1.45)),
        ],
        if (photo != null && photo.isNotEmpty) ...[
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _PostPhoto(source: photo, height: 360),
          ),
        ],
        const Divider(color: _line, height: 26),
        Wrap(
          spacing: 8,
          children: ['👏', '💛', '🌿'].map((emoji) {
            final id = '${post['id']}-$emoji';
            return FilterChip(
              selected: controller.hasReaction(id),
              showCheckmark: false,
              label: Text(emoji),
              onSelected: (_) => controller.react(id),
              selectedColor: const Color(0xff263e35),
              backgroundColor: _raised,
              side: const BorderSide(color: _line),
            );
          }).toList(),
        ),
      ]),
    );
  }
}

class _SquadCard extends StatelessWidget {
  const _SquadCard({required this.controller});
  final WellnessController controller;
  @override
  Widget build(BuildContext context) => _Panel(
        tint: const Color(0xff152420),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.groups_2_outlined, color: _green),
            SizedBox(width: 9),
            Text('Squad progress',
                style: TextStyle(color: _text, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 14),
          if (!controller.hasSquad) ...[
            const Text('Bangun habit bersama 3–5 teman.',
                style: TextStyle(color: _muted, fontSize: 12)),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: controller.joinSquad,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Cari / Buat Squad'),
            ),
          ] else ...[
            const Text('September reset',
                style: TextStyle(
                    color: _text, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            const Text('24 / 50 Tasks',
                style: TextStyle(color: _muted, fontSize: 12)),
            const SizedBox(height: 7),
            const LinearProgressIndicator(
              value: .48,
              minHeight: 8,
              color: _green,
              backgroundColor: Color(0xff2a4039),
            ),
          ],
        ]),
      );
}

class _PostPhoto extends StatelessWidget {
  const _PostPhoto({required this.source, required this.height});
  final String source;
  final double height;

  @override
  Widget build(BuildContext context) {
    try {
      final encoded = source.contains(',') ? source.split(',').last : source;
      return Image.memory(
        base64Decode(encoded),
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback,
      );
    } catch (_) {
      return _fallback;
    }
  }

  Widget get _fallback => Container(
        height: height,
        color: _raised,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined, color: _muted),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = 20, this.tint});
  final Widget child;
  final double padding;
  final Color? tint;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: tint ?? _panel,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      );
}
