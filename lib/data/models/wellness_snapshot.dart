import 'dart:convert';

import 'package:youwell/core/types/json_map.dart';

/// Local-only product state while the experience is being validated.
/// Version 3 drops earlier social, moderation, nutrition, and clinical demos.
JsonMap createEmptyWellnessState() => {
  'version': 3,
  'dayOffset': 0,
  'profile': null,
  'days': <String, dynamic>{},
  'energyCheckIns': <dynamic>[],
  'focusSessions': <dynamic>[],
  'habitDelays': <dynamic>[],
};

JsonMap restoreWellnessState(String serialized) {
  final decoded = jsonDecode(serialized);
  if (decoded is! Map<String, dynamic> || decoded['version'] != 3) {
    throw const FormatException('Unsupported local state format');
  }
  return {...createEmptyWellnessState(), ...decoded};
}
