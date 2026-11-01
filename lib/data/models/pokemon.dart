import '../../core/errors/app_exception.dart';
import '../../core/utils/formatters.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
List<dynamic> _list(Object? v) => v is List<dynamic> ? v : const <dynamic>[];
int? _int(Object? v) => v is num ? v.toInt() : null;
String? _str(Object? v) => v is String ? v : null;
bool _bool(Object? v) => v is bool && v;

AppException _parseError(String what) =>
    AppException(AppErrorKind.parse, 'Malformed $what from PokéAPI.');

/// Canonical order of the six base stats.
const List<String> kStatOrder = [
  'hp',
  'attack',
  'defense',
  'special-attack',
  'special-defense',
  'speed',
];

String statLabel(String stat) {
  switch (stat) {
    case 'hp':
      return 'HP';
    case 'attack':
      return 'Attack';
    case 'defense':
      return 'Defense';
    case 'special-attack':
      return 'Sp. Atk';
    case 'special-defense':
      return 'Sp. Def';
    case 'speed':
      return 'Speed';
  }
  return titleCase(stat);
}

/// Entry in the catalogue (name + id only; details are fetched lazily).
class PokemonSummary {
  const PokemonSummary({required this.id, required this.name});

  final int id;
  final String name;

  String get displayName => titleCase(name);

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  static PokemonSummary? tryFromJson(Object? raw) {
    final m = _map(raw);
    if (m == null) {
      return null;
    }
    final id = _int(m['id']);
    final name = _str(m['name']);
    if (id == null || name == null || name.isEmpty) {
      return null;
    }
    return PokemonSummary(id: id, name: name);
  }

  /// Parses an item of PokéAPI's `/pokemon?limit=` list.
  static PokemonSummary? tryFromListItem(Object? raw) {
    final m = _map(raw);
    if (m == null) {
      return null;
    }
    final name = _str(m['name']);
    final id = idFromUrl(_str(m['url']));
    if (name == null || name.isEmpty || id == null) {
      return null;
    }
    return PokemonSummary(id: id, name: name);
  }

  @override
  bool operator ==(Object other) =>
      other is PokemonSummary && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

class PokemonStat {
  const PokemonStat(this.name, this.value);
  final String name;
  final int value;
}

class PokemonAbility {
  const PokemonAbility(this.name, {this.hidden = false});
  final String name;
  final bool hidden;

  String get displayName => titleCase(name);
}

class PokemonDetail {
  const PokemonDetail({
    required this.id,
    required this.name,
    required this.heightDm,
    required this.weightHg,
    required this.types,
    required this.stats,
    required this.abilities,
    required this.moves,
    required this.moveCount,
    this.baseExperience,
  });

  final int id;
  final String name;

  /// Height in decimetres and weight in hectograms, exactly as PokéAPI reports.
  final int heightDm;
  final int weightHg;
  final List<String> types;
  final List<PokemonStat> stats;
  final List<PokemonAbility> abilities;

  /// A sample of learnable moves (not the full list).
  final List<String> moves;
  final int moveCount;
  final int? baseExperience;

  String get displayName => titleCase(name);
  double get heightM => heightDm / 10;
  double get weightKg => weightHg / 10;
  int get statTotal => stats.fold(0, (sum, s) => sum + s.value);

  int stat(String name) {
    for (final s in stats) {
      if (s.name == name) {
        return s.value;
      }
    }
    return 0;
  }

  /// The stat with the highest value (ties resolved by canonical order).
  PokemonStat? get topStat {
    PokemonStat? best;
    for (final key in kStatOrder) {
      final value = stat(key);
      if (best == null || value > best.value) {
        best = PokemonStat(key, value);
      }
    }
    return stats.isEmpty ? null : best;
  }

