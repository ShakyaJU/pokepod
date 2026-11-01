import '../data/models/pokemon.dart';
import 'generations.dart';

/// Groups used to organise the sort options.
enum SortGroup { identity, classification, measurements, baseStats }

extension SortGroupX on SortGroup {
  String get label => switch (this) {
    SortGroup.identity => 'Identity',
    SortGroup.classification => 'Classification',
    SortGroup.measurements => 'Measurements',
    SortGroup.baseStats => 'Base stats',
  };
}

/// The property the Pokédex is ordered by. Direction is a separate choice.
enum SortKey {
  number,
  name,
  generation,
  type,
  special,
  favourite,
  height,
  weight,
  total,
  hp,
  attack,
  defense,
  specialAttack,
  specialDefense,
  speed,
}

extension SortKeyX on SortKey {
  String get label => switch (this) {
    SortKey.number => 'Pokédex number',
    SortKey.name => 'Name',
    SortKey.generation => 'Generation',
    SortKey.type => 'Type',
    SortKey.special => 'Legendary & Mythical',
    SortKey.favourite => 'Favourites',
    SortKey.height => 'Height',
    SortKey.weight => 'Weight',
    SortKey.total => 'Base stat total',
    SortKey.hp => 'HP',
    SortKey.attack => 'Attack',
    SortKey.defense => 'Defense',
    SortKey.specialAttack => 'Sp. Atk',
    SortKey.specialDefense => 'Sp. Def',
    SortKey.speed => 'Speed',
  };

  SortGroup get group => switch (this) {
    SortKey.number || SortKey.name => SortGroup.identity,
    SortKey.generation ||
    SortKey.type ||
    SortKey.special ||
    SortKey.favourite => SortGroup.classification,
    SortKey.height || SortKey.weight => SortGroup.measurements,
    _ => SortGroup.baseStats,
  };

  /// What the "ascending" direction means for this property.
  String get ascendingLabel => switch (this) {
    SortKey.number => 'Lowest first',
    SortKey.name => 'A → Z',
    SortKey.generation => 'Oldest first',
    SortKey.type => 'A → Z',
    SortKey.special => 'Special first',
    SortKey.favourite => 'Favourites first',
    SortKey.height => 'Shortest first',
    SortKey.weight => 'Lightest first',
    _ => 'Lowest first',
  };

  /// What the "descending" direction means for this property.
  String get descendingLabel => switch (this) {
    SortKey.number => 'Highest first',
    SortKey.name => 'Z → A',
    SortKey.generation => 'Newest first',
    SortKey.type => 'Z → A',
    SortKey.special => 'Special last',
    SortKey.favourite => 'Favourites last',
    SortKey.height => 'Tallest first',
    SortKey.weight => 'Heaviest first',
    _ => 'Highest first',
  };

  /// True when the value lives in a Pokémon's details (type, size, stats).
  bool get needsDetails => switch (this) {
    SortKey.type ||
    SortKey.height ||
    SortKey.weight ||
    SortKey.total ||
    SortKey.hp ||
    SortKey.attack ||
    SortKey.defense ||
    SortKey.specialAttack ||
    SortKey.specialDefense ||
    SortKey.speed => true,
    _ => false,
  };

  /// True when the value lives in species data (Legendary/Mythical status).
  bool get needsSpecies => this == SortKey.special;

  /// True when the catalogue alone is not enough and extra data must be saved
  /// on the device before the order is complete.
  bool get needsFacts => needsDetails || needsSpecies;

  /// PokéAPI stat name for the stat keys.
  String? get statName => switch (this) {
    SortKey.hp => 'hp',
    SortKey.attack => 'attack',
    SortKey.defense => 'defense',
    SortKey.specialAttack => 'special-attack',
    SortKey.specialDefense => 'special-defense',
    SortKey.speed => 'speed',
    _ => null,
  };
}

