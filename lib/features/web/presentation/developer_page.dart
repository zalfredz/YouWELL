import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';

const _bg = Color(0xff0d0e11);
const _panel = Color(0xff16181d);
const _raised = Color(0xff1c1f25);
const _line = Color(0xff2a2d34);
const _text = Color(0xfff1f3f5);
const _muted = Color(0xff9298a3);
const _green = Color(0xff78e3b1);
const _cyan = Color(0xff77d7e5);
const _amber = Color(0xffffc875);

class DeveloperPage extends StatefulWidget {
  const DeveloperPage({
    super.key,
    required this.controller,
    required this.onOpenHome,
  });

  final WellnessController controller;
  final VoidCallback onOpenHome;

  @override
  State<DeveloperPage> createState() => _DeveloperPageState();
}

class _DeveloperPageState extends State<DeveloperPage> {
  String? _feedback;

  void _advance(int days) {
    widget.controller.advancePreviewDays(days);
    setState(() =>
        _feedback = 'Preview maju $days hari ke ${widget.controller.today}.');
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: _bg,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Developer',
                style: TextStyle(
                  color: _text,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Kontrol preview lokal untuk menguji siklus harian dan state aplikasi.',
                style: TextStyle(color: _muted),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _Metric(
                    label: 'Preview date',
                    value: widget.controller.today,
                    detail: 'Offset +${widget.controller.dayOffset} hari',
                    color: _cyan,
                  ),
                  _Metric(
                    label: 'Daily cards',
                    value: '${widget.controller.dailyDrawCards.length}',
                    detail:
                        '${widget.controller.completedCards.length} selesai',
                    color: _green,
                  ),
                  _Metric(
                    label: 'Moderation queue',
                    value:
                        '${widget.controller.posts.where((p) => p['status'] == 'pending').length}',
                    detail: 'post menunggu admin',
                    color: _amber,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Time travel',
                      style: TextStyle(
                        color: _text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Gunakan untuk menguji daily draw, streak, recap, dan perubahan tanggal tanpa menunggu besok.',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _advance(1),
                          icon: const Icon(Icons.skip_next_rounded),
                          label: const Text('Next day'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _advance(7),
                          icon: const Icon(Icons.calendar_view_week_rounded),
                          label: const Text('+7 days'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            widget.controller.drawDailyCards();
                            setState(() => _feedback =
                                'Daily deck untuk ${widget.controller.today} sudah disiapkan.');
                          },
                          icon: const Icon(Icons.style_rounded),
                          label: const Text('Generate daily deck'),
                        ),
                        TextButton.icon(
                          onPressed: widget.onOpenHome,
                          icon: const Icon(Icons.home_outlined),
                          label: const Text('Open Home'),
                        ),
                      ],
                    ),
                    if (_feedback != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xff17251f),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xff315043)),
                        ),
                        child: Text(
                          _feedback!,
                          style: const TextStyle(color: _green),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Preview state',
                      style: TextStyle(
                        color: _text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Squad joined',
                          style: TextStyle(color: _text)),
                      subtitle: const Text('Uji state Squad widget dan hub.',
                          style: TextStyle(color: _muted)),
                      value: widget.controller.hasSquad,
                      onChanged: (joined) => joined
                          ? widget.controller.joinSquad()
                          : widget.controller.leaveSquad(),
                    ),
                    const Divider(color: _line),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.delete_sweep_outlined,
                          color: Color(0xffff9f9f)),
                      title: const Text('Reset all local preview data',
                          style: TextStyle(color: _text)),
                      subtitle: const Text(
                        'Menghapus profil, task, post, dan seluruh progres pada browser ini.',
                        style: TextStyle(color: _muted),
                      ),
                      trailing: OutlinedButton(
                        onPressed: () => _confirmReset(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xffff9f9f),
                        ),
                        child: const Text('Reset'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset preview data?'),
        content: const Text('Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset data'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.controller.reset();
    if (mounted) widget.onOpenHome();
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _panel,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });
  final String label, value, detail;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: 230,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _raised,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
            const SizedBox(height: 9),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(detail, style: const TextStyle(color: _muted, fontSize: 11)),
          ],
        ),
      );
}
