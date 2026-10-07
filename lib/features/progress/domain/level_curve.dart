// Rising level curve (CHALLENGE_SPEC §9): going from level n to n + 1 costs
// 100 + 50 × (n − 1) XP, so 100, 150, 200, … Levels never go down.

/// Total XP needed to reach [level] (level 1 starts at 0 XP).
int xpForLevel(int level) {
  final n = level - 1;
  if (n <= 0) return 0;
  return 100 * n + 25 * n * (n - 1);
}

/// Highest level whose threshold is covered by [xp].
int levelForXp(int xp) {
  var level = 1;
  while (xpForLevel(level + 1) <= xp) {
    level++;
  }
  return level;
}

/// Level from the old flat curve (every 100 XP), used once for migration.
int legacyLevelForXp(int xp) => 1 + xp ~/ 100;
