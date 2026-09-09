import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/core/utils/date_key.dart';
import 'package:youwell/data/models/wellness_snapshot.dart';
import 'package:youwell/features/home/domain/daily_card_generator.dart';
import 'package:youwell/features/home/domain/progress_calculator.dart';

/// Application state and commands shared across features.
/// Widgets may read state, but all changes are saved in order through this class.
class WellnessController extends ChangeNotifier {
  WellnessController({String? saved, this.persist, DateTime Function()? clock})
      : clock = clock ?? DateTime.now {
    if (saved != null) {
      try {
        _data = restoreWellnessState(saved);
      } catch (_) {
        storageError =
            'Data lokal tidak terbaca. Simpan salinan data browser sebelum menghapus penyimpanan.';
      }
    }
  }
  final Future<void> Function(String)? persist;
  final DateTime Function() clock;
  JsonMap _data = createEmptyWellnessState();

  /// UI reads snapshots and invokes named commands; it never mutates state.
  List<String> get frozenDays => List<String>.from(_data['frozen']);
  int get dayOffset => (_data['dayOffset'] ?? 0) as int;
  bool get hasSquad => _data['squad'] == true;
  JsonMap? get buddy =>
      _data['buddy'] == null ? null : Map<String, dynamic>.from(_data['buddy']);
  bool hasReaction(String id) => (_data['reactions'] as List).contains(id);
  bool isReported(String id) => reports.any((report) => report['post'] == id);
  String? storageError;
  Future<void> _pending = Future.value();
  DateTime get now =>
      clock().add(Duration(days: (_data['dayOffset'] ?? 0) as int));
  String get today => dayKey(now);
  JsonMap? get profile => _data['profile'] == null
      ? null
      : Map<String, dynamic>.from(_data['profile']);
  bool get reduction => profile?['path'] == 'reduction';
  Map<String, dynamic> get days => Map<String, dynamic>.from(_data['days']);
  List<JsonMap> _rows(String key) =>
      (_data[key] as List).map((e) => Map<String, dynamic>.from(e)).toList();
  List<JsonMap> get quests => ((days[today]?['quests'] ?? []) as List)
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
  List<JsonMap> get dailyCards => quests;
  JsonMap? get dailyCardDraw {
    final value = days[today]?['cardDraw'];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  /// A draw is considered complete once its card pool exists. This also keeps
  /// previews created before the reveal experience compatible with the new UI.
  bool get hasDrawnDailyCards => dailyCards.isNotEmpty;

  /// Keep presenting an unfinished deck on later visits, but never interrupt a
  /// user who has already committed today's challenge.
  bool get needsDailyCardDraw => profile != null && !hasCommittedDailyCard;
  String? get selectedDailyCardId =>
      dailyCardDraw?['selectedCardId']?.toString();
  JsonMap? get selectedDailyCard {
    final id = selectedDailyCardId;
    if (id == null) return null;
    for (final card in dailyCards) {
      if (card['id'] == id) return card;
    }
    return null;
  }

  bool get hasCommittedDailyCard =>
      committedCards.isNotEmpty || completedCards.isNotEmpty;
  List<JsonMap> get availableCards =>
      dailyCards.where((card) => _cardStatus(card) == 'available').toList();
  List<JsonMap> get committedCards =>
      dailyCards.where((card) => _cardStatus(card) == 'committed').toList();
  List<JsonMap> get completedCards =>
      dailyCards.where((card) => _cardStatus(card) == 'completed').toList();
  int get dailyXp => completedCards.fold(
        0,
        (sum, card) => sum + ((card['xp'] ?? 0) as num).toInt(),
      );
  double get dailyProgress => committedCards.isEmpty && completedCards.isEmpty
      ? 0
      : completedCards.length / (committedCards.length + completedCards.length);
  ProgressCalculator get _progress => ProgressCalculator(
        days: days,
        frozenDays: frozenDays,
        now: now,
        fitness: (profile?['fitness'] ?? 1) as int,
        lowImpact: profile?['lowImpact'] == true,
      );
  List<String> get completedDays => _progress.completedDays;
  int get xp => _progress.xp;
  int get level => _progress.level;
  int get tokens => _progress.tokens;
  int get streak => _progress.streak;
  double compliance(int period) => _progress.compliance(period);
  int get difficulty => _progress.difficulty;

  double total(String key, String field, {int period = 1}) {
    final start = dayKey(now.subtract(Duration(days: period - 1)));
    return _rows(key)
        .where(
          (r) =>
              r['day'].toString().compareTo(start) >= 0 &&
              r['day'].toString().compareTo(today) <= 0,
        )
        .fold(0.0, (sum, r) => sum + ((r[field] ?? 0) as num).toDouble());
  }

  double get water => ((days[today]?['water'] ?? 0) as num).toDouble();
  double savings(int period) => _rows('cravings')
      .where(
        (r) =>
            r['success'] == true &&
            r['day'].toString().compareTo(
                      dayKey(now.subtract(Duration(days: period - 1))),
                    ) >=
                0 &&
            r['day'].toString().compareTo(today) <= 0 &&
            r['avoided'] == true,
      )
      .fold(
        0.0,
        (sum, r) =>
            sum + ((r['cost'] ?? profile?['cost'] ?? 0) as num).toDouble(),
      );
  Future<void> _save() {
    notifyListeners();
    final value = jsonEncode(_data);
    _pending = _pending.then((_) async {
      try {
        await persist?.call(value);
        storageError = null;
      } catch (_) {
        storageError =
            'Perubahan belum tersimpan. Penyimpanan browser mungkin penuh. Ekspor datamu dan kurangi foto.';
      }
      notifyListeners();
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
    };
    await _save();
  }

  /// Starts one curated, non-rerollable deck for this local calendar day.
  /// The UI reveals a choice from this deck; generation never happens again
  /// once a deck has been stored.
  void drawDailyCards() {
    if (profile == null) return;
    if (hasDrawnDailyCards) {
      return;
    }
    final list = const DailyCardGenerator().generate(
      today: today,
      difficulty: difficulty,
      lowImpact: profile?['lowImpact'] == true,
      reduction: reduction,
      compliance: compliance(7),
      daysUsingApp: _daysUsingApp,
    );
    _data['days'][today] = {
      ...?days[today] as Map?,
      'quests': list,
      'difficulty': difficulty,
      'cardDraw': {'startedAt': now.toIso8601String(), 'selectedCardId': null},
    };
    _save();
  }

  /// Reveals a card but does not lock it yet. The user may return to the deck
  /// before committing, which makes an accidental choice easy to reverse.
  bool selectDailyCard(String id) {
    if (hasCommittedDailyCard ||
        !availableCards.any((card) => card['id'] == id)) {
      return false;
    }
    final existing = dailyCardDraw ?? const <String, dynamic>{};
    _data['days'][today] = {
      ...?days[today] as Map?,
      'cardDraw': {
        ...existing,
        'selectedCardId': id,
        'revealedAt': now.toIso8601String(),
      },
    };
    _save();
    return true;
  }

  /// Available only before commit. A committed challenge cannot be replaced.
  bool clearDailyCardSelection() {
    if (hasCommittedDailyCard || selectedDailyCardId == null) return false;
    final existing = dailyCardDraw ?? const <String, dynamic>{};
    _data['days'][today] = {
      ...?days[today] as Map?,
      'cardDraw': {...existing, 'selectedCardId': null},
    };
    _save();
    return true;
  }

  bool commitCard(String id) {
    final list = dailyCards;
    final i = list.indexWhere((q) => q['id'] == id);
    final draw = dailyCardDraw;
    if (i < 0 ||
        _cardStatus(list[i]) != 'available' ||
        (draw != null && selectedDailyCardId != id)) {
      return false;
    }
    list[i]['status'] = 'committed';
    list[i]['committedAt'] = now.toIso8601String();
    _data['days'][today]['quests'] = list;
    _save();
    return true;
  }

  bool completeCard(String id) {
    final list = dailyCards;
    final i = list.indexWhere((q) => q['id'] == id);
    if (i < 0 || _cardStatus(list[i]) != 'committed') return false;
    list[i]['status'] = 'completed';
    list[i]['done'] = true;
    _data['days'][today]['quests'] = list;
    _save();
    return true;
  }

  String _cardStatus(JsonMap card) =>
      card['status']?.toString() ??
      (card['done'] == true ? 'completed' : 'available');

  int get _daysUsingApp {
    final started = DateTime.tryParse(profile?['started']?.toString() ?? '');
    return started == null ? 1 : now.difference(started).inDays.abs() + 1;
  }

  bool freeze() {
    final yesterday = dayKey(now.subtract(const Duration(days: 1)));
    final before = dayKey(now.subtract(const Duration(days: 2)));
    if (tokens == 0 ||
        completedDays.contains(yesterday) ||
        (_data['frozen'] as List).contains(yesterday) ||
        !({
          ...completedDays,
          ...(_data['frozen'] as List).cast<String>(),
        }.contains(before))) {
      return false;
    }
    (_data['frozen'] as List).add(yesterday);
    _save();
    return true;
  }

  void _add(String key, JsonMap value) {
    (_data[key] as List).add({
      ...value,
      'id': '${now.microsecondsSinceEpoch}-${Random().nextInt(99999)}',
      'day': today,
      'time': now.toIso8601String(),
    });
    _save();
  }

  void _remove(String key, String id) {
    (_data[key] as List).removeWhere((r) => r['id'] == id);
    _save();
  }

  void addWater() {
    _data['days'][today] = {
      ...?days[today] as Map?,
      'water': water + 250,
      'quests': quests,
    };
    _save();
  }

  void react(String id) {
    final reactions = _data['reactions'] as List;
    reactions.contains(id) ? reactions.remove(id) : reactions.add(id);
    _save();
  }

  void updatePost(String id, String status, String note) {
    for (final post in _data['posts'] as List) {
      if (post['id'] == id) {
        post['status'] = status;
        post['note'] = note;
      }
    }
    _save();
  }

  String export() => const JsonEncoder.withIndent('  ').convert(_data);
  Future<void> reset() async {
    _data = createEmptyWellnessState();
    await _save();
  }

  // Feature commands: all writes pass through this controller and persistence queue.
  List<JsonMap> get meals => _rows('meals');
  void addMeal(JsonMap value) => _add('meals', value);
  void deleteMeal(String id) => _remove('meals', id);
  List<JsonMap> get activities => _rows('activities');
  void logActivity(JsonMap value) => _add('activities', value);
  void deleteActivity(String id) => _remove('activities', id);
  List<JsonMap> get moods => _rows('moods');
  void checkInMood(JsonMap value) => _add('moods', value);
  void deleteMood(String id) => _remove('moods', id);
  List<JsonMap> get cravings => _rows('cravings');
  void recordCraving(JsonMap value) => _add('cravings', value);
  void deleteCraving(String id) => _remove('cravings', id);
  List<JsonMap> get posts => _rows('posts');
  void submitPost(JsonMap value) => _add('posts', value);
  void deletePost(String id) => _remove('posts', id);
  List<JsonMap> get reports => _rows('reports');
  void reportContent(JsonMap value) => _add('reports', value);
  void resolveReport(String id) => _remove('reports', id);

  void switchPath(bool reduction) {
    _data['profile']['path'] = reduction ? 'reduction' : 'wellness';
    _data['buddy'] = null;
    _save();
  }

  void setLowImpact(bool enabled) {
    _data['profile']['lowImpact'] = enabled;
    if (enabled) {
      for (final quest in _data['days'][today]?['quests'] ?? []) {
        if (quest['category'] == 'Physical' && quest['status'] == 'available') {
          quest['title'] = 'Gentle Stretch Break';
          quest['description'] =
              'Move and stretch gently for five minutes at your own pace.';
          quest['difficulty'] = 1;
          quest['xp'] = 20;
        }
      }
    }
    _save();
  }

  void updateNutritionTargets(Map<String, int> targets) {
    _data['profile'].addAll(targets);
    _save();
  }

  void joinSquad() {
    _data['squad'] = true;
    _data['squadJoined'] = today;
    _save();
  }

  void leaveSquad() {
    _data['squad'] = false;
    _save();
  }

  void matchBuddy() {
    final candidates = reduction
        ? ['pelanpelan', 'jeda_sore', 'ruangbaru']
        : ['daunpagi', 'mori_kecil', 'awanbiru'];
    _data['buddy'] = {
      'alias': (candidates..shuffle()).first,
      'path': profile!['path'],
      'streak': 3,
    };
    _save();
  }

  void endBuddy() {
    _data['buddy'] = null;
    _save();
  }

  void advancePreviewDays(int count) {
    if (count < 1) {
      throw ArgumentError.value(count, 'count', 'Must be positive');
    }
    _data['dayOffset'] = dayOffset + count;
    _save();
  }
}