  factory PokemonDetail.fromApiJson(Map<String, dynamic> json) {
    final id = _int(json['id']);
    final name = _str(json['name']);
    if (id == null || name == null || name.isEmpty) {
      throw _parseError('Pokémon');
    }

    final typeEntries = <MapEntry<int, String>>[];
    for (final raw in _list(json['types'])) {
      final m = _map(raw);
      final typeName = _str(_map(m?['type'])?['name']);
      if (typeName == null) {
        continue;
      }
      typeEntries.add(MapEntry(_int(m?['slot']) ?? 99, typeName));
    }
    typeEntries.sort((a, b) => a.key.compareTo(b.key));

    final statMap = <String, int>{};
    for (final raw in _list(json['stats'])) {
      final m = _map(raw);
      final statName = _str(_map(m?['stat'])?['name']);
      if (statName == null) {
        continue;
      }
      statMap[statName] = _int(m?['base_stat']) ?? 0;
    }
    final stats = [
      for (final key in kStatOrder)
        if (statMap.containsKey(key)) PokemonStat(key, statMap[key]!),
    ];

    final abilities = <PokemonAbility>[];
    for (final raw in _list(json['abilities'])) {
      final m = _map(raw);
      final abilityName = _str(_map(m?['ability'])?['name']);
      if (abilityName == null) {
        continue;
      }
      abilities.add(
        PokemonAbility(abilityName, hidden: _bool(m?['is_hidden'])),
      );
    }

    final moveNames = <String>{};
    for (final raw in _list(json['moves'])) {
      final n = _str(_map(_map(raw)?['move'])?['name']);
      if (n != null) {
        moveNames.add(n);
      }
    }
    final sortedMoves = moveNames.toList()..sort();

    return PokemonDetail(
      id: id,
      name: name,
      heightDm: _int(json['height']) ?? 0,
      weightHg: _int(json['weight']) ?? 0,
      types: [for (final e in typeEntries) e.value],
      stats: stats,
      abilities: abilities,
      moves: sortedMoves.take(12).toList(),
      moveCount: sortedMoves.length,
      baseExperience: _int(json['base_experience']),
    );
  }

