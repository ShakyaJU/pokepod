import 'package:flutter_test/flutter_test.dart';
import 'package:pokepod/data/models/pokemon.dart';
import 'package:pokepod/domain/generations.dart';
import 'package:pokepod/domain/pokedex_filter.dart';
import 'package:pokepod/features/pokedex/pokedex_controller.dart';

import 'support/support.dart';

void main() {
  const all = [
    PokemonSummary(id: 1, name: 'bulbasaur'),
    PokemonSummary(id: 4, name: 'charmander'),
    PokemonSummary(id: 25, name: 'pikachu'),
    PokemonSummary(id: 122, name: 'mr-mime'),
    PokemonSummary(id: 152, name: 'chikorita'),
    PokemonSummary(id: 250, name: 'ho-oh'),
    PokemonSummary(id: 252, name: 'treecko'),
  ];

  List<int> ids(List<PokemonSummary> l) => [for (final p in l) p.id];

  group('search', () {
    test('matches names case-insensitively and as substrings', () {
      expect(ids(applyPokedexFilter(all, const PokedexFilter(query: 'CHAR'))), [
        4,
      ]);
      expect(ids(applyPokedexFilter(all, const PokedexFilter(query: 'ch'))), [
        4,
        25,
        152,
      ]);
      expect(
        ids(applyPokedexFilter(all, const PokedexFilter(query: 'mr mime'))),
        [122],
      );
      expect(
        ids(applyPokedexFilter(all, const PokedexFilter(query: 'mr-mime'))),
        [122],
      );
    });

    test('matches dex numbers with or without # and leading zeros', () {
      expect(ids(applyPokedexFilter(all, const PokedexFilter(query: '25'))), [
        25,
        250,
        252,
      ]);
      expect(ids(applyPokedexFilter(all, const PokedexFilter(query: '#25'))), [
        25,
        250,
        252,
      ]);
      expect(ids(applyPokedexFilter(all, const PokedexFilter(query: '0025'))), [
        25,
        250,
        252,
      ]);
      expect(
        ids(applyPokedexFilter(all, const PokedexFilter(query: '000'))),
        isEmpty,
      );
    });

    test('blank queries match everything', () {
      expect(
        applyPokedexFilter(all, const PokedexFilter(query: '  ')),
        hasLength(all.length),
      );
      expect(
        applyPokedexFilter(all, const PokedexFilter(query: '#')),
        hasLength(all.length),
      );
    });
  });

  group('filters and sort', () {
    test('generation filter uses the national-dex ranges', () {
      expect(ids(applyPokedexFilter(all, const PokedexFilter(generation: 1))), [
        1,
        4,
        25,
        122,
      ]);
      expect(ids(applyPokedexFilter(all, const PokedexFilter(generation: 2))), [
        152,
        250,
      ]);
      expect(ids(applyPokedexFilter(all, const PokedexFilter(generation: 3))), [
        252,
      ]);
    });

    test('type filter needs loaded members; unloaded yields nothing', () {
      const f = PokedexFilter(type: 'fire');
      expect(applyPokedexFilter(all, f), isEmpty);
      expect(ids(applyPokedexFilter(all, f, typeMembers: {4, 250})), [4, 250]);
    });

    test('filters combine', () {
      const f = PokedexFilter(type: 'fire', generation: 1, query: 'char');
      expect(ids(applyPokedexFilter(all, f, typeMembers: {4, 250})), [4]);
      const fav = PokedexFilter(favouritesOnly: true, generation: 1);
      expect(ids(applyPokedexFilter(all, fav, favourites: {25, 152})), [25]);
    });

    test('sorting', () {
      expect(
        ids(
          applyPokedexFilter(
            all,
            const PokedexFilter(sortKey: SortKey.number, ascending: false),
          ),
        ).first,
        252,
      );
      expect(
        [
          for (final p in applyPokedexFilter(
            all,
            const PokedexFilter(sortKey: SortKey.name),
          ))
            p.name,
        ].first,
        'bulbasaur',
      );
      expect(
        [
          for (final p in applyPokedexFilter(
            all,
            const PokedexFilter(sortKey: SortKey.name, ascending: false),
          ))
            p.name,
        ].first,
        'treecko',
      );
    });

    test('duplicate catalogue entries never produce duplicate results', () {
      final dup = [...all, const PokemonSummary(id: 25, name: 'pikachu')];
      expect(
        applyPokedexFilter(dup, const PokedexFilter()),
        hasLength(all.length),
      );
    });

    test('isActive and copyWith', () {
      expect(const PokedexFilter().isActive, isFalse);
      expect(const PokedexFilter(sortKey: SortKey.name).isActive, isFalse);
      final f = const PokedexFilter().copyWith(type: 'fire', generation: 2);
      expect(f.isActive, isTrue);
      expect(f.copyWith(type: null).type, isNull);
      expect(f.copyWith(query: 'x').type, 'fire');
    });
  });

  group('generations', () {
    test('ranges are contiguous and cover 1..1025', () {
      expect(generationOf(1), 1);
      expect(generationOf(151), 1);
      expect(generationOf(152), 2);
      expect(generationOf(1025), 9);
      expect(generationOf(0), isNull);
      expect(generationOf(1026), isNull);
      var total = 0;
      for (var g = 1; g <= 9; g++) {
        total += generationSize(g);
      }
      expect(total, 1025);
    });
  });

  group('incremental loading', () {
    test('nextVisibleCount grows by a page and clamps', () {
      expect(nextVisibleCount(30, 100), 60);
      expect(nextVisibleCount(90, 100), 100);
      expect(nextVisibleCount(100, 100), 100);
      expect(nextVisibleCount(0, 10), 10);
    });

    test('repeated loadMore calls for the same window are ignored', () async {
      final prefs = await mockPrefs();
      final container = makeContainer(prefs);
      final notifier = container.read(pokedexProvider.notifier);
      expect(container.read(pokedexProvider).visibleCount, kPokedexPageSize);

      notifier.loadMore(200, renderedCount: kPokedexPageSize);
      notifier.loadMore(200, renderedCount: kPokedexPageSize);
      notifier.loadMore(200, renderedCount: kPokedexPageSize);
      expect(
        container.read(pokedexProvider).visibleCount,
        kPokedexPageSize * 2,
      );

      notifier.loadMore(200, renderedCount: kPokedexPageSize * 2);
      expect(
        container.read(pokedexProvider).visibleCount,
        kPokedexPageSize * 3,
      );
    });

    test(
      'never exceeds the total and filter changes reset the window',
      () async {
        final prefs = await mockPrefs();
        final container = makeContainer(prefs);
        final notifier = container.read(pokedexProvider.notifier);
        notifier.loadMore(40, renderedCount: kPokedexPageSize);
        expect(container.read(pokedexProvider).visibleCount, 40);
        notifier.loadMore(40, renderedCount: 40);
        expect(container.read(pokedexProvider).visibleCount, 40);

        notifier.setQuery('pika');
        expect(container.read(pokedexProvider).visibleCount, kPokedexPageSize);
        notifier.setType('fire');
        notifier.clearFilters();
        final ui = container.read(pokedexProvider);
        expect(ui.filter.isActive, isFalse);
        expect(ui.filter.query, isEmpty);
      },
    );
  });
}