/// Per-Pokémon values a sort may need, beyond the catalogue's name and number.
///
/// Heights are decimetres and weights hectograms, exactly as PokéAPI reports
/// them, so ordering is numeric and never lexicographic. Every field is
/// nullable: `null` means "not known yet".
class SortFacts {
  const SortFacts({
    this.heightDm,
    this.weightHg,
    this.stats = const {},
    this.types,
    this.special,
  });

  final int? heightDm;
  final int? weightHg;
  final Map<String, int> stats;
  final List<String>? types;

  /// True for Legendary or Mythical species, null while species data is unknown.
  final bool? special;

  /// Whether details (size, stats, types) are known.
  bool get hasDetails => heightDm != null;

  int? get statTotal {
    if (stats.isEmpty) {
      return null;
    }
    final sum = stats.values.fold<int>(0, (a, b) => a + b);
    return sum > 0 ? sum : null;
  }

  SortFacts merge(SortFacts other) => SortFacts(
    heightDm: other.heightDm ?? heightDm,
    weightHg: other.weightHg ?? weightHg,
    stats: other.stats.isNotEmpty ? other.stats : stats,
    types: other.types ?? types,
    special: other.special ?? special,
  );

  /// Whether the value needed by [key] is known.
  bool hasValueFor(SortKey key) {
    if (key.needsSpecies) {
      return special != null;
    }
    if (key.needsDetails) {
      return hasDetails;
    }
    return true;
  }

  int? numericFor(SortKey key) => switch (key) {
    SortKey.height => heightDm,
    SortKey.weight => weightHg,
    SortKey.total => statTotal,
    _ => key.statName == null ? null : stats[key.statName],
  };
}

class PokedexFilter {
  const PokedexFilter({
    this.query = '',
    this.type,
    this.generation,
    this.sortKey = SortKey.number,
    this.ascending = true,
    this.favouritesOnly = false,
  });

  final String query;
  final String? type;
  final int? generation;
  final SortKey sortKey;
  final bool ascending;
  final bool favouritesOnly;

  /// True when a search or filter narrows the list. Sorting is separate.
  bool get isActive =>
      query.trim().isNotEmpty ||
      type != null ||
      generation != null ||
      favouritesOnly;

  bool get isDefaultSort => sortKey == SortKey.number && ascending;

  /// Human-readable current order, e.g. "Height · Tallest first".
  String get sortSummary =>
      '${sortKey.label} · ${ascending ? sortKey.ascendingLabel : sortKey.descendingLabel}';

  PokedexFilter copyWith({
    String? query,
    Object? type = _unset,
    Object? generation = _unset,
    SortKey? sortKey,
    bool? ascending,
    bool? favouritesOnly,
  }) {
    return PokedexFilter(
      query: query ?? this.query,
      type: identical(type, _unset) ? this.type : type as String?,
      generation: identical(generation, _unset)
          ? this.generation
          : generation as int?,
      sortKey: sortKey ?? this.sortKey,
      ascending: ascending ?? this.ascending,
      favouritesOnly: favouritesOnly ?? this.favouritesOnly,
    );
  }
}

const Object _unset = Object();

/// Name or number match. Digits (optionally prefixed with `#`) match the start
/// of the dex number; anything else matches inside the name.
bool matchesQuery(PokemonSummary p, String rawQuery) {
  var q = rawQuery.trim().toLowerCase();
  if (q.isEmpty) {
    return true;
  }
  if (q.startsWith('#')) {
    q = q.substring(1);
  }
  if (q.isEmpty) {
    return true;
  }
  if (RegExp(r'^\d+$').hasMatch(q)) {
    final digits = q.replaceFirst(RegExp(r'^0+'), '');
    if (digits.isEmpty) {
      return false;
    }
    return p.id.toString().startsWith(digits);
  }
  return p.name
      .toLowerCase()
      .replaceAll('-', ' ')
      .contains(q.replaceAll('-', ' '));
}

