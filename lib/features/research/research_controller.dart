import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/local_store.dart';
import '../../domain/research_rules.dart';

/// Per-Pokémon research stage, persisted locally.
class ResearchNotifier extends Notifier<Map<int, ResearchState>> {
  static const storageKey = 'research.v1';

  @override
  Map<int, ResearchState> build() {
    final json = readJsonMap(ref.watch(sharedPreferencesProvider), storageKey);
    final out = <int, ResearchState>{};
    json?.forEach((k, v) {
      final id = int.tryParse(k);
      if (id == null ||
          v is! int ||
          v < 1 ||
          v >= ResearchState.values.length) {
        return;
      }
      out[id] = ResearchState.values[v];
    });
    return out;
  }

  ResearchState stateOf(int id) => state[id] ?? ResearchState.unseen;

  /// Opening a dossier counts as discovering the Pokémon, but never more.
  bool discover(int id) {
    if (stateOf(id) != ResearchState.unseen) {
      return false;
    }
    return transition(id, ResearchState.discovered);
  }

  /// Applies [ResearchRules]; returns whether the change was allowed.
  bool transition(int id, ResearchState to) {
    final from = stateOf(id);
    if (!ResearchRules.canTransition(from, to)) {
      return false;
    }
    final next = Map<int, ResearchState>.from(state);
    if (to == ResearchState.unseen) {
      next.remove(id);
    } else {
      next[id] = to;
    }
    state = next;
    _save();
    return true;
  }

  void _save() {
    ref
        .read(sharedPreferencesProvider)
        .setString(
          storageKey,
          jsonEncode({
            for (final e in state.entries) '${e.key}': e.value.index,
          }),
        );
  }
}

final researchProvider =
    NotifierProvider<ResearchNotifier, Map<int, ResearchState>>(
      ResearchNotifier.new,
    );

class ResearchSummary {
  const ResearchSummary({
    required this.discovered,
    required this.studied,
    required this.mastered,
    required this.discoveredIds,
  });

  /// "At least" counts: discovered includes studied and mastered.
  final int discovered;
  final int studied;
  final int mastered;
  final Set<int> discoveredIds;
}

final researchSummaryProvider = Provider<ResearchSummary>((ref) {
  final research = ref.watch(researchProvider);
  var studied = 0;
  var mastered = 0;
  for (final s in research.values) {
    if (s.index >= ResearchState.studied.index) {
      studied++;
    }
    if (s == ResearchState.mastered) {
      mastered++;
    }
  }
  return ResearchSummary(
    discovered: research.length,
    studied: studied,
    mastered: mastered,
    discoveredIds: research.keys.toSet(),
  );
});

/// Extracts Pokémon ids from text containing PokéAPI URLs (the legacy app
/// stored favourites as `https://pokeapi.co/api/v2/pokemon/<id>/`) or plain
/// ids separated by commas/whitespace.
Set<int> parseLegacyFavourites(String text) {
  final ids = <int>{};
  for (final m in RegExp(r'pokemon/(\d+)').allMatches(text)) {
    final id = int.tryParse(m.group(1)!);
    if (id != null && id > 0) {
      ids.add(id);
    }
  }
  final stripped = text.replaceAll(RegExp(r'https?://\S+'), ' ');
  for (final m in RegExp(r'\b\d{1,4}\b').allMatches(stripped)) {
    final id = int.tryParse(m.group(0)!);
    if (id != null && id > 0) {
      ids.add(id);
    }
  }
  return ids;
}

class FavouritesNotifier extends Notifier<Set<int>> {
  static const storageKey = 'favourites.v1';

  @override
  Set<int> build() {
    final list = readJsonList(ref.watch(sharedPreferencesProvider), storageKey);
    return {
      for (final v in list ?? const <dynamic>[])
        if (v is int) v,
    };
  }

  bool isFavourite(int id) => state.contains(id);

  void toggle(int id) {
    final next = Set<int>.from(state);
    if (!next.remove(id)) {
      next.add(id);
    }
    state = next;
    _save();
  }

  /// Merges ids; returns how many were new.
  int addAll(Iterable<int> ids) {
    final next = Set<int>.from(state);
    final before = next.length;
    next.addAll(ids);
    state = next;
    _save();
    return next.length - before;
  }

  void _save() {
    ref
        .read(sharedPreferencesProvider)
        .setString(storageKey, jsonEncode(state.toList()..sort()));
  }
}

final favouritesProvider = NotifierProvider<FavouritesNotifier, Set<int>>(
  FavouritesNotifier.new,
);

/// Most recently opened dossiers, newest first (max 20).
class RecentNotifier extends Notifier<List<int>> {
  static const storageKey = 'recent.v1';
  static const maxItems = 20;

  @override
  List<int> build() {
    final list = readJsonList(ref.watch(sharedPreferencesProvider), storageKey);
    return [
      for (final v in list ?? const <dynamic>[])
        if (v is int) v,
    ].take(maxItems).toList();
  }

  void touch(int id) {
    final next = [id, ...state.where((e) => e != id)].take(maxItems).toList();
    state = next;
    ref.read(sharedPreferencesProvider).setString(storageKey, jsonEncode(next));
  }
}

final recentProvider = NotifierProvider<RecentNotifier, List<int>>(
  RecentNotifier.new,
);

/// Personal research-journal notes per Pokémon.
class NotesNotifier extends Notifier<Map<int, String>> {
  static const storageKey = 'notes.v1';

  @override
  Map<int, String> build() {
    final json = readJsonMap(ref.watch(sharedPreferencesProvider), storageKey);
    final out = <int, String>{};
    json?.forEach((k, v) {
      final id = int.tryParse(k);
      if (id != null && v is String && v.trim().isNotEmpty) {
        out[id] = v;
      }
    });
    return out;
  }

  void setNote(int id, String text) {
    final next = Map<int, String>.from(state);
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      next.remove(id);
    } else {
      next[id] = trimmed;
    }
    state = next;
    ref
        .read(sharedPreferencesProvider)
        .setString(
          storageKey,
          jsonEncode({for (final e in next.entries) '${e.key}': e.value}),
        );
  }
}

final notesProvider = NotifierProvider<NotesNotifier, Map<int, String>>(
  NotesNotifier.new,
);
