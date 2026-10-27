import 'package:flutter/material.dart';
import 'package:youwell/application/admin_progress_editor.dart';
import 'package:youwell/application/research_overview.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/features/auth/presentation/account_scope.dart';
import 'package:youwell/features/home/domain/quest_ladder.dart';
import 'package:youwell/features/progress/domain/research_store.dart';

/// Admin Overview (phase 10): restores progress a participant lost, per
/// account. Quests are ticked (XP and level follow), daily smoking/vaping
/// totals and Habit Swaps are set, and mission levels changed. Every save is
/// an admin intervention with a reason; the phone takes it on its next sync.
class AdminOverviewPage extends StatefulWidget {
  const AdminOverviewPage({super.key, this.store, this.now});

  /// Overrides the account's store (tests).
  final ResearchStore? store;

  /// Fixed clock for tests.
  final DateTime? now;

  @override
  State<AdminOverviewPage> createState() => _AdminOverviewPageState();
}

class _AdminOverviewPageState extends State<AdminOverviewPage> {
  ResearchStore? _store;
  List<ParticipantOverview>? _people;
  List<JsonMap> _log = const [];
  List<JsonMap>? _history;
  String? _error, _account;
  AdminProgressEditor? _editor;
  bool _loading = false, _saving = false;
  final _reason = TextEditingController();

  DateTime get _now => widget.now ?? DateTime.now();

