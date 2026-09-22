import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/core/utils/date_key.dart';
import 'package:youwell/data/models/wellness_snapshot.dart';
import 'package:youwell/features/home/domain/daily_card_generator.dart';
import 'package:youwell/features/home/domain/progress_calculator.dart';

/// Single local-first state boundary shared by mobile and web.
/// Remote auth and sync can later replace [persist] without changing the UI.
class WellnessController extends ChangeNotifier {
  WellnessController({String? saved, this.persist, DateTime Function()? clock})
    : clock = clock ?? DateTime.now {
    if (saved != null) {
      try {
        _data = restoreWellnessState(saved);
      } catch (_) {
        storageError =
            'Preview lokal lama direset untuk memakai versi terbaru.';
      }
    }
  }

  final Future<void> Function(String)? persist;
  final DateTime Function() clock;
  JsonMap _data = createEmptyWellnessState();
  Future<void> _pending = Future.value();
  String? storageError;

  int get dayOffset => (_data['dayOffset'] as num?)?.toInt() ?? 0;
  DateTime get now => clock().add(Duration(days: dayOffset));
  String get today => dayKey(now);
  JsonMap? get profile => _data['profile'] == null
      ? null
      : Map<String, dynamic>.from(_data['profile']);
  bool get reduction => profile?['path'] == 'reduction';
  Map<String, dynamic> get days => Map<String, dynamic>.from(_data['days']);

  List<JsonMap> _rows(String key) => ((_data[key] ?? const []) as List)
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();

