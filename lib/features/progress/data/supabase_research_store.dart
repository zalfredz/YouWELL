import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youwell/core/types/json_map.dart';
import '../domain/research_store.dart';

class SupabaseResearchStore implements ResearchStore {
  SupabaseResearchStore(this.client);
  final SupabaseClient client;

  @override
  Future<List<JsonMap>> progressOverview() async {
    final rows = await client.rpc('youwell_admin_progress_overview') as List;
    return [
      for (final row in rows.whereType<Map>()) Map<String, dynamic>.from(row),
    ];
  }

  @override
  Future<void> setParticipantCode(String account, String? code) async {
    try {
      await client.rpc(
        'set_youwell_participant_code',
        params: {'p_account': account, 'p_code': code},
      );
    } on PostgrestException catch (error) {
      throw StateError(
        error.code == '23505'
            ? 'Kode $code sudah dipakai akun lain.'
            : 'Kode belum tersimpan. Periksa koneksi dan migration tahap 6.',
      );
    }
  }

  static StateError _error(
    PostgrestException error,
  ) => StateError(switch (error.code) {
    'PGRST202' || '42883' =>
      'Server belum mendukung Overview. Jalankan migration Supabase tahap 10.',
    '42501' => 'Akses ini butuh akun admin dengan verifikasi dua langkah.',
    '22023' when error.message.contains('Reason') =>
      'Tulis alasan intervensi (minimal 5 karakter).',
    '22023' => 'Data ditolak server: ${error.message}',
    'P0002' => 'Data peserta tidak ditemukan.',
    _ => 'Perubahan belum tersimpan. Periksa koneksi lalu coba lagi.',
  });

  Future<Object?> _rpc(String name, Map<String, dynamic> params) async {
    try {
      return await client.rpc(name, params: params);
    } on PostgrestException catch (error) {
      throw _error(error);
    }
  }

  @override
  Future<bool> writeProgress({
    required String account,
    required int expectedRevision,
    required JsonMap payload,
    required String reason,
    required List<JsonMap> changes,
  }) async {
    final result = await _rpc('admin_write_youwell_progress', {
      'p_account': account,
      'p_expected_revision': expectedRevision,
      'p_payload': payload,
      'p_reason': reason,
      'p_changes': changes,
    });
    return result is Map && result['saved'] == true;
  }

  @override
  Future<List<JsonMap>> interventions() async => [
    for (final row
        in ((await _rpc('youwell_admin_interventions', {})) as List)
            .whereType<Map>())
      Map<String, dynamic>.from(row),
  ];

  @override
  Future<List<JsonMap>> history(String account) async => [
    for (final row
        in ((await _rpc('youwell_admin_progress_history', {
                  'p_account': account,
                }))
                as List)
            .whereType<Map>())
      Map<String, dynamic>.from(row),
  ];

  @override
  Future<void> restoreRevision(
    String account,
    int revision,
    String reason,
  ) async {
    await _rpc('admin_restore_youwell_revision', {
      'p_account': account,
      'p_revision': revision,
      'p_reason': reason,
    });
  }
}
