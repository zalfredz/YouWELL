import 'dart:typed_data';

/// Meal Snap verification (phase 9, team decision 23 Oct 2026): a photo is
/// reviewed by an MFA admin, or by the Edge Function `meal-ai-check` after
/// 3 hours without a decision. The file is deleted once decided.
abstract interface class MealVerifier {
  /// Uploads one PNG for the meal row [clientId] and queues it for review.
  Future<void> submit(String clientId, Uint8List png);

  /// The account's decisions of the last 30 days: client id → status
  /// ('pending', 'approved' or 'rejected').
  Future<Map<String, String>> decisions();

  /// Asks the server to check the caller's photos waiting over 3 hours.
  Future<void> checkOverdue();

  /// Admin: photos waiting for a decision, oldest first.
  Future<List<MealReview>> queue();

  /// Admin: the latest decisions, by admin or AI.
  Future<List<MealDecision>> recent();

  /// Admin: approves or rejects one photo, then deletes the file.
  Future<void> review(String id, {required bool approve});

  /// Admin: runs the AI check for every photo waiting over 3 hours.
  Future<void> checkAllOverdue();
}

class MealReview {
  const MealReview({
    required this.id,
    required this.alias,
    required this.createdAt,
    this.imageUrl,
  });
  final String id, alias;
  final DateTime createdAt;
  final String? imageUrl;
}

class MealDecision {
  const MealDecision({
    required this.id,
    required this.alias,
    required this.approved,
    required this.byAi,
    this.reviewedAt,
  });
  final String id, alias;
  final bool approved, byAi;
  final DateTime? reviewedAt;
}

class MealVerifierException implements Exception {
  const MealVerifierException(this.message, {this.unsupported = false});
  final String message;

  /// The server has no phase 9 yet: the photo counts as before.
  final bool unsupported;
  @override
  String toString() => message;
}
