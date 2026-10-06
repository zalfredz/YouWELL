import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/features/home/domain/quest_ladder.dart';

/// Explainable, rule-based daily packs. Every card carries the user's ladder
/// quest for each category; light side quests make the five cards differ.
class DailyCardGenerator {
  const DailyCardGenerator();

  List<JsonMap> cardPacks({
    required String today,
    required Map<String, int> steps,
    required int pace,
    required bool lowImpact,
    required bool reduction,
    bool relaxed = false,
    bool mobileThemes = false,
  }) {
    final sideCount = pace.clamp(1, 2);
    final catalog = [
      ..._catalog,
      ...(mobileThemes ? _mobileCatalog : _webCatalog),
    ];
    final eligible = catalog.where((task) {
      if (task.reductionOnly && !reduction) return false;
      if (task.difficulty > pace.clamp(1, 3)) return false;
      return true;
    }).toList();
    const names = [
      'Tunas Baru',
      'Langkah Segar',
      'Cahaya Hari',
      'Ritme Ceria',
      'Arah Baru',
    ];
    const themes = [
      'Gerak Ringan',
      'Energi Segar',
      'Istirahat',
      'Hidrasi & Makan',
      'Udara Segar',
    ];
    const themedIds = [
      ['posture', 'stretch', 'fresh-air'],
      ['sunlight', 'stand-break', 'stretch'],
      ['screen-break', 'posture', 'stretch'],
      ['water-glass', 'meal-snap', 'fruit-veg'],
      ['fresh-air', 'sunlight', 'screen-break'],
    ];
    return List.generate(names.length, (index) {
      // Keep reduction extras reachable, rather than merely present in a pool
      // that physical theme priorities would always outrank.
      final preferredIds = reduction && index == 1
          ? const ['habit-swap', 'trigger', 'swap-plan']
          : themedIds[index];
      final ladderTasks = [
        for (final category in ladderCategories(reduction: reduction))
          _ladderTask(
            category,
            ((steps[category] ?? 1) - (relaxed ? 1 : 0)).clamp(
              1,
              ladderMax(category, lowImpact: lowImpact),
            ),
            today,
            index,
          ),
      ];
      final sides = [...eligible]
        ..sort((a, b) {
          if (mobileThemes) {
            final preferredA = preferredIds.contains(a.id) ? 0 : 1;
            final preferredB = preferredIds.contains(b.id) ? 0 : 1;
            if (preferredA != preferredB) {
              return preferredA.compareTo(preferredB);
            }
          }
          return _score(
            a.id,
            '$today:$index',
          ).compareTo(_score(b.id, '$today:$index'));
        });
      final tasks = [
        ...ladderTasks,
        for (final (sideIndex, task) in sides.take(sideCount).indexed)
          {
            ..._toMap(task, today, 'card-$index-side-$sideIndex'),
            if (mobileThemes) 'xp': 20,
          },
      ];
      if (relaxed) {
        for (final task in tasks.where((task) => task['ladder'] != null)) {
          task['practiceOnly'] = task['step'] != steps[task['ladder']];
        }
      }
      return {
        'id': '$today-card-$index',
        'title': mobileThemes ? themes[index] : names[index],
        'cardStyle': index,
        'difficulty': pace.clamp(1, 3),
        'tasks': tasks,
        'xp': tasks.fold<int>(0, (sum, task) => sum + (task['xp'] as int)),
        'durationMinutes': tasks.fold<int>(
          0,
          (sum, task) => sum + (task['durationMinutes'] as int),
        ),
      };
    });
  }

  JsonMap _ladderTask(String category, int step, String today, int card) {
    final rung = ladders[category]![step - 1];
    return {
      'id': '$today-card-$card-ladder-$category',
      'catalogId': 'ladder-${category.toLowerCase()}',
      'ladder': category,
      'step': step,
      'title': rung.title,
      'description': rung.description,
      'category': category,
      'difficulty': step,
      'durationMinutes': rung.durationMinutes,
      'xp': 15 + step * 5,
      'source': 'card',
      'status': 'available',
      'done': false,
      'activityKind': ?rung.activityKind,
      'targetMeters': ?rung.targetMeters,
      'delayMinutes': ?rung.delayMinutes,
      'waterMl': ?rung.waterMl,
      if (rung.strenuous) 'strenuous': true,
    };
  }

  JsonMap _toMap(_TaskDefinition task, String today, String suffix) => {
    'id': '$today-$suffix-${task.id}',
    'catalogId': task.id,
    'title': task.title,
    'description': task.description,
    'category': task.category,
    'difficulty': task.difficulty,
    'durationMinutes': task.durationMinutes,
    'xp': task.xp,
    'source': 'card',
    'status': 'available',
    'done': false,
    'activityKind': ?task.activityKind,
    'waterMl': ?task.waterMl,
  };

  int _score(String value, String salt) {
    var score = 17;
    for (final code in '$salt:$value'.codeUnits) {
      score = (score * 31 + code) % 100003;
    }
    return score;
  }
}

class _TaskDefinition {
  const _TaskDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.durationMinutes,
    required this.xp,
    this.reductionOnly = false,
    this.activityKind,
    this.waterMl,
  });
  final String id, title, description, category;
  final int difficulty, durationMinutes, xp;
  final bool reductionOnly;
  final String? activityKind;
  final int? waterMl;
}

