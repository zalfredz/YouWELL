/// Public build-time configuration loaded with --dart-define-from-file.
/// Values are injected with --dart-define-from-file at build time.
abstract final class AppEnvironment {
  static const appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'YouWell',
  );
  static const name = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  static const storageKey = String.fromEnvironment(
    'LOCAL_STORAGE_KEY',
    defaultValue: 'youwell.local.v2',
  );
  static const showPreviewTools = bool.fromEnvironment(
    'SHOW_PREVIEW_TOOLS',
    defaultValue: true,
  );
  static const playStoreUrl = String.fromEnvironment('PLAY_STORE_URL');
  static const appStoreUrl = String.fromEnvironment('APP_STORE_URL');
}