  List<JsonMap> get quests => ((days[today]?['quests'] ?? const []) as List)
      .whereType<Map>()
      .map((task) => Map<String, dynamic>.from(task))
      .toList();
  List<JsonMap> get dailyDrawCards =>
      ((days[today]?['cardPacks'] ?? days[today]?['bonusCards'] ?? const [])
              as List)
          .whereType<Map>()
          .map((card) => Map<String, dynamic>.from(card))
          .toList();
  JsonMap? get dailyCardDraw {
    final value = days[today]?['cardDraw'];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  String? get selectedDailyCardId =>
      dailyCardDraw?['selectedCardId']?.toString();
  List<String> get passedDailyCardIds =>
      ((dailyCardDraw?['passedCardIds'] ?? const []) as List)
          .map((id) => id.toString())
          .toList();
  int get dailyDeckStartIndex {
    if (dailyDrawCards.isEmpty) return 0;
    return ((dailyCardDraw?['deckStartIndex'] as num?)?.toInt() ?? 0) %
        dailyDrawCards.length;
  }

  JsonMap? get selectedDailyCard {
    final id = selectedDailyCardId;
    if (id == null) return null;
    return dailyDrawCards.cast<JsonMap?>().firstWhere(
      (card) => card?['id'] == id,
      orElse: () => null,
    );
  }

  bool get hasCommittedDailyCard => dailyCardDraw?['committedCardId'] != null;
  bool get needsDailyCardDraw => profile != null && !hasCommittedDailyCard;
  int get dailyCardSwitchesRemaining =>
      (1 - passedDailyCardIds.length).clamp(0, 1);
  bool get canChooseAnotherDailyCard =>
      selectedDailyCard != null &&
      dailyCardSwitchesRemaining > 0 &&
      !hasCommittedDailyCard;

  List<JsonMap> get completedCards =>
      quests.where((task) => task['status'] == 'completed').toList();
  int get dailyXp => completedCards.fold<int>(
    0,
    (sum, task) => sum + ((task['xp'] as num?)?.toInt() ?? 0),
  );
  double get dailyProgress =>
      quests.isEmpty ? 0 : completedCards.length / quests.length;
  double get water => ((days[today]?['water'] ?? 0) as num).toDouble();

  ProgressCalculator get _progress => ProgressCalculator(
    days: days,
    now: now,
    basePace: (profile?['pace'] as num?)?.toInt() ?? 1,
    lowImpact: profile?['lowImpact'] == true,
  );
  List<String> get completedDays => _progress.completedDays;
  List<String> get activeDays => _progress.activeDays;
  int get xp => _progress.xp;
  int get level => _progress.level;
  int get difficulty => _progress.recommendedDifficulty;
  int activeDaysIn(int period) => _progress.activeDaysIn(period);
  double compliance(int period) => _progress.completionRate(period);

  List<JsonMap> get energyCheckIns => _rows('energyCheckIns');
  List<JsonMap> get focusSessions => _rows('focusSessions');
  List<JsonMap> get habitDelays => _rows('habitDelays');
  List<JsonMap> get workoutSessions => _rows('workoutSessions');
  List<JsonMap> get mealCheckIns => _rows('mealCheckIns');
  List<JsonMap> get communityPosts => [
    ..._seedCommunityPosts,
    ..._rows('communityPosts'),
  ];
  List<JsonMap> get approvedCommunityPosts =>
      communityPosts.where((post) => post['status'] == 'approved').toList()
        ..sort((a, b) => b['time'].toString().compareTo(a['time'].toString()));
  List<JsonMap> get moderationQueue => _rows(
    'communityPosts',
  ).where((post) => post['status'] == 'pending').toList();
  List<JsonMap> get communityReports => _rows('communityReports');
  JsonMap? get squad =>
      _data['squad'] == null ? null : Map<String, dynamic>.from(_data['squad']);
  JsonMap? get buddy =>
      _data['buddy'] == null ? null : Map<String, dynamic>.from(_data['buddy']);
  int get focusMinutesToday => focusSessions
      .where((row) => row['day'] == today)
      .fold<int>(
        0,
        (sum, row) => sum + ((row['minutes'] as num?)?.toInt() ?? 0),
      );
  int get delayedToday =>
      habitDelays.where((row) => row['day'] == today).length;

  Future<void> _save() {
    notifyListeners();
    final value = jsonEncode(_data);
    _pending = _pending.then((_) async {
      try {
        await persist?.call(value);
      } catch (_) {
        storageError = 'Perubahan lokal belum tersimpan.';
      }
    });
    return _pending;
  }

  Future<void> setup(JsonMap value) async {
    final alias = value['alias'].toString().trim();
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{2,19}$').hasMatch(alias)) {
      throw ArgumentError('Alias 3–20 karakter: huruf, angka, underscore.');
    }
    _data['profile'] = {
      ...?profile,
      ...value,
      'alias': alias,
      'started': profile?['started'] ?? today,
      'waterGoal': value['waterGoal'] ?? profile?['waterGoal'] ?? 2000,
    };
    prepareToday();
    await _save();
  }

  void prepareToday() {
    if (profile == null) return;
    final generator = const DailyCardGenerator();
    final existing = days[today];
    if (existing != null &&
        (existing['cardPacks'] != null ||
            hasCommittedDailyCard ||
            completedCards.isNotEmpty)) {
      return;
    }
    final oldCards = existing == null ? <JsonMap>[] : dailyDrawCards;
    final packs = generator.cardPacks(
      today: today,
      difficulty: difficulty,
      lowImpact: profile?['lowImpact'] == true,
      reduction: reduction,
      completionRate: compliance(7),
      daysUsingApp: _daysUsingApp,
    );
    if (existing != null) {
      // Upgrade an untouched draft without wiping water or rejected choices.
      for (
        var index = 0;
        index < packs.length && index < oldCards.length;
        index++
      ) {
        packs[index]['id'] = oldCards[index]['id'];
      }
      _data['days'][today]['quests'] = <JsonMap>[];
      _data['days'][today]['cardPacks'] = packs;
      _data['days'][today].remove('bonusCards');
      _save();
      return;
    }
    _data['days'][today] = {
      'quests': <JsonMap>[],
      'cardPacks': packs,
      'water': 0,
      'cardDraw': {
        'selectedCardId': null,
        'passedCardIds': <String>[],
        'deckStartIndex': Random().nextInt(packs.length),
      },
    };
    _save();
  }

