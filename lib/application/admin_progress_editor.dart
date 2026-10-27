import 'dart:convert';

import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/core/utils/date_key.dart';
import 'package:youwell/features/home/domain/daily_card_generator.dart';
import 'package:youwell/features/home/domain/quest_ladder.dart';

/// Admin Overview (phase 10): edits a participant's synced progress when it
/// was lost (force majeure). Every edit is marked in the data itself
/// (`adminCompleted`, `source: admin`, `admin-` Habit Swap ids,
/// `adminSetOn`) and listed in [changes] for the intervention log, so the
/// research export can tell it apart from what the app recorded.
class AdminProgressEditor {
  AdminProgressEditor(JsonMap payload, {required DateTime now})
    : _original = _copy(payload),
      payload = _copy(payload),
      today = dayKey(now);

  final JsonMap _original;

  /// The edited snapshot, in the cloud format.
  final JsonMap payload;
  final String today;

  static JsonMap _copy(JsonMap value) =>
      jsonDecode(jsonEncode(value)) as JsonMap;

  Map get _profile => (payload['profile'] as Map?) ?? const {};
  bool get reduction => _profile['path'] == 'reduction';
  bool get _lowImpact => _profile['lowImpact'] == true;
  String get started => _profile['started']?.toString() ?? today;

  Map<String, dynamic> get _days =>
      (payload['days'] ??= <String, dynamic>{}) as Map<String, dynamic>;
  Map<String, dynamic> get _capacity =>
      (payload['capacity'] ??= <String, dynamic>{}) as Map<String, dynamic>;
  List get _usage => (payload['usageTotals'] ??= <dynamic>[]) as List;
  List get _swaps => (payload['habitSwaps'] ??= <dynamic>[]) as List;

  /// Program days from the start up to today, newest first.
  List<String> get days {
    if (started.compareTo(today) > 0) return const [];
    final count = daysBetweenKeys(started, today) + 1;
    return [for (var i = count - 1; i >= 0; i--) shiftDayKey(started, i)];
  }

  int dayNumber(String day) => daysBetweenKeys(started, day) + 1;

  // ---------------------------------------------------------------- quests

  List<JsonMap> questsOn(String day) => [
    for (final task
        in ((_days[day]?['quests'] ?? const []) as List).whereType<Map>())
      Map<String, dynamic>.from(task),
  ];

  bool hasCard(String day) => questsOn(day).isNotEmpty;

  /// Gives a day without a committed card the card the app would have
  /// recommended (same generator, the participant's levels and tempo).
  void createCard(String day) {
    if (hasCard(day)) return;
    final packs = const DailyCardGenerator().cardPacks(
      today: day,
      steps: ladderSteps,
      pace: (_profile['pace'] as num?)?.toInt() ?? 1,
      lowImpact: _lowImpact,
      reduction: reduction,
      hour: 7,
      wellnessUat: true,
    );
    final card =
        packs.where((pack) => pack['recommended'] == true).firstOrNull ??
        packs.first;
    final existing = (_days[day] as Map?) ?? const {};
    _days[day] = {
      ...existing,
      'quests': [
        for (final task in (card['tasks'] as List).whereType<Map>())
          {...task, 'status': 'committed', 'done': false},
      ],
      'water': existing['water'] ?? 0,
      'cardDraw': {'committedCardId': card['id'], 'adminCreated': true},
    }..remove('cardPacks');
  }

  /// Ticks or unticks a quest. Quests the app already completed stay.
  void setQuestDone(String day, String id, bool done) {
    final quests = (_days[day]?['quests'] as List?)?.whereType<Map>();
    final task = quests?.where((task) => task['id'] == id).firstOrNull;
    if (task == null) return;
    final byApp =
        task['status'] == 'completed' && task['adminCompleted'] != true;
    if (byApp) return;
    if (done) {
      task
        ..['status'] = 'completed'
        ..['done'] = true
        ..['adminCompleted'] = true
        ..['validationInvalidated'] = false
        ..remove('partial');
    } else {
      task
        ..['status'] = 'committed'
        ..['done'] = false
        ..remove('adminCompleted');
    }
  }

  static bool doneByApp(Map task) =>
      task['status'] == 'completed' && task['adminCompleted'] != true;

  // ---------------------------------------------------------- opened days

  List get _opened => (payload['openedDays'] ??= <dynamic>[]) as List;
  List get _adminOpened =>
      (payload['adminOpenedDays'] ??= <dynamic>[]) as List;

  bool openedOn(String day) => _opened.contains(day);

  /// Opened in the app itself; the admin cannot remove those days.
  bool openedByApp(String day) =>
      openedOn(day) && !_adminOpened.contains(day);

  void setOpened(String day, bool opened) {
    if (openedByApp(day)) return;
    _opened.remove(day);
    _adminOpened.remove(day);
    if (opened) {
      _opened
        ..add(day)
        ..sort();
      _adminOpened
        ..add(day)
        ..sort();
    }
  }

