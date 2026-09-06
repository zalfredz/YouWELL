import 'package:shared_preferences/shared_preferences.dart';
import 'package:youwell/core/storage/wellness_repository.dart';

/// Local browser/device persistence. Keeps the existing key to preserve progress.
class LocalWellnessRepository implements WellnessRepository {
  LocalWellnessRepository(this._preferences, {required this.storageKey});
  final SharedPreferences _preferences;
  final String storageKey;

  @override
  Future<String?> read() async => _preferences.getString(storageKey);

  @override
  Future<void> write(String serializedState) async {
    final saved = await _preferences.setString(storageKey, serializedState);
    if (!saved) throw StateError('Penyimpanan perangkat penuh.');
  }

  /// Removes the unauthenticated cache after it has been moved into an account.
  Future<void> clear() async => _preferences.remove(storageKey);
}
