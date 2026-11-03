import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokepod/app/app.dart';
import 'package:pokepod/app/design_system/widgets.dart';
import 'package:pokepod/core/storage/local_store.dart';
import 'package:pokepod/data/providers.dart';
import 'package:pokepod/domain/achievements.dart';
import 'package:pokepod/domain/research_rules.dart';
import 'package:pokepod/features/mystery/mystery_controller.dart';
import 'package:pokepod/features/research/research_controller.dart';
import 'package:pokepod/features/trainer_profile/achievement_unlocks.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/support.dart';

AchievementInput _input({
  int discovered = 0,
  int studied = 0,
  int mastered = 0,
  Set<int> ids = const {},
  int bestStreak = 0,
}) {
  return AchievementInput(
    discovered: discovered,
    studied: studied,
    mastered: mastered,
    favourites: 0,
    largestCollection: 0,
    collections: 0,
    largestTeam: 0,
    mysteryWins: 0,
    bestStreak: bestStreak,
    discoveredIds: ids,
    notes: 0,
  );
}

List<Achievement> _achievements({
  int discovered = 0,
  int studied = 0,
  int mastered = 0,
  Set<int> ids = const {},
  int bestStreak = 0,
}) {
  return computeAchievements(
    _input(
      discovered: discovered,
      studied: studied,
      mastered: mastered,
      ids: ids,
      bestStreak: bestStreak,
    ),
  );
}

/// Pumps the real app with a small catalogue and the artwork stub, the same
/// way the app tests do, and returns the scope so a test can drive providers.
Future<ProviderScope> _pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  final SharedPreferences store = await mockPrefs(prefs);
  final client = FakeApiClient({
    '$apiBase/pokemon?limit=1025&offset=0': catalogJson([
      (1, 'bulbasaur'),
      (4, 'charmander'),
      (25, 'pikachu'),
    ]),
    '$apiBase/pokemon/25': pokemonJson(),
    '$apiBase/pokemon-species/25': {
      'id': 25,
      'flavor_text_entries': [
        {
          'flavor_text': 'Stores electricity.',
          'language': {'name': 'en'},
        },
      ],
    },
  });
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final scope = ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(store),
      apiClientProvider.overrideWithValue(client),
      imageProviderFactoryProvider.overrideWithValue(
        (url) => MemoryImage(kTestPixel),
      ),
      todayKeyProvider.overrideWithValue('2026-10-21'),
    ],
    child: PokePodApp(splashDuration: Duration.zero),
  );
  await tester.pumpWidget(scope);
  await tester.pump(const Duration(milliseconds: 400));
  return scope;
}

Future<void> _settle(WidgetTester tester) async {
  // pumpAndSettle never returns: skeletons and progress indicators animate.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Lets the post-frame callback hand the unlock to the messenger, builds the
/// snackbar and lets its 250 ms entrance finish.
Future<void> _showSnack(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('unlock tracking', () {
    test('the first observation only records the baseline', () {
      final tracker = AchievementUnlocks();
      final alreadyEarned = _achievements(discovered: 25, mastered: 1);
      expect(alreadyEarned.where((a) => a.unlocked), isNotEmpty);

      expect(tracker.observe(alreadyEarned), isEmpty);
      expect(tracker.hasPending, isFalse);
      // Reading the same state again is still not an event.
      expect(tracker.observe(alreadyEarned), isEmpty);
      expect(tracker.hasPending, isFalse);
    });

    test('a real locked to unlocked transition is announced exactly once', () {
      final tracker = AchievementUnlocks();
      tracker.observe(_achievements());

      final fresh = tracker.observe(_achievements(discovered: 1));
      expect(fresh.map((a) => a.id), ['first_contact']);
      expect(tracker.queued, 1);
      expect(tracker.hasPending, isTrue);

      // The same state, or a change that unlocks nothing, never repeats it.
      expect(tracker.observe(_achievements(discovered: 1)), isEmpty);
      expect(tracker.observe(_achievements(discovered: 5)), isEmpty);
      expect(tracker.queued, 1);
    });

    test('several unlocks queue together without loss or duplicates', () {
      final tracker = AchievementUnlocks();
      tracker.observe(_achievements());

      final fresh = tracker.observe(
        _achievements(discovered: 25, mastered: 1, bestStreak: 3),
      );
      expect(
        fresh.map((a) => a.id),
        unorderedEquals([
          'first_contact',
          'field_researcher',
          'mastery',
          'streak_3',
        ]),
      );
      expect(tracker.queued, fresh.length);
      expect(fresh.toSet(), hasLength(fresh.length));

      // A later observation that unlocks nothing adds nothing.
      expect(
        tracker.observe(
          _achievements(discovered: 25, mastered: 1, bestStreak: 3),
        ),
        isEmpty,
      );
      expect(tracker.queued, fresh.length);
    });

    test('a re-locked achievement speaks again only when earned again', () {
      final tracker = AchievementUnlocks();
      tracker.observe(_achievements());
      tracker.observe(_achievements(discovered: 1));
      expect(tracker.queued, 1);

      // Correcting the log back down re-locks it: no announcement.
      expect(tracker.observe(_achievements()), isEmpty);
      expect(tracker.queued, 1);

      // Earning it a second time is a genuine transition.
      final again = tracker.observe(_achievements(discovered: 1));
      expect(again.map((a) => a.id), ['first_contact']);
      expect(tracker.queued, 2);
    });
  });

  group('unlock notifications', () {
    testWidgets('a launch with achievements already earned says nothing', (
      tester,
    ) async {
      // First Contact is already earned in the stored log: the first
      // observation is a baseline, not an event.
      await _pumpApp(tester, prefs: {'research.v1': '{"1": 1}'});
      await _settle(tester);

      expect(find.text('Achievement unlocked'), findsNothing);
      expect(find.text('First Contact'), findsNothing);
    });

    testWidgets('a real unlock announces title, rule and rarity', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _settle(tester);
      expect(find.text('Achievement unlocked'), findsNothing);

      final scope = ProviderScope.containerOf(
        tester.element(find.byType(PokePodApp)),
      );
      scope
          .read(researchProvider.notifier)
          .transition(1, ResearchState.discovered);
      await _showSnack(tester);

      expect(find.text('Achievement unlocked'), findsOneWidget);
      expect(find.text('First Contact'), findsOneWidget);
      expect(find.text('Discover your first Pokémon.'), findsOneWidget);
      expect(find.text('COMMON'), findsOneWidget);

      // Nothing else fires for the same transition.
      await _settle(tester);
      expect(find.text('Achievement unlocked'), findsOneWidget);
    });

    testWidgets('queued unlocks are shown one at a time', (tester) async {
      await _pumpApp(tester);
      await _settle(tester);

      final scope = ProviderScope.containerOf(
        tester.element(find.byType(PokePodApp)),
      );
      final research = scope.read(researchProvider.notifier);
      // Two real unlocks raised back to back: both must be announced, but
      // only one may be on screen at a time.
      research.transition(1, ResearchState.discovered); // First Contact
      research.transition(1, ResearchState.studied); // nothing new
      research.transition(1, ResearchState.mastered); // Mastery
      await _showSnack(tester);

      expect(find.text('First Contact'), findsOneWidget);
      expect(find.text('Mastery'), findsNothing);

      // Let the first snackbar time out and the second take its turn.
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('First Contact'), findsNothing);
      expect(find.text('Mastery'), findsOneWidget);
      expect(find.text('Master a Pokémon.'), findsOneWidget);
      expect(find.text('COMMON'), findsOneWidget);
    });
  });
}
