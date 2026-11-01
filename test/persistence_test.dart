import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokepod/domain/research_rules.dart';
import 'package:pokepod/features/collections/collections_controller.dart';
import 'package:pokepod/features/research/research_controller.dart';
import 'package:pokepod/features/team_builder/teams_controller.dart';
import 'package:pokepod/features/trainer_profile/profile_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/support.dart';

/// Reads state through a brand-new container over the same preferences, which
/// is what an app restart looks like.
ProviderContainer restart(SharedPreferences prefs) => makeContainer(prefs);

void main() {
  group('favourites', () {
    test('toggle persists across a restart', () async {
      final prefs = await mockPrefs();
      final c = makeContainer(prefs);
      c.read(favouritesProvider.notifier)
        ..toggle(25)
        ..toggle(6)
        ..toggle(25);
      expect(c.read(favouritesProvider), {6});
      expect(restart(prefs).read(favouritesProvider), {6});
    });

    test(
      'corrupt stored data yields an empty set instead of crashing',
      () async {
        final prefs = await mockPrefs({'favourites.v1': '{not a list'});
        expect(makeContainer(prefs).read(favouritesProvider), isEmpty);
      },
    );

    test('legacy favourite URLs and plain ids can be imported', () {
      final ids = parseLegacyFavourites(
        'https://pokeapi.co/api/v2/pokemon/25/\nhttps://pokeapi.co/api/v2/pokemon/6/, 150 and 7',
      );
      expect(ids, {25, 6, 150, 7});
      expect(parseLegacyFavourites('nothing here'), isEmpty);
    });

    test('importing merges and reports how many were new', () async {
      final prefs = await mockPrefs();
      final c = makeContainer(prefs);
      c.read(favouritesProvider.notifier).toggle(25);
      final added = c.read(favouritesProvider.notifier).addAll([25, 6, 7]);
      expect(added, 2);
      expect(restart(prefs).read(favouritesProvider), {25, 6, 7});
    });
  });

  group('research state', () {
    test('discover only moves unseen to discovered', () async {
      final prefs = await mockPrefs();
      final c = makeContainer(prefs);
      final n = c.read(researchProvider.notifier);
      expect(n.discover(25), isTrue);
      expect(n.discover(25), isFalse);
      expect(n.stateOf(25), ResearchState.discovered);
    });

    test(
      'opening a page can never award mastery; transitions follow the rules',
      () async {
        final prefs = await mockPrefs();
        final c = makeContainer(prefs);
        final n = c.read(researchProvider.notifier);
        n.discover(25);
        expect(n.transition(25, ResearchState.mastered), isFalse);
        expect(n.stateOf(25), ResearchState.discovered);
        expect(n.transition(25, ResearchState.studied), isTrue);
        expect(n.transition(25, ResearchState.mastered), isTrue);
        expect(n.transition(25, ResearchState.mastered), isFalse);
      },
    );

    test('state persists and reset removes the entry', () async {
      final prefs = await mockPrefs();
      final c = makeContainer(prefs);
      final n = c.read(researchProvider.notifier);
      n.discover(1);
      n.discover(4);
      n.transition(4, ResearchState.studied);
      final again = restart(prefs);
      expect(
        again.read(researchProvider.notifier).stateOf(4),
        ResearchState.studied,
      );
      expect(
        again.read(researchProvider.notifier).stateOf(1),
        ResearchState.discovered,
      );
      expect(again.read(researchSummaryProvider).discovered, 2);
      expect(again.read(researchSummaryProvider).studied, 1);

      n.transition(4, ResearchState.unseen);
      expect(restart(prefs).read(researchProvider).containsKey(4), isFalse);
    });

    test('summary counts are "at least" counts', () async {
      final prefs = await mockPrefs();
      final c = makeContainer(prefs);
      final n = c.read(researchProvider.notifier);
      n.discover(1);
      n.transition(1, ResearchState.studied);
      n.transition(1, ResearchState.mastered);
      final s = c.read(researchSummaryProvider);
      expect((s.discovered, s.studied, s.mastered), (1, 1, 1));
    });
  });

  group('recents and notes', () {
    test('recents are newest-first, unique and capped', () async {
      final prefs = await mockPrefs();
      final c = makeContainer(prefs);
      final n = c.read(recentProvider.notifier);
      for (var i = 1; i <= 25; i++) {
        n.touch(i);
      }
      n.touch(3);
      final list = c.read(recentProvider);
      expect(list.first, 3);
      expect(list.length, RecentNotifier.maxItems);
      expect(list.toSet().length, list.length);
      expect(restart(prefs).read(recentProvider).first, 3);
    });

    test('notes persist, trim and can be cleared', () async {
      final prefs = await mockPrefs();
      final c = makeContainer(prefs);
      final n = c.read(notesProvider.notifier);
      n.setNote(25, '  likes apples  ');
      expect(restart(prefs).read(notesProvider)[25], 'likes apples');
      n.setNote(25, '   ');
      expect(restart(prefs).read(notesProvider), isEmpty);
    });
  });

  group('collections', () {
    test(
      'CRUD persists and membership is separate from Pokémon data',
      () async {
        final prefs = await mockPrefs();
        final c = makeContainer(prefs);
        final n = c.read(collectionsProvider.notifier);
        final id = n.create('  Water ideas ');
        expect(n.add(id, 7), isTrue);
        expect(n.add(id, 7), isFalse);
        expect(n.add('missing', 7), isFalse);
        n.add(id, 9);
        expect(n.remove(id, 7), isTrue);
        expect(n.remove(id, 7), isFalse);
        n.rename(id, 'Starters');

        final again = restart(prefs).read(collectionsProvider);
        expect(again.single.name, 'Starters');
        expect(again.single.ids, [9]);

        n.delete(id);
        expect(restart(prefs).read(collectionsProvider), isEmpty);
      },
    );

    test('blank names get a default and blank renames are ignored', () async {
      final prefs = await mockPrefs();
      final c = makeContainer(prefs);
      final n = c.read(collectionsProvider.notifier);
      final id = n.create('   ');
      expect(c.read(collectionsProvider).single.name, 'Untitled collection');
      n.rename(id, '  ');
      expect(c.read(collectionsProvider).single.name, 'Untitled collection');
    });

    test('ids stay unique even when created back to back', () async {
      final prefs = await mockPrefs();
      final c = makeContainer(prefs);
      final n = c.read(collectionsProvider.notifier);
      final ids = {for (var i = 0; i < 20; i++) n.create('c$i')};
      expect(ids.length, 20);
    });
  });

  group('teams', () {
    test('a team holds at most six unique members and persists', () async {
      final prefs = await mockPrefs();
      final c = makeContainer(prefs);
      final n = c.read(teamsProvider.notifier);
      final id = n.create('Main');
      for (var i = 1; i <= 6; i++) {
        expect(n.addMember(id, i), isTrue);
      }
      expect(n.addMember(id, 7), isFalse);
      expect(n.addMember(id, 1), isFalse);
      expect(restart(prefs).read(teamsProvider).single.members, [
        1,
        2,
        3,
        4,
        5,
        6,
      ]);
    });

    test('rename, duplicate, remove member and delete', () async {
      final prefs = await mockPrefs();
      final c = makeContainer(prefs);
      final n = c.read(teamsProvider.notifier);
      final id = n.create('A');
      n.addMember(id, 25);
      n.rename(id, 'Alpha');
      final copyId = n.duplicate(id)!;
      n.removeMember(id, 25);
      final teams = restart(prefs).read(teamsProvider);
      expect(teams.firstWhere((t) => t.id == id).members, isEmpty);
      final copy = teams.firstWhere((t) => t.id == copyId);
      expect(copy.name, 'Alpha copy');
      expect(copy.members, [25]);
      expect(n.duplicate('nope'), isNull);

      n.delete(id);
      expect(restart(prefs).read(teamsProvider).map((t) => t.id), [copyId]);
    });
  });

  group('profile', () {
    test('defaults, edits and showcase persist', () async {
      final prefs = await mockPrefs();
      final c = makeContainer(prefs);
      expect(c.read(profileProvider).nickname, 'Trainer');
      final n = c.read(profileProvider.notifier);
      n.setNickname('  Ash  ');
      n.setAccent(3);
      n.setAvatar(25);
      n.setThemeMode(ThemeMode.light);
      for (var i = 1; i <= kShowcaseSize; i++) {
        expect(n.toggleShowcase(i), isTrue);
      }
      expect(n.toggleShowcase(99), isFalse);
      n.reorderShowcase(0, 3);

      final p = restart(prefs).read(profileProvider);
      expect(p.nickname, 'Ash');
      expect(p.accentIndex, 3);
      expect(p.avatarId, 25);
      expect(p.themeMode, ThemeMode.light);
      expect(p.showcase, [2, 3, 1, 4, 5, 6]);
    });

    test(
      'blank nickname falls back and invalid stored values are sanitised',
      () async {
        final prefs = await mockPrefs({
          'profile.v1':
              '{"nick":"","accent":99,"avatar":"x","showcase":[1,"a"],"theme":"nope"}',
        });
        final p = makeContainer(prefs).read(profileProvider);
        expect(p.nickname, 'Trainer');
        expect(p.accentIndex, 0);
        expect(p.avatarId, isNull);
        expect(p.showcase, [1]);
        expect(p.themeMode, ThemeMode.dark);
      },
    );
  });
}