  // ----------------------------------------------------------------- usage

  /// 'rokok' or 'vape' total of [day], null when nothing was logged.
  int? usage(String day, String type) =>
      (_usage
                  .whereType<Map>()
                  .where((row) => row['day'] == day && row['type'] == type)
                  .firstOrNull?['total']
              as num?)
          ?.toInt();

  void setUsage(String day, String type, int total) {
    _usage
      ..removeWhere(
        (row) => row is Map && row['day'] == day && row['type'] == type,
      )
      ..add({
        'day': day,
        'type': type,
        'total': total.clamp(0, 500),
        'confirmed': true,
        'source': 'admin',
      });
  }

  // ------------------------------------------------------------ Habit Swap

  int swapsOn(String day) =>
      _swaps.whereType<Map>().where((row) => row['day'] == day).length;

  /// Swaps recorded by the app on [day]; the admin cannot remove those.
  int appSwapsOn(String day) => _swaps
      .whereType<Map>()
      .where((row) => row['day'] == day && !_adminRow(row))
      .length;

  static bool _adminRow(Map row) =>
      row['id']?.toString().startsWith('admin-') ?? false;

  void setSwaps(String day, int count) {
    final target = count.clamp(appSwapsOn(day), 20);
    _swaps.removeWhere(
      (row) => row is Map && row['day'] == day && _adminRow(row),
    );
    for (var i = appSwapsOn(day); i < target; i++) {
      _swaps.add({'id': 'admin-swap-$day-$i', 'day': day});
    }
  }

  // ---------------------------------------------------------------- levels

  List<String> get categories => ladderCategories(reduction: reduction);

  Map<String, int> get ladderSteps => {
    for (final category in categories)
      category: ((_capacity[category] as Map?)?['step'] as num?)?.toInt() ?? 1,
  };

  int maxStep(String category) =>
      ladderMax(category, lowImpact: _lowImpact, wellnessUat: true);

  void setStep(String category, int step) {
    final value = step.clamp(1, maxStep(category));
    final entry = Map<String, dynamic>.from(
      (_capacity[category] as Map?) ?? const {},
    )..remove('offerStep');
    _capacity[category] = {
      'reviewedOn': today,
      ...entry,
      'step': value,
      'adminSetOn': today,
    };
    if (_days[today] case final Map day) {
      (day['ladderSteps'] ??= <String, dynamic>{})[category] = value;
    }
  }

  // --------------------------------------------------------------- changes

  /// What differs from the loaded snapshot, for the intervention log.
  List<JsonMap> get changes {
    final before = AdminProgressEditor(_original, now: DateTime.parse(today));
    return [
      for (final category in categories)
        if (before.ladderSteps[category] != ladderSteps[category])
          {
            'kind': 'level',
            'category': category,
            'from': before.ladderSteps[category],
            'to': ladderSteps[category],
          },
      for (final day in days) ...[
        if (before.openedOn(day) != openedOn(day))
          {'kind': 'opened', 'day': day, 'opened': openedOn(day)},
        if (!before.hasCard(day) && hasCard(day)) {'kind': 'card', 'day': day},
        for (final task in questsOn(day))
          if (before
                  .questsOn(day)
                  .where((old) => old['id'] == task['id'])
                  .firstOrNull?['status'] !=
              task['status'])
            {
              'kind': 'quest',
              'day': day,
              'title': task['title'],
              'done': task['status'] == 'completed',
            },
        for (final type in const ['rokok', 'vape'])
          if (before.usage(day, type) != usage(day, type))
            {
              'kind': 'usage',
              'day': day,
              'type': type,
              'from': before.usage(day, type),
              'to': usage(day, type),
            },
        if (before.swapsOn(day) != swapsOn(day))
          {
            'kind': 'habit_swap',
            'day': day,
            'from': before.swapsOn(day),
            'to': swapsOn(day),
          },
      ],
    ];
  }

  bool get changed => changes.isNotEmpty;
}

/// One line per change, for the confirmation and the intervention log.
String describeChange(Map change) {
  final day = change['day'];
  return switch (change['kind']) {
    'level' =>
      'Level ${ladderLabels[change['category']] ?? change['category']}: '
          '${change['from']} → ${change['to']}',
    'card' => '$day: kartu dibuat',
    'opened' =>
      '$day: ${change['opened'] == true ? 'ditandai membuka aplikasi' : 'tanda buka aplikasi dihapus'}',
    'quest' =>
      '$day: "${change['title']}" '
          '${change['done'] == true ? 'dicentang' : 'dibatalkan'}',
    'usage' =>
      '$day: ${change['type']} ${change['from'] ?? '–'} → ${change['to']}',
    'habit_swap' => '$day: Habit Swap ${change['from']} → ${change['to']}',
    'restore' => 'Dipulihkan dari salinan revisi ${change['from_revision']}',
    _ => change.toString(),
  };
}