  /// Kept as a semantic entry point for both existing web and mobile UI.
  void drawDailyCards() => prepareToday();

  bool selectDailyCard(String id) {
    if (hasCommittedDailyCard ||
        passedDailyCardIds.contains(id) ||
        !dailyDrawCards.any((card) => card['id'] == id)) {
      return false;
    }
    _writeDraw({...?dailyCardDraw, 'selectedCardId': id});
    return true;
  }

  bool chooseAnotherDailyCard() {
    if (!canChooseAnotherDailyCard) return false;
    final passed = [...passedDailyCardIds, selectedDailyCardId!];
    final choices = dailyDrawCards
        .where((card) => !passed.contains(card['id']))
        .toList();
    final next = choices.isEmpty
        ? null
        : choices[Random().nextInt(choices.length)];
    _writeDraw({
      ...?dailyCardDraw,
      'selectedCardId': null,
      'passedCardIds': passed,
      'deckStartIndex': next == null
          ? 0
          : dailyDrawCards.indexWhere((card) => card['id'] == next['id']),
    });
    return true;
  }

  bool commitDailyCardPack() {
    final card = selectedDailyCard;
    if (card == null || hasCommittedDailyCard) return false;
    final packTasks = card['tasks'] is List
        ? (card['tasks'] as List)
              .whereType<Map>()
              .map((task) => Map<String, dynamic>.from(task))
              .toList()
        : [card]; // A committed legacy draft may still contain one task.
    if (packTasks.isEmpty) return false;
    final tasks = [
      ...quests,
      for (final task in packTasks)
        {...task, 'status': 'committed', 'done': false},
    ];
    _data['days'][today]['quests'] = tasks;
    _data['days'][today]['cardDraw'] = {
      ...?dailyCardDraw,
      'committedCardId': card['id'],
    };
    _save();
    return true;
  }

  void _writeDraw(JsonMap draw) {
    _data['days'][today]['cardDraw'] = draw;
    _save();
  }

  bool completeCard(String id) {
    final tasks = quests;
    final index = tasks.indexWhere((task) => task['id'] == id);
    if (index < 0 || tasks[index]['status'] == 'completed') return false;
    tasks[index] = {...tasks[index], 'status': 'completed', 'done': true};
    _data['days'][today]['quests'] = tasks;
    _save();
    return true;
  }

  void addWater() {
    prepareToday();
    _data['days'][today]['water'] = (water + 250).clamp(0, 4000);
    _save();
  }

  void recordWorkout({
    required String kind,
    required int seconds,
    required int meters,
  }) {
    if (seconds < 1) return;
    _add('workoutSessions', {
      'kind': kind,
      'seconds': seconds,
      'meters': meters,
    });
    final completedMinutes = seconds ~/ 60;
    for (final task in quests) {
      if (task['status'] == 'completed') continue;
      final activity = task['activityKind'];
      if ((activity == 'walk' && (kind == 'walk' || kind == 'run') ||
              activity == 'run' && kind == 'run') &&
          completedMinutes >=
              ((task['durationMinutes'] as num?)?.toInt() ?? 0)) {
        completeCard(task['id'].toString());
      }
    }
  }

  void recordMeal({required String photoPath}) {
    _add('mealCheckIns', {'photoPath': photoPath});
    for (final task in quests) {
      if (task['activityKind'] == 'meal_snap' &&
          task['status'] != 'completed') {
        completeCard(task['id'].toString());
      }
    }
  }

  void checkInEnergy(String energy, {List<String> tags = const []}) =>
      _add('energyCheckIns', {'energy': energy, 'tags': tags});

  void recordFocusSession(JsonMap value) => _add('focusSessions', value);
  void recordHabitDelay({int minutes = 5}) =>
      _add('habitDelays', {'minutes': minutes});

