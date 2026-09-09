import 'dart:convert';
import 'package:youwell/core/types/json_map.dart';

/// Version-2 storage schema. Keep existing keys compatible to retain local progress.
JsonMap createEmptyWellnessState() => {
      'version': 2,
      'dayOffset': 0,
      'profile': null,
      'days': <String, dynamic>{},
      'meals': [],
      'activities': [],
      'moods': [],
      'cravings': [],
      'focusSessions': [],
      'posts': [],
      'reactions': [],
      'reports': [],
      'frozen': [],
      'buddy': null,
      'squad': false,
    };

JsonMap restoreWellnessState(String serialized) {
  final decoded = jsonDecode(serialized);
  if (decoded is! Map<String, dynamic> || decoded['version'] != 2) {
    throw const FormatException('Unsupported local state format');
  }
  return {...createEmptyWellnessState(), ...decoded};
}
