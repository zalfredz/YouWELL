import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/activity/domain/meal_verifier.dart';
import 'package:youwell/features/auth/presentation/account_scope.dart';

/// Admin: approve or reject Meal Snap photos (phase 9). After 2 hours
/// without a decision the AI fallback decides; the file is deleted either
/// way. Only the alias is shown, never the account.
class AdminMealPage extends StatefulWidget {
  const AdminMealPage({super.key, this.verifier});

  /// Overrides the account's verifier (tests).
  final MealVerifier? verifier;

  @override
  State<AdminMealPage> createState() => _AdminMealPageState();
}

/// Matches the Edge Function's wait before the AI fallback.
const _aiAfter = Duration(hours: 2);

class _AdminMealPageState extends State<AdminMealPage> {
  MealVerifier? _verifier;
  List<MealReview>? _queue;
  List<MealDecision>? _recent;
  String? _error;
  bool _busy = false;
  var _view = 'pending';
  Timer? _refresh;
  DateTime? _lastAiRun;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final verifier = widget.verifier ?? AccountScope.maybeOf(context)?.meals;
    if (!identical(verifier, _verifier)) {
      _verifier = verifier;
      unawaited(_load());
    }
    _refresh ??= Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(_load()),
    );
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final verifier = _verifier;
    if (verifier == null) return;
    try {
      var queue = await verifier.queue();
      // Photos past 2 hours go to the AI, at most every 5 minutes, so they
      // are decided even when the participant does not open the app.
      final last = _lastAiRun;
      if (queue.any((item) => _waited(item) >= _aiAfter) &&
          (last == null ||
              DateTime.now().difference(last) >= const Duration(minutes: 5))) {
        _lastAiRun = DateTime.now();
        await verifier.checkAllOverdue();
        queue = await verifier.queue();
      }
      final recent = await verifier.recent();
      if (mounted) {
        setState(() {
          _queue = queue;
          _recent = recent;
          _error = null;
        });
      }
    } on MealVerifierException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _review(MealReview item, {required bool approve}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _verifier!.review(item.id, approve: approve);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                approve
                    ? 'Disetujui. Misi @${item.alias} tercentang.'
                    : 'Ditolak. @${item.alias} diminta foto ulang.',
              ),
            ),
          );
      }
    } on MealVerifierException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  static Duration _waited(MealReview item) =>
      DateTime.now().difference(item.createdAt);

  @override
  Widget build(BuildContext context) {
    final queue = _queue, recent = _recent;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(30),
        children: [
          const Text(
            'Meal Snap',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Setujui jika foto menunjukkan makanan atau minuman. Setelah 2 '
            'jam tanpa keputusan, AI yang memeriksa. Foto dihapus dari server '
            'setelah diputuskan.',
            style: TextStyle(color: context.colors.muted),
          ),
          const SizedBox(height: 24),
          if (_verifier == null)
            const _Empty(
              message:
                  'Pratinjau lokal. Verifikasi Meal Snap butuh akun admin '
                  'Supabase.',
            )
          else if (_error != null) ...[
            _Empty(message: _error!),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _load,
                child: const Text('Coba lagi'),
              ),
            ),
          ] else if (queue == null || recent == null)
            const Center(child: CircularProgressIndicator())
          else ...[
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: 'pending',
                  label: Text('Menunggu (${queue.length})'),
                ),
                const ButtonSegment(
                  value: 'decided',
                  label: Text('Sudah diputuskan'),
                ),
              ],
              selected: {_view},
              onSelectionChanged: (value) =>
                  setState(() => _view = value.single),
            ),
            const SizedBox(height: 20),
            if (_view == 'pending') ...[
              if (queue.isEmpty)
                const _Empty(message: 'Tidak ada foto yang menunggu.'),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final item in queue)
                    _MealCard(
                      item: item,
                      waited: _waited(item),
                      busy: _busy,
                      onApprove: () => _review(item, approve: true),
                      onReject: () => _review(item, approve: false),
                    ),
                ],
              ),
            ] else ...[
              if (recent.isEmpty)
                const _Empty(message: 'Belum ada foto yang diputuskan.'),
              for (final decision in recent) _DecisionRow(decision: decision),
            ],
          ],
        ],
      ),
    );
  }
}

/// "baru saja", "35 menit", "2 jam 10 menit".
String _duration(Duration value) {
  if (value.inMinutes < 1) return 'baru saja';
  if (value.inHours < 1) return '${value.inMinutes} menit';
  final minutes = value.inMinutes % 60;
  return minutes == 0
      ? '${value.inHours} jam'
      : '${value.inHours} jam $minutes menit';
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.item,
    required this.waited,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });
  final MealReview item;
  final Duration waited;
  final bool busy;
  final VoidCallback onApprove, onReject;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final left = _aiAfter - waited;
    return Container(
      width: 320,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: item.imageUrl == null
                ? ColoredBox(
                    color: c.raised,
                    child: Center(
                      child: Text(
                        'Foto belum bisa dimuat',
                        style: TextStyle(color: c.muted),
                      ),
                    ),
                  )
                : Image.network(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                    semanticLabel: 'Foto makan @${item.alias}',
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: c.raised,
                      child: Center(
                        child: Text(
                          'Foto belum bisa dimuat',
                          style: TextStyle(color: c.muted),
                        ),
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@${item.alias}',
                  style: TextStyle(
                    color: c.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  left.isNegative || left == Duration.zero
                      ? 'Menunggu ${_duration(waited)} · giliran AI'
                      : 'Menunggu ${_duration(waited)} · AI dalam '
                            '${_duration(left)}',
                  style: TextStyle(color: c.muted, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: busy ? null : onApprove,
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Setujui'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : onReject,
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Tolak'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DecisionRow extends StatelessWidget {
  const _DecisionRow({required this.decision});
  final MealDecision decision;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final at = decision.reviewedAt;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(
            decision.approved ? Icons.check_circle_rounded : Icons.cancel,
            color: decision.approved ? c.success : c.amber,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@${decision.alias} · '
                  '${decision.approved ? 'Disetujui' : 'Ditolak'}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (at != null)
                  Text(
                    '${_duration(DateTime.now().difference(at))} lalu',
                    style: TextStyle(color: c.muted, fontSize: 13),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: decision.byAi ? c.xpSoft : c.raised,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              decision.byAi ? 'AI' : 'Admin',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.colors.border),
    ),
    child: Text(message, style: TextStyle(color: context.colors.muted)),
  );
}