  void submitCommunityPost(String text) {
    final clean = text.trim();
    if (clean.length < 3 || clean.length > 180) {
      throw ArgumentError('Post harus 3–180 karakter.');
    }
    _add('communityPosts', {
      'alias': profile?['alias'] ?? 'anonymous',
      'text': clean,
      'status': 'pending',
      'moderationNote': '',
    });
  }

  void moderateCommunityPost(String id, String status, {String note = ''}) {
    if (!const {'approved', 'rejected'}.contains(status)) return;
    for (final post in _data['communityPosts'] as List) {
      if (post['id'] == id) {
        post['status'] = status;
        post['moderationNote'] = note.trim();
        post['reviewedAt'] = now.toIso8601String();
      }
    }
    _save();
  }

  bool hasCommunityReaction(String postId, String reaction) =>
      (_data['communityReactions'] as List).any(
        (row) => row['postId'] == postId && row['reaction'] == reaction,
      );

  void reactToCommunityPost(String postId, String reaction) {
    final rows = _data['communityReactions'] as List;
    final index = rows.indexWhere(
      (row) => row['postId'] == postId && row['reaction'] == reaction,
    );
    if (index >= 0) {
      rows.removeAt(index);
    } else {
      rows.add({'postId': postId, 'reaction': reaction});
    }
    _save();
  }

  void reportCommunityPost(String postId, String reason) {
    if (communityReports.any((report) => report['postId'] == postId)) return;
    _add('communityReports', {'postId': postId, 'reason': reason});
  }

  void resolveCommunityReport(String id) {
    (_data['communityReports'] as List).removeWhere((row) => row['id'] == id);
    _save();
  }

  void joinSquad() {
    _data['squad'] = {
      'name': 'Small Steps Club',
      'goal': 50,
      'progress': 18,
      'members': ['daunpagi', 'awanbiru', 'ruangbaru', profile?['alias']],
    };
    _save();
  }

  void leaveSquad() {
    _data['squad'] = null;
    _save();
  }

  void matchBuddy() {
    final aliases = reduction
        ? ['pelanpelan', 'jeda_sore', 'ruangbaru']
        : ['daunpagi', 'mori_kecil', 'awanbiru'];
    _data['buddy'] = {
      'alias': aliases[Random().nextInt(aliases.length)],
      'activeDays': 3,
      'path': reduction ? 'reduction' : 'wellness',
    };
    _save();
  }

  void endBuddy() {
    _data['buddy'] = null;
    _save();
  }

  void _add(String key, JsonMap value) {
    (_data[key] as List).add({
      ...value,
      'id': '${now.microsecondsSinceEpoch}-${Random().nextInt(9999)}',
      'day': today,
      'time': now.toIso8601String(),
    });
    _save();
  }

  void switchPath(bool enabled) {
    _data['profile']['path'] = enabled ? 'reduction' : 'wellness';
    _save();
  }

  void setLowImpact(bool enabled) {
    _data['profile']['lowImpact'] = enabled;
    _save();
  }

  int get _daysUsingApp {
    final started = DateTime.tryParse(profile?['started']?.toString() ?? '');
    return started == null ? 1 : now.difference(started).inDays.abs() + 1;
  }

  String export() {
    final copy = jsonDecode(jsonEncode(_data)) as JsonMap;
    for (final row in copy['mealCheckIns'] as List) {
      if (row is Map) row.remove('photoPath');
    }
    return const JsonEncoder.withIndent('  ').convert(copy);
  }

  Future<void> reset() async {
    _data = createEmptyWellnessState();
    await _save();
  }
}

final List<JsonMap> _seedCommunityPosts = [
  {
    'id': 'seed-water',
    'alias': 'daunpagi',
    'text': 'Hari ini berhasil memenuhi target minum air. Small win!',
    'status': 'approved',
    'time': '2026-09-20T08:00:00.000',
  },
  {
    'id': 'seed-walk',
    'alias': 'awanbiru',
    'text': 'Jalan santai sepuluh menit ternyata bikin energi balik lagi.',
    'status': 'approved',
    'time': '2026-09-20T07:00:00.000',
  },
];
