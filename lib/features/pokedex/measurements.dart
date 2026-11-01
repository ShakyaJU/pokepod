import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/local_store.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/pokemon.dart';
import '../../data/providers.dart';
import '../../domain/pokedex_filter.dart';

/// Extra per-Pokémon values (size, stats, types, Legendary/Mythical status)
/// that some sort options need.
///
/// The catalogue only lists names and numbers, so these come from details and
/// species data that are already saved on the device. The user can additionally
/// ask for the currently filtered Pokémon to be loaded; that goes through the
/// existing [pokemonDetailProvider] and [speciesProvider], so nothing is
/// fetched twice.
class MeasurementsState {
  const MeasurementsState({
    this.data = const {},
    this.loadingTotal = 0,
    this.loadingDone = 0,
    this.failed = 0,
  });

  final Map<int, SortFacts> data;
  final int loadingTotal;
  final int loadingDone;
  final int failed;

  bool get loading => loadingTotal > 0 && loadingDone < loadingTotal;
}

SortFacts _factsFromDetail(PokemonDetail d) => SortFacts(
  heightDm: d.heightDm,
  weightHg: d.weightHg,
  stats: {for (final s in d.stats) s.name: s.value},
  types: d.types,
);

SortFacts _factsFromSpecies(PokemonSpecies s) =>
    SortFacts(special: s.isLegendary || s.isMythical);

class MeasurementsNotifier extends Notifier<MeasurementsState> {
  static const int batchSize = 6;

  @override
  MeasurementsState build() => MeasurementsState(data: _readSaved());

  /// Reads details and species already persisted by the repository (cache keys
  /// `pokemon.<id>` and `species.<id>`). This performs no network request.
  Map<int, SortFacts> _readSaved() {
    final cache = ref.read(jsonCacheProvider);
    final out = <int, SortFacts>{};
    for (var id = 1; id <= kNationalDexSize; id++) {
      var facts = const SortFacts();
      var found = false;
      final rawDetail = cache.read('pokemon.$id');
      if (rawDetail is Map<String, dynamic>) {
        try {
          facts = facts.merge(
            _factsFromDetail(PokemonDetail.fromJson(rawDetail)),
          );
          found = true;
        } catch (_) {
          // An unreadable cache entry is simply skipped.
        }
      }
      final rawSpecies = cache.read('species.$id');
      if (rawSpecies is Map<String, dynamic>) {
        try {
          facts = facts.merge(
            _factsFromSpecies(PokemonSpecies.fromJson(rawSpecies)),
          );
          found = true;
        } catch (_) {
          // Skipped as above.
        }
      }
      if (found) {
        out[id] = facts;
      }
    }
    return out;
  }

  /// Picks up data saved since the last read (for example after opening a
  /// Pokémon's dossier).
  void refreshFromSaved() {
    final saved = _readSaved();
    final merged = Map<int, SortFacts>.from(state.data);
    saved.forEach((id, facts) {
      final existing = merged[id];
      merged[id] = existing == null ? facts : existing.merge(facts);
    });
    state = MeasurementsState(
      data: merged,
      loadingTotal: state.loadingTotal,
      loadingDone: state.loadingDone,
      failed: state.failed,
    );
  }

  /// Loads whatever [key] needs for the Pokémon in [ids] that do not have it
  /// yet, a few at a time.
  Future<void> loadMissing(Iterable<int> ids, SortKey key) async {
    if (state.loading || !key.needsFacts) {
      return;
    }
    refreshFromSaved();
    final missing = [
      for (final id in ids)
        if (!(state.data[id]?.hasValueFor(key) ?? false)) id,
    ];
    if (missing.isEmpty) {
      return;
    }

    state = MeasurementsState(data: state.data, loadingTotal: missing.length);
    var done = 0;
    var failed = 0;
    for (var i = 0; i < missing.length; i += batchSize) {
      final chunk = missing.skip(i).take(batchSize).toList();
      final results = await Future.wait([
        for (final id in chunk) _loadOne(id, species: key.needsSpecies),
      ]);
      final next = Map<int, SortFacts>.from(state.data);
      for (var j = 0; j < chunk.length; j++) {
        done++;
        final loaded = results[j];
        if (loaded == null) {
          failed++;
        } else {
          final existing = next[chunk[j]];
          next[chunk[j]] = existing == null ? loaded : existing.merge(loaded);
        }
      }
      state = MeasurementsState(
        data: next,
        loadingTotal: missing.length,
        loadingDone: done,
        failed: failed,
      );
    }
  }

  Future<SortFacts?> _loadOne(int id, {required bool species}) async {
    try {
      if (species) {
        return _factsFromSpecies(await ref.read(speciesProvider(id).future));
      }
      return _factsFromDetail(await ref.read(pokemonDetailProvider(id).future));
    } catch (_) {
      return null;
    }
  }
}

final measurementsProvider =
    NotifierProvider<MeasurementsNotifier, MeasurementsState>(
      MeasurementsNotifier.new,
    );
