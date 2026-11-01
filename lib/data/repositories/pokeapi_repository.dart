import 'package:dio/dio.dart';

import '../../core/errors/app_exception.dart';
import '../../core/networking/api_client.dart';
import '../../core/storage/local_store.dart';
import '../../core/utils/formatters.dart';
import '../models/pokemon.dart';

/// Reads PokéAPI with a cache-first strategy. Pokémon data is effectively
/// static, so anything already in memory or on disk is served without a
/// network request; this also makes previously viewed entries work offline.
class PokeApiRepository {
  PokeApiRepository({
    required this.client,
    required this.cache,
    this.onLiveStatus,
  });

  static const String base = 'https://pokeapi.co/api/v2';

  final ApiClient client;
  final JsonCache cache;

  /// Called with `true` after a successful network request and `false` after a
  /// failed one, so the UI can show an honest connectivity indicator.
  final void Function(bool live)? onLiveStatus;

  final Map<String, Object> _memory = {};
  final Map<String, Future<Object>> _inflight = {};

  Future<List<PokemonSummary>> fetchCatalog({CancelToken? cancelToken}) {
    return _load<List<PokemonSummary>>(
      key: 'catalog',
      url: '$base/pokemon?limit=$kNationalDexSize&offset=0',
      cancelToken: cancelToken,
      parseApi: (json) {
        final items = <PokemonSummary>[];
        final seen = <int>{};
        final results = json['results'];
        if (results is! List<dynamic>) {
          throw const AppException(AppErrorKind.parse, 'Malformed catalogue.');
        }
        for (final raw in results) {
          final item = PokemonSummary.tryFromListItem(raw);
          if (item != null && seen.add(item.id)) {
            items.add(item);
          }
        }
        if (items.isEmpty) {
          throw const AppException(AppErrorKind.parse, 'Empty catalogue.');
        }
        items.sort((a, b) => a.id.compareTo(b.id));
        return items;
      },
      parseCache: (json) {
        final raw = json['items'];
        if (raw is! List<dynamic>) {
          throw const AppException(AppErrorKind.parse, 'Bad cache.');
        }
        final items = [
          for (final r in raw)
            if (PokemonSummary.tryFromJson(r) != null)
              PokemonSummary.tryFromJson(r)!,
        ];
        if (items.isEmpty) {
          throw const AppException(AppErrorKind.parse, 'Bad cache.');
        }
        return items;
      },
      toCache: (items) => {
        'items': [for (final i in items) i.toJson()],
      },
    );
  }

  Future<PokemonDetail> fetchPokemon(int id, {CancelToken? cancelToken}) {
    return _load<PokemonDetail>(
      key: 'pokemon.$id',
      url: '$base/pokemon/$id',
      cancelToken: cancelToken,
      parseApi: PokemonDetail.fromApiJson,
      parseCache: PokemonDetail.fromJson,
      toCache: (d) => d.toJson(),
    );
  }

  Future<PokemonSpecies> fetchSpecies(int id, {CancelToken? cancelToken}) {
    return _load<PokemonSpecies>(
      key: 'species.$id',
      url: '$base/pokemon-species/$id',
      cancelToken: cancelToken,
      parseApi: PokemonSpecies.fromApiJson,
      parseCache: PokemonSpecies.fromJson,
      toCache: (s) => s.toJson(),
    );
  }

  Future<EvolutionChain> fetchEvolutionChain(
    int chainId, {
    CancelToken? cancelToken,
  }) {
    return _load<EvolutionChain>(
      key: 'chain.$chainId',
      url: '$base/evolution-chain/$chainId',
      cancelToken: cancelToken,
      parseApi: EvolutionChain.fromApiJson,
      parseCache: EvolutionChain.fromJson,
      toCache: (c) => c.toJson(),
    );
  }

  /// National-dex ids of every Pokémon that has [typeName] as a type.
  Future<Set<int>> fetchTypeMembers(
    String typeName, {
    CancelToken? cancelToken,
  }) {
    return _load<Set<int>>(
      key: 'type.$typeName',
      url: '$base/type/$typeName',
      cancelToken: cancelToken,
      parseApi: (json) {
        final ids = <int>{};
        final list = json['pokemon'];
        if (list is! List<dynamic>) {
          throw const AppException(AppErrorKind.parse, 'Malformed type.');
        }
        for (final raw in list) {
          if (raw is! Map<String, dynamic>) {
            continue;
          }
          final p = raw['pokemon'];
          final id = idFromUrl(
            p is Map<String, dynamic> ? p['url'] as String? : null,
          );
          // Alternate forms live above the national dex range; skip them.
          if (id != null && id >= 1 && id <= kNationalDexSize) {
            ids.add(id);
          }
        }
        return ids;
      },
      parseCache: (json) {
        final raw = json['ids'];
        if (raw is! List<dynamic>) {
          throw const AppException(AppErrorKind.parse, 'Bad cache.');
        }
        return {
          for (final v in raw)
            if (v is int) v,
        };
      },
      toCache: (ids) => {'ids': ids.toList()..sort()},
    );
  }

  Future<T> _load<T extends Object>({
    required String key,
    required String url,
    required T Function(Map<String, dynamic>) parseApi,
    required T Function(Map<String, dynamic>) parseCache,
    required Map<String, dynamic> Function(T) toCache,
    CancelToken? cancelToken,
  }) {
    final memo = _memory[key];
    if (memo is T) {
      return Future<T>.value(memo);
    }
    final running = _inflight[key];
    if (running != null) {
      return running.then((v) => v as T);
    }

    final future = _loadUncached<T>(
      key: key,
      url: url,
      parseApi: parseApi,
      parseCache: parseCache,
      toCache: toCache,
      cancelToken: cancelToken,
    );
    _inflight[key] = future;
    future.then<void>(
      (_) {
        _inflight.remove(key);
      },
      onError: (Object _) {
        _inflight.remove(key);
      },
    );
    return future;
  }

  Future<T> _loadUncached<T extends Object>({
    required String key,
    required String url,
    required T Function(Map<String, dynamic>) parseApi,
    required T Function(Map<String, dynamic>) parseCache,
    required Map<String, dynamic> Function(T) toCache,
    CancelToken? cancelToken,
  }) async {
    final cached = cache.read(key);
    if (cached is Map<String, dynamic>) {
      try {
        final value = parseCache(cached);
        _memory[key] = value;
        return value;
      } catch (_) {
        // Corrupt cache entry: fall through and refetch.
      }
    }

    final Map<String, dynamic> json;
    try {
      json = await client.getJson(url, cancelToken: cancelToken);
    } on AppException catch (e) {
      if (e.kind == AppErrorKind.network) {
        onLiveStatus?.call(false);
      }
      rethrow;
    }
    onLiveStatus?.call(true);

    final T value;
    try {
      value = parseApi(json);
    } on AppException {
      rethrow;
    } catch (_) {
      throw AppException(AppErrorKind.parse, 'Malformed response for $key.');
    }
    _memory[key] = value;
    try {
      await cache.write(key, toCache(value));
    } catch (_) {
      // Failing to persist must never fail the read itself.
    }
    return value;
  }
}
