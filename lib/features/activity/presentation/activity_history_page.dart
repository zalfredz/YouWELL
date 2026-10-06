import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/features/activity/data/meal_photo_store.dart';

class ActivityHistoryPage extends StatelessWidget {
  const ActivityHistoryPage({super.key, required this.controller});
  final WellnessController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final rows = [
        for (final row in controller.workoutSessions)
          {...row, 'collection': 'workoutSessions'},
        for (final row in controller.mealCheckIns)
          {...row, 'collection': 'mealCheckIns'},
      ]..sort((a, b) => b['time'].toString().compareTo(a['time'].toString()));
      return Scaffold(
        appBar: AppBar(title: const Text('Riwayat aktivitas')),
        body: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Text(
              'Catatan pribadi. Koreksi tidak mengulang atau mencabut XP.',
              style: TextStyle(color: context.colors.muted),
            ),
            const SizedBox(height: 16),
            if (rows.isEmpty)
              const Text('Belum ada catatan. Mulai dari satu aktivitas kecil.'),
            for (final row in rows)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Icon(
                    row['collection'] == 'mealCheckIns'
                        ? Icons.restaurant_outlined
                        : Icons.directions_walk_rounded,
                    color: context.colors.accent,
                  ),
                  title: Text(
                    row['collection'] == 'mealCheckIns'
                        ? 'Momen makan'
                        : row['kind'] == 'run'
                        ? 'Lari'
                        : 'Jalan',
                  ),
                  subtitle: Text(row['day'].toString()),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => _ActivityDetailPage(
                        controller: controller,
                        collection: row['collection'].toString(),
                        id: row['id'].toString(),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _ActivityDetailPage extends StatefulWidget {
  const _ActivityDetailPage({
    required this.controller,
    required this.collection,
    required this.id,
  });
  final WellnessController controller;
  final String collection, id;
  @override
  State<_ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<_ActivityDetailPage> {
  String? _error;
  bool _deleting = false;
  bool get _meal => widget.collection == 'mealCheckIns';
  JsonMap? get _row =>
      (_meal
              ? widget.controller.mealCheckIns
              : widget.controller.workoutSessions)
          .where((row) => row['id'] == widget.id)
          .firstOrNull;
  Future<void> _edit(JsonMap row) async {
    var note = row['note']?.toString() ?? '';
    final saved = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit catatan pribadi'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_meal) ...[
                const Text(
                  'Durasi dan jarak tidak bisa diedit. Hapus sesi jika keliru.',
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                initialValue: note,
                onChanged: (value) => note = value,
                maxLength: 200,
                maxLines: 3,
                decoration: InputDecoration(labelText: 'Catatan pribadi'),
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
            onPressed: () => Navigator.pop(dialogContext, note),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (saved == null || !mounted) return;
    final changed = widget.controller.editActivity(
      widget.collection,
      widget.id,
      note: saved,
    );
    setState(() => _error = changed ? null : 'Catatan belum bisa disimpan.');
  }

  Future<void> _delete(JsonMap row) async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus catatan ini?'),
        content: Text(
          _meal
              ? 'Catatan dan foto lokal dihapus permanen. XP yang sudah diperoleh tetap tersimpan.'
              : 'Sesi dihapus permanen dan tidak lagi menjadi bukti evaluasi tangga atau quest penelitian. XP tetap tersimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (agreed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      if (_meal && row['photoPath'] is String) {
        await MealPhotoStore.delete(row['photoPath']);
      }
      widget.controller.deleteActivity(widget.collection, widget.id);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Catatan belum bisa dihapus. Coba lagi.';
          _deleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = _row;
    return Scaffold(
      appBar: AppBar(title: Text(_meal ? 'Momen makan' : 'Detail gerak')),
      body: row == null
          ? const Center(child: Text('Catatan sudah dihapus.'))
          : ListView(
              padding: const EdgeInsets.all(22),
              children: [
                Text(
                  row['day'].toString(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                if (_meal && row['photoPath'] is String)
                  FutureBuilder<Uint8List?>(
                    future: MealPhotoStore.read(row['photoPath']),
                    builder: (context, snapshot) => ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: snapshot.data != null
                          ? Image.memory(snapshot.data!, fit: BoxFit.contain)
                          : SizedBox(
                              height: 180,
                              child: Center(
                                child: Text(
                                  snapshot.connectionState ==
                                          ConnectionState.waiting
                                      ? 'Membuka foto…'
                                      : 'Foto tidak tersedia.',
                                ),
                              ),
                            ),
                    ),
                  ),
                if (!_meal) ...[
                  Text(
                    '${((row['seconds'] as num?) ?? 0) ~/ 60} menit · ${row['meters'] ?? 0} meter',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (row['countsForQuest'] == false)
                    Text(
                      'Sesi tersimpan, tetapi tidak dihitung untuk quest.',
                      style: TextStyle(color: context.colors.muted),
                    ),
                ],
                const SizedBox(height: 16),
                if (row['note']?.toString().isNotEmpty == true)
                  Text(row['note'].toString()),
                if (row['correctedAt'] != null || row['noteEditedAt'] != null)
                  Text(
                    'Catatan sudah dikoreksi',
                    style: TextStyle(color: context.colors.muted),
                  ),
                if (_error != null)
                  Text(_error!, style: TextStyle(color: context.colors.amber)),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _deleting ? null : () => _edit(row),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit catatan'),
                ),
                TextButton.icon(
                  onPressed: _deleting ? null : () => _delete(row),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Hapus catatan'),
                ),
              ],
            ),
    );
  }
}
