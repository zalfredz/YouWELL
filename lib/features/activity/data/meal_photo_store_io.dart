import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

class MealPhotoStore {
  static Future<Directory> _folder() async {
    final root = await getApplicationDocumentsDirectory();
    return Directory('${root.path}/meal_photos');
  }

  static Future<String?> save(Uint8List bytes) async {
    final folder = await _folder();
    await folder.create(recursive: true);
    final path = '${folder.path}/${DateTime.now().microsecondsSinceEpoch}.jpg';
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  static Future<Uint8List?> read(String path) async {
    if (!await File(path).exists()) return null;
    return File(path).readAsBytes();
  }

  static Future<void> clear() async {
    final folder = await _folder();
    if (await folder.exists()) await folder.delete(recursive: true);
  }
}
