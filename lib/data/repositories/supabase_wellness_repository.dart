import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youwell/core/storage/wellness_repository.dart';

/// Persists the complete wellness snapshot for the currently signed-in account.
/// Row Level Security in Supabase limits each user to their own row.
class SupabaseWellnessRepository implements WellnessRepository {
  SupabaseWellnessRepository(this._client);

  final SupabaseClient _client;

  User get _user {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Masuk ke akun terlebih dahulu.');
    return user;
  }

  @override
  Future<String?> read() async {
    final row = await _client
        .from('wellness_snapshots')
        .select('state')
        .eq('user_id', _user.id)
        .maybeSingle();
    return row?['state'] as String?;
  }

  @override
  Future<void> write(String serializedState) async {
    await _client.from('wellness_snapshots').upsert({
      'user_id': _user.id,
      'state': serializedState,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  }
}
