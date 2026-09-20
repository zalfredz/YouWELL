import 'dart:async';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
