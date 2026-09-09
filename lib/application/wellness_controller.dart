import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/core/utils/date_key.dart';
import 'package:youwell/data/models/wellness_snapshot.dart';
import 'package:youwell/features/home/domain/quest_generator.dart';
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

  void draw() {
    if (quests.isNotEmpty || profile == null) return;
    final d = difficulty;
    final list = const QuestGenerator().generate(
      today: today,
      difficulty: d,
      lowImpact: profile?['lowImpact'] == true,
      reduction: reduction,
    );
    _data['days'][today] = {
      ...?days[today] as Map?,
      'quests': list,
      'difficulty': d,
    };
    _save();
  }

  void complete(String id) {
    final list = quests;
    final i = list.indexWhere((q) => q['id'] == id);
    if (i < 0 || list[i]['done'] == true) return;
    list[i]['done'] = true;
    _data['days'][today]['quests'] = list;
    _save();
  }

  /// Restores a task completion when a user changes their mind.
  void undoComplete(String id) {
    final list = quests;
    final i = list.indexWhere((q) => q['id'] == id);
    if (i < 0 || list[i]['done'] != true) return;
    list[i]['done'] = false;
    _data['days'][today]['quests'] = list;
    _save();
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
        if (quest['category'] == 'Gerak' && quest['done'] != true) {
          quest['title'] = 'Istirahat nyaman dan ambil jeda layar 5 menit';
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
