/// Public build-time configuration loaded with --dart-define-from-file.
/// Values in Flutter web bundles are visible to visitors; never put secrets here.
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
  // Public client credentials for Supabase auth and account-scoped sync.
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const mobileAuthRedirectUrl = String.fromEnvironment(
    'MOBILE_AUTH_REDIRECT_URL',
    defaultValue: 'com.youwell.app://login-callback/',
  );

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
