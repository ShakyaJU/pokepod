import 'generations.dart';

/// How prestigious an achievement is. The names are inspired by Pokémon
/// Trading Card Game rarity terminology but are PokéPod's own system; they are
/// not official Pokémon card classifications. Colours and presentation live in
/// `app/theme/rarity.dart` — the domain never imports Flutter.
enum AchievementRarity {
  common('Common'),
  uncommon('Uncommon'),
  rare('Rare'),
  epic('Epic'),
  doubleRare('Double Rare'),
  ultraRare('Ultra Rare'),
  illustrationRare('Illustration Rare'),
  specialIllustrationRare('Special Illustration Rare'),
  hyperRare('Hyper Rare');

  const AchievementRarity(this.label);

  /// Display name shown in the UI.
  final String label;
}

/// Inputs for badge rules. Everything is derived from the user's real,
/// persisted activity.
class AchievementInput {
  const AchievementInput({
    required this.discovered,
    required this.studied,
    required this.mastered,
    required this.favourites,
    required this.largestCollection,
    required this.collections,
    required this.largestTeam,
    required this.mysteryWins,
    required this.bestStreak,
    required this.discoveredIds,
    required this.notes,
  });

  /// Counts of Pokémon at *least* at each stage (discovered includes studied
  /// and mastered).
  final int discovered;
  final int studied;
  final int mastered;
  final int favourites;
  final int largestCollection;
  final int collections;
  final int largestTeam;
  final int mysteryWins;
  final int bestStreak;
  final Set<int> discoveredIds;
  final int notes;
}

class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.rule,
    required this.progress,
    required this.target,
    required this.rarity,
  });

  final String id;
  final String title;

  /// Plain-language rule, shown to the user.
  final String rule;
  final int progress;
  final int target;

  /// Prestige tier, assigned per achievement (never derived at runtime).
  final AchievementRarity rarity;

  bool get unlocked => progress >= target;

  /// Progress as 0..1 for progress bars, from the same `progress` and `target` shown as text.
  /// A missing target (0 or less) gives 0 rather than a misleading full bar.
  double get fraction {
    if (target <= 0 || progress <= 0) {
      return 0;
    }
    final f = progress / target;
    return f > 1 ? 1 : f;
  }
}

/// Number of generations (1..9) with at least one discovered Pokémon.
int generationsCovered(Iterable<int> discoveredIds) {
  final covered = <int>{};
  for (final id in discoveredIds) {
    final gen = generationOf(id);
    if (gen != null) {
      covered.add(gen);
    }
  }
  return covered.length;
}

List<Achievement> computeAchievements(AchievementInput i) {
  final (lo, hi) = kGenerationRanges.first;
  final genOneDone = [
    for (var id = lo; id <= hi; id++)
      if (i.discoveredIds.contains(id)) id,
  ].length;

  Achievement a(
    String id,
    String title,
    String rule,
    int progress,
    int target,
    AchievementRarity rarity,
  ) => Achievement(
    id: id,
    title: title,
    rule: rule,
    progress: progress > target ? target : progress,
    target: target,
    rarity: rarity,
  );

  return [
    a(
      'first_contact',
      'First Contact',
      'Discover your first Pokémon.',
      i.discovered,
      1,
      AchievementRarity.common,
    ),
    a(
      'field_researcher',
      'Field Researcher',
      'Discover 25 Pokémon.',
      i.discovered,
      25,
      AchievementRarity.uncommon,
    ),
    a(
      'cataloguer',
      'Cataloguer',
      'Discover 100 Pokémon.',
      i.discovered,
      100,
      AchievementRarity.rare,
    ),
    a(
      'kanto_complete',
      'Kanto Complete',
      'Discover all 151 Generation I Pokémon.',
      genOneDone,
      generationSize(1),
      AchievementRarity.specialIllustrationRare,
    ),
    a(
      'world_tour',
      'World Tour',
      'Discover at least one Pokémon from every generation.',
      generationsCovered(i.discoveredIds),
      kGenerationRanges.length,
      AchievementRarity.rare,
    ),
    a(
      'scholar',
      'Scholar',
      'Mark 10 Pokémon as Studied or Mastered.',
      i.studied,
      10,
      AchievementRarity.uncommon,
    ),
    a(
      'mastery',
      'Mastery',
      'Master a Pokémon.',
      i.mastered,
      1,
      AchievementRarity.common,
    ),
    a(
      'curator',
      'Curator',
      'Build a collection with 5 Pokémon.',
      i.largestCollection,
      5,
      AchievementRarity.uncommon,
    ),
    a(
      'team_architect',
      'Team Architect',
      'Build a team of 6.',
      i.largestTeam,
      6,
      AchievementRarity.uncommon,
    ),
    a(
      'first_solve',
      'Mystery Solved',
      'Solve Who\'s That Pokémon? once.',
      i.mysteryWins,
      1,
      AchievementRarity.common,
    ),
    a(
      'streak_3',
      'On a Roll',
      'Reach a best Mystery streak of 3.',
      i.bestStreak,
      3,
      AchievementRarity.common,
    ),
    a(
      'streak_10',
      'Blaze Keeper',
      'Reach a best mystery streak of 10 days.',
      i.bestStreak,
      10,
      AchievementRarity.rare,
    ),
    a(
      'streak_30',
      'Month of Mysteries',
      'Reach a best mystery streak of 30 days.',
      i.bestStreak,
      30,
      AchievementRarity.epic,
    ),
    a(
      'streak_60',
      'Seasoned Sleuth',
      'Reach a best mystery streak of 60 days.',
      i.bestStreak,
      60,
      AchievementRarity.doubleRare,
    ),
    a(
      'streak_100',
      'Hundred-Day Hero',
      'Reach a best mystery streak of 100 days.',
      i.bestStreak,
      100,
      AchievementRarity.ultraRare,
    ),
    a(
      'streak_150',
      'Shadow Master',
      'Reach a best mystery streak of 150 days.',
      i.bestStreak,
      150,
      AchievementRarity.illustrationRare,
    ),
    a(
      'streak_365',
      'A Year Unbroken',
      'Reach a best mystery streak of 365 days.',
      i.bestStreak,
      365,
      AchievementRarity.hyperRare,
    ),
    a(
      'mystery_50',
      'Dedicated Challenger',
      'Win 50 Who\'s That Pokémon? challenges.',
      i.mysteryWins,
      50,
      AchievementRarity.epic,
    ),
    a(
      'journalist',
      'Field Notes',
      'Write notes for 3 Pokémon.',
      i.notes,
      3,
      AchievementRarity.common,
    ),
    a(
      'favourite_five',
      'Favourites',
      'Favourite 5 Pokémon.',
      i.favourites,
      5,
      AchievementRarity.uncommon,
    ),
  ];
}
