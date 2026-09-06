import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

@JS('wellDownload')
external void _download(JSString filename, JSString value, JSString mime);
@JS('wellPhoto')
external JSPromise<JSString> _photo();
@JS('wellSound')
external void _sound(JSString name);
@JS('wellOpen')
external void _open(JSString url);
void download(String filename, Uint8List bytes, String mime) =>
    _download(filename.toJS, base64Encode(bytes).toJS, mime.toJS);
Future<String?> pickPhoto() async {
  final result = (await _photo().toDart).toDart;
  return result.isEmpty ? null : result;
}

void sound(String name) => _sound(name.toJS);
void openLink(String url) => _open(url.toJS);
