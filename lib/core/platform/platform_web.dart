import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

@JS('wellDownload')
external void _download(JSString filename, JSString value, JSString mime);
@JS('wellPhoto')
external JSPromise<JSString> _photo();
@JS('wellSound')
external void _sound(JSString name);
@JS('wellSoundVolume')
external void _soundVolume(JSNumber value);
@JS('wellAudioPick')
external JSPromise<JSString> _audioPick();
@JS('wellCustomAudio')
external void _customAudio(JSString source);
@JS('wellCustomAudioPause')
external void _customAudioPause();
@JS('wellOpen')
external void _open(JSString url);
void download(String filename, Uint8List bytes, String mime) =>
    _download(filename.toJS, base64Encode(bytes).toJS, mime.toJS);
Future<String?> pickPhoto() async {
  final result = (await _photo().toDart).toDart;
  return result.isEmpty ? null : result;
}

void sound(String name) => _sound(name.toJS);
void setSoundVolume(double value) => _soundVolume(value.toJS);
Future<String?> pickAudio() async {
  final value = (await _audioPick().toDart).toDart;
  return value.isEmpty ? null : value;
}
void playCustomAudio(String source) => _customAudio(source.toJS);
void pauseCustomAudio() => _customAudioPause();
void openLink(String url) => _open(url.toJS);