/// Applies the combined filters and then the chosen sort.
///
/// [typeMembers] must be supplied when [PokedexFilter.type] is set (null is
/// treated as "not loaded yet" and yields no results for that filter).
/// [facts] supplies the values needed by sorts that depend on details or
/// species data; Pokémon without a known value are always listed last,
/// whichever direction is chosen, and ties fall back to the Pokédex number.
List<PokemonSummary> applyPokedexFilter(
  List<PokemonSummary> all,
  PokedexFilter filter, {
  Set<int>? typeMembers,
  Set<int> favourites = const {},
  Map<int, SortFacts>? facts,
}) {
  final out = <PokemonSummary>[];
  final seen = <int>{};
  for (final p in all) {
    if (!seen.add(p.id)) {
      continue;
    }
    if (filter.generation != null && !inGeneration(p.id, filter.generation!)) {
      continue;
    }
    if (filter.type != null && !(typeMembers?.contains(p.id) ?? false)) {
      continue;
    }
    if (filter.favouritesOnly && !favourites.contains(p.id)) {
      continue;
    }
    if (!matchesQuery(p, filter.query)) {
      continue;
    }
    out.add(p);
  }
  out.sort(_comparatorFor(filter, favourites, facts));
  return out;
}

int Function(PokemonSummary, PokemonSummary) _comparatorFor(
  PokedexFilter filter,
  Set<int> favourites,
  Map<int, SortFacts>? facts,
) {
  final dir = filter.ascending ? 1 : -1;
  final key = filter.sortKey;

  int byId(PokemonSummary a, PokemonSummary b) => a.id.compareTo(b.id);

  // Compares two possibly-unknown values: unknown always last, ties by number.
  int known<T extends Comparable<dynamic>>(
    PokemonSummary a,
    PokemonSummary b,
    T? x,
    T? y,
  ) {
    if (x == null && y == null) {
      return byId(a, b);
    }
    if (x == null) {
      return 1;
    }
    if (y == null) {
      return -1;
    }
    final c = dir * x.compareTo(y);
    return c != 0 ? c : byId(a, b);
  }

  switch (key) {
    case SortKey.number:
      return (a, b) => dir * a.id.compareTo(b.id);
    case SortKey.name:
      return (a, b) {
        final c = dir * a.name.compareTo(b.name);
        return c != 0 ? c : byId(a, b);
      };
    case SortKey.generation:
      return (a, b) {
        final c =
            dir * (generationOf(a.id) ?? 0).compareTo(generationOf(b.id) ?? 0);
        return c != 0 ? c : byId(a, b);
      };
    case SortKey.favourite:
      return (a, b) {
        final c =
            dir *
            (favourites.contains(a.id) ? 0 : 1).compareTo(
              favourites.contains(b.id) ? 0 : 1,
            );
        return c != 0 ? c : byId(a, b);
      };
    case SortKey.special:
      return (a, b) {
        final sa = facts?[a.id]?.special;
        final sb = facts?[b.id]?.special;
        return known<int>(
          a,
          b,
          sa == null ? null : (sa ? 0 : 1),
          sb == null ? null : (sb ? 0 : 1),
        );
      };
    case SortKey.type:
      return (a, b) {
        String? typeKey(int id) {
          final t = facts?[id]?.types;
          if (t == null || t.isEmpty) {
            return null;
          }
          return '${t[0]}|${t.length > 1 ? t[1] : ''}';
        }

        return known<String>(a, b, typeKey(a.id), typeKey(b.id));
      };
    case SortKey.height:
    case SortKey.weight:
    case SortKey.total:
    case SortKey.hp:
    case SortKey.attack:
    case SortKey.defense:
    case SortKey.specialAttack:
    case SortKey.specialDefense:
    case SortKey.speed:
      return (a, b) => known<int>(
        a,
        b,
        facts?[a.id]?.numericFor(key),
        facts?[b.id]?.numericFor(key),
      );
  }
}

/// Next window size for incremental loading; never exceeds [total].
int nextVisibleCount(int current, int total, {int pageSize = 30}) {
  if (current >= total) {
    return total;
  }
  final next = current + pageSize;
  return next > total ? total : next;
}
