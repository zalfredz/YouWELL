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

    // Three choices preserve a playful "pick a card" moment without making
    // the daily decision feel like a long checklist.
    const target = 3;
    final selected = <_CardDefinition>[];
    final categories = reduction
        ? const ['Reduction Challenge', 'Mental', 'Physical']
        : const ['Mental', 'Nutrition', 'Physical', 'Social/Wellbeing'];

    for (final category in categories) {
      final candidates =
          matching.where((card) => card.category == category).toList();
      if (candidates.isNotEmpty && selected.length < target) {
        selected.add(candidates.first);
      }
    }
    for (final card in matching) {
      if (selected.length == target) break;
      if (!selected.contains(card)) selected.add(card);
    }

    // The pool is filtered first; only the placement in the deck is shuffled.
    selected.sort(
      (a, b) => _dailyScore(
        a.id,
        '$today:deck',
      ).compareTo(_dailyScore(b.id, '$today:deck')),
    );

    return selected.indexed
        .map(
          (entry) => {
            'id': '$today-${entry.$2.id}-${entry.$1}',
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
  }

  int _dailyScore(String value, String day) {
    var score = 17;
    for (final code in '$day:$value'.codeUnits) {
      score = (score * 31 + code) % 100003;
    }
    return score;
  }
}

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
