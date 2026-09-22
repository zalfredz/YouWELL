import 'package:youwell/core/types/json_map.dart';

/// Explainable, rule-based daily packs. Each card becomes the day's plan.
class DailyCardGenerator {
  const DailyCardGenerator();

  List<JsonMap> cardPacks({
    required String today,
    required int difficulty,
    required bool lowImpact,
    required bool reduction,
    required double completionRate,
    required int daysUsingApp,
  }) {
    final level = daysUsingApp <= 2 || completionRate < .4
        ? 1
        : difficulty.clamp(1, 3);
    final questCount = level + 2;
    final eligible = _catalog.where((task) {
      if (task.reductionOnly && !reduction) return false;
      if (task.difficulty > level) return false;
      if (lowImpact && task.category == 'Body' && !task.lowImpact) return false;
      return true;
    }).toList();
    final categories = reduction
        ? const ['Body', 'Energy', 'Reduction']
        : const ['Body', 'Energy', 'Lifestyle'];
    const names = [
      'Tunas Baru',
      'Langkah Segar',
      'Cahaya Hari',
      'Ritme Ceria',
      'Arah Baru',
    ];
    return List.generate(names.length, (index) {
      final picked = <_TaskDefinition>[];
      var stride = 1;
      for (final category in categories) {
        final choices =
            eligible.where((task) => task.category == category).toList()..sort(
              (a, b) => _score(a.id, today).compareTo(_score(b.id, today)),
            );
        picked.add(choices[(index + index ~/ stride) % choices.length]);
        stride *= choices.length;
      }
      final remaining =
          eligible.where((task) => !picked.contains(task)).toList()..sort(
            (a, b) => _score(
              a.id,
              '$today:$index',
            ).compareTo(_score(b.id, '$today:$index')),
          );
      if (level > 1 && picked.length < questCount) {
        final challenge = remaining.firstWhere(
          (task) => task.difficulty == level,
          orElse: () => remaining.first,
        );
        picked.add(challenge);
        remaining.remove(challenge);
      }
      picked.addAll(remaining.take(questCount - picked.length));
      final tasks = [
        for (final (taskIndex, task) in picked.indexed)
          _toMap(task, today, 'card-$index-task-$taskIndex'),
      ];
      return {
        'id': '$today-card-$index',
        'title': names[index],
        'cardStyle': index,
        'difficulty': level,
        'tasks': tasks,
        'xp': tasks.fold<int>(0, (sum, task) => sum + (task['xp'] as int)),
        'durationMinutes': tasks.fold<int>(
          0,
          (sum, task) => sum + (task['durationMinutes'] as int),
        ),
      };
    });
  }

  JsonMap _toMap(_TaskDefinition task, String today, String suffix) => {
    'id': '$today-$suffix-${task.id}',
    'title': task.title,
    'description': task.description,
    'category': task.category,
    'difficulty': task.difficulty,
    'durationMinutes': task.durationMinutes,
    'xp': task.xp,
    'source': 'card',
    'status': 'available',
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
  });
  final String id, title, description, category;
  final int difficulty, durationMinutes, xp;
  final bool lowImpact, reductionOnly;
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
    id: 'walk-long',
    title: 'Jalan 20 menit',
    description: 'Nikmati rute yang aman dengan ritmemu.',
    category: 'Body',
    difficulty: 3,
    durationMinutes: 20,
    xp: 45,
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
    id: 'focus-deep',
    title: 'Fokus 20 menit',
    description: 'Pilih satu hal dan beri perhatian penuh.',
    category: 'Energy',
    difficulty: 3,
    durationMinutes: 20,
    xp: 45,
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
    id: 'swap-plan',
    title: 'Rencana habit swap',
    description: 'Siapkan dua pengganti untuk momen craving.',
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
