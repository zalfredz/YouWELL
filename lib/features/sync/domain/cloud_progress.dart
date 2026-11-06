import 'dart:collection';
import 'dart:convert';
import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/data/models/wellness_snapshot.dart';

/// Explicit cloud boundary. Never send a raw controller export to the server.
abstract final class CloudProgress {
  static const _shared = [
    'days',
    'capacity',
    'mobileRewards',
    'achievements',
    'openedDays',
    // Days an admin marked as opened (Overview); kept apart for research.
    'adminOpenedDays',
    'activityDays',
    'levelFloor',
    'themeMode',
    'reduceMotion',
    'haptics',
    'companionAccessory',
    'companionBackground',
  ];
  static const _privateKeys = {
    'photoPath',
    'photo',
    'image',
    'bytes',
    'base64',
    'latitude',
    'longitude',
    'coordinates',
    'route',
    'note',
    'noteEditedAt',
    'email',
    'user_id',
    'researchParticipation',
    'participant_code',
    'access_token',
    'refresh_token',
    // Raw smoking/vaping moments stay on the device; daily totals are separate.
    'product',
    'trigger',
    'triggers',
    'outcome',
    'activity',
    'activities',
    'eventId',
    'cigarette',
    'vape',
    'nicotineDays',
    'reductionSettings',
    'reductionPlans',
    'reductionSetup',
    // Raw sleep times stay on the device (docs/PROJECT_DECISIONS.md).
    'sleepLogs',
    'openSleep',
    'bedAt',
    'wakeAt',
    'activeSwapMoment',
    'customTriggers',
    'customActivities',
    'usedProduct',
    'reductionTargets',
  };

  static JsonMap _pick(Map source, List<String> keys) => {
    for (final key in keys)
      if (source.containsKey(key)) key: source[key],
  };

  static Object? _strip(Object? value) => switch (value) {
    Map() => {
      for (final entry in value.entries)
        if (!_privateKeys.contains(entry.key))
          entry.key.toString(): _strip(entry.value),
    },
    List() => [for (final item in value) _strip(item)],
    _ => value,
  };

  static JsonMap project(String raw) {
    final source = restoreWellnessState(raw);
    final profile = source['profile'];
    return {
      'schemaVersion': 1,
      'version': 3,
      'profile': profile is Map
          ? _pick(profile, [
              'alias',
              'path',
              'pace',
              'lowImpact',
              'companion',
              'started',
              'waterGoal',
              'ageGroup',
              'companionName',
            ])
          : null,
      for (final key in _shared)
        if (source.containsKey(key)) key: _strip(source[key]),
      'workoutSessions': [
        for (final row in (source['workoutSessions'] as List).whereType<Map>())
          _pick(row, [
            'id',
            'day',
            'time',
            'kind',
            'seconds',
            'meters',
            'countsForQuest',
            'correctedAt',
          ]),
      ],
      'mealCheckIns': [
        for (final row in (source['mealCheckIns'] as List).whereType<Map>())
          {
            ..._pick(row, ['id', 'day', 'time', 'checkId', 'verification']),
            'photoCaptured':
                row['photoCaptured'] == true || row['photoPath'] is String,
          },
      ],
      'habitDelays': [
        for (final row in (source['habitDelays'] as List).whereType<Map>())
          _pick(row, [
            'id',
            'day',
            'time',
            'minutes',
            'plannedMinutes',
            'completed',
          ]),
      ],
      // Counts per day only: moment times would be a craving-frequency log.
      'habitSwaps': [
        for (final row in (source['habitSwaps'] as List).whereType<Map>())
          _pick(row, ['id', 'day']),
      ],
      // Latest proposal: the daily total per product is research data. Only
      // the numbers leave the phone, never times, triggers or notes.
      'usageTotals': usageTotals(source['nicotineDays']),
      // Habit Swap results per day and product, counts only (phase 13).
      // Left out when empty, so wellness snapshots stay valid for a server
      // that has not run phase 13 yet.
      if (swapResults(source['habitSwaps'], source['swapResultsCloud'])
          case final results when results.isNotEmpty)
        'swapResults': results,
    };
  }

  /// `{day, type, tried, skipped, used}` per day and product from the
  /// moments on this phone. Days this phone has no results for (a new
  /// install) keep the counts last read from the cloud, so they are never
  /// sent back as zero; a day an admin restored keeps the admin's counts.
  static List<JsonMap> swapResults(Object? swaps, Object? cloud) {
    final counts = <String, JsonMap>{};
    for (final row in ((swaps ?? const []) as List).whereType<Map>()) {
      final day = row['day'], product = row['usedProduct'] ?? row['product'];
      final type = _usageTypes[product];
      final tried =
          row['tried'] == true ||
          const ['skipped', 'used'].contains(row['outcome']);
      if (day is! String || type == null || !tried) continue;
      final entry = counts.putIfAbsent(
        '$day|$type',
        () => {'day': day, 'type': type, 'tried': 0, 'skipped': 0, 'used': 0},
      );
      entry['tried'] = (entry['tried'] as int) + 1;
      if (row['outcome'] == 'skipped') {
        entry['skipped'] = (entry['skipped'] as int) + 1;
      } else if (row['outcome'] == 'used') {
        entry['used'] = (entry['used'] as int) + 1;
      }
    }
    for (final row in ((cloud ?? const []) as List).whereType<Map>()) {
      final key = '${row['day']}|${row['type']}';
      if (!counts.containsKey(key) || row['source'] == 'admin') {
        counts[key] = Map<String, dynamic>.from(row);
      }
    }
    return counts.values.toList()..sort(
      (a, b) => '${a['day']}${a['type']}'.compareTo('${b['day']}${b['type']}'),
    );
  }

