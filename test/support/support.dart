import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokepod/core/audio/sound_service.dart';
import 'package:pokepod/core/errors/app_exception.dart';
import 'package:pokepod/core/networking/api_client.dart';
import 'package:pokepod/core/storage/local_store.dart';
import 'package:pokepod/data/models/pokemon.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Scripted [ApiClient]: routes map a URL to a JSON map, or to an
/// [AppException] to throw. Unknown URLs behave like a 404.
class FakeApiClient implements ApiClient {
  FakeApiClient(this.routes, {this.delay = Duration.zero});

  final Map<String, Object> routes;
  final Duration delay;
  final List<String> requests = [];

  @override
  Future<Map<String, dynamic>> getJson(
    String url, {
    CancelToken? cancelToken,
  }) async {
    requests.add(url);
    if (delay != Duration.zero) {
      await Future<void>.delayed(delay);
    }
    final route = routes[url];
    if (route is AppException) {
      throw route;
    }
    if (route is Map<String, dynamic>) {
      return route;
    }
    throw const AppException(AppErrorKind.notFound, 'No such route in test.');
  }
}

Future<SharedPreferences> mockPrefs([
  Map<String, Object> values = const {},
]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

ProviderContainer makeContainer(
  SharedPreferences prefs, {
  List<Override> overrides = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  return container;
}

const String apiBase = 'https://pokeapi.co/api/v2';

Map<String, dynamic> pokemonJson({int id = 25, String name = 'pikachu'}) => {
  'id': id,
  'name': name,
  'height': 4,
  'weight': 60,
  'base_experience': 112,
  'types': [
    {
      'slot': 2,
      'type': {'name': 'flying'},
    },
    {
      'slot': 1,
      'type': {'name': 'electric'},
    },
  ],
  'stats': [
    {
      'base_stat': 90,
      'stat': {'name': 'speed'},
    },
    {
      'base_stat': 35,
      'stat': {'name': 'hp'},
    },
    {
      'base_stat': 55,
      'stat': {'name': 'attack'},
    },
    {
      'base_stat': 40,
      'stat': {'name': 'defense'},
    },
    {
      'base_stat': 50,
      'stat': {'name': 'special-attack'},
    },
    {
      'base_stat': 50,
      'stat': {'name': 'special-defense'},
    },
  ],
  'abilities': [
    {
      'is_hidden': false,
      'ability': {'name': 'static'},
    },
    {
      'is_hidden': true,
      'ability': {'name': 'lightning-rod'},
    },
  ],
  'moves': [
    {
      'move': {'name': 'thunder-shock'},
    },
    {
      'move': {'name': 'growl'},
    },
    {
      'move': {'name': 'growl'},
    },
  ],
};

Map<String, dynamic> catalogJson(List<(int, String)> items) => {
  'count': items.length,
  'results': [
    for (final (id, name) in items)
      {'name': name, 'url': '$apiBase/pokemon/$id/'},
  ],
};

Map<String, dynamic> _species(int id, String name) => {
  'name': name,
  'url': '$apiBase/pokemon-species/$id/',
};

/// A branching family: eevee -> vaporeon / jolteon / umbreon.
Map<String, dynamic> eeveeChainJson() => {
  'id': 67,
  'chain': {
    'species': _species(133, 'eevee'),
    'evolution_details': [],
    'evolves_to': [
      {
        'species': _species(134, 'vaporeon'),
        'evolution_details': [
          {
            'trigger': {'name': 'use-item'},
            'item': {'name': 'water-stone'},
          },
        ],
        'evolves_to': [],
      },
      {
        'species': _species(135, 'jolteon'),
        'evolution_details': [
          {
            'trigger': {'name': 'use-item'},
            'item': {'name': 'thunder-stone'},
          },
        ],
        'evolves_to': [],
      },
      {
        'species': _species(197, 'umbreon'),
        'evolution_details': [
          {
            'trigger': {'name': 'level-up'},
            'min_happiness': 160,
            'time_of_day': 'night',
          },
        ],
        'evolves_to': [],
      },
    ],
  },
};

/// A linear three-stage family: charmander -> charmeleon -> charizard.
Map<String, dynamic> charmanderChainJson() => {
  'id': 2,
  'chain': {
    'species': _species(4, 'charmander'),
    'evolves_to': [
      {
        'species': _species(5, 'charmeleon'),
        'evolution_details': [
          {
            'trigger': {'name': 'level-up'},
            'min_level': 16,
          },
        ],
        'evolves_to': [
          {
            'species': _species(6, 'charizard'),
            'evolution_details': [
              {
                'trigger': {'name': 'level-up'},
                'min_level': 36,
              },
            ],
            'evolves_to': [],
          },
        ],
      },
    ],
  },
};

PokemonDetail makeDetail(
  int id,
  String name,
  List<String> types, {
  List<String> abilities = const [],
  int heightDm = 10,
  int weightHg = 100,
  int hp = 50,
  int atk = 50,
  int def = 50,
  int spa = 50,
  int spd = 50,
  int spe = 50,
}) {
  return PokemonDetail(
    id: id,
    name: name,
    heightDm: heightDm,
    weightHg: weightHg,
    types: types,
    stats: [
      PokemonStat('hp', hp),
      PokemonStat('attack', atk),
      PokemonStat('defense', def),
      PokemonStat('special-attack', spa),
      PokemonStat('special-defense', spd),
      PokemonStat('speed', spe),
    ],
    abilities: [for (final a in abilities) PokemonAbility(a)],
    moves: const [],
    moveCount: 0,
  );
}

/// A valid 1x1 transparent PNG so artwork never touches the network in tests.
final kTestPixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Scripted [SoundBackend]: records everything it is asked to do. A sound
/// stays "playing" until the test calls [finishSound], so screens that
/// coordinate with real playback can be driven frame by frame.
class FakeSoundBackend implements SoundBackend {
  FakeSoundBackend({this.autoComplete = true, this.playDelay = Duration.zero});

  /// When false, [playToCompletion] stays pending until [finishSound].
  final bool autoComplete;

  /// How long [play] takes to reach the platform, to exercise play/stop races.
  final Duration playDelay;

  final List<Sfx> preloaded = [];
  final List<Sfx> played = [];
  final List<Sfx> playedToCompletion = [];
  final List<Sfx> stopped = [];
  final Set<Sfx> active = {};
  final Map<Sfx, Completer<void>> _pending = {};

  /// Set to make every play request fail, as a broken audio system would.
  Object? playError;

  /// The sound is over: it stops counting as playing and any waiter on
  /// [playToCompletion] is released.
  void finishSound(Sfx sfx) {
    active.remove(sfx);
    final waiter = _pending.remove(sfx);
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete();
    }
  }

  @override
  Future<void> preload(Sfx sfx) async {
    preloaded.add(sfx);
  }

  @override
  Future<void> play(Sfx sfx) async {
    if (playError != null) {
      throw playError!;
    }
    if (playDelay != Duration.zero) {
      await Future<void>.delayed(playDelay);
    }
    played.add(sfx);
    active.add(sfx);
  }

  @override
  Future<void> playToCompletion(Sfx sfx) async {
    if (playError != null) {
      throw playError!;
    }
    playedToCompletion.add(sfx);
    if (autoComplete) {
      return;
    }
    active.add(sfx);
    await _pending.putIfAbsent(sfx, Completer<void>.new).future;
    active.remove(sfx);
  }

  @override
  Future<void> stop(Sfx sfx) async {
    stopped.add(sfx);
    active.remove(sfx);
  }

  @override
  bool isPlaying(Sfx sfx) => active.contains(sfx);

  @override
  Future<void> stopAll() async {
    active.clear();
  }

  @override
  Future<void> dispose() async {}
}
