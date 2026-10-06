import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/core/utils/date_key.dart';
import 'package:youwell/data/models/wellness_snapshot.dart';
import 'package:youwell/features/home/domain/daily_card_generator.dart';
import 'package:youwell/features/home/domain/progress_calculator.dart';
import 'package:youwell/features/home/domain/quest_ladder.dart';
import 'package:youwell/features/progress/domain/research_summary.dart';
import 'package:youwell/features/companion/domain/companion_rewards.dart';

part 'wellness_gamification.dart';

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
  bool _mobileRewardsEnabled = false;
  final List<RewardMoment> _moments = [];
  int rewardSerial = 0;

  String get themePreference => _data['themeMode']?.toString() ?? 'system';

  Future<void> setThemePreference(String value) {
    if (!const ['system', 'light', 'dark'].contains(value)) {
      throw ArgumentError.value(value, 'value', 'Unsupported theme mode');
    }
    _data['themeMode'] = value;
    return _save();
  }

  int get dayOffset => (_data['dayOffset'] as num?)?.toInt() ?? 0;
  DateTime get now => clock().add(Duration(days: dayOffset));
  String get today => dayKey(now);
  JsonMap? get profile => _data['profile'] == null
      ? null
      : Map<String, dynamic>.from(_data['profile']);
  bool get reduction => profile?['path'] == 'reduction';

  /// Under 21 the reduction path speaks about quitting (PP 28/2024 Ps. 434).
  bool get quitFraming =>
      const {'under18', '18-20'}.contains(profile?['ageGroup']);
  String get reductionLabel =>
      quitFraming ? 'Berhenti rokok / vape' : 'Kurangi rokok / vape';
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
  int get dailyXp =>
      mobileBonusXpToday +
      completedCards.fold<int>(
        0,
        (sum, task) => sum + ((task['xp'] as num?)?.toInt() ?? 0),
      );
  double get dailyProgress =>
      quests.isEmpty ? 0 : completedCards.length / quests.length;
  double get water => ((days[today]?['water'] ?? 0) as num).toDouble();

  ProgressCalculator get _progress => ProgressCalculator(days: days, now: now);
  List<String> get completedDays => _progress.completedDays;
  List<String> get activeDays => _progress.activeDays;
  int get xp => _progress.xp + mobileBonusXp;
  int get level => 1 + xp ~/ 100;
  int activeDaysIn(int period) => _progress.activeDaysIn(period);
  double compliance(int period) => _progress.completionRate(period);

  List<JsonMap> get energyCheckIns => _rows('energyCheckIns');
  List<JsonMap> get focusSessions => _rows('focusSessions');
  List<JsonMap> get habitDelays => _rows('habitDelays');
  List<JsonMap> get habitSwaps => _rows('habitSwaps');
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
  int get focusMinutesToday => focusSessions
      .where((row) => row['day'] == today)
      .fold<int>(
        0,
        (sum, row) => sum + ((row['minutes'] as num?)?.toInt() ?? 0),
      );

  /// Only full timers count as a finished delay; partial ones stay in the log.
  int get delayedToday => habitDelays
      .where((row) => row['day'] == today && row['completed'] != false)
      .length;
  int get habitSwapsToday =>
      habitSwaps.where((row) => row['day'] == today).length;
  List<String> get openedDays =>
      ((_data['openedDays'] ?? const []) as List).cast<String>();

  /// Ladder state per category: step, offered step, and the last reason.
  Map<String, JsonMap> get capacity => {
    for (final entry in ((_data['capacity'] ?? const {}) as Map).entries)
      entry.key.toString(): Map<String, dynamic>.from(entry.value as Map),
  };
  Map<String, int> get ladderSteps => {
    for (final entry in capacity.entries)
      entry.key: (entry.value['step'] as num?)?.toInt() ?? 1,
  };
  List<String> get ladderOffers => [
    for (final category in ladderCategories(reduction: reduction))
      if (capacity[category]?['offerStep'] != null) category,
  ];

  ResearchSummary researchSummary(int week) => ResearchSummary.forWeek(
    week: week,
    started: profile?['started']?.toString() ?? today,
    days: days,
    openedDays: openedDays,
    activityDays: activityDays,
    habitDelays: habitDelays,
    habitSwaps: habitSwaps,
  );

  Future<void> _save() {
    if (days[today] is Map && capacity.isNotEmpty) {
      _data['days'][today]['ladderSteps'] = ladderSteps;
    }
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
    final opened = (_data['openedDays'] ??= <dynamic>[]) as List;
    final firstOpenToday = !opened.contains(today);
    if (firstOpenToday) opened.add(today);
    final existing = days[today];
    if (existing != null &&
        (existing['cardPacks'] != null ||
            hasCommittedDailyCard ||
            completedCards.isNotEmpty)) {
      if (firstOpenToday || _mobileRewardsEnabled) _save();
      return;
    }
    _reviewLadders();
    final oldCards = existing == null ? <JsonMap>[] : dailyDrawCards;
    final packs = _cardPacks();
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
      'ladderSteps': ladderSteps,
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

  List<JsonMap> _cardPacks() => const DailyCardGenerator().cardPacks(
    today: today,
    steps: ladderSteps,
    pace: dailyPace == 'relaxed' ? 1 : (profile?['pace'] as num?)?.toInt() ?? 1,
    relaxed: dailyPace == 'relaxed',
    mobileThemes: _mobileRewardsEnabled,
    lowImpact: profile?['lowImpact'] == true,
    reduction: reduction,
  );

  /// Rebuilds today's untouched cards after a ladder or path change.
  void _refreshDraft() {
    if (days[today] == null || hasCommittedDailyCard) return;
    _data['days'][today]['cardPacks'] = _cardPacks();
  }

  void _reviewLadders() {
    final ladderState = (_data['capacity'] ??= <String, dynamic>{}) as Map;
    final pace = (profile?['pace'] as num?)?.toInt() ?? 1;
    final lowImpact = profile?['lowImpact'] == true;
    final inactive = _inactiveDays;
    for (final category in ladderCategories(reduction: reduction)) {
      final maxStep = ladderMax(category, lowImpact: lowImpact);
      final entry = ladderState[category];
      if (entry is! Map) {
        final step = pace.clamp(1, maxStep);
        ladderState[category] = {
          'step': step,
          'reviewedOn': today,
          'change': 'start',
          'reason': 'Mulai dari anak tangga $step sesuai tempo pilihanmu.',
        };
        continue;
      }
      final since = _daysBetween(entry['reviewedOn'].toString(), today);
      if (since < 7 && !(inactive >= 5 && since >= 5)) continue;
      final current = ((entry['step'] as num?)?.toInt() ?? 1).clamp(1, maxStep);
      final review = reviewLadder(
        category: category,
        current: current,
        maxStep: maxStep,
        weekQuests: _ladderQuestsBefore(category, 7),
        inactiveDays: inactive,
      );
      final offered = review.change == 'up';
      ladderState[category] = {
        'step': offered ? current : review.step,
        if (offered) 'offerStep': review.step,
        'reviewedOn': today,
        'change': review.change,
        'reason': review.reason,
      };
    }
  }

  /// Ladder quests the user committed to in the [period] days before today.
  List<JsonMap> _ladderQuestsBefore(String category, int period) {
    final start = dayKey(now.subtract(Duration(days: period)));
    return [
      for (final entry in days.entries)
        if (entry.key.compareTo(start) >= 0 && entry.key.compareTo(today) < 0)
          for (final task
              in ((entry.value as Map)['quests'] ?? const []) as List)
            if (task is Map &&
                task['ladder'] == category &&
                task['practiceOnly'] != true)
              Map<String, dynamic>.from(task),
    ];
  }

  /// Full days without a finished quest before today.
  int get _inactiveDays {
    final before = activeDays.where((day) => day.compareTo(today) < 0);
    final started = profile?['started']?.toString() ?? today;
    if (before.isEmpty) return _daysBetween(started, today);
    return _daysBetween(before.last, today) - 1;
  }

  int _daysBetween(String from, String to) =>
      DateTime.parse(to).difference(DateTime.parse(from)).inDays;

  void acceptLadderStep(String category) {
    final entry = capacity[category];
    final offer = (entry?['offerStep'] as num?)?.toInt();
    if (entry == null || offer == null) return;
    _data['capacity'][category] = {
      ...entry..remove('offerStep'),
      'step': offer,
      'change': 'up',
      'acceptedOn': today,
    };
    if (_mobileRewardsEnabled) {
      _moments.add(
        RewardMoment(
          serial: ++rewardSerial,
          ladder: '${ladderLabels[category] ?? category}: anak tangga $offer',
          badges: _claimAchievements(),
        ),
      );
    }
    _refreshDraft();
    _save();
  }

  void declineLadderStep(String category) {
    final entry = capacity[category];
    if (entry == null || entry['offerStep'] == null) return;
    _data['capacity'][category] = {
      ...entry..remove('offerStep'),
      'change': 'hold',
      'reason': 'Tetap di level ini sesuai pilihanmu.',
    };
    _save();
  }

  /// One-tap effort rating after a quest: ringan, pas, or berat.
  void rateQuestEffort(String id, String effort) {
    if (!const {'ringan', 'pas', 'berat'}.contains(effort)) return;
    final tasks = quests;
    final index = tasks.indexWhere((task) => task['id'] == id);
    if (index < 0 || tasks[index]['status'] != 'completed') return;
    tasks[index] = {...tasks[index], 'effort': effort};
    _data['days'][today]['quests'] = tasks;
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
    final before = quests;
    final index = tasks.indexWhere((task) => task['id'] == id);
    if (index < 0 || tasks[index]['status'] == 'completed') return false;
    tasks[index] = {...tasks[index], 'status': 'completed', 'done': true};
    _data['days'][today]['quests'] = tasks;
    _markActivity();
    _rewardCompletions(before);
    _save();
    return true;
  }

  void addWater() {
    prepareToday();
    _markActivity();
    _data['days'][today]['water'] = (water + 250).clamp(0, 4000);
    _completeWhere(
      (task) =>
          task['activityKind'] == 'water' &&
          water >= ((task['waterMl'] as num?)?.toInt() ?? 0),
    );
    if (_mobileRewardsEnabled) _claimAchievements();
    _save();
  }

  /// Logs only meters and seconds, then checks walk/run quests against them.
  WorkoutResult recordWorkout({
    required String kind,
    required int seconds,
    required int meters,
  }) {
    if (seconds < 1) return const WorkoutResult();
    final kmPerHour = meters / seconds * 3.6;
    final tooFast = kmPerHour > maxWalkRunKmPerHour;
    _add('workoutSessions', {
      'kind': kind,
      'seconds': seconds,
      'meters': meters,
      if (tooFast) 'countsForQuest': false,
    });
    if (tooFast) return const WorkoutResult(tooFast: true);
    final completed = <String>[], partial = <String>[];
    final before = quests;
    final tasks = quests;
    for (final (index, task) in tasks.indexed) {
      if (task['status'] == 'completed') continue;
      final activity = task['activityKind'];
      if (!(activity == 'walk' && (kind == 'walk' || kind == 'run') ||
          activity == 'run' && kind == 'run')) {
        continue;
      }
      final targetMeters = (task['targetMeters'] as num?)?.toInt();
      final targetSeconds = max(
        1,
        ((task['durationMinutes'] as num?)?.toInt() ?? 0) * 60,
      );
      // Valid sessions accumulate across the day; corrections never add credit.
      final ratio = workoutSessions
          .where(
            (row) =>
                row['day'] == today &&
                row['countsForQuest'] != false &&
                row['correctedAt'] == null &&
                (activity == 'walk'
                    ? const {'walk', 'run'}.contains(row['kind'])
                    : row['kind'] == 'run'),
          )
          .fold<double>(0, (sum, row) {
            final loggedMeters = (row['meters'] as num?)?.toInt() ?? 0;
            final loggedSeconds = (row['seconds'] as num?)?.toInt() ?? 0;
            return sum +
                (targetMeters != null && loggedMeters > 0
                    ? loggedMeters / targetMeters
                    : loggedSeconds / targetSeconds);
          });
      if (ratio >= 1) {
        completed.add(task['title'].toString());
        tasks[index] = {...task, 'status': 'completed', 'done': true};
      } else if (ratio > 0) {
        partial.add(task['title'].toString());
        final best = max(ratio, (task['partial'] as num?)?.toDouble() ?? 0);
        tasks[index] = {...task, 'partial': (best * 100).floor() / 100};
      }
    }
    _data['days'][today]['quests'] = tasks;
    _rewardCompletions(before);
    _save();
    return WorkoutResult(completed: completed, partial: partial);
  }

  void recordMeal({String? photoPath, String note = ''}) {
    if (photoPath == null && note.trim().isEmpty) return;
    _add('mealCheckIns', {
      if (photoPath != null) 'photoPath': photoPath,
      'note': note.trim(),
    });
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

  /// A stopped timer is logged as "ditunda X menit", never as a miss.
  void recordHabitDelay({
    int minutes = 5,
    int plannedMinutes = 5,
    bool completed = true,
  }) {
    _add('habitDelays', {
      'minutes': minutes,
      'plannedMinutes': plannedMinutes,
      'completed': completed,
    });
    if (completed) {
      _completeWhere(
        (task) =>
            task['activityKind'] == 'delay' &&
            plannedMinutes >= ((task['delayMinutes'] as num?)?.toInt() ?? 5),
      );
    }
  }

  /// Minutes until another Habit Swap can be logged (one per craving moment).
  int get habitSwapCooldownMinutes {
    if (habitSwaps.isEmpty) return 0;
    final last = DateTime.tryParse(habitSwaps.last['time'].toString());
    if (last == null) return 0;
    final left = habitSwapCooldown - now.difference(last);
    return left.inMicroseconds <= 0
        ? 0
        : (left.inMicroseconds / Duration.microsecondsPerMinute).ceil();
  }

  /// Habit Swap stays self-reported; logging one also ticks its quest.
  bool recordHabitSwap(String swap) {
    if (habitSwapCooldownMinutes > 0) return false;
    _add('habitSwaps', {'swap': swap});
    _completeWhere((task) => task['activityKind'] == 'habit_swap');
    return true;
  }

  /// Minutes of the Delay Craving timer for today's ladder quest.
  int get delayTargetMinutes {
    for (final task in quests) {
      if (task['activityKind'] == 'delay' && task['status'] != 'completed') {
        return (task['delayMinutes'] as num?)?.toInt() ?? 5;
      }
    }
    final step = ladderSteps['Reduction'] ?? 2;
    return ladders['Reduction']![(step - 1).clamp(0, 3)].delayMinutes ?? 5;
  }

  void _completeWhere(bool Function(JsonMap task) test) {
    for (final task in quests) {
      if (test(task) && task['status'] != 'completed') {
        completeCard(task['id'].toString());
      }
    }
  }

  void submitCommunityPost(String text) {
    final clean = text.trim();
    if (clean.length < 3 || clean.length > maxCommunityPostLength) {
      throw ArgumentError('Post harus 3–$maxCommunityPostLength karakter.');
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

  /// One reaction per post, matching the reactions(post_id, user_id) key.
  void reactToCommunityPost(String postId, String reaction) {
    final rows = _data['communityReactions'] as List;
    final wasActive = hasCommunityReaction(postId, reaction);
    rows.removeWhere((row) => row['postId'] == postId);
    if (!wasActive) rows.add({'postId': postId, 'reaction': reaction});
    _save();
  }

  bool hasReportedCommunityPost(String postId) =>
      communityReports.any((report) => report['postId'] == postId);

  /// Returns false when this post was already reported.
  bool reportCommunityPost(String postId, String reason) {
    if (hasReportedCommunityPost(postId)) return false;
    _add('communityReports', {'postId': postId, 'reason': reason});
    return true;
  }

  void resolveCommunityReport(String id) {
    (_data['communityReports'] as List).removeWhere((row) => row['id'] == id);
    _save();
  }

  void _add(String key, JsonMap value) {
    (_data[key] as List).add({
      ...value,
      'id': '${now.microsecondsSinceEpoch}-${Random().nextInt(9999)}',
      'day': today,
      'time': now.toIso8601String(),
    });
    if (const {
      'energyCheckIns',
      'focusSessions',
      'habitDelays',
      'habitSwaps',
      'workoutSessions',
      'mealCheckIns',
    }.contains(key)) {
      _markActivity();
      if (_mobileRewardsEnabled) {
        final badges = _claimAchievements();
        if (badges.isNotEmpty) {
          _moments.add(RewardMoment(serial: ++rewardSerial, badges: badges));
        }
      }
    }
    _save();
  }

  /// Turning the reduction path on requires consent for its sensitive data.
  void switchPath(bool enabled, {bool consent = false}) {
    if (enabled && !consent && profile?['reductionConsent'] != true) {
      throw StateError('Persetujuan data rokok/vape diperlukan.');
    }
    _data['profile']['path'] = enabled ? 'reduction' : 'wellness';
    if (enabled) _data['profile']['reductionConsent'] = true;
    _reviewLadders();
    _refreshDraft();
    _save();
  }

  void setLowImpact(bool enabled) {
    _data['profile']['lowImpact'] = enabled;
    final body = capacity['Body'];
    if (enabled && body != null) {
      final step = (body['step'] as num?)?.toInt() ?? 1;
      _data['capacity']['Body'] = {
        ...body..remove('offerStep'),
        'step': min(step, lowImpactBodyMax),
      };
    }
    _refreshDraft();
    _save();
  }

  String export() {
    final copy = jsonDecode(jsonEncode(_data)) as JsonMap;
    for (final row in copy['mealCheckIns'] as List) {
      if (row is Map) row.remove('photoPath');
    }
    return const JsonEncoder.withIndent('  ').convert(copy);
  }

  JsonMap? get researchParticipation => _data['researchParticipation'] is Map
      ? Map<String, dynamic>.from(_data['researchParticipation'])
      : null;

  void setResearchParticipation(String? code, {required bool consent}) {
    if (consent &&
        (code == null || !RegExp(r'^P(?:[1-9]|10)$').hasMatch(code))) {
      throw ArgumentError('Pilih kode P1–P10.');
    }
    _data['researchParticipation'] = consent
        ? {'code': code, 'consentedOn': today}
        : null;
    _save();
  }

  String exportResearchSummary() {
    if (researchParticipation == null) {
      throw StateError('Persetujuan ringkasan diperlukan.');
    }
    return const JsonEncoder.withIndent('  ').convert({
      'participant_code': researchParticipation!['code'],
      'weeks': [
        for (var week = 1; week <= 4; week++) researchSummary(week).toJson(),
      ],
    });
  }

  /// Corrections change the journal only. Previously earned XP stays earned.
  bool editActivity(
    String collection,
    String id, {
    String? note,
    int? seconds,
    int? meters,
  }) {
    if (!const {'mealCheckIns', 'workoutSessions'}.contains(collection)) {
      return false;
    }
    final rows = _data[collection] as List;
    final index = rows.indexWhere((row) => row['id'] == id);
    if (index < 0) return false;
    rows[index] = {
      ...rows[index] as Map,
      if (note != null) 'note': note.trim(),
      if (seconds != null && seconds > 0) 'seconds': seconds,
      if (meters != null && meters >= 0) 'meters': meters,
      'correctedAt': now.toIso8601String(),
    };
    _save();
    return true;
  }

  bool deleteActivity(String collection, String id) {
    if (!const {'mealCheckIns', 'workoutSessions'}.contains(collection)) {
      return false;
    }
    final rows = _data[collection] as List;
    final count = rows.length;
    rows.removeWhere((row) => row['id'] == id);
    if (rows.length == count) return false;
    _save();
    return true;
  }

  Future<void> reset() async {
    _data = createEmptyWellnessState();
    _moments.clear();
    await _save();
  }
}

const maxCommunityPostLength = 280;
const habitSwapCooldown = Duration(minutes: 10);

/// Above this average speed a session was most likely in a vehicle.
const maxWalkRunKmPerHour = 20.0;

class WorkoutResult {
  const WorkoutResult({
    this.completed = const [],
    this.partial = const [],
    this.tooFast = false,
  });
  final List<String> completed, partial;
  final bool tooFast;
}

/// Example posts, flagged so the Wall can label them as "contoh".
final List<JsonMap> _seedCommunityPosts = [
  {
    'id': 'seed-water',
    'alias': 'daunpagi',
    'text': 'Hari ini berhasil memenuhi target minum air. Small win!',
    'status': 'approved',
    'sample': true,
    'time': '2026-09-20T08:00:00.000',
  },
  {
    'id': 'seed-walk',
    'alias': 'awanbiru',
    'text': 'Jalan santai sepuluh menit ternyata bikin energi balik lagi.',
    'status': 'approved',
    'sample': true,
    'time': '2026-09-20T07:00:00.000',
  },
];
