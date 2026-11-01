import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../core/storage/local_store.dart';
import '../../domain/achievements.dart';
import '../collections/collections_controller.dart';
import '../mystery/mystery_controller.dart';
import '../research/research_controller.dart';
import '../team_builder/teams_controller.dart';

const int kShowcaseSize = 6;

class ProfileState {
  const ProfileState({
    this.nickname = 'Trainer',
    this.accentIndex = 0,
    this.avatarId,
    this.showcase = const [],
    this.themeMode = ThemeMode.dark,
  });

  final String nickname;
  final int accentIndex;

  /// Pokémon whose artwork is used as the avatar, if chosen.
  final int? avatarId;
  final List<int> showcase;
  final ThemeMode themeMode;

  Color get accent => kAccents[accentIndex.clamp(0, kAccents.length - 1)];

  ProfileState copyWith({
    String? nickname,
    int? accentIndex,
    Object? avatarId = _unset,
    List<int>? showcase,
    ThemeMode? themeMode,
  }) {
    return ProfileState(
      nickname: nickname ?? this.nickname,
      accentIndex: accentIndex ?? this.accentIndex,
      avatarId: identical(avatarId, _unset) ? this.avatarId : avatarId as int?,
      showcase: showcase ?? this.showcase,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  Map<String, dynamic> toJson() => {
    'nick': nickname,
    'accent': accentIndex,
    'avatar': avatarId,
    'showcase': showcase,
    'theme': themeMode.name,
  };
}

const Object _unset = Object();

class ProfileNotifier extends Notifier<ProfileState> {
  static const storageKey = 'profile.v1';

  @override
  ProfileState build() {
    final json = readJsonMap(ref.watch(sharedPreferencesProvider), storageKey);
    if (json == null) {
      return const ProfileState();
    }
    final nick = json['nick'];
    final accent = json['accent'];
    final avatar = json['avatar'];
    final showcase = json['showcase'];
    final theme = json['theme'];
    return ProfileState(
      nickname: nick is String && nick.trim().isNotEmpty ? nick : 'Trainer',
      accentIndex: accent is int && accent >= 0 && accent < kAccents.length
          ? accent
          : 0,
      avatarId: avatar is int ? avatar : null,
      showcase: [
        for (final v
            in showcase is List<dynamic> ? showcase : const <dynamic>[])
          if (v is int) v,
      ].take(kShowcaseSize).toList(),
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == theme,
        orElse: () => ThemeMode.dark,
      ),
    );
  }

  void setNickname(String value) {
    final trimmed = value.trim();
    _set(state.copyWith(nickname: trimmed.isEmpty ? 'Trainer' : trimmed));
  }

  void setAccent(int index) => _set(state.copyWith(accentIndex: index));
  void setAvatar(int? id) => _set(state.copyWith(avatarId: id));
  void setThemeMode(ThemeMode mode) => _set(state.copyWith(themeMode: mode));

  /// Adds/removes from the showcase; returns false when the showcase is full.
  bool toggleShowcase(int id) {
    if (state.showcase.contains(id)) {
      _set(
        state.copyWith(
          showcase: [
            for (final s in state.showcase)
              if (s != id) s,
          ],
        ),
      );
      return true;
    }
    if (state.showcase.length >= kShowcaseSize) {
      return false;
    }
    _set(state.copyWith(showcase: [...state.showcase, id]));
    return true;
  }

  void reorderShowcase(int oldIndex, int newIndex) {
    final list = [...state.showcase];
    if (oldIndex < 0 || oldIndex >= list.length) {
      return;
    }
    var target = newIndex;
    if (target > oldIndex) {
      target -= 1;
    }
    final item = list.removeAt(oldIndex);
    list.insert(target.clamp(0, list.length), item);
    _set(state.copyWith(showcase: list));
  }

  void _set(ProfileState next) {
    state = next;
    ref
        .read(sharedPreferencesProvider)
        .setString(storageKey, jsonEncode(next.toJson()));
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, ProfileState>(
  ProfileNotifier.new,
);

final achievementsProvider = Provider<List<Achievement>>((ref) {
  final summary = ref.watch(researchSummaryProvider);
  final favourites = ref.watch(favouritesProvider);
  final collections = ref.watch(collectionsProvider);
  final teams = ref.watch(teamsProvider);
  final mystery = ref.watch(mysteryProvider);
  final notes = ref.watch(notesProvider);
  final streaks = ref.watch(mysteryStreaksProvider);

  var largestCollection = 0;
  for (final c in collections) {
    if (c.ids.length > largestCollection) {
      largestCollection = c.ids.length;
    }
  }
  var largestTeam = 0;
  for (final t in teams) {
    if (t.members.length > largestTeam) {
      largestTeam = t.members.length;
    }
  }
  return computeAchievements(
    AchievementInput(
      discovered: summary.discovered,
      studied: summary.studied,
      mastered: summary.mastered,
      favourites: favourites.length,
      largestCollection: largestCollection,
      collections: collections.length,
      largestTeam: largestTeam,
      mysteryWins: mystery.history.values.where((r) => r.won).length,
      bestStreak: streaks.best,
      discoveredIds: summary.discoveredIds,
      notes: notes.length,
    ),
  );
});

/// The selected accent color. The app theme, the Settings indicator and the swatch
/// selection all read this, so they cannot disagree.
final accentColorProvider = Provider<Color>(
  (ref) => ref.watch(profileProvider.select((p) => p.accent)),
);

final themeModeProvider = Provider<ThemeMode>(
  (ref) => ref.watch(profileProvider.select((p) => p.themeMode)),
);
