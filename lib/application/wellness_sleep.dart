part of 'wellness_controller.dart';

/// Sleep check-in ("Aku mau tidur") and check-out ("Aku sudah bangun"),
/// for the sleep quests of 23 Oct–4 Nov 2026 (Istirahat is calm breathing
/// from 5 Nov); kept so those quests and an open check-in can still finish,
/// both stamped with the time the button is pressed; times are never typed
/// in afterwards, so a missed press simply does not count. The times stay
/// on this device; only the quest's completion is synced. A night belongs
/// to the day the user wakes up, which is the day its quest is on.
extension SleepCheckIns on WellnessController {
  List<JsonMap> get sleepLogs => _rows('sleepLogs');

  /// Bedtime of a check-in still waiting for its check-out.
  DateTime? get sleepCheckIn {
    final value = DateTime.tryParse(_data['openSleep']?.toString() ?? '');
    // A check-in older than 20 hours is stale and no longer offered.
    if (value == null || now.difference(value).inHours >= 20) return null;
    return value;
  }

  /// Last night, recorded with a check-out today.
  JsonMap? get lastNightSleep =>
      sleepLogs.where((row) => row['day'] == today).lastOrNull;

  /// Check-ins open from 18.00 to 06.00, so a tap during the day cannot
  /// start a "night" that blocks tonight's real one.
  static bool bedtimeWindow(DateTime time) => time.hour >= 18 || time.hour < 6;

  bool get canCheckInSleep =>
      profile != null && sleepCheckIn == null && bedtimeWindow(now);

  bool checkInSleep() {
    if (!canCheckInSleep) return false;
    _data['openSleep'] = now.toIso8601String();
    _save();
    return true;
  }

  void cancelSleepCheckIn() {
    if (_data.remove('openSleep') != null) _save();
  }

  /// "Aku sudah bangun": closes tonight's check-in at this moment.
  bool checkOutSleep() {
    final bed = sleepCheckIn;
    if (bed == null) return false;
    return recordSleep(bedAt: bed, wakeAt: now);
  }

  /// One night per wake-up day: the longer one is kept, so an evening nap
  /// never replaces the night that ended that morning. Nights shorter than
  /// 2 hours or longer than 16 are not plausible.
  bool recordSleep({required DateTime bedAt, required DateTime wakeAt}) {
    final hours = wakeAt.difference(bedAt).inMinutes / 60;
    if (profile == null || hours < 2 || hours > 16 || wakeAt.isAfter(now)) {
      return false;
    }
    final day = dayKey(wakeAt);
    final rows = (_data['sleepLogs'] ??= <dynamic>[]) as List;
    final kept = rows.whereType<Map>().where((row) => row['day'] == day);
    for (final row in kept) {
      final bed = DateTime.tryParse(row['bedAt']?.toString() ?? '');
      final wake = DateTime.tryParse(row['wakeAt']?.toString() ?? '');
      if (bed != null &&
          wake != null &&
          wake.difference(bed) >= wakeAt.difference(bedAt)) {
        _data.remove('openSleep');
        if (day == today) _applySleepEvidence();
        _save();
        return true;
      }
    }
    rows.removeWhere((row) => row is Map && row['day'] == day);
    rows.add({
      'id': 'sleep-${wakeAt.microsecondsSinceEpoch}',
      'day': day,
      'bedAt': bedAt.toIso8601String(),
      'wakeAt': wakeAt.toIso8601String(),
    });
    _data.remove('openSleep');
    if (day == today) _applySleepEvidence();
    _save();
    return true;
  }

  void _applySleepEvidence() {
    final night = lastNightSleep;
    if (night == null) return;
    for (final task in quests) {
      if (task['activityKind'] == 'sleep' &&
          task['status'] != 'completed' &&
          sleepMeets(task, night)) {
        completeCard(task['id'].toString());
      }
    }
  }
}

/// Minutes after 18.00 (so 00.30 is later than 23.00).
int bedMinutes(DateTime time) => (time.hour * 60 + time.minute - 1080) % 1440;

/// Whether [night] went to bed and woke up early enough for [task].
bool sleepMeets(Map task, Map night) {
  final bed = DateTime.tryParse(night['bedAt']?.toString() ?? '');
  final wake = DateTime.tryParse(night['wakeAt']?.toString() ?? '');
  final bedBefore = (task['bedBefore'] as num?)?.toInt();
  final wakeBefore = (task['wakeBefore'] as num?)?.toInt();
  if (bed == null || wake == null || bedBefore == null || wakeBefore == null) {
    return false;
  }
  return bedMinutes(bed) <= bedBefore &&
      wake.hour * 60 + wake.minute <= wakeBefore;
}
