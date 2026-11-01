import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/networking/api_client.dart';
import '../core/storage/local_store.dart';
import 'models/pokemon.dart';
import 'repositories/pokeapi_repository.dart';

enum LiveState { unknown, live, offline }

class LiveStatusNotifier extends Notifier<LiveState> {
  @override
  LiveState build() => LiveState.unknown;

  void report(bool live) {
    state = live ? LiveState.live : LiveState.offline;
  }
}

final liveStatusProvider = NotifierProvider<LiveStatusNotifier, LiveState>(
  LiveStatusNotifier.new,
);

final apiClientProvider = Provider<ApiClient>((ref) => DioApiClient());

final repositoryProvider = Provider<PokeApiRepository>((ref) {
  final status = ref.read(liveStatusProvider.notifier);
  return PokeApiRepository(
    client: ref.watch(apiClientProvider),
    cache: ref.watch(jsonCacheProvider),
    onLiveStatus: (live) {
      // Deferred so it never mutates provider state in the middle of a build.
      Future<void>.microtask(() {
        try {
          status.report(live);
        } catch (_) {
          // The container may already be disposed (e.g. at the end of a test).
        }
      });
    },
  );
});

CancelToken _tokenFor(Ref ref) {
  final token = CancelToken();
  ref.onDispose(() {
    if (!token.isCancelled) {
      token.cancel();
    }
  });
  return token;
}

final catalogProvider = FutureProvider<List<PokemonSummary>>((ref) {
  return ref
      .watch(repositoryProvider)
      .fetchCatalog(cancelToken: _tokenFor(ref));
});

/// id -> summary lookup derived from the catalogue.
final catalogByIdProvider = Provider<Map<int, PokemonSummary>>((ref) {
  final list =
      ref.watch(catalogProvider).valueOrNull ?? const <PokemonSummary>[];
  return {for (final p in list) p.id: p};
});

final pokemonDetailProvider = FutureProvider.family<PokemonDetail, int>((
  ref,
  id,
) {
  return ref.watch(repositoryProvider).fetchPokemon(id);
});

final speciesProvider = FutureProvider.family<PokemonSpecies, int>((ref, id) {
  return ref.watch(repositoryProvider).fetchSpecies(id);
});

/// Evolution family of the Pokémon with national dex number [id].
final evolutionProvider = FutureProvider.family<EvolutionChain, int>((
  ref,
  id,
) async {
  final repo = ref.watch(repositoryProvider);
  final species = await ref.watch(speciesProvider(id).future);
  final chainId = species.evolutionChainId;
  if (chainId == null) {
    final detail = await ref.watch(pokemonDetailProvider(id).future);
    return EvolutionChain.single(id, detail.name);
  }
  return repo.fetchEvolutionChain(chainId);
});

final typeMembersProvider = FutureProvider.family<Set<int>, String>((
  ref,
  type,
) {
  return ref.watch(repositoryProvider).fetchTypeMembers(type);
});