/// Side quests: short, self-reported (or photo-backed) extras.
const _catalog = [
  _TaskDefinition(
    id: 'posture',
    title: 'Rapikan postur',
    description: 'Lepaskan bahu dan rapikan posisi duduk.',
    category: 'Body',
    difficulty: 1,
    durationMinutes: 1,
    xp: 15,
  ),
  _TaskDefinition(
    id: 'stretch',
    title: 'Stretching ringan',
    description: 'Leher, bahu, dan punggung dengan nyaman.',
    category: 'Body',
    difficulty: 1,
    durationMinutes: 3,
    xp: 20,
  ),
  _TaskDefinition(
    id: 'meal-snap',
    title: 'Catat satu momen makan',
    description: 'Foto untuk jurnal makan pribadimu. Foto tetap di HP.',
    category: 'Lifestyle',
    difficulty: 1,
    durationMinutes: 1,
    xp: 15,
    activityKind: 'meal_snap',
  ),
  _TaskDefinition(
    id: 'sunlight',
    title: 'Cari cahaya pagi',
    description: 'Keluar atau duduk dekat jendela.',
    category: 'Energy',
    difficulty: 1,
    durationMinutes: 3,
    xp: 15,
  ),
  _TaskDefinition(
    id: 'screen-break',
    title: 'Jeda layar',
    description: 'Alihkan pandangan dari layar.',
    category: 'Energy',
    difficulty: 1,
    durationMinutes: 2,
    xp: 15,
  ),
  _TaskDefinition(
    id: 'habit-swap',
    title: 'Coba 1 Habit Swap',
    description: 'Saat keinginan muncul, pilih satu aktivitas pengganti.',
    category: 'Reduction',
    difficulty: 1,
    durationMinutes: 2,
    xp: 20,
    reductionOnly: true,
    activityKind: 'habit_swap',
  ),
  _TaskDefinition(
    id: 'trigger',
    title: 'Kenali satu pemicu',
    description: 'Perhatikan situasi saat keinginan muncul.',
    category: 'Reduction',
    difficulty: 2,
    durationMinutes: 3,
    xp: 30,
    reductionOnly: true,
  ),
  _TaskDefinition(
    id: 'swap-plan',
    title: 'Rencana Habit Swap',
    description: 'Siapkan dua pengganti untuk momen keinginan.',
    category: 'Reduction',
    difficulty: 3,
    durationMinutes: 8,
    xp: 40,
    reductionOnly: true,
  ),
  _TaskDefinition(
    id: 'fresh-air',
    title: 'Cari udara segar',
    description: 'Keluar sebentar dan ubah suasana.',
    category: 'Lifestyle',
    difficulty: 1,
    durationMinutes: 5,
    xp: 25,
  ),
];

/// Physical wellness extras for mobile; never change the web quest pool.
const _mobileCatalog = [
  _TaskDefinition(
    id: 'water-glass',
    title: 'Satu gelas air',
    description: 'Minum sesuai kebutuhanmu, lalu catat di Hidrasi.',
    category: 'Lifestyle',
    difficulty: 1,
    durationMinutes: 1,
    xp: 20,
    activityKind: 'water',
    waterMl: 250,
  ),
  _TaskDefinition(
    id: 'fruit-veg',
    title: 'Tambahkan buah atau sayur',
    description: 'Pilih buah atau sayur yang tersedia saat makan.',
    category: 'Lifestyle',
    difficulty: 1,
    durationMinutes: 2,
    xp: 20,
  ),
  _TaskDefinition(
    id: 'stand-break',
    title: 'Ubah posisi sebentar',
    description: 'Berdiri atau regangkan tubuh sambil duduk senyamanmu.',
    category: 'Body',
    difficulty: 1,
    durationMinutes: 1,
    xp: 20,
  ),
];

/// Existing desktop tasks stay available to the untouched web experience.
const _webCatalog = [
  _TaskDefinition(
    id: 'focus-sprint',
    title: 'Fokus singkat 10 menit',
    description: 'Kerjakan satu hal tanpa berpindah.',
    category: 'Energy',
    difficulty: 2,
    durationMinutes: 10,
    xp: 30,
  ),
  _TaskDefinition(
    id: 'tidy',
    title: 'Rapikan satu sudut',
    description: 'Cukup satu area kecil di dekatmu.',
    category: 'Lifestyle',
    difficulty: 1,
    durationMinutes: 3,
    xp: 20,
  ),
  _TaskDefinition(
    id: 'tomorrow',
    title: 'Siapkan besok',
    description: 'Pilih satu hal yang ingin dipermudah.',
    category: 'Lifestyle',
    difficulty: 2,
    durationMinutes: 5,
    xp: 25,
  ),
  _TaskDefinition(
    id: 'kind-message',
    title: 'Kirim kabar baik',
    description: 'Sapa satu orang yang kamu pedulikan.',
    category: 'Lifestyle',
    difficulty: 1,
    durationMinutes: 2,
    xp: 20,
  ),
  _TaskDefinition(
    id: 'routine-plan',
    title: 'Rancang rutinitas kecil',
    description: 'Pilih tiga langkah realistis untuk besok.',
    category: 'Lifestyle',
    difficulty: 3,
    durationMinutes: 10,
    xp: 40,
  ),
  _TaskDefinition(
    id: 'music',
    title: 'Satu lagu tanpa layar',
    description: 'Nikmati satu lagu tanpa membuka aplikasi lain.',
    category: 'Energy',
    difficulty: 1,
    durationMinutes: 4,
    xp: 20,
  ),
];
