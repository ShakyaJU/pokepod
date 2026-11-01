import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/local_store.dart';

class Collection {
  const Collection({required this.id, required this.name, this.ids = const []});

  final String id;
  final String name;
  final List<int> ids;

  Collection copyWith({String? name, List<int>? ids}) =>
      Collection(id: id, name: name ?? this.name, ids: ids ?? this.ids);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'ids': ids};

  static Collection? tryFromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final id = raw['id'];
    final name = raw['name'];
    if (id is! String || name is! String) {
      return null;
    }
    final ids = raw['ids'];
    return Collection(
      id: id,
      name: name,
      ids: [
        for (final v in ids is List<dynamic> ? ids : const <dynamic>[])
          if (v is int) v,
      ],
    );
  }
}

String newLocalId(Iterable<String> existing) {
  var n = DateTime.now().microsecondsSinceEpoch;
  while (existing.contains('$n')) {
    n++;
  }
  return '$n';
}

class CollectionsNotifier extends Notifier<List<Collection>> {
  static const storageKey = 'collections.v1';

  @override
  List<Collection> build() {
    final list = readJsonList(ref.watch(sharedPreferencesProvider), storageKey);
    return [
      for (final raw in list ?? const <dynamic>[])
        if (Collection.tryFromJson(raw) != null) Collection.tryFromJson(raw)!,
    ];
  }

  String create(String name) {
    final id = newLocalId(state.map((c) => c.id));
    final trimmed = name.trim();
    state = [
      ...state,
      Collection(
        id: id,
        name: trimmed.isEmpty ? 'Untitled collection' : trimmed,
      ),
    ];
    _save();
    return id;
  }

  void rename(String id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    state = [for (final c in state) c.id == id ? c.copyWith(name: trimmed) : c];
    _save();
  }

  void delete(String id) {
    state = [
      for (final c in state)
        if (c.id != id) c,
    ];
    _save();
  }

  /// Returns false if the collection is missing or already contains [pokemonId].
  bool add(String collectionId, int pokemonId) {
    final index = state.indexWhere((c) => c.id == collectionId);
    if (index < 0 || state[index].ids.contains(pokemonId)) {
      return false;
    }
    final next = [...state];
    next[index] = next[index].copyWith(ids: [...next[index].ids, pokemonId]);
    state = next;
    _save();
    return true;
  }

  bool remove(String collectionId, int pokemonId) {
    final index = state.indexWhere((c) => c.id == collectionId);
    if (index < 0 || !state[index].ids.contains(pokemonId)) {
      return false;
    }
    final next = [...state];
    next[index] = next[index].copyWith(
      ids: [
        for (final i in next[index].ids)
          if (i != pokemonId) i,
      ],
    );
    state = next;
    _save();
    return true;
  }

  void _save() {
    ref
        .read(sharedPreferencesProvider)
        .setString(storageKey, jsonEncode([for (final c in state) c.toJson()]));
  }
}

final collectionsProvider =
    NotifierProvider<CollectionsNotifier, List<Collection>>(
      CollectionsNotifier.new,
    );
