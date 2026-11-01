import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/local_store.dart';
import '../collections/collections_controller.dart' show newLocalId;

const int kTeamSize = 6;

class Team {
  const Team({required this.id, required this.name, this.members = const []});

  final String id;
  final String name;
  final List<int> members;

  Team copyWith({String? name, List<int>? members}) =>
      Team(id: id, name: name ?? this.name, members: members ?? this.members);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'members': members};

  static Team? tryFromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final id = raw['id'];
    final name = raw['name'];
    if (id is! String || name is! String) {
      return null;
    }
    final members = raw['members'];
    return Team(
      id: id,
      name: name,
      members: [
        for (final v in members is List<dynamic> ? members : const <dynamic>[])
          if (v is int) v,
      ].take(kTeamSize).toList(),
    );
  }
}

class TeamsNotifier extends Notifier<List<Team>> {
  static const storageKey = 'teams.v1';

  @override
  List<Team> build() {
    final list = readJsonList(ref.watch(sharedPreferencesProvider), storageKey);
    return [
      for (final raw in list ?? const <dynamic>[])
        if (Team.tryFromJson(raw) != null) Team.tryFromJson(raw)!,
    ];
  }

  String create(String name) {
    final id = newLocalId(state.map((t) => t.id));
    final trimmed = name.trim();
    state = [
      ...state,
      Team(id: id, name: trimmed.isEmpty ? 'New team' : trimmed),
    ];
    _save();
    return id;
  }

  void rename(String id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    state = [for (final t in state) t.id == id ? t.copyWith(name: trimmed) : t];
    _save();
  }

  String? duplicate(String id) {
    final source = state.where((t) => t.id == id).firstOrNull;
    if (source == null) {
      return null;
    }
    final newId = newLocalId(state.map((t) => t.id));
    state = [
      ...state,
      Team(
        id: newId,
        name: '${source.name} copy',
        members: [...source.members],
      ),
    ];
    _save();
    return newId;
  }

  void delete(String id) {
    state = [
      for (final t in state)
        if (t.id != id) t,
    ];
    _save();
  }

  /// Fails (returns false) when the team is full or already has the Pokémon.
  bool addMember(String teamId, int pokemonId) {
    final index = state.indexWhere((t) => t.id == teamId);
    if (index < 0) {
      return false;
    }
    final team = state[index];
    if (team.members.length >= kTeamSize || team.members.contains(pokemonId)) {
      return false;
    }
    final next = [...state];
    next[index] = team.copyWith(members: [...team.members, pokemonId]);
    state = next;
    _save();
    return true;
  }

  void removeMember(String teamId, int pokemonId) {
    state = [
      for (final t in state)
        t.id == teamId
            ? t.copyWith(
                members: [
                  for (final m in t.members)
                    if (m != pokemonId) m,
                ],
              )
            : t,
    ];
    _save();
  }

  void _save() {
    ref
        .read(sharedPreferencesProvider)
        .setString(storageKey, jsonEncode([for (final t in state) t.toJson()]));
  }
}

final teamsProvider = NotifierProvider<TeamsNotifier, List<Team>>(
  TeamsNotifier.new,
);
