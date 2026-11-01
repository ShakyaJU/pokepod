import 'package:flutter_test/flutter_test.dart';
import 'package:pokepod/core/errors/app_exception.dart';
import 'package:pokepod/core/utils/formatters.dart';
import 'package:pokepod/data/models/pokemon.dart';

import 'support/support.dart';

void main() {
  group('PokemonDetail parsing', () {
    test(
      'parses types in slot order, stats in canonical order, dedupes moves',
      () {
        final d = PokemonDetail.fromApiJson(pokemonJson());
        expect(d.id, 25);
        expect(d.displayName, 'Pikachu');
        expect(d.types, ['electric', 'flying']);
        expect([for (final s in d.stats) s.name], kStatOrder);
        expect(d.statTotal, 320);
        expect(d.stat('speed'), 90);
        expect(d.topStat!.name, 'speed');
        expect(d.heightM, 0.4);
        expect(d.weightKg, 6.0);
        expect(d.moves, ['growl', 'thunder-shock']);
        expect(d.moveCount, 2);
        expect(d.abilities.last.hidden, isTrue);
      },
    );

    test('tolerates missing optional fields', () {
      final d = PokemonDetail.fromApiJson({'id': 1, 'name': 'bulbasaur'});
      expect(d.types, isEmpty);
      expect(d.stats, isEmpty);
      expect(d.statTotal, 0);
      expect(d.topStat, isNull);
      expect(d.baseExperience, isNull);
    });

    test('ignores malformed entries inside lists', () {
      final json = pokemonJson()
        ..['types'] = [
          'oops',
          {'slot': 1},
          {
            'slot': 1,
            'type': {'name': 'water'},
          },
        ]
        ..['abilities'] = [null, 3];
      final d = PokemonDetail.fromApiJson(json);
      expect(d.types, ['water']);
      expect(d.abilities, isEmpty);
    });

    test('throws a parse AppException when id or name is missing/invalid', () {
      expect(
        () => PokemonDetail.fromApiJson(<String, dynamic>{}),
        throwsA(
          isA<AppException>().having((e) => e.kind, 'kind', AppErrorKind.parse),
        ),
      );
      expect(
        () => PokemonDetail.fromApiJson({'id': 'abc', 'name': 'x'}),
        throwsA(isA<AppException>()),
      );
    });

    test('compact cache format round-trips', () {
      final original = PokemonDetail.fromApiJson(pokemonJson());
      final copy = PokemonDetail.fromJson(original.toJson());
      expect(copy.toJson(), original.toJson());
    });
  });

  group('PokemonSpecies parsing', () {
    test('uses the newest English flavour text and cleans whitespace', () {
      final s = PokemonSpecies.fromApiJson({
        'id': 25,
        'genera': [
          {
            'genus': 'Souris',
            'language': {'name': 'fr'},
          },
          {
            'genus': 'Mouse Pokémon',
            'language': {'name': 'en'},
          },
        ],
        'flavor_text_entries': [
          {
            'flavor_text': 'Old text.',
            'language': {'name': 'en'},
          },
          {
            'flavor_text': 'Texte',
            'language': {'name': 'fr'},
          },
          {
            'flavor_text': 'When it\nis angry,\fit  sparks.',
            'language': {'name': 'en'},
          },
        ],
        'generation': {'url': '$apiBase/generation/1/'},
        'evolution_chain': {'url': '$apiBase/evolution-chain/10/'},
        'is_legendary': false,
        'is_mythical': true,
      });
      expect(s.genus, 'Mouse Pokémon');
      expect(s.flavorText, 'When it is angry, it sparks.');
      expect(s.generationId, 1);
      expect(s.evolutionChainId, 10);
      expect(s.isMythical, isTrue);
      expect(PokemonSpecies.fromJson(s.toJson()).flavorText, s.flavorText);
    });

    test('missing species fields become null, not errors', () {
      final s = PokemonSpecies.fromApiJson({'id': 7});
      expect(s.genus, isNull);
      expect(s.flavorText, isNull);
      expect(s.evolutionChainId, isNull);
    });
  });

  group('Evolution chain', () {
    test('parses a branching family with conditions', () {
      final chain = EvolutionChain.fromApiJson(eeveeChainJson());
      expect(chain.root.name, 'eevee');
      expect(chain.root.links, hasLength(3));
      expect(chain.memberIds, {133, 134, 135, 197});
      expect(chain.isSingle, isFalse);
      final conditions = [for (final l in chain.root.links) l.condition];
      expect(conditions, [
        'Use Water Stone',
        'Use Thunder Stone',
        'Level up, happiness ≥ 160, at night',
      ]);
    });

    test('parses a multistage chain and survives a cache round trip', () {
      final chain = EvolutionChain.fromApiJson(charmanderChainJson());
      expect([for (final n in chain.allNodes) n.id], [4, 5, 6]);
      final copy = EvolutionChain.fromJson(chain.toJson());
      expect(copy.toJson(), chain.toJson());
      expect(copy.root.links.single.condition, 'Level 16');
    });

    test('a chain with no evolutions is single', () {
      final chain = EvolutionChain.fromApiJson({
        'id': 1,
        'chain': {
          'species': {'name': 'tauros', 'url': '$apiBase/pokemon-species/128/'},
          'evolves_to': [],
        },
      });
      expect(chain.isSingle, isTrue);
    });

    test('malformed chains raise a parse error', () {
      expect(
        () => EvolutionChain.fromApiJson({'id': 1}),
        throwsA(isA<AppException>()),
      );
      expect(
        () => EvolutionChain.fromApiJson({
          'chain': {'evolves_to': []},
        }),
        throwsA(isA<AppException>()),
      );
    });

    test('describeEvolution handles trades, items, gender and empties', () {
      expect(describeEvolution(const []), '');
      expect(
        describeEvolution([
          {
            'trigger': {'name': 'trade'},
            'held_item': {'name': 'metal-coat'},
          },
        ]),
        'Trade, holding Metal Coat',
      );
      expect(
        describeEvolution([
          {
            'trigger': {'name': 'level-up'},
            'min_level': 20,
            'gender': 1,
          },
          {
            'trigger': {'name': 'level-up'},
            'min_level': 20,
            'gender': 1,
          },
        ]),
        'Level 20, female only',
      );
      expect(describeEvolution(['junk', null]), '');
    });
  });

  group('helpers', () {
    test('idFromUrl', () {
      expect(idFromUrl('$apiBase/pokemon/25/'), 25);
      expect(idFromUrl('$apiBase/pokemon/25'), 25);
      expect(idFromUrl(null), isNull);
      expect(idFromUrl(''), isNull);
      expect(idFromUrl('$apiBase/pokemon/abc/'), isNull);
    });

    test('summary list items skip malformed entries', () {
      expect(
        PokemonSummary.tryFromListItem({
          'name': 'a',
          'url': '$apiBase/pokemon/3/',
        })!.id,
        3,
      );
      expect(PokemonSummary.tryFromListItem({'name': 'a'}), isNull);
      expect(PokemonSummary.tryFromListItem('x'), isNull);
    });

    test('titleCase and dexNumber', () {
      expect(titleCase('mr-mime'), 'Mr Mime');
      expect(dexNumber(7), '#0007');
    });
  });
}
