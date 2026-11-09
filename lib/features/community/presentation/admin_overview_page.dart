import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:youwell/application/admin_progress_editor.dart';
import 'package:youwell/application/research_overview.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/features/auth/presentation/account_scope.dart';
import 'package:youwell/features/home/domain/quest_ladder.dart';
import 'package:youwell/features/progress/domain/research_store.dart';
import 'package:youwell/features/sync/domain/cloud_progress.dart';

/// Admin-only participant progress editor, available by direct /overview URL.
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
      if (!mounted) return;
      setState(() {
        _people = [
          for (final row in rows) ?ParticipantOverview.fromRow(row, now: _now),
        ]..sort(byParticipantCode);
        _error = null;
        final person = _person;
        _editor = person == null
            ? null
            : AdminProgressEditor(person.payload, now: _now);
        _edits.clear();
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
      _edits.clear();
      _reason.clear();
    });
  }

  /// The admin's edits since loading, replayed onto a newer snapshot when
  /// the participant's phone synced before the save.
  final _edits = <void Function(AdminProgressEditor editor)>[];

  void _edit(void Function(AdminProgressEditor editor) change) => setState(() {
    change(_editor!);
    _edits.add(change);
  });

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
      _toast('Tulis catatan minimal 5 karakter.');
      return;
    }
    final changes = editor.changes;
    if (!await _confirm('Simpan perubahan?', [
      for (final change in changes) describeChange(change),
      'Catatan: $reason',
    ])) {
      return;
    }
    setState(() => _saving = true);
    try {
      var (revision, latest, saved) = (person.revision, editor, false);
      // The phone may sync between loading and saving (a newer revision):
      // apply the same edits to the newest snapshot instead of failing.
      for (var attempt = 0; attempt < 3 && !saved; attempt++) {
        if (attempt > 0) {
          final fresh = [
            for (final row in await store.progressOverview())
              ?ParticipantOverview.fromRow(row, now: _now),
          ].where((p) => p.account == person.account).firstOrNull;
          if (fresh == null) break;
          revision = fresh.revision;
          latest = AdminProgressEditor(fresh.payload, now: _now);
          for (final change in _edits) {
            change(latest);
          }
          if (!latest.changed) {
            saved = true; // The phone already holds every edit.
            break;
          }
        }
        saved = await store.writeProgress(
          account: person.account,
          expectedRevision: revision,
          payload: CloudProgress.serverSafe(latest.payload),
          reason: reason,
          changes: latest.changes,
        );
      }
      _toast(
        saved
            ? 'Tersimpan. HP peserta mengambilnya saat sinkron berikutnya.'
            : 'Peserta sedang aktif sinkron. Perubahanmu tetap ada; coba '
                  'simpan lagi sebentar lagi.',
      );
      if (saved) _reason.clear();
      final pending = saved
          ? const <void Function(AdminProgressEditor)>[]
          : [..._edits];
      await _load();
      if (mounted && pending.isNotEmpty && _editor != null) {
        pending.forEach(_edit);
      }
    } catch (error) {
      _toast(error is StateError ? error.message : 'Belum tersimpan.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _importCorrectionPlan() async {
    final store = _store;
    if (store == null || _saving) return;
    final input = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Impor koreksi UAT'),
        content: SizedBox(
          width: 720,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tempel seluruh isi file preview JSON. Data akan dicek '
                'terhadap revisi terbaru sebelum disimpan.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: input,
                minLines: 8,
                maxLines: 16,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '{ "mode": "preview-only", ... }',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, input.text),
            child: const Text('Periksa preview'),
          ),
        ],
      ),
    );
    input.dispose();
    if (raw == null || raw.trim().isEmpty || !mounted) return;

    late final JsonMap plan;
    late final List<JsonMap> participants;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('Root JSON harus object.');
      }
      plan = Map<String, dynamic>.from(decoded);
      if (plan['mode'] != 'preview-only' || plan['applied'] != false) {
        throw const FormatException(
          'File harus preview koreksi yang belum diterapkan.',
        );
      }
      final rows = plan['participants'];
      if (rows is! List) {
        throw const FormatException('Daftar peserta tidak ada.');
      }
      if (plan['warnings'] is! List) {
        throw const FormatException('Ringkasan peringatan tidak ada.');
      }
      participants = [
        for (final row in rows)
          if (row is Map) Map<String, dynamic>.from(row),
      ];
      const requiredCodes = {'P5', 'P6', 'P7', 'P8', 'P9', 'P10'};
      if (participants.length != requiredCodes.length ||
          participants.map((p) => p['code']).toSet().length !=
              requiredCodes.length ||
          !participants
              .map((p) => p['code'])
              .toSet()
              .containsAll(requiredCodes)) {
        throw const FormatException(
          'Preview harus berisi P5 sampai P10 tepat satu kali.',
        );
      }
      for (final p in participants) {
        final days = p['daily'];
        final logins = p['loginDayKeys'];
        final payload = p['proposedPayload'];
        final code = p['code']?.toString();
        final expectedProduct = const {
          'P5': 'cigarette',
          'P6': 'cigarette',
          'P7': 'cigarette',
          'P8': 'vape',
          'P9': 'vape',
          'P10': 'vape',
        }[code];
        if (!RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
              caseSensitive: false,
            ).hasMatch(p['account']?.toString() ?? '') ||
            (p['expectedRevision'] as num?)?.toInt() == null ||
            p['actualLoginDays'] is! int ||
            p['actualLoginDays'] != (logins is List ? logins.length : -1) ||
            days is! List ||
            days.length != p['actualLoginDays'] ||
            payload is! Map ||
            (payload['profile'] is! Map) ||
            (payload['profile'] as Map)['path'] != 'reduction' ||
            p['proposedProductChoice'] != expectedProduct ||
            (p['studyWindowDays'] is! List ||
                (p['studyWindowDays'] as List).length != 28) ||
            p['warnings'] is! List) {
          throw FormatException('Preview untuk ${p['code']} tidak lengkap.');
        }
      }
    } catch (error) {
      _toast(
        error is FormatException ? error.message : 'File preview tidak valid.',
      );
      return;
    }

    final summary = [
      for (final p in participants)
        '${p['code']}: ${p['actualLoginDays']} hari · '
            '${p['proposedProductChoice'] == 'cigarette' ? 'rokok' : 'vape'} · '
            '${(p['daily'] as List).length} catatan konsumsi + hasil Swap',
      for (final warning in (plan['warnings'] as List).whereType<String>())
        'PERINGATAN: $warning',
      'Login dan quest tidak diubah. Konsumsi, hasil Swap, dan jumlah dicoba '
          'pada jendela 28 hari diganti sesuai preview.',
    ];
    if (!await _confirm('Terapkan koreksi UAT ke enam peserta?', summary)) {
      return;
    }

    setState(() => _saving = true);
    var savedCount = 0;
    try {
      // Check all six snapshots before the first write so stale plans do not
      // partially apply just because one account changed before confirmation.
      final latest = await store.progressOverview();
      final byCode = <String, JsonMap>{
        for (final row in latest)
          if (row['code'] is String) row['code'] as String: row,
      };
      for (final p in participants) {
        final current = byCode[p['code']];
        if (current == null ||
            current['account'] != p['account'] ||
            (current['revision'] as num?)?.toInt() != p['expectedRevision']) {
          throw StateError(
            '${p['code']} berubah sejak preview. Muat ulang overview dan buat preview baru.',
          );
        }
        final before = current['payload'];
        final after = p['proposedPayload'];
        if (before is! Map ||
            after is! Map ||
            jsonEncode(before['profile']) != jsonEncode(after['profile'])) {
          throw StateError('${p['code']}: profil tidak cocok dengan preview.');
        }
      }

      const reason =
          'Koreksi UAT dari tabel acuan peneliti; data diisi pada '
          'tanggal login tercatat, tanpa menambah login.';
      for (final p in participants) {
        final current = byCode[p['code']]!;
        final before = Map<String, dynamic>.from(current['payload'] as Map);
        final after = Map<String, dynamic>.from(p['proposedPayload'] as Map);
        final changes = _correctionChanges(before, after, p);
        final saved = await store.writeProgress(
          account: p['account'] as String,
          expectedRevision: (p['expectedRevision'] as num).toInt(),
          payload: CloudProgress.serverSafe(after),
          reason: reason,
          changes: changes,
        );
        if (!saved) {
          throw StateError(
            '${p['code']} berubah saat disimpan; berhenti setelah $savedCount peserta.',
          );
        }
        savedCount++;
      }
      _toast('Perubahan tersimpan untuk $savedCount peserta.');
      await _load();
    } catch (error) {
      final message = error is StateError
          ? error.message
          : 'Koreksi belum selesai.';
      _toast(
        savedCount == 0
            ? message
            : '$message Sudah tersimpan untuk $savedCount peserta; periksa Overview sebelum melanjutkan.',
      );
      await _load();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<JsonMap> _correctionChanges(
    JsonMap before,
    JsonMap after,
    JsonMap participant,
  ) {
    final window = (participant['studyWindowDays'] as List)
        .cast<String>()
        .toSet();
    Map<String, Map> indexed(Object? rows) => {
      for (final row in (rows as List? ?? const []).whereType<Map>())
        if (window.contains(row['day']) &&
            ['rokok', 'vape'].contains(row['type']))
          '${row['day']}:${row['type']}': row,
    };
    final oldUsage = indexed(before['usageTotals']);
    final newUsage = indexed(after['usageTotals']);
    final oldSwap = indexed(before['swapResults']);
    final newSwap = indexed(after['swapResults']);
    final changes = <JsonMap>[
      for (final key in {...oldUsage.keys, ...newUsage.keys})
        if (oldUsage[key]?['total'] != newUsage[key]?['total'] ||
            oldUsage[key]?['source'] != newUsage[key]?['source'])
          {
            'kind': 'usage',
            'day': (newUsage[key] ?? oldUsage[key])!['day'],
            'type': (newUsage[key] ?? oldUsage[key])!['type'],
            'from': oldUsage[key]?['total'],
            'to': newUsage[key]?['total'],
          },
      for (final key in {...oldSwap.keys, ...newSwap.keys})
        if (oldSwap[key]?['tried'] != newSwap[key]?['tried'] ||
            oldSwap[key]?['skipped'] != newSwap[key]?['skipped'] ||
            oldSwap[key]?['used'] != newSwap[key]?['used'] ||
            oldSwap[key]?['source'] != newSwap[key]?['source'])
          {
            'kind': 'swap_result',
            'day': (newSwap[key] ?? oldSwap[key])!['day'],
            'type': (newSwap[key] ?? oldSwap[key])!['type'],
            'from_tried': oldSwap[key]?['tried'],
            'tried': newSwap[key]?['tried'],
            'skipped': newSwap[key]?['skipped'],
            'used': newSwap[key]?['used'],
          },
      for (final day in window)
        if (_habitSwapCount(before['habitSwaps'], day) !=
            _habitSwapCount(after['habitSwaps'], day))
          {
            'kind': 'habit_swap',
            'day': day,
            'from': _habitSwapCount(before['habitSwaps'], day),
            'to': _habitSwapCount(after['habitSwaps'], day),
          },
      {'kind': 'product_choice', 'to': participant['proposedProductChoice']},
    ];
    return changes;
  }

  int _habitSwapCount(Object? rows, String day) => (rows as List? ?? const [])
      .whereType<Map>()
      .where((row) => row['day'] == day)
      .length;

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
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _saving ? null : _importCorrectionPlan,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Impor koreksi UAT'),
          ),
        ),
        const SizedBox(height: 6),
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
              'Pilih peserta untuk melihat progresnya.',
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
            '${editor.reduction ? ', mengisi total ${editor.reductionProducts.join(' / ')}, Habit Swap, dan hasilnya' : ''}. '
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
                labelText: 'Catatan',
                hintText: 'Catatan perubahan (opsional)',
              ),
            ),
            Wrap(
              spacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: changes.isEmpty || _saving ? null : _save,
                  icon: const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'Menyimpan...' : 'Simpan perubahan'),
                ),
                TextButton(
                  onPressed: changes.isEmpty
                      ? null
                      : () => setState(() {
                          _editor = AdminProgressEditor(
                            person.payload,
                            now: _now,
                          );
                          _edits.clear();
                        }),
                  child: const Text('Batalkan perubahan'),
                ),
              ],
            ),
          ],
        ),
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
        if (editor.reductionProducts.contains('rokok') && rokok != null)
          'rokok $rokok',
        if (editor.reductionProducts.contains('vape') && vape != null)
          'vape $vape',
        if (editor.swapsOn(day) > 0) 'Habit Swap ${editor.swapsOn(day)}',
        for (final type in editor.reductionProducts)
          if (editor.swapResult(day, type) case final r?)
            '$type: ${r.skipped} tidak jadi, ${r.used} tetap',
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
                  ? 'tercatat'
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
              value: AdminProgressEditor.isDone(task),
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
                  else if (AdminProgressEditor.invalidByApp(task))
                    'selesai di versi lama, belum dihitung',
                ].join(' · '),
              ),
            ),
          if (editor.reduction) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                for (final type in editor.reductionProducts)
                  _Counter(
                    label: type == 'rokok' ? 'Rokok (batang)' : 'Vape (sesi)',
                    value: editor.usage(day, type),
                    min: 0,
                    max: 500,
                    onChanged: (v) =>
                        _edit((e) => e.setUsage(day, type, v ?? 0)),
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
            const SizedBox(height: 12),
            Text(
              'Hasil Habit Swap',
              style: TextStyle(color: c.muted, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                for (final type in editor.reductionProducts) ...[
                  _Counter(
                    label: 'Tidak jadi ${type == 'rokok' ? 'merokok' : 'vape'}',
                    value: editor.swapResult(day, type)?.skipped,
                    min: 0,
                    max: 200,
                    onChanged: (v) => _edit(
                      (e) => e.setSwapResult(day, type, skipped: v ?? 0),
                    ),
                  ),
                  _Counter(
                    label: 'Tetap ${type == 'rokok' ? 'merokok' : 'vape'}',
                    value: editor.swapResult(day, type)?.used,
                    min: 0,
                    max: 200,
                    onChanged: (v) =>
                        _edit((e) => e.setSwapResult(day, type, used: v ?? 0)),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
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
