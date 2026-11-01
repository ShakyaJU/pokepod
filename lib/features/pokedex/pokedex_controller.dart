import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/pokemon.dart';
import '../../data/providers.dart';
import '../../domain/pokedex_filter.dart';
import '../research/research_controller.dart';
import 'measurements.dart';

enum PokedexView { grid, list }

const int kPokedexPageSize = 30;

class PokedexUiState {
  const PokedexUiState({
    this.filter = const PokedexFilter(),
    this.visibleCount = kPokedexPageSize,
    this.view = PokedexView.grid,
    this.livingDex = false,
  });

  final PokedexFilter filter;
  final int visibleCount;
  final PokedexView view;

  /// When on, undiscovered entries are shown as silhouettes (names stay visible).
  final bool livingDex;

  PokedexUiState copyWith({
    PokedexFilter? filter,
    int? visibleCount,
    PokedexView? view,
    bool? livingDex,
  }) {
    return PokedexUiState(
      filter: filter ?? this.filter,
      visibleCount: visibleCount ?? this.visibleCount,
      view: view ?? this.view,
      livingDex: livingDex ?? this.livingDex,
    );
  }
}

class PokedexNotifier extends Notifier<PokedexUiState> {
  @override
  PokedexUiState build() => const PokedexUiState();

  void _filter(PokedexFilter filter) {
    // Any filter change restarts the incremental window.
    state = state.copyWith(filter: filter, visibleCount: kPokedexPageSize);
  }

  void setQuery(String query) => _filter(state.filter.copyWith(query: query));
  void setType(String? type) => _filter(state.filter.copyWith(type: type));
  void setGeneration(int? generation) =>
      _filter(state.filter.copyWith(generation: generation));
  void setSortKey(SortKey key) => _filter(state.filter.copyWith(sortKey: key));
  void setAscending(bool ascending) =>
      _filter(state.filter.copyWith(ascending: ascending));
  void resetSort() =>
      _filter(state.filter.copyWith(sortKey: SortKey.number, ascending: true));
  void toggleFavourites() => _filter(
    state.filter.copyWith(favouritesOnly: !state.filter.favouritesOnly),
  );
  void clearFilters() => _filter(
    PokedexFilter(
      sortKey: state.filter.sortKey,
      ascending: state.filter.ascending,
    ),
  );
  void setView(PokedexView view) => state = state.copyWith(view: view);
  void toggleLivingDex() => state = state.copyWith(livingDex: !state.livingDex);

  /// Grows the window by one page. [renderedCount] is the count the caller
  /// rendered; if the window already moved on, the call is a no-op, so
  /// bursts of scroll notifications cannot trigger duplicate loads.
  void loadMore(int total, {required int renderedCount}) {
    if (state.visibleCount != renderedCount) {
      return;
    }
    final next = nextVisibleCount(
      renderedCount,
      total,
      pageSize: kPokedexPageSize,
    );
    if (next == renderedCount) {
      return;
    }
    state = state.copyWith(visibleCount: next);
  }
}

final pokedexProvider = NotifierProvider<PokedexNotifier, PokedexUiState>(
  PokedexNotifier.new,
);

typedef PokedexResults = AsyncValue<List<PokemonSummary>>;

/// Catalogue after applying search, filters and sort.
final filteredPokedexProvider = Provider<PokedexResults>((ref) {
  final catalog = ref.watch(catalogProvider);
  final ui = ref.watch(pokedexProvider);
  final favourites = ref.watch(favouritesProvider);
  // Only watched for measurement sorts, so other sorts never rebuild on it.
  final facts = ui.filter.sortKey.needsFacts
      ? ref.watch(measurementsProvider.select((m) => m.data))
      : null;

  return catalog.when<PokedexResults>(
    data: (all) {
      final type = ui.filter.type;
      if (type == null) {
        return AsyncData<List<PokemonSummary>>(
          applyPokedexFilter(
            all,
            ui.filter,
            favourites: favourites,
            facts: facts,
          ),
        );
      }
      return ref
          .watch(typeMembersProvider(type))
          .when<PokedexResults>(
            data: (members) => AsyncData<List<PokemonSummary>>(
              applyPokedexFilter(
                all,
                ui.filter,
                typeMembers: members,
                favourites: favourites,
                facts: facts,
              ),
            ),
            loading: () => const AsyncLoading<List<PokemonSummary>>(),
            error: (e, s) => AsyncError<List<PokemonSummary>>(e, s),
          );
    },
    loading: () => const AsyncLoading<List<PokemonSummary>>(),
    error: (e, s) => AsyncError<List<PokemonSummary>>(e, s),
  );
});
