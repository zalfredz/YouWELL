import 'dart:convert';

import 'package:youwell/core/types/json_map.dart';

/// Local-only product state while the experience is being validated.
/// Version 3 remains backward-compatible with new local activity collections.
JsonMap createEmptyWellnessState() => {
  'version': 3,
  'dayOffset': 0,
  'profile': null,
  'days': <String, dynamic>{},
  'energyCheckIns': <dynamic>[],
  'focusSessions': <dynamic>[],
  'habitDelays': <dynamic>[],
  'workoutSessions': <dynamic>[],
  'mealCheckIns': <dynamic>[],
  'communityPosts': <dynamic>[],
  'communityReactions': <dynamic>[],
  'communityReports': <dynamic>[],
  'squad': null,
  'buddy': null,
};

JsonMap restoreWellnessState(String serialized) {
  final decoded = jsonDecode(serialized);
  if (decoded is! Map<String, dynamic> || decoded['version'] != 3) {
    throw const FormatException('Unsupported local state format');
  }
  return {...createEmptyWellnessState(), ...decoded};
}