  ParticipantOverview? get _person =>
      _people?.where((p) => p.account == _account).firstOrNull;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = widget.store ?? AccountScope.maybeOf(context)?.researchStore;
    if (store != null && _store == null) {
      _store = store;
      _load();
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final store = _store;
    if (store == null || _loading) return;
    setState(() => _loading = true);
    try {
      final rows = await store.progressOverview();
      var log = const <JsonMap>[];
      try {
        log = await store.interventions();
      } catch (_) {
        // Before phase 10 there is no log; editing reports that on save.
      }
      if (!mounted) return;
      setState(() {
        _people = [
          for (final row in rows) ?ParticipantOverview.fromRow(row, now: _now),
        ]..sort(byParticipantCode);
        _log = log;
        _error = null;
        final person = _person;
        _editor = person == null
            ? null
            : AdminProgressEditor(person.payload, now: _now);
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Data belum bisa dimuat. Periksa koneksi dan migration tahap 10.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _select(ParticipantOverview person) {
    setState(() {
      _account = person.account;
      _editor = AdminProgressEditor(person.payload, now: _now);
      _history = null;
      _reason.clear();
    });
  }

  void _edit(void Function(AdminProgressEditor editor) change) =>
      setState(() => change(_editor!));

  void _toast(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<bool> _confirm(String title, List<String> lines) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final line in lines) Text('• $line')],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _save() async {
    final person = _person, editor = _editor, store = _store;
    if (person == null || editor == null || store == null || _saving) return;
    final reason = _reason.text.trim();
    if (reason.length < 5) {
      _toast('Tulis alasan intervensi dulu (minimal 5 karakter).');
      return;
    }
    final changes = editor.changes;
    if (!await _confirm('Simpan sebagai intervensi admin?', [
      for (final change in changes) describeChange(change),
      'Alasan: $reason',
    ])) {
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await store.writeProgress(
        account: person.account,
        expectedRevision: person.revision,
        payload: editor.payload,
        reason: reason,
        changes: changes,
      );
      _toast(
        saved
            ? 'Tersimpan. HP peserta mengambilnya saat sinkron berikutnya.'
            : 'Peserta baru saja sinkron. Data dimuat ulang; ulangi '
                  'perubahannya.',
      );
      if (saved) _reason.clear();
      await _load();
    } catch (error) {
      _toast(error is StateError ? error.message : 'Belum tersimpan.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _loadHistory() async {
    final person = _person;
    if (person == null) return;
    try {
      final rows = await _store!.history(person.account);
      if (mounted) setState(() => _history = rows);
    } catch (error) {
      if (mounted) {
        setState(() => _history = const []);
        _toast(error is StateError ? error.message : 'Riwayat belum dimuat.');
      }
    }
  }

  Future<void> _restore(int revision) async {
    final person = _person;
    final reason = _reason.text.trim();
    if (person == null) return;
    if (reason.length < 5) {
      _toast('Tulis alasan intervensi dulu (minimal 5 karakter).');
      return;
    }
    if (!await _confirm('Pulihkan salinan revisi $revision?', [
      'Progres sekarang diganti salinan itu (salinan sekarang tetap '
          'tersimpan di riwayat).',
      'Alasan: $reason',
    ])) {
      return;
    }
    try {
      await _store!.restoreRevision(person.account, revision, reason);
      _reason.clear();
      _toast('Dipulihkan. HP peserta mengambilnya saat sinkron berikutnya.');
      _history = null;
      await _load();
    } catch (error) {
      _toast(error is StateError ? error.message : 'Belum dipulihkan.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_store == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Text('Overview butuh login admin.'),
        ),
      );
    }
    final people = _people, editor = _editor, person = _person;
    return ListView(
      padding: const EdgeInsets.all(30),
      children: [
        const Text(
          'Overview',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'Pulihkan progres peserta yang hilang. Setiap simpan dicatat '
          'sebagai intervensi admin dan ditandai di ekspor riset.',
          style: TextStyle(color: c.muted),
        ),
        const SizedBox(height: 20),
        if (_error != null)
          Text(_error!, style: TextStyle(color: c.amber))
        else if (people == null)
          const Center(child: CircularProgressIndicator())
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in people)
                ChoiceChip(
                  selected: p.account == _account,
                  onSelected: (_) => _select(p),
                  avatar: p.activeLast7 == 0
                      ? Icon(Icons.bedtime_outlined, size: 18, color: c.amber)
                      : null,
                  label: Text(
                    p.code == null ? p.alias : '${p.code} · ${p.alias}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Ikon bulan: tidak aktif 7 hari terakhir.',
            style: TextStyle(color: c.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 24),
          if (editor == null || person == null)
            Text(
              'Pilih peserta untuk melihat dan memulihkan progresnya.',
              style: TextStyle(color: c.muted),
            )
          else
            ..._editorView(context, person, editor),
        ],
      ],
    );
  }

  List<Widget> _editorView(
    BuildContext context,
    ParticipantOverview person,
    AdminProgressEditor editor,
  ) {
    final c = context.colors;
    final preview = ParticipantOverview.fromRow({
      'account': person.account,
      'payload': editor.payload,
    }, now: _now);
    final changes = editor.changes;
    String arrow(int before, int? after) =>
        after == null || after == before ? '$before' : '$before → $after';
    return [
      _Section(
        title: person.code == null
            ? person.alias
            : '${person.code} · ${person.alias}',
        child: Wrap(
          spacing: 28,
          runSpacing: 12,
          children: [
            _Fact('Jalur', person.path),
            _Fact(
              'Hari',
              person.complete ? 'Selesai' : '${person.dayNumber} dari 28',
            ),
            _Fact('XP', arrow(person.xp, preview?.xp)),
            _Fact('Level', arrow(person.level, preview?.level)),
            _Fact(
              'Quest selesai',
              arrow(person.questsDone, preview?.questsDone),
            ),
            _Fact('Aktif 7 hari', '${person.activeLast7}/7'),
          ],
        ),
      ),
      _Section(
        title: 'Level misi',
        child: Wrap(
          spacing: 16,
          runSpacing: 10,
          children: [
            for (final category in editor.categories)
              _Counter(
                label: ladderLabels[category] ?? category,
                value: editor.ladderSteps[category],
                min: 1,
                max: editor.maxStep(category),
                onChanged: (step) =>
                    _edit((e) => e.setStep(category, step ?? 1)),
              ),
          ],
        ),
      ),
      _Section(
        title: 'Harian',
        subtitle:
            'Buka satu hari untuk mencentang quest'
            '${editor.reduction ? ', mengisi total rokok/vape, dan Habit Swap' : ''}. '
            'Quest yang selesai di aplikasi tidak bisa diubah.',
        child: Column(
          children: [
            for (final day in editor.days) _dayTile(context, editor, day),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: changes.isEmpty ? c.surface : c.xpSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: changes.isEmpty ? c.border : c.xp),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              changes.isEmpty
                  ? 'Belum ada perubahan.'
                  : '${changes.length} perubahan belum disimpan',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _reason,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Alasan intervensi',
                hintText:
                    'Contoh: data hilang setelah install ulang, dikonfirmasi '
                    'peserta lewat chat 27 Okt',
              ),
            ),
            Wrap(
              spacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: changes.isEmpty || _saving ? null : _save,
                  icon: const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'Menyimpan...' : 'Simpan intervensi'),
                ),
                TextButton(
                  onPressed: changes.isEmpty
                      ? null
                      : () => setState(
                          () => _editor = AdminProgressEditor(
                            person.payload,
                            now: _now,
                          ),
                        ),
                  child: const Text('Batalkan perubahan'),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      _Section(title: 'Log intervensi', child: _logView(context, person)),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text(
          'Salinan sebelumnya',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          'Server menyimpan 60 salinan terakhir sejak migration tahap 10. '
          'Pakai ini jika progres tertimpa dari HP.',
          style: TextStyle(color: c.muted, fontSize: 12.5),
        ),
        onExpansionChanged: (open) {
          if (open && _history == null) _loadHistory();
        },
        children: [
          if (_history == null)
            const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            )
          else if (_history!.isEmpty)
            const ListTile(title: Text('Belum ada salinan sebelumnya.'))
          else
            for (final row in _history!)
              ListTile(
                title: Text(
                  'Revisi ${row['revision']} · ${row['quests_done']} quest '
                  'selesai · ${row['days']} hari',
                ),
                subtitle: Text(_date(row['saved_at'])),
                trailing: TextButton(
                  onPressed: () => _restore((row['revision'] as num).toInt()),
                  child: const Text('Pulihkan'),
                ),
              ),
        ],
      ),
    ];
  }

  Widget _dayTile(
    BuildContext context,
    AdminProgressEditor editor,
    String day,
  ) {
    final c = context.colors;
    final quests = editor.questsOn(day);
    final done = quests.where((t) => t['status'] == 'completed').length;
    final rokok = editor.usage(day, 'rokok'), vape = editor.usage(day, 'vape');
    final summary = [
      editor.openedOn(day) ? 'dibuka' : 'tidak dibuka',
      quests.isEmpty ? 'belum ada kartu' : '$done/${quests.length} quest',
      if (editor.reduction) ...[
        if (rokok != null) 'rokok $rokok',
        if (vape != null) 'vape $vape',
        if (editor.swapsOn(day) > 0) 'Habit Swap ${editor.swapsOn(day)}',
      ],
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        key: PageStorageKey('day-$day'),
        title: Text(
          'Hari ${editor.dayNumber(day)} · ${_dayLabel(day)}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(summary, style: TextStyle(color: c.muted)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: editor.openedOn(day),
            onChanged: editor.openedByApp(day)
                ? null
                : (value) => _edit((e) => e.setOpened(day, value)),
            title: const Text('Membuka aplikasi'),
            subtitle: Text(
              editor.openedByApp(day)
                  ? 'tercatat dari aplikasi'
                  : editor.openedOn(day)
                  ? 'ditandai admin'
                  : 'tidak tercatat',
            ),
          ),
          if (quests.isEmpty)
            OutlinedButton.icon(
              onPressed: () => _edit((e) => e.createCard(day)),
              icon: const Icon(Icons.style_rounded),
              label: const Text('Buat kartu yang direkomendasikan'),
            ),
          for (final task in quests)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: task['status'] == 'completed',
              onChanged: AdminProgressEditor.doneByApp(task)
                  ? null
                  : (value) => _edit(
                      (e) => e.setQuestDone(day, task['id'].toString(), value!),
                    ),
              title: Text(task['title'].toString()),
              subtitle: Text(
                [
                  '${task['xp'] ?? 15} XP',
                  if (AdminProgressEditor.doneByApp(task))
                    'selesai di aplikasi'
                  else if (task['adminCompleted'] == true)
                    'dicentang admin',
                ].join(' · '),
              ),
            ),
          if (editor.reduction) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                _Counter(
                  label: 'Rokok (batang)',
                  value: rokok,
                  min: 0,
                  max: 500,
                  onChanged: (v) =>
                      _edit((e) => e.setUsage(day, 'rokok', v ?? 0)),
                ),
                _Counter(
                  label: 'Vape (sesi)',
                  value: vape,
                  min: 0,
                  max: 500,
                  onChanged: (v) =>
                      _edit((e) => e.setUsage(day, 'vape', v ?? 0)),
                ),
                _Counter(
                  label: 'Habit Swap dicoba',
                  value: editor.swapsOn(day),
                  min: editor.appSwapsOn(day),
                  max: 20,
                  onChanged: (v) => _edit((e) => e.setSwaps(day, v ?? 0)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _logView(BuildContext context, ParticipantOverview person) {
    final rows = _log.where((row) => row['account'] == person.account);
    if (rows.isEmpty) {
      return Text(
        'Belum ada intervensi untuk peserta ini.',
        style: TextStyle(color: context.colors.muted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_date(row['created_at'])} · ${row['reason']}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                for (final change
                    in ((row['changes'] ?? const []) as List).whereType<Map>())
                  Text(
                    '• ${describeChange(change)}',
                    style: TextStyle(color: context.colors.muted),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

const _weekdays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

String _dayLabel(String day) {
  final date = DateTime.tryParse(day);
  return date == null
      ? day
      : '${_weekdays[date.weekday - 1]} ${date.day}/${date.month}';
}

String _date(Object? value) {
  final time = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (time == null) return '–';
  return '${time.day}/${time.month} ${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: TextStyle(color: context.colors.muted)),
        ],
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: context.colors.muted, fontSize: 13)),
      Text(
        value,
        style: TextStyle(
          color: context.colors.accent,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

/// − value + with a tap on the value to type it. Null shows "–".
class _Counter extends StatelessWidget {
  const _Counter({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final int? value;
  final int min, max;
  final ValueChanged<int?> onChanged;

  Future<void> _type(BuildContext context) async {
    final controller = TextEditingController(text: value?.toString() ?? '');
    final typed = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(helperText: '$min–$max'),
          onSubmitted: (text) =>
              Navigator.pop(dialogContext, int.tryParse(text.trim())),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              int.tryParse(controller.text.trim()),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (typed != null) onChanged(typed.clamp(min, max));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final current = value;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Kurangi $label',
            onPressed: current == null || current <= min
                ? null
                : () => onChanged(current - 1),
            icon: const Icon(Icons.remove_rounded),
          ),
          InkWell(
            onTap: () => _type(context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                current?.toString() ?? '–',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Tambah $label',
            onPressed: current != null && current >= max
                ? null
                : () => onChanged(current == null ? min : current + 1),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}
