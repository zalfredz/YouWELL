import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/config/app_environment.dart';
import 'package:youwell/data/repositories/local_wellness_repository.dart';
import 'package:youwell/data/repositories/supabase_wellness_repository.dart';

/// Owns the signed-in session, role and safe handoff from local to cloud data.
class AppAuthController extends ChangeNotifier {
  static const _syncTimeout = Duration(seconds: 12);
  AppAuthController.connected({
    required SupabaseClient client,
    required WellnessController wellness,
    required LocalWellnessRepository localRepository,
  })  : _client = client,
        _wellness = wellness,
        _localRepository = localRepository;

  AppAuthController.disabled({
    required WellnessController wellness,
    required LocalWellnessRepository localRepository,
  })  : _client = null,
        _wellness = wellness,
        _localRepository = localRepository;

  final SupabaseClient? _client;
  final WellnessController _wellness;
  final LocalWellnessRepository _localRepository;
  StreamSubscription<AuthState>? _subscription;
  SupabaseWellnessRepository? _remoteRepository;
  String? _activeUserId;
  String? _loadingUserId;
  String? _role;
  String? error;
  bool isReady = false;
  int _syncRevision = 0;

  bool get isEnabled => _client != null;
  bool get isAuthenticated => _client?.auth.currentSession != null;
  bool get isAdmin => _role == 'admin';
  String? get email => _client?.auth.currentUser?.email;

  Future<void> initialize() async {
    if (_client == null) {
      isReady = true;
      notifyListeners();
      return;
    }
    _subscription = _client.auth.onAuthStateChange.listen(
      (event) => unawaited(_applySession(event.session)),
    );
    await _applySession(_client.auth.currentSession);
  }

  Future<void> _applySession(Session? session) async {
    final revision = ++_syncRevision;
    final user = session?.user;
    if (user == null) {
      _activeUserId = null;
      _loadingUserId = null;
      _role = null;
      _wellness.setPersistence(_localRepository.write);
      _wellness.restoreFrom(null);
      error = null;
      isReady = true;
      notifyListeners();
      return;
    }

    if (_activeUserId == user.id && (_loadingUserId == user.id || isReady)) {
      return;
    }
    _activeUserId = user.id;
    _loadingUserId = user.id;
    isReady = false;
    error = null;
    notifyListeners();

    try {
      _remoteRepository = SupabaseWellnessRepository(_client!);
      final profile = await _client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(_syncTimeout);
      var remoteState = await _remoteRepository!.read().timeout(_syncTimeout);

      // A visitor's existing local work is moved to their first signed-in row.
      if (remoteState == null) {
        remoteState = await _localRepository.read();
        if (remoteState != null) await _remoteRepository!.write(remoteState);
      }
      await _localRepository.clear();

      if (revision != _syncRevision) return;
      _role = profile?['role'] as String? ?? 'user';
      _wellness.setPersistence(_remoteRepository!.write);
      _wellness.restoreFrom(remoteState);
    } on Object catch (_) {
      if (revision != _syncRevision) return;
      error =
          'Akun berhasil masuk, tetapi data belum dapat disinkronkan. Pastikan migration Supabase sudah dijalankan.';
      _role = 'user';
      _wellness.setPersistence(_localRepository.write);
    } finally {
      if (revision == _syncRevision) {
        _loadingUserId = null;
        isReady = true;
        notifyListeners();
      }
    }
  }

  Future<void> signInWithGoogle() async {
    if (_client == null) return;
    error = null;
    notifyListeners();
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : AppEnvironment.mobileAuthRedirectUrl,
      );
    } on AuthException catch (exception) {
      error = exception.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (_client == null) return;
    await _client.auth.signOut();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
