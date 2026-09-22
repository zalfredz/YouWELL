import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/activity/data/meal_photo_store.dart';

class MealSnapPage extends StatefulWidget {
  const MealSnapPage({super.key, required this.controller});
  final WellnessController controller;

  @override
  State<MealSnapPage> createState() => _MealSnapPageState();
}

class _MealSnapPageState extends State<MealSnapPage> {
  final _picker = ImagePicker();
  Uint8List? _photo;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _recoverInterruptedPick();
  }

  Future<void> _recoverInterruptedPick() async {
    try {
      final response = await _picker.retrieveLostData();
      final image = response.files?.firstOrNull;
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (mounted) setState(() => _photo = bytes);
    } catch (_) {
      // The regular camera/gallery actions remain available.
    }
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        imageQuality: 72,
      );
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      if (mounted) {
        setState(() {
          _photo = bytes;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Foto belum bisa dibuka. Coba galeri atau periksa izin kamera.',
        );
      }
    }
  }

  Future<void> _save() async {
    final photo = _photo;
    if (photo == null || _saving) return;
    setState(() => _saving = true);
    try {
      final path = await MealPhotoStore.save(photo);
      if (path == null) {
        throw const FormatException('Penyimpanan foto tidak tersedia.');
      }
      widget.controller.recordMeal(photoPath: path);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Foto gagal disimpan di perangkat ini.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Meal Snap')),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const Text(
          'Catat makanmu',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          'Jurnal visual pribadi. Tanpa hitung kalori atau penilaian makanan.',
          style: TextStyle(color: appMuted),
        ),
        const SizedBox(height: 24),
        Container(
          height: 280,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: appSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: appBorder),
          ),
          child: _photo == null
              ? const Center(
                  child: Icon(
                    Icons.photo_camera_outlined,
                    size: 72,
                    color: appMuted,
                  ),
                )
              : Image.memory(_photo!, fit: BoxFit.cover),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pick(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Kamera'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galeri'),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!, style: const TextStyle(color: appAccentAmber)),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _photo == null || _saving ? null : _save,
          icon: const Icon(Icons.check_rounded),
          label: Text(_saving ? 'Menyimpan...' : 'Simpan momen'),
        ),
      ],
    ),
  );
}
