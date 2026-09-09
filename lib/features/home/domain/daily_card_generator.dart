import 'package:youwell/core/types/json_map.dart';

/// Creates a stable daily draw from challenges suitable for a user's rhythm.
/// The same profile receives the same set for the same day; cards never reroll.
class DailyCardGenerator {
  const DailyCardGenerator();

  List<JsonMap> generate({
    required String today,
    required int difficulty,
    required bool lowImpact,
    required bool reduction,
    required double compliance,
    required int daysUsingApp,
  }) {
    final matching = _catalog.where((card) {
      if (card.reductionOnly && !reduction) return false;
      if (!card.reductionOnly &&
          card.category == 'Reduction Challenge' &&
          !reduction) {
        return false;
      }
      if (card.difficulty > difficulty) return false;
      // The first days and a rough recent rhythm should start gently. The
      // adaptive difficulty also accounts for longer-term completion history.
      if ((daysUsingApp <= 2 || compliance < .35) && card.difficulty > 1) {
        return false;
      }
      if (lowImpact && card.category == 'Physical' && !card.lowImpact) {
        return false;
      }
      return true;
    }).toList()
      ..sort(
        (a, b) => _dailyScore(a.id, today).compareTo(_dailyScore(b.id, today)),
      );

    // The deck always contains five collectible cards. One card is a package
    // of 3–5 tasks, not a single task, so the chosen card becomes a full day.
    const cardCount = 5;
    final taskCount = daysUsingApp <= 2
        ? 3
        : compliance >= .75
            ? 5
            : 4;
    final categories = reduction
        ? const [
            'Reduction Challenge',
            'Mental',
            'Nutrition',
            'Physical',
            'Social/Wellbeing',
          ]
        : const ['Mental', 'Nutrition', 'Physical', 'Social/Wellbeing'];

    return List.generate(cardCount, (cardIndex) {
      final ranked = [...matching]..sort(
          (a, b) => _dailyScore(a.id, '$today:pack:$cardIndex')
              .compareTo(_dailyScore(b.id, '$today:pack:$cardIndex')),
        );
      final tasks = <_CardDefinition>[];

      for (final category in categories) {
        final candidate = ranked.where((task) => task.category == category);
        if (candidate.isNotEmpty && tasks.length < taskCount) {
          tasks.add(candidate.first);
        }
      }
      for (final task in ranked) {
        if (tasks.length == taskCount) break;
        if (!tasks.contains(task)) tasks.add(task);
      }

      final pack = _packThemes[cardIndex];
      final taskRows = tasks.indexed
          .map(
            (entry) => {
              'id': '$today-pack-$cardIndex-${entry.$2.id}-${entry.$1}',
              'title': entry.$2.title,
              'description': entry.$2.description,
              'category': entry.$2.category,
              'difficulty': entry.$2.difficulty,
              'xp': entry.$2.xp,
              'status': 'available',
              'done': false,
            },
          )
          .toList();
      return {
        'id': '$today-pack-$cardIndex',
        'title': pack.$1,
        'description': pack.$2,
        'taskCount': taskRows.length,
        'xp':
            taskRows.fold<int>(0, (total, task) => total + (task['xp'] as int)),
        'cardStyle': cardIndex,
        'tasks': taskRows,
        'status': 'available',
      };
    });
  }

  int _dailyScore(String value, String day) {
    var score = 17;
    for (final code in '$day:$value'.codeUnits) {
      score = (score * 31 + code) % 100003;
    }
    return score;
  }
}

const _packThemes = [
  ('Soft Reset', 'A gentle set of small wins for your day.'),
  ('Bright Momentum', 'A balanced mini-plan to build momentum.'),
  ('Steady Energy', 'A focused mix for feeling a little more grounded.'),
  ('Kind to Yourself', 'Small tasks designed to meet you where you are.'),
  ('Fresh Start', 'A playful set of steps for a healthier rhythm.'),
];

class _CardDefinition {
  const _CardDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.xp,
    this.lowImpact = true,
    this.reductionOnly = false,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final int difficulty;
  final int xp;
  final bool lowImpact;
  final bool reductionOnly;
}

const _catalog = [
  _CardDefinition(
    id: 'walk-15',
    title: 'Walk 15 Minutes',
    description: 'Walk for 15 minutes today at a comfortable pace.',
    category: 'Physical',
    difficulty: 2,
    xp: 30,
    lowImpact: false,
  ),
  _CardDefinition(
    id: 'stretch-5',
    title: 'Gentle Stretch Break',
    description: 'Move and stretch gently for five minutes.',
    category: 'Physical',
    difficulty: 1,
    xp: 20,
  ),
  _CardDefinition(
    id: 'posture-reset',
    title: 'Posture Reset',
    description: 'Relax your shoulders and reset your posture for one minute.',
    category: 'Physical',
    difficulty: 1,
    xp: 15,
  ),
  _CardDefinition(
    id: 'breathing',
    title: 'One Minute to Breathe',
    description: 'Take six slow breaths before continuing your day.',
    category: 'Mental',
    difficulty: 1,
    xp: 15,
  ),
  _CardDefinition(
    id: 'journal',
    title: 'Three-Line Journal',
    description: 'Write three lines about what you need today.',
    category: 'Mental',
    difficulty: 2,
    xp: 30,
  ),
  _CardDefinition(
    id: 'water',
    title: 'Water Reset',
    description: 'Drink one glass of water with full attention.',
    category: 'Nutrition',
    difficulty: 1,
    xp: 15,
  ),
  _CardDefinition(
    id: 'color-plate',
    title: 'Add One Color',
    description: 'Add one fruit or vegetable color to a meal today.',
    category: 'Nutrition',
    difficulty: 2,
    xp: 25,
  ),
  _CardDefinition(
    id: 'kind-message',
    title: 'Send a Kind Message',
    description: 'Send one sincere check-in to someone you trust.',
    category: 'Social/Wellbeing',
    difficulty: 1,
    xp: 20,
  ),
  _CardDefinition(
    id: 'quiet-connection',
    title: 'Quiet Connection',
    description: 'Share a small moment with someone without multitasking.',
    category: 'Social/Wellbeing',
    difficulty: 2,
    xp: 30,
  ),
  _CardDefinition(
    id: 'delay-five',
    title: 'Delay the Urge',
    description:
        'When an urge appears, wait five minutes with water or breath.',
    category: 'Reduction Challenge',
    difficulty: 1,
    xp: 25,
    reductionOnly: true,
  ),
  _CardDefinition(
    id: 'trigger-note',
    title: 'Name the Trigger',
    description: 'Write one trigger and one gentler alternative for today.',
    category: 'Reduction Challenge',
    difficulty: 2,
    xp: 35,
    reductionOnly: true,
  ),
];
