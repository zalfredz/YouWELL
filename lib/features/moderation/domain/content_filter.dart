import 'package:youwell/features/support/domain/crisis_detector.dart';

/// Local pre-moderation rules. Production moderation must also run server-side.
String? moderationReason(String text) {
  if (crisisSignal(text)) {
    return 'Ceritamu membutuhkan dukungan pribadi. Buka bantuan sekarang; kiriman ini tidak dipublikasikan.';
  }
  if (RegExp(
    r'\b\d[\d\s+().-]{6,}\d\b|[\w.+-]+@[\w.-]+\.[a-z]{2,}|https?://|www\.|@[a-z0-9_]+|\b(jl\.?|alamat|instagram|whatsapp|telegram)\s|\bjalan\s+\w+\s+(nomor|no\.?)\s*\d',
    caseSensitive: false,
  ).hasMatch(text)) {
    return 'Hapus nomor, tautan, akun sosial, atau alamat pribadi sebelum mengirim.';
  }
  if (RegExp(
    r'\b(anjing|bangsat|tolol|goblok|bajingan|jual|promo|diskon)\b',
    caseSensitive: false,
  ).hasMatch(text)) {
    return 'Ubah kata kasar atau promosi agar ruang ini tetap nyaman.';
  }
  return null;
}
