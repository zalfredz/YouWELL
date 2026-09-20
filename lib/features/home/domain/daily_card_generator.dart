import 'package:youwell/core/types/json_map.dart';

/// Explainable, rule-based personalization for the local prototype.
/// Three core quests are prepared automatically; the draw adds one bonus.
class DailyCardGenerator {
  const DailyCardGenerator();

  List<JsonMap> coreQuests({
    required String today,
    required int difficulty,
    required bool lowImpact,
    required bool reduction,
    required double completionRate,
    required int daysUsingApp,
  }) {
    final easyDay = daysUsingApp <= 2 || completionRate < .4;
    final maxDifficulty = easyDay ? 1 : difficulty;
    final eligible = _catalog.where((task) {
      if (task.bonusOnly || (task.reductionOnly && !reduction)) return false;
      if (task.difficulty > maxDifficulty) return false;
      if (lowImpact && task.category == 'Body' && !task.lowImpact) return false;
      return true;
    }).toList();
    final categories = reduction
        ? const ['Body', 'Energy', 'Reduction']
        : const ['Body', 'Energy', 'Lifestyle'];
    return categories.indexed.map((entry) {
      final candidates =
          eligible.where((task) => task.category == entry.$2).toList()..sort(
            (a, b) => _score(
              a.id,
              '$today:${entry.$1}',
            ).compareTo(_score(b.id, '$today:${entry.$1}')),
          );
      return _toMap(candidates.first, today, 'core-${entry.$1}', 'core');
    }).toList();
  }

  List<JsonMap> bonusCards({
    required String today,
    required int difficulty,
    required bool lowImpact,
    required bool reduction,
    required Set<String> excludedTitles,
  }) {
    final eligible =
        _catalog.where((task) {
          if (task.reductionOnly && !reduction) return false;
          if (task.difficulty > (difficulty + 1).clamp(1, 3)) return false;
          if (lowImpact && task.category == 'Body' && !task.lowImpact) {
            return false;
          }
          return !excludedTitles.contains(task.title);
        }).toList()..sort(
          (a, b) => _score(
            a.id,
            '$today:bonus',
          ).compareTo(_score(b.id, '$today:bonus')),
        );
    return List.generate(5, (index) {
      final task = eligible[index % eligible.length];
      return {
        ..._toMap(task, today, 'bonus-$index', 'bonus'),
        'cardStyle': index,
      };
    });
  }

  JsonMap _toMap(
    _TaskDefinition task,
    String today,
    String suffix,
    String source,
  ) => {
    'id': '$today-$suffix-${task.id}',
    'title': task.title,
    'description': task.description,
    'category': task.category,
    'difficulty': task.difficulty,
    'durationMinutes': task.durationMinutes,
    'xp': task.xp,
    'source': source,
    'status': source == 'core' ? 'committed' : 'available',
    'done': false,
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
    this.lowImpact = true,
    this.reductionOnly = false,
    this.bonusOnly = false,
  });
  final String id, title, description, category;
  final int difficulty, durationMinutes, xp;
  final bool lowImpact, reductionOnly, bonusOnly;
}

const _catalog = [
  _TaskDefinition(
    id: 'water',
    title: 'Minum satu gelas air',
    description: 'Satu gelas, pelan-pelan.',
    category: 'Body',
    difficulty: 1,
    durationMinutes: 1,
    xp: 15,
  ),
  _TaskDefinition(
    id: 'posture',
    title: 'Posture reset',
    description: 'Lepaskan bahu dan rapikan posisi duduk.',
    category: 'Body',
    difficulty: 1,
    durationMinutes: 1,
    xp: 15,
  ),
  _TaskDefinition(
    id: 'stretch',
    title: 'Stretch ringan',
    description: 'Gerakkan tubuh dengan nyaman.',
    category: 'Body',
    difficulty: 1,
    durationMinutes: 3,
    xp: 20,
  ),
  _TaskDefinition(
    id: 'walk',
    title: 'Jalan santai',
    description: 'Berjalan dengan ritmemu sendiri.',
    category: 'Body',
    difficulty: 2,
    durationMinutes: 10,
    xp: 30,
    lowImpact: false,
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
    id: 'focus-sprint',
    title: 'Focus sprint',
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
    id: 'delay',
    title: 'Tunda 5 menit',
    description: 'Saat ingin merokok atau vape, beri jeda.',
    category: 'Reduction',
    difficulty: 1,
    durationMinutes: 5,
    xp: 25,
    reductionOnly: true,
  ),
  _TaskDefinition(
    id: 'habit-swap',
    title: 'Siapkan habit swap',
    description: 'Taruh air atau permen bebas gula di dekatmu.',
    category: 'Reduction',
    difficulty: 1,
    durationMinutes: 2,
    xp: 20,
    reductionOnly: true,
  ),
  _TaskDefinition(
    id: 'trigger',
    title: 'Kenali satu pemicu',
    description: 'Catat situasi dan alternatif yang lebih baik.',
    category: 'Reduction',
    difficulty: 2,
    durationMinutes: 3,
    xp: 30,
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
    bonusOnly: true,
  ),
  _TaskDefinition(
    id: 'music',
    title: 'Satu lagu tanpa layar',
    description: 'Nikmati satu lagu tanpa membuka aplikasi lain.',
    category: 'Energy',
    difficulty: 1,
    durationMinutes: 4,
    xp: 20,
    bonusOnly: true,
  ),
];
