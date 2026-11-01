import 'package:flutter_test/flutter_test.dart';
import 'package:pokepod/core/errors/app_exception.dart';
import 'package:pokepod/core/storage/local_store.dart';
import 'package:pokepod/data/repositories/pokeapi_repository.dart';

import 'support/support.dart';

void main() {
  group('PokeApiRepository', () {
    test('serves repeat reads from memory without a second request', () async {
      final prefs = await mockPrefs();
      final client = FakeApiClient({'$apiBase/pokemon/25': pokemonJson()});
      final repo = PokeApiRepository(client: client, cache: JsonCache(prefs));
      final a = await repo.fetchPokemon(25);
      final b = await repo.fetchPokemon(25);
      expect(a.name, 'pikachu');
      expect(identical(a, b), isTrue);
      expect(client.requests, hasLength(1));
    });

    test(
      'previously cached data still works when the network is down',
      () async {
        final prefs = await mockPrefs();
        final online = PokeApiRepository(
          client: FakeApiClient({'$apiBase/pokemon/25': pokemonJson()}),
          cache: JsonCache(prefs),
        );
        await online.fetchPokemon(25);

        final offlineClient = FakeApiClient({
          '$apiBase/pokemon/25': const AppException(
            AppErrorKind.network,
            'down',
          ),
        });
        final offline = PokeApiRepository(
          client: offlineClient,
          cache: JsonCache(prefs),
        );
        final d = await offline.fetchPokemon(25);
        expect(d.name, 'pikachu');
        expect(offlineClient.requests, isEmpty);
      },
    );

    test('de-duplicates concurrent requests for the same resource', () async {
      final prefs = await mockPrefs();
      final client = FakeApiClient({
        '$apiBase/pokemon/25': pokemonJson(),
      }, delay: const Duration(milliseconds: 10));
      final repo = PokeApiRepository(client: client, cache: JsonCache(prefs));
      final results = await Future.wait([
        repo.fetchPokemon(25),
        repo.fetchPokemon(25),
      ]);
      expect(results.first.id, results.last.id);
      expect(client.requests, hasLength(1));
    });

    test(
      'reports network failures honestly and does not fabricate data',
      () async {
        final prefs = await mockPrefs();
        final live = <bool>[];
        final repo = PokeApiRepository(
          client: FakeApiClient({
            '$apiBase/pokemon/25': const AppException(
              AppErrorKind.network,
              'down',
            ),
          }),
          cache: JsonCache(prefs),
          onLiveStatus: live.add,
        );
        await expectLater(
          repo.fetchPokemon(25),
          throwsA(
            isA<AppException>().having(
              (e) => e.kind,
              'kind',
              AppErrorKind.network,
            ),
          ),
        );
        expect(live, [false]);
      },
    );

    test('a successful request reports live', () async {
      final prefs = await mockPrefs();
      final live = <bool>[];
      final repo = PokeApiRepository(
        client: FakeApiClient({'$apiBase/pokemon/25': pokemonJson()}),
        cache: JsonCache(prefs),
        onLiveStatus: live.add,
      );
      await repo.fetchPokemon(25);
      expect(live, [true]);
    });

    test(
      'malformed responses surface as parse errors and are not cached',
      () async {
        final prefs = await mockPrefs();
        final client = FakeApiClient({
          '$apiBase/pokemon/1': <String, dynamic>{'oops': true},
        });
        final repo = PokeApiRepository(client: client, cache: JsonCache(prefs));
        await expectLater(
          repo.fetchPokemon(1),
          throwsA(
            isA<AppException>().having(
              (e) => e.kind,
              'kind',
              AppErrorKind.parse,
            ),
          ),
        );
        expect(JsonCache(prefs).read('pokemon.1'), isNull);
      },
    );

    test('a corrupt cache entry falls back to the network', () async {
      final prefs = await mockPrefs({'cache.v1.pokemon.25': 'not json{'});
      final client = FakeApiClient({'$apiBase/pokemon/25': pokemonJson()});
      final repo = PokeApiRepository(client: client, cache: JsonCache(prefs));
      expect((await repo.fetchPokemon(25)).name, 'pikachu');
      expect(client.requests, hasLength(1));
    });

    test(
      'catalogue is deduplicated, sorted and skips malformed items',
      () async {
        final prefs = await mockPrefs();
        final json = catalogJson([
          (3, 'venusaur'),
          (1, 'bulbasaur'),
          (3, 'venusaur'),
          (2, 'ivysaur'),
        ]);
        (json['results'] as List<dynamic>).add({'name': 'broken'});
        final client = FakeApiClient({
          '$apiBase/pokemon?limit=1025&offset=0': json,
        });
        final repo = PokeApiRepository(client: client, cache: JsonCache(prefs));
        final list = await repo.fetchCatalog();
        expect([for (final p in list) p.id], [1, 2, 3]);
      },
    );

    test(
      'type membership ignores alternate forms beyond the national dex',
      () async {
        final prefs = await mockPrefs();
        final client = FakeApiClient({
          '$apiBase/type/fire': {
            'pokemon': [
              {
                'pokemon': {'name': 'charmander', 'url': '$apiBase/pokemon/4/'},
              },
              {
                'pokemon': {
                  'name': 'charizard-mega-x',
                  'url': '$apiBase/pokemon/10034/',
                },
              },
              {
                'pokemon': {'name': 'vulpix', 'url': '$apiBase/pokemon/37/'},
              },
              'junk',
            ],
          },
        });
        final repo = PokeApiRepository(client: client, cache: JsonCache(prefs));
        expect(await repo.fetchTypeMembers('fire'), {4, 37});
      },
    );

    test('evolution chains are fetched and cached', () async {
      final prefs = await mockPrefs();
      final client = FakeApiClient({
        '$apiBase/evolution-chain/67': eeveeChainJson(),
      });
      final repo = PokeApiRepository(client: client, cache: JsonCache(prefs));
      final chain = await repo.fetchEvolutionChain(67);
      expect(chain.memberIds, contains(197));
      final again = PokeApiRepository(
        client: FakeApiClient({}),
        cache: JsonCache(prefs),
      );
      expect((await again.fetchEvolutionChain(67)).root.name, 'eevee');
    });
  });
}