  static const _usageTypes = {'cigarette': 'rokok', 'vape': 'vape'};

  /// `{day, type: rokok|vape, total, confirmed, source}` per logged product.
  static List<JsonMap> usageTotals(Object? nicotineDays) => [
    for (final row in ((nicotineDays ?? const []) as List).whereType<Map>())
      for (final MapEntry(key: kind, value: type) in _usageTypes.entries)
        if (row['day'] is String && row[kind] is num)
          {
            'day': row['day'],
            'type': type,
            'total': (row[kind] as num).toInt(),
            'confirmed': row['confirmed'] == true,
            if (row['source'] == 'admin') 'source': 'admin',
          },
  ];

  /// Device rows for the cloud totals: a day missing on this phone (a new
  /// install) or one an admin set is taken from the cloud; other days keep
  /// what the phone recorded.
  static List<JsonMap> _mergeUsage(Object? device, Object? cloud) {
    final rows = {
      for (final row in ((device ?? const []) as List).whereType<Map>())
        row['day'].toString(): Map<String, dynamic>.from(row),
    };
    final byDay = <String, List<Map>>{};
    for (final row in ((cloud ?? const []) as List).whereType<Map>()) {
      if (row['day'] is String && row['total'] is num) {
        (byDay[row['day']] ??= []).add(row);
      }
    }
    for (final MapEntry(key: day, value: totals) in byDay.entries) {
      final admin = totals.any((row) => row['source'] == 'admin');
      if (rows.containsKey(day) && !admin) continue;
      int? total(String type) =>
          (totals.where((row) => row['type'] == type).firstOrNull?['total']
                  as num?)
              ?.toInt();
      final cigarettes = total('rokok'), vape = total('vape');
      rows[day] = {
        ...?rows[day],
        'day': day,
        'product': cigarettes != null && vape != null
            ? 'both'
            : vape != null
            ? 'vape'
            : 'cigarette',
        'confirmed': totals.any((row) => row['confirmed'] == true),
        'cigarette': cigarettes,
        'vape': vape,
        if (admin) 'source': 'admin',
      };
    }
    return rows.values.toList()
      ..sort((a, b) => a['day'].toString().compareTo(b['day'].toString()));
  }

  /// Overlay shared fields, keeping device-only data and local photo handles.
  static String apply(JsonMap payload, String? local) {
    if (payload['schemaVersion'] != 1 || payload['version'] != 3) {
      throw const FormatException('Unsupported cloud progress schema');
    }
    final device = local == null
        ? createEmptyWellnessState()
        : restoreWellnessState(local);
    final shared = project(
      jsonEncode({...createEmptyWellnessState(), ...payload}),
    );
    final result = {...device, ...shared}
      ..remove('schemaVersion')
      ..remove('usageTotals')
      ..remove('swapResults');
    // Kept on the phone (never sent as such) so a reinstall keeps them.
    result['swapResultsCloud'] = [
      ...((payload['swapResults'] ?? device['swapResultsCloud'] ?? const [])
          as List),
    ];
    result['nicotineDays'] = _mergeUsage(
      device['nicotineDays'],
      payload['usageTotals'],
    );
    for (final collection in [
      'mealCheckIns',
      'workoutSessions',
      'habitSwaps',
    ]) {
      final rows = (device[collection] as List).whereType<Map>();
      final originals = {for (final row in rows) row['id']: row};
      result[collection] = [
        for (final row in ((shared[collection] ?? []) as List).whereType<Map>())
          {
            ...row,
            if (collection == 'habitSwaps') 'swap': 'Aktivitas pengganti',
            if (originals[row['id']] case final original?)
              ..._pick(original, [
                'photoPath',
                'note',
                'noteEditedAt',
                if (collection == 'habitSwaps') ...[
                  'time',
                  'eventId',
                  'product',
                  'trigger',
                  'triggers',
                  'activity',
                  'activities',
                  'customTriggers',
                  'customActivities',
                  'outcome',
                  'swap',
                  'tried',
                  'status',
                  'startedAt',
                  'resultAt',
                  'usedProduct',
                ],
              ]),
          },
      ];
    }
    return jsonEncode(result);
  }

  static String canonical(Object? value) {
    Object? order(Object? input) => switch (input) {
      Map() => SplayTreeMap<String, Object?>.from({
        for (final entry in input.entries)
          entry.key.toString(): order(entry.value),
      }),
      List() => input.map(order).toList(),
      num() => input == input.roundToDouble() ? input.toInt() : input,
      _ => input,
    };
    return jsonEncode(order(value));
  }
}

class CloudProgressSnapshot {
  const CloudProgressSnapshot({
    required this.revision,
    required this.payload,
    required this.updatedAt,
  });
  final int revision;
  final JsonMap payload;
  final DateTime updatedAt;
  factory CloudProgressSnapshot.fromJson(Map value) => CloudProgressSnapshot(
    revision: (value['revision'] as num).toInt(),
    payload: Map<String, dynamic>.from(value['payload'] as Map),
    updatedAt: DateTime.parse(value['updated_at'] as String),
  );
}

class ProgressSaveResult {
  const ProgressSaveResult({required this.saved, required this.snapshot});
  final bool saved;
  final CloudProgressSnapshot? snapshot;
}

abstract interface class ProgressCloudStore {
  Future<CloudProgressSnapshot?> read();
  Future<ProgressSaveResult> save(
    JsonMap payload, {
    required int expectedRevision,
  });
}
