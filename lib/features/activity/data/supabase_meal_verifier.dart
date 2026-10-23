import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youwell/features/auth/data/fresh_session.dart';
import 'package:youwell/features/community/data/community_photo.dart';
import '../domain/meal_verifier.dart';

/// Meal Snap verification through the phase 9 RPCs. Photos sit in the
/// private `meals` bucket only until an admin or the AI fallback decides.
class SupabaseMealVerifier implements MealVerifier {
  SupabaseMealVerifier({
    required this.client,
    required this.userId,
    required this.url,
    required this.publishableKey,
  });
  final SupabaseClient client;
  final String userId, url, publishableKey;

  static const bucket = 'meals';
  static const function = 'meal-ai-check';

  Future<Session> _session() async {
    try {
      return await freshSession(client, userId);
    } catch (_) {
      throw const MealVerifierException(
        'Sesi login perlu diperbarui. Periksa koneksi lalu coba lagi.',
      );
    }
  }

  // Bound to this account's JWT, as in Community and progress sync.
  Future<T> _call<T>(String name, [Map<String, dynamic>? params]) async {
    final session = await _session();
    final request = PostgrestClient(
      '$url/rest/v1',
      headers: {
        'apikey': publishableKey,
        'Authorization': 'Bearer ${session.accessToken}',
      },
      retryEnabled: false,
      requestTimeout: const Duration(seconds: 10),
    );
    try {
      return await request.rpc(name, params: params) as T;
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST202' || error.code == '42883') {
        throw const MealVerifierException(
          'Server belum mendukung verifikasi Meal Snap. Jalankan migration '
          'Supabase tahap 9.',
          unsupported: true,
        );
      }
      throw MealVerifierException(switch (error.code) {
        'P0002' => 'Foto ini sudah diputuskan.',
        '42501' => 'Akses ini butuh akun admin dengan verifikasi dua langkah.',
        '22023' => 'Foto belum terunggah. Coba kirim lagi.',
        _ => 'Verifikasi belum terhubung. Periksa koneksi lalu coba lagi.',
      });
    } catch (_) {
      throw const MealVerifierException(
        'Verifikasi belum terhubung. Periksa koneksi lalu coba lagi.',
      );
    } finally {
      await request.dispose();
    }
  }

  @override
  Future<void> submit(String clientId, Uint8List png) async {
    await _session();
    final path = '$userId/${randomUuid()}.png';
    try {
      await client.storage
          .from(bucket)
          .uploadBinary(
            path,
            png,
            fileOptions: const FileOptions(contentType: 'image/png'),
          );
    } on StorageException catch (error) {
      final text = '${error.message} ${error.error ?? ''}'.toLowerCase();
      if (text.contains('bucket not found')) {
        throw const MealVerifierException(
          'Penyimpanan foto makan belum disiapkan di server. Jalankan '
          'migration Supabase tahap 9.',
          unsupported: true,
        );
      }
      throw const MealVerifierException(
        'Foto belum bisa dikirim. Periksa koneksi lalu coba lagi.',
      );
    } catch (_) {
      throw const MealVerifierException(
        'Foto belum bisa dikirim. Periksa koneksi lalu coba lagi.',
      );
    }
    try {
      await _call<Object?>('submit_youwell_meal', {
        'p_client_id': clientId,
        'p_image_path': path,
      });
    } catch (_) {
      await _remove([path]);
      rethrow;
    }
  }

  @override
  Future<Map<String, String>> decisions() async {
    final rows = await _call<List>('youwell_my_meal_checks');
    return {
      for (final row in rows.whereType<Map>())
        if (row['client_id'] case final String id)
          id: row['status']?.toString() ?? 'pending',
    };
  }

  Future<void> _invoke() async {
    final session = await _session();
    try {
      await client.functions.invoke(
        function,
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );
    } catch (_) {
      // The function may not be deployed yet; photos simply stay pending.
    }
  }

  @override
  Future<void> checkOverdue() => _invoke();

  @override
  Future<void> checkAllOverdue() => _invoke();

  @override
  Future<List<MealReview>> queue() async {
    final rows = (await _call<List>('youwell_meal_queue')).whereType<Map>();
    final paths = [
      for (final row in rows)
        if (row['image_path'] case final String path) path,
    ];
    var links = <String, String>{};
    if (paths.isNotEmpty) {
      try {
        final signed = await client.storage
            .from(bucket)
            .createSignedUrlsResult(paths, 900);
        links = {
          for (final link in signed.whereType<SignedUrlSuccess>())
            link.path: link.signedUrl,
        };
      } catch (_) {
        // The decisions still load; the photo shows as unavailable.
      }
    }
    return [
      for (final row in rows)
        MealReview(
          id: row['id'].toString(),
          alias: row['alias']?.toString() ?? 'peserta',
          createdAt:
              DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
          imageUrl: links[row['image_path']],
        ),
    ];
  }

  @override
  Future<List<MealDecision>> recent() async => [
    for (final row
        in (await _call<List>('youwell_meal_recent')).whereType<Map>())
      MealDecision(
        id: row['id'].toString(),
        alias: row['alias']?.toString() ?? 'peserta',
        approved: row['status'] == 'approved',
        byAi: row['reviewer'] == 'ai',
        reviewedAt: DateTime.tryParse(
          row['reviewed_at']?.toString() ?? '',
        )?.toLocal(),
      ),
  ];

  @override
  Future<void> review(String id, {required bool approve}) async {
    final photo = await _call<Object?>('review_youwell_meal', {
      'p_id': id,
      'p_approve': approve,
    });
    if (photo is String) await _remove([photo]);
  }

  Future<void> _remove(List<String> paths) async {
    try {
      await client.storage.from(bucket).remove(paths);
    } catch (_) {
      // Best effort; the file stays private to its author and admins.
    }
  }
}
