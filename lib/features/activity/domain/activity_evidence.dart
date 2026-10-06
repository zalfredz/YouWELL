import 'dart:math';

import 'package:youwell/core/types/json_map.dart';

/// Timer/GPS evidence is separate from rewards, which are never taken back.
abstract final class ActivityEvidence {
  static bool isWorkout(JsonMap task) =>
      const {'walk', 'run'}.contains(task['activityKind']);

  static double workoutProgress(
    JsonMap task,
    Iterable<JsonMap> sessions,
    String day,
  ) {
    final targetMeters = (task['targetMeters'] as num?)?.toInt();
    final targetSeconds = max(
      1,
      ((task['durationMinutes'] as num?)?.toInt() ?? 0) * 60,
    );
    return sessions
        .where(
          (row) =>
              row['day'] == day &&
              row['countsForQuest'] != false &&
              // Old versions allowed editing metrics: those are not evidence.
              row['correctedAt'] == null &&
              (task['activityKind'] == 'walk'
                  ? const {'walk', 'run'}.contains(row['kind'])
                  : row['kind'] == 'run'),
        )
        .fold<double>(0, (sum, row) {
          final meters = (row['meters'] as num?)?.toInt() ?? 0;
          final seconds = (row['seconds'] as num?)?.toInt() ?? 0;
          return sum +
              (targetMeters != null && targetMeters > 0 && meters > 0
                  ? meters / targetMeters
                  : seconds / targetSeconds);
        });
  }
}