  /// Compact cache format.
  factory PokemonDetail.fromJson(Map<String, dynamic> json) {
    final id = _int(json['id']);
    final name = _str(json['name']);
    if (id == null || name == null) {
      throw _parseError('cached Pokémon');
    }
    return PokemonDetail(
      id: id,
      name: name,
      heightDm: _int(json['h']) ?? 0,
      weightHg: _int(json['w']) ?? 0,
      types: [
        for (final t in _list(json['types']))
          if (t is String) t,
      ],
      stats: [
        for (final s in _list(json['stats']))
          if (_map(s) != null && _str(_map(s)!['n']) != null)
            PokemonStat(_str(_map(s)!['n'])!, _int(_map(s)!['v']) ?? 0),
      ],
      abilities: [
        for (final a in _list(json['abilities']))
          if (_map(a) != null && _str(_map(a)!['n']) != null)
            PokemonAbility(_str(_map(a)!['n'])!, hidden: _bool(_map(a)!['h'])),
      ],
      moves: [
        for (final m in _list(json['moves']))
          if (m is String) m,
      ],
      moveCount: _int(json['mc']) ?? 0,
      baseExperience: _int(json['xp']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'h': heightDm,
    'w': weightHg,
    'types': types,
    'stats': [
      for (final s in stats) {'n': s.name, 'v': s.value},
    ],
    'abilities': [
      for (final a in abilities) {'n': a.name, 'h': a.hidden},
    ],
    'moves': moves,
    'mc': moveCount,
    'xp': baseExperience,
  };
}

class PokemonSpecies {
  const PokemonSpecies({
    required this.id,
    this.genus,
    this.flavorText,
    this.generationId,
    this.isLegendary = false,
    this.isMythical = false,
    this.isBaby = false,
    this.evolutionChainId,
    this.evolvesFrom,
    this.color,
    this.habitat,
  });

  final int id;
  final String? genus;
  final String? flavorText;
  final int? generationId;
  final bool isLegendary;
  final bool isMythical;
  final bool isBaby;
  final int? evolutionChainId;
  final String? evolvesFrom;
  final String? color;
  final String? habitat;

  factory PokemonSpecies.fromApiJson(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id == null) {
      throw _parseError('species');
    }

    String? genus;
    for (final raw in _list(json['genera'])) {
      final m = _map(raw);
      if (_str(_map(m?['language'])?['name']) == 'en') {
        genus = _str(m?['genus']);
        break;
      }
    }

    // PokéAPI lists entries oldest to newest; prefer the most recent English one.
    String? flavor;
    for (final raw in _list(json['flavor_text_entries'])) {
      final m = _map(raw);
      if (_str(_map(m?['language'])?['name']) == 'en') {
        final text = _str(m?['flavor_text']);
        if (text != null) {
          flavor = cleanFlavorText(text);
        }
      }
    }

    return PokemonSpecies(
      id: id,
      genus: genus,
      flavorText: flavor,
      generationId: idFromUrl(_str(_map(json['generation'])?['url'])),
      isLegendary: _bool(json['is_legendary']),
      isMythical: _bool(json['is_mythical']),
      isBaby: _bool(json['is_baby']),
      evolutionChainId: idFromUrl(_str(_map(json['evolution_chain'])?['url'])),
      evolvesFrom: _str(_map(json['evolves_from_species'])?['name']),
      color: _str(_map(json['color'])?['name']),
      habitat: _str(_map(json['habitat'])?['name']),
    );
  }

  factory PokemonSpecies.fromJson(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id == null) {
      throw _parseError('cached species');
    }
    return PokemonSpecies(
      id: id,
      genus: _str(json['genus']),
      flavorText: _str(json['flavor']),
      generationId: _int(json['gen']),
      isLegendary: _bool(json['legendary']),
      isMythical: _bool(json['mythical']),
      isBaby: _bool(json['baby']),
      evolutionChainId: _int(json['chain']),
      evolvesFrom: _str(json['from']),
      color: _str(json['color']),
      habitat: _str(json['habitat']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'genus': genus,
    'flavor': flavorText,
    'gen': generationId,
    'legendary': isLegendary,
    'mythical': isMythical,
    'baby': isBaby,
    'chain': evolutionChainId,
    'from': evolvesFrom,
    'color': color,
    'habitat': habitat,
  };
}

/// Collapses the line breaks and form feeds PokéAPI leaves in flavour text.
String cleanFlavorText(String raw) => raw
    .replaceAll(RegExp(r'[\n\f\r\u00ad]+'), ' ')
    .replaceAll(RegExp(r' {2,}'), ' ')
    .trim();

class EvoNode {
  const EvoNode({required this.id, required this.name, this.links = const []});

  final int id;
  final String name;
  final List<EvoLink> links;

  String get displayName => titleCase(name);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'links': [
      for (final l in links) {'c': l.condition, 'n': l.node.toJson()},
    ],
  };

  static EvoNode fromJson(Map<String, dynamic> json, [int depth = 0]) {
    final id = _int(json['id']);
    final name = _str(json['name']);
    if (id == null || name == null || depth > 12) {
      throw _parseError('cached evolution chain');
    }
    final links = <EvoLink>[];
    for (final raw in _list(json['links'])) {
      final m = _map(raw);
      final child = _map(m?['n']);
      if (child == null) {
        continue;
      }
      links.add(EvoLink(_str(m?['c']) ?? '', fromJson(child, depth + 1)));
    }
    return EvoNode(id: id, name: name, links: links);
  }
}

class EvoLink {
  const EvoLink(this.condition, this.node);

  /// Human-readable trigger, or an empty string when PokéAPI gives none.
  final String condition;
  final EvoNode node;
}

class EvolutionChain {
  const EvolutionChain({required this.id, required this.root});

  /// A family consisting of a single, non-evolving species.
  factory EvolutionChain.single(int id, String name) => EvolutionChain(
    id: 0,
    root: EvoNode(id: id, name: name),
  );

  final int id;
  final EvoNode root;

  bool get isSingle => root.links.isEmpty;

  List<EvoNode> get allNodes {
    final out = <EvoNode>[];
    void walk(EvoNode n) {
      out.add(n);
      for (final l in n.links) {
        walk(l.node);
      }
    }

    walk(root);
    return out;
  }

  Set<int> get memberIds => {for (final n in allNodes) n.id};

  factory EvolutionChain.fromApiJson(Map<String, dynamic> json) {
    final chain = _map(json['chain']);
    if (chain == null) {
      throw _parseError('evolution chain');
    }
    return EvolutionChain(id: _int(json['id']) ?? 0, root: _parseNode(chain));
  }

