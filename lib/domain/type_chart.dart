/// Type-effectiveness engine.
///
/// Ruleset: the current 18-type chart used since Generation VI (Fairy type
/// included, Steel no longer resisting Ghost/Dark). Multipliers are
/// 0, 0.5, 1 and 2 for a single type and multiply together for dual types.
library;

const List<String> kTypes = [
  'normal',
  'fire',
  'water',
  'electric',
  'grass',
  'ice',
  'fighting',
  'poison',
  'ground',
  'flying',
  'psychic',
  'bug',
  'rock',
  'ghost',
  'dragon',
  'dark',
  'steel',
  'fairy',
];

const Map<String, Map<String, double>> _chart = {
  'normal': {'rock': 0.5, 'steel': 0.5, 'ghost': 0},
  'fire': {
    'grass': 2,
    'ice': 2,
    'bug': 2,
    'steel': 2,
    'fire': 0.5,
    'water': 0.5,
    'rock': 0.5,
    'dragon': 0.5,
  },
  'water': {
    'fire': 2,
    'ground': 2,
    'rock': 2,
    'water': 0.5,
    'grass': 0.5,
    'dragon': 0.5,
  },
  'electric': {
    'water': 2,
    'flying': 2,
    'electric': 0.5,
    'grass': 0.5,
    'dragon': 0.5,
    'ground': 0,
  },
  'grass': {
    'water': 2,
    'ground': 2,
    'rock': 2,
    'fire': 0.5,
    'grass': 0.5,
    'poison': 0.5,
    'flying': 0.5,
    'bug': 0.5,
    'dragon': 0.5,
    'steel': 0.5,
  },
  'ice': {
    'grass': 2,
    'ground': 2,
    'flying': 2,
    'dragon': 2,
    'fire': 0.5,
    'water': 0.5,
    'ice': 0.5,
    'steel': 0.5,
  },
  'fighting': {
    'normal': 2,
    'ice': 2,
    'rock': 2,
    'dark': 2,
    'steel': 2,
    'poison': 0.5,
    'flying': 0.5,
    'psychic': 0.5,
    'bug': 0.5,
    'fairy': 0.5,
    'ghost': 0,
  },
  'poison': {
    'grass': 2,
    'fairy': 2,
    'poison': 0.5,
    'ground': 0.5,
    'rock': 0.5,
    'ghost': 0.5,
    'steel': 0,
  },
  'ground': {
    'fire': 2,
    'electric': 2,
    'poison': 2,
    'rock': 2,
    'steel': 2,
    'grass': 0.5,
    'bug': 0.5,
    'flying': 0,
  },
  'flying': {
    'grass': 2,
    'fighting': 2,
    'bug': 2,
    'electric': 0.5,
    'rock': 0.5,
    'steel': 0.5,
  },
  'psychic': {
    'fighting': 2,
    'poison': 2,
    'psychic': 0.5,
    'steel': 0.5,
    'dark': 0,
  },
  'bug': {
    'grass': 2,
    'psychic': 2,
    'dark': 2,
    'fire': 0.5,
    'fighting': 0.5,
    'poison': 0.5,
    'flying': 0.5,
    'ghost': 0.5,
    'steel': 0.5,
    'fairy': 0.5,
  },
  'rock': {
    'fire': 2,
    'ice': 2,
    'flying': 2,
    'bug': 2,
    'fighting': 0.5,
    'ground': 0.5,
    'steel': 0.5,
  },
  'ghost': {'psychic': 2, 'ghost': 2, 'dark': 0.5, 'normal': 0},
  'dragon': {'dragon': 2, 'steel': 0.5, 'fairy': 0},
  'dark': {
    'psychic': 2,
    'ghost': 2,
    'fighting': 0.5,
    'dark': 0.5,
    'fairy': 0.5,
  },
  'steel': {
    'ice': 2,
    'rock': 2,
    'fairy': 2,
    'fire': 0.5,
    'water': 0.5,
    'electric': 0.5,
    'steel': 0.5,
  },
  'fairy': {
    'fighting': 2,
    'dragon': 2,
    'dark': 2,
    'fire': 0.5,
    'poison': 0.5,
    'steel': 0.5,
  },
};

class TypeChart {
  const TypeChart._();

  /// Multiplier of a single [attacker] type against one [defender] type.
  static double single(String attacker, String defender) =>
      _chart[attacker]?[defender] ?? 1.0;

  /// Multiplier of an [attacker] type against a (possibly dual-typed)
  /// defender. Multipliers multiply, so the result can be 0, 0.25, 0.5, 1, 2
  /// or 4.
  static double against(String attacker, List<String> defenderTypes) {
    var result = 1.0;
    for (final d in defenderTypes) {
      result *= single(attacker, d);
    }
    return result;
  }

  /// Defensive multiplier from every attacking type against a Pokémon with
  /// [types].
  static Map<String, double> defensiveProfile(List<String> types) => {
    for (final attacker in kTypes) attacker: against(attacker, types),
  };

  /// Defending types that [attacker] hits for more than normal damage.
  static List<String> superEffectiveTargets(String attacker) => [
    for (final d in kTypes)
      if (single(attacker, d) > 1) d,
  ];

  /// Attacking types that hit a defender of type [defender] super effectively.
  static List<String> attackersSuperEffectiveAgainst(String defender) => [
    for (final a in kTypes)
      if (single(a, defender) > 1) a,
  ];
}

String formatMultiplier(double m) {
  if (m == 0) {
    return '×0';
  }
  if (m == 0.25) {
    return '×¼';
  }
  if (m == 0.5) {
    return '×½';
  }
  if (m == m.roundToDouble()) {
    return '×${m.toInt()}';
  }
  return '×$m';
}
