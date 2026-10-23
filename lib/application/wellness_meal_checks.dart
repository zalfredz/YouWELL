part of 'wellness_controller.dart';

/// Meal Snap verification (phase 9): a photo sent for review waits as
/// 'pending' until an admin, or the AI fallback after 3 hours, approves or
/// rejects it. Only approved photos (and photos from before verification)
/// count; the reward goes to the day the photo was taken.
extension MealChecks on WellnessController {
  /// Photos still waiting for a decision.
  List<JsonMap> get pendingMealChecks => [
    for (final row in mealCheckIns)
      if (row['verification'] == 'pending' && row['checkId'] is String) row,
  ];

  /// Whether any pending photo was sent more than [age] ago.
  bool hasMealCheckOlderThan(Duration age) => pendingMealChecks.any((row) {
    final time = DateTime.tryParse(row['time']?.toString() ?? '');
    return time != null && now.difference(time) >= age;
  });

  /// 'pending' or 'rejected' for an unfinished meal quest on [day] (today
  /// by default), so the quest can say why it is not checked yet.
  String? mealVerificationFor(JsonMap task, {String? day}) {
    if (task['activityKind'] != 'meal_snap' || task['status'] == 'completed') {
      return null;
    }
    final photos = [
      for (final row in mealCheckIns)
        if (row['day'] == (day ?? today) &&
            row['verification'] is String &&
            (row['photoPath'] is String || row['photoCaptured'] == true))
          row['verification'],
    ];
    if (photos.contains('pending')) return 'pending';
    if (photos.isNotEmpty && photos.last == 'rejected') return 'rejected';
    return null;
  }

  /// Applies server decisions (check id → status); approved photos complete
  /// their day's meal quests. A decided photo is not kept on the device
  /// either: returns the local photo files to delete.
  List<String> applyMealVerdicts(Map<String, String> verdicts) {
    final approvedDays = <String>{};
    final files = <String>[];
    var changed = 0;
    for (final row in (_data['mealCheckIns'] as List).whereType<Map>()) {
      final verdict = verdicts[row['checkId']];
      if (row['verification'] != 'pending' ||
          (verdict != 'approved' && verdict != 'rejected')) {
        continue;
      }
      row['verification'] = verdict;
      // photoCaptured stays true, so an approved photo keeps counting.
      if (row.remove('photoPath') case final String path) files.add(path);
      changed++;
      if (verdict == 'approved') approvedDays.add(row['day'].toString());
    }
    if (changed == 0) return files;
    for (final day in approvedDays) {
      _applyMealPhotos(day: day);
    }
    _save();
    return files;
  }
}