  factory EvolutionChain.fromJson(Map<String, dynamic> json) {
    final root = _map(json['root']);
    if (root == null) {
      throw _parseError('cached evolution chain');
    }
    return EvolutionChain(
      id: _int(json['id']) ?? 0,
      root: EvoNode.fromJson(root),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'root': root.toJson()};

  static EvoNode _parseNode(Map<String, dynamic> node, [int depth = 0]) {
    final species = _map(node['species']);
    final name = _str(species?['name']);
    final id = idFromUrl(_str(species?['url']));
    if (name == null || id == null || depth > 12) {
      throw _parseError('evolution chain');
    }
    final links = <EvoLink>[];
    for (final raw in _list(node['evolves_to'])) {
      final child = _map(raw);
      if (child == null) {
        continue;
      }
      links.add(
        EvoLink(
          describeEvolution(_list(child['evolution_details'])),
          _parseNode(child, depth + 1),
        ),
      );
    }
    return EvoNode(id: id, name: name, links: links);
  }
}

/// Builds a readable condition such as "Level 16, at night" from PokéAPI
/// `evolution_details`. Returns an empty string when there is nothing to say.
String describeEvolution(List<dynamic> details) {
  final out = <String>[];
  for (final raw in details) {
    final d = _map(raw);
    if (d == null) {
      continue;
    }
    final trigger = _str(_map(d['trigger'])?['name']);
    final parts = <String>[];
    final minLevel = _int(d['min_level']);
    final item = _str(_map(d['item'])?['name']);

    switch (trigger) {
      case 'level-up':
        parts.add(minLevel != null ? 'Level $minLevel' : 'Level up');
      case 'trade':
        parts.add('Trade');
      case 'use-item':
        parts.add(item != null ? 'Use ${titleCase(item)}' : 'Use item');
      case 'shed':
        parts.add('Shed');
      case null:
        break;
      default:
        parts.add(titleCase(trigger));
    }

    final heldItem = _str(_map(d['held_item'])?['name']);
    if (heldItem != null) {
      parts.add('holding ${titleCase(heldItem)}');
    }
    final knownMove = _str(_map(d['known_move'])?['name']);
    if (knownMove != null) {
      parts.add('knowing ${titleCase(knownMove)}');
    }
    final knownMoveType = _str(_map(d['known_move_type'])?['name']);
    if (knownMoveType != null) {
      parts.add('knowing a ${titleCase(knownMoveType)}-type move');
    }
    final happiness = _int(d['min_happiness']);
    if (happiness != null) {
      parts.add('happiness ≥ $happiness');
    }
    final affection = _int(d['min_affection']);
    if (affection != null) {
      parts.add('affection ≥ $affection');
    }
    final beauty = _int(d['min_beauty']);
    if (beauty != null) {
      parts.add('beauty ≥ $beauty');
    }
    final time = _str(d['time_of_day']);
    if (time != null && time.isNotEmpty) {
      parts.add('at $time');
    }
    final location = _str(_map(d['location'])?['name']);
    if (location != null) {
      parts.add('at ${titleCase(location)}');
    }
    final gender = _int(d['gender']);
    if (gender == 1) {
      parts.add('female only');
    }
    if (gender == 2) {
      parts.add('male only');
    }
    if (_bool(d['needs_overworld_rain'])) {
      parts.add('while raining');
    }
    if (_bool(d['turn_upside_down'])) {
      parts.add('console upside down');
    }
    final partySpecies = _str(_map(d['party_species'])?['name']);
    if (partySpecies != null) {
      parts.add('with ${titleCase(partySpecies)} in party');
    }
    final partyType = _str(_map(d['party_type'])?['name']);
    if (partyType != null) {
      parts.add('with a ${titleCase(partyType)} type in party');
    }
    final tradeSpecies = _str(_map(d['trade_species'])?['name']);
    if (tradeSpecies != null) {
      parts.add('for ${titleCase(tradeSpecies)}');
    }
    final stats = _int(d['relative_physical_stats']);
    if (stats == 1) {
      parts.add('Attack > Defense');
    }
    if (stats == -1) {
      parts.add('Defense > Attack');
    }
    if (stats == 0) {
      parts.add('Attack = Defense');
    }

    if (parts.isEmpty) {
      continue;
    }
    final text = parts.join(', ');
    if (!out.contains(text)) {
      out.add(text);
    }
  }
  return out.join(' / ');
}
