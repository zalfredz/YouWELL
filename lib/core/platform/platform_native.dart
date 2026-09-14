import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

final _imagePicker = ImagePicker();

void download(String filename, Uint8List bytes, String mime) {
  unawaited(
    SharePlus.instance.share(
      ShareParams(
        title: 'YouWell',
        files: [XFile.fromData(bytes, mimeType: mime)],
        fileNameOverrides: [filename],
      ),
    ),
  );
}

Future<String?> pickPhoto() async {
  final photo = await _imagePicker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 78,
    maxWidth: 1440,
  );
  if (photo == null) return null;

  final bytes = await photo.readAsBytes();
  final mime = photo.mimeType ?? _imageMime(photo.name);
  return 'data:$mime;base64,${base64Encode(bytes)}';
}

Future<String?> pickAudio() async => null;

void sound(String name) {
  if (name == 'stop') return;
  if (name == 'ding') {
    unawaited(SystemSound.play(SystemSoundType.alert));
  } else if (name == 'release') {
    unawaited(HapticFeedback.mediumImpact());
  }
}

void setSoundVolume(double value) {}
void playCustomAudio(String source) {}
void pauseCustomAudio() {}

void openLink(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
}

String _imageMime(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.heic')) return 'image/heic';
  return 'image/jpeg';
}
