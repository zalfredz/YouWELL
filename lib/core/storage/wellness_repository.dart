/// Serialized app state boundary. The controller does not depend on a browser SDK.
abstract interface class WellnessRepository {
  Future<String?> read();
  Future<void> write(String serializedState);
}
