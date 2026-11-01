import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokepod/data/models/pokemon.dart';
import 'package:pokepod/data/providers.dart';
import 'package:pokepod/domain/pokedex_filter.dart';
import 'package:pokepod/features/pokedex/measurements.dart';
import 'package:pokepod/features/pokedex/pokedex_controller.dart';

import 'support/support.dart';

SortFacts f({
  int? h,
  int? w,
  Map<String, int> stats = const {},
  List<String>? types,
  bool? special,
}) => SortFacts(
  heightDm: h,
  weightHg: w,
  stats: stats,
  types: types,
  special: special,
);

List<int> order(
  List<PokemonSummary> all,
  SortKey key, {
  bool ascending = true,
  Map<int, SortFacts>? facts,
  Set<int> favourites = const {},
  PokedexFilter? base,
}) {
  final filter = (base ?? const PokedexFilter()).copyWith(
    sortKey: key,
    ascending: ascending,
  );
  return [
    for (final p in applyPokedexFilter(
      all,
      filter,
      facts: facts,
      favourites: favourites,
    ))
      p.id,
  ];
}

void main() {
  const five = [
    PokemonSummary(id: 1, name: 'a'),
    PokemonSummary(id: 2, name: 'b'),
    PokemonSummary(id: 3, name: 'c'),
    PokemonSummary(id: 4, name: 'd'),
    PokemonSummary(id: 5, name: 'e'),
  ];

  group('numeric sorts', () {
    // Heights in decimetres: 100 > 20 > 9. Compared as text, "9" would sort after
    // "100", which is exactly what numeric sorting must avoid.
    final sizes = {
      1: f(h: 100, w: 5),
      2: f(h: 9, w: 900),
      3: f(h: 20, w: 90),
      4: f(h: 20, w: 90),
    };

    test(
      'height: shortest and tallest first, unknown last, ties by number',
      () {
        expect(order(five, SortKey.height, facts: sizes), [2, 3, 4, 1, 5]);
        expect(order(five, SortKey.height, ascending: false, facts: sizes), [
          1,
          3,
          4,
          2,
          5,
        ]);
      },
    );

    test('weight: lightest and heaviest first', () {
      expect(order(five, SortKey.weight, facts: sizes), [1, 3, 4, 2, 5]);
      expect(order(five, SortKey.weight, ascending: false, facts: sizes), [
        2,
        3,
        4,
        1,
        5,
      ]);
    });

    test('base stat total, treating zero or missing stats as unknown', () {
      final facts = {
        1: f(h: 1, stats: {'hp': 100, 'attack': 200}),
        2: f(h: 1),
        3: f(h: 1, stats: {'hp': 500}),
        4: f(h: 1, stats: {'hp': 500}),
        5: f(h: 1, stats: {'hp': 0}),
      };
      expect(order(five, SortKey.total, facts: facts), [1, 3, 4, 2, 5]);
      expect(order(five, SortKey.total, ascending: false, facts: facts), [
        3,
        4,
        1,
        2,
        5,
      ]);
    });

    test('an individual stat uses that stat only', () {
      final facts = {
        1: f(h: 1, stats: {'speed': 30}),
        2: f(h: 1, stats: {'speed': 90}),
        3: f(h: 1, stats: {'speed': 60}),
        4: f(h: 1, stats: {'hp': 1}),
      };
      expect(order(five, SortKey.speed, facts: facts), [1, 3, 2, 4, 5]);
      expect(order(five, SortKey.speed, ascending: false, facts: facts), [
        2,
        3,
        1,
        4,
        5,
      ]);
    });

    test('with no facts every Pokémon is unknown and falls back to number', () {
      expect(order(five, SortKey.height), [1, 2, 3, 4, 5]);
      expect(order(five, SortKey.weight, ascending: false, facts: const {}), [
        1,
        2,
        3,
        4,
        5,
      ]);
    });
  });

  group('classification sorts', () {
    test('type orders by primary then secondary type, alphabetically', () {
      final facts = {
        1: f(h: 1, types: ['water']),
        2: f(h: 1, types: ['fire', 'flying']),
        3: f(h: 1, types: ['fire']),
        4: f(h: 1, types: ['bug', 'poison']),
      };
      expect(order(five, SortKey.type, facts: facts), [4, 3, 2, 1, 5]);
      expect(order(five, SortKey.type, ascending: false, facts: facts), [
        1,
        2,
        3,
        4,
        5,
      ]);
    });

    test(
      'Legendary and Mythical status: special first or last, unknown always last',
      () {
        final facts = {
          1: f(special: true),
          2: f(special: false),
          3: f(special: true),
          5: f(special: false),
        };
        expect(order(five, SortKey.special, facts: facts), [1, 3, 2, 5, 4]);
        expect(order(five, SortKey.special, ascending: false, facts: facts), [
          2,
          5,
          1,
          3,
          4,
        ]);
      },
    );

    test('generation: oldest or newest first, number within a generation', () {
      const spread = [
        PokemonSummary(id: 252, name: 'g3'),
        PokemonSummary(id: 25, name: 'g1b'),
        PokemonSummary(id: 160, name: 'g2b'),
        PokemonSummary(id: 1, name: 'g1a'),
        PokemonSummary(id: 152, name: 'g2a'),
      ];
      expect(order(spread, SortKey.generation), [1, 25, 152, 160, 252]);
      expect(order(spread, SortKey.generation, ascending: false), [
        252,
        152,
        160,
        1,
        25,
      ]);
    });

    test('favourites first or last using the favourite set', () {
      expect(order(five, SortKey.favourite, favourites: {2, 4}), [
        2,
        4,
        1,
        3,
        5,
      ]);
      expect(
        order(five, SortKey.favourite, ascending: false, favourites: {2, 4}),
        [1, 3, 5, 2, 4],
      );
    });

    test('number and name reverse completely', () {
      expect(order(five, SortKey.number, ascending: false), [5, 4, 3, 2, 1]);
      expect(order(five, SortKey.name, ascending: false), [5, 4, 3, 2, 1]);
    });
  });

  group('sorting together with filters', () {
    test(
      'a sort never changes which Pokémon match and never duplicates them',
      () {
        const withDuplicate = [...five, PokemonSummary(id: 3, name: 'c')];
        final facts = {for (var i = 1; i <= 5; i++) i: f(h: i * 10)};
        final base = const PokedexFilter(favouritesOnly: true, query: '');
        final result = order(
          withDuplicate,
          SortKey.height,
          ascending: false,
          facts: facts,
          favourites: {1, 3, 5},
          base: base,
        );
        expect(result, [5, 3, 1]);
      },
    );

    test('search and generation filters combine with a measurement sort', () {
      const mixed = [
        PokemonSummary(id: 1, name: 'alpha'),
        PokemonSummary(id: 2, name: 'alpine'),
        PokemonSummary(id: 152, name: 'alpaca'),
        PokemonSummary(id: 3, name: 'beta'),
      ];
      final facts = {1: f(h: 5), 2: f(h: 50), 152: f(h: 500), 3: f(h: 1)};
      final result = order(
        mixed,
        SortKey.height,
        ascending: false,
        facts: facts,
        base: const PokedexFilter(query: 'alp', generation: 1),
      );
      expect(result, [2, 1]);
    });
  });

  group('sort model', () {
    test('every key has a label, a group and distinct direction wording', () {
      for (final key in SortKey.values) {
        expect(key.label, isNotEmpty);
        expect(
          key.ascendingLabel,
          isNot(key.descendingLabel),
          reason: key.name,
        );
        expect(SortGroup.values, contains(key.group));
      }
      expect(
        SortKey.values.map((k) => k.label).toSet(),
        hasLength(SortKey.values.length),
      );
    });

    test('keys are grouped logically', () {
      List<SortKey> inGroup(SortGroup g) => [
        for (final k in SortKey.values)
          if (k.group == g) k,
      ];
      expect(inGroup(SortGroup.identity), [SortKey.number, SortKey.name]);
      expect(inGroup(SortGroup.classification), [
        SortKey.generation,
        SortKey.type,
        SortKey.special,
        SortKey.favourite,
      ]);
      expect(inGroup(SortGroup.measurements), [SortKey.height, SortKey.weight]);
      expect(inGroup(SortGroup.baseStats).first, SortKey.total);
    });

    test('which keys need saved data', () {
      expect(SortKey.number.needsFacts, isFalse);
      expect(SortKey.generation.needsFacts, isFalse);
      expect(SortKey.favourite.needsFacts, isFalse);
      expect(SortKey.height.needsDetails, isTrue);
      expect(SortKey.special.needsSpecies, isTrue);
      expect(SortKey.speed.statName, 'speed');
    });

    test('filter summary, default sort and independence from filtering', () {
      const tall = PokedexFilter(sortKey: SortKey.height, ascending: false);
      expect(tall.sortSummary, 'Height · Tallest first');
      expect(tall.isDefaultSort, isFalse);
      expect(tall.isActive, isFalse);
      expect(const PokedexFilter().isDefaultSort, isTrue);
      expect(
        const PokedexFilter().sortSummary,
        'Pokédex number · Lowest first',
      );
    });

    test('SortFacts merge keeps what is known and derives the total', () {
      final merged = f(
        h: 7,
        stats: {'hp': 10, 'speed': 5},
      ).merge(f(special: true));
      expect(merged.heightDm, 7);
      expect(merged.special, isTrue);
      expect(merged.statTotal, 15);
      expect(const SortFacts().statTotal, isNull);
      expect(merged.hasValueFor(SortKey.special), isTrue);
      expect(const SortFacts().hasValueFor(SortKey.height), isFalse);
      expect(const SortFacts().hasValueFor(SortKey.number), isTrue);
    });
  });

  group('sort state', () {
    test(
      'changing or resetting the sort keeps filters and restarts the window',
      () async {
        final prefs = await mockPrefs();
        final container = makeContainer(prefs);
        final notifier = container.read(pokedexProvider.notifier);
        notifier.setQuery('pika');
        notifier.setType('electric');
        notifier.loadMore(200, renderedCount: kPokedexPageSize);

        notifier.setSortKey(SortKey.weight);
        notifier.setAscending(false);
        var ui = container.read(pokedexProvider);
        expect(ui.filter.query, 'pika');
        expect(ui.filter.type, 'electric');
        expect(ui.filter.sortKey, SortKey.weight);
        expect(ui.filter.ascending, isFalse);
        expect(ui.visibleCount, kPokedexPageSize);

        notifier.clearFilters();
        ui = container.read(pokedexProvider);
        expect(ui.filter.isActive, isFalse);
        expect(
          ui.filter.sortKey,
          SortKey.weight,
          reason: 'clearing filters keeps the sort',
        );

        notifier.resetSort();
        ui = container.read(pokedexProvider);
        expect(ui.filter.isDefaultSort, isTrue);
      },
    );
  });

  group('MeasurementsNotifier', () {
    test('reads saved details and species without any request', () async {
      final saved = makeDetail(
        25,
        'pikachu',
        ['electric'],
        hp: 35,
        atk: 55,
        def: 40,
        spa: 50,
        spd: 50,
        spe: 90,
      );
      final species = PokemonSpecies(id: 25, isMythical: true);
      final prefs = await mockPrefs({
        'cache.v1.pokemon.25': jsonEncode(saved.toJson()),
        'cache.v1.species.25': jsonEncode(species.toJson()),
        'cache.v1.species.30': jsonEncode(
          const PokemonSpecies(id: 30).toJson(),
        ),
      });
      final client = FakeApiClient({});
      final container = makeContainer(
        prefs,
        overrides: [apiClientProvider.overrideWithValue(client)],
      );

      final data = container.read(measurementsProvider).data;
      expect(data.keys.toSet(), {25, 30});
      expect(data[25]!.heightDm, 10);
      expect(data[25]!.types, ['electric']);
      expect(data[25]!.numericFor(SortKey.speed), 90);
      expect(data[25]!.special, isTrue);
      expect(data[30]!.special, isFalse);
      expect(data[30]!.hasDetails, isFalse);
      expect(client.requests, isEmpty);
    });

    test('loads only the missing details for a details-based sort', () async {
      final saved = makeDetail(25, 'pikachu', ['electric']);
      final prefs = await mockPrefs({
        'cache.v1.pokemon.25': jsonEncode(saved.toJson()),
      });
      final client = FakeApiClient({
        '$apiBase/pokemon/26': pokemonJson(id: 26, name: 'raichu'),
      });
      final container = makeContainer(
        prefs,
        overrides: [apiClientProvider.overrideWithValue(client)],
      );

      await container.read(measurementsProvider.notifier).loadMissing([
        25,
        26,
      ], SortKey.height);
      final done = container.read(measurementsProvider);
      expect(done.data.keys.toSet(), {25, 26});
      expect(done.loading, isFalse);
      expect(done.failed, 0);
      expect(client.requests, ['$apiBase/pokemon/26']);
    });

    test('loads species for Legendary & Mythical sorting', () async {
      final prefs = await mockPrefs();
      final client = FakeApiClient({
        '$apiBase/pokemon-species/150': {'id': 150, 'is_legendary': true},
        '$apiBase/pokemon-species/25': {'id': 25},
      });
      final container = makeContainer(
        prefs,
        overrides: [apiClientProvider.overrideWithValue(client)],
      );

      await container.read(measurementsProvider.notifier).loadMissing([
        150,
        25,
      ], SortKey.special);
      final data = container.read(measurementsProvider).data;
      expect(data[150]!.special, isTrue);
      expect(data[25]!.special, isFalse);
      expect(
        client.requests.every((r) => r.contains('pokemon-species')),
        isTrue,
      );
    });

    test('failed loads are counted and do not stop the others', () async {
      final prefs = await mockPrefs();
      final client = FakeApiClient({
        '$apiBase/pokemon/26': pokemonJson(id: 26, name: 'raichu'),
      });
      final container = makeContainer(
        prefs,
        overrides: [apiClientProvider.overrideWithValue(client)],
      );
      await container.read(measurementsProvider.notifier).loadMissing([
        26,
        27,
      ], SortKey.weight);
      final s = container.read(measurementsProvider);
      expect(s.data.keys, [26]);
      expect(s.failed, 1);
      expect(s.loadingDone, 2);
    });

    test('sorts that need nothing extra never trigger loading', () async {
      final prefs = await mockPrefs();
      final client = FakeApiClient({});
      final container = makeContainer(
        prefs,
        overrides: [apiClientProvider.overrideWithValue(client)],
      );
      await container.read(measurementsProvider.notifier).loadMissing([
        1,
        2,
        3,
      ], SortKey.number);
      expect(client.requests, isEmpty);
    });
  });
}
