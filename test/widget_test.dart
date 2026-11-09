import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokepod/app/app.dart';
import 'package:pokepod/app/design_system/widgets.dart';
import 'package:pokepod/core/audio/sound_service.dart';
import 'package:pokepod/core/errors/app_exception.dart';
import 'package:pokepod/core/storage/local_store.dart';
import 'package:pokepod/data/providers.dart';
import 'package:pokepod/features/pokedex/pokemon_tiles.dart';
import 'package:pokepod/features/mystery/mystery_controller.dart';
import 'package:pokepod/features/onboarding/onboarding_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/support.dart';

// A valid 1x1 transparent PNG so artwork never touches the network in tests.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

Future<FakeApiClient> pumpApp(
  WidgetTester tester, {
  Map<String, Object>? prefsValues,
  Duration splash = Duration.zero,
  SoundBackend? soundBackend,
}) async {
  // Every pump here is an established install. The first-run introduction is
  // a flow of its own with its own tests; without this flag a genuinely new
  // installation would be pushed through it and cover the app underneath.
  SharedPreferences.setMockInitialValues({
    kOnboardingStorageKey: true,
    ...?prefsValues,
  });
  final prefs = await SharedPreferences.getInstance();
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

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiClientProvider.overrideWithValue(client),
        imageProviderFactoryProvider.overrideWithValue(
          (url) => MemoryImage(_png),
        ),
        todayKeyProvider.overrideWithValue('2026-10-21'),
        if (soundBackend != null)
          soundBackendProvider.overrideWithValue(soundBackend),
      ],
      child: PokePodApp(splashDuration: splash),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  return client;
}

/// A destination label inside the bottom navigation bar only (several pages
/// reuse words such as "Lab" or "Pokédex" in their own headings).
Finder nav(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Future<void> settle(WidgetTester tester) async {
  // pumpAndSettle would never return: skeletons and progress indicators animate forever.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('shows the five primary destinations', (tester) async {
    await pumpApp(tester);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    for (final label in [
      'Discover',
      'Pokédex',
      'Lab',
      'Collections',
      'Profile',
    ]) {
      expect(nav(label), findsOneWidget);
    }
    expect(find.textContaining('Trainer'), findsWidgets);
    expect(find.text('RESEARCH DEVICE ONLINE'), findsOneWidget);
  });

  testWidgets('a new user sees helpful empty states on Discover', (
    tester,
  ) async {
    await pumpApp(tester);
    await settle(tester);
    expect(find.textContaining('log your first discovery'), findsOneWidget);
    expect(find.text('Who\'s That Pokémon?'), findsOneWidget);
  });

  testWidgets('Pokédex lists catalogue entries and filters by search', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(nav('Pokédex'));
    await settle(tester);

    expect(find.text('Search name or number'), findsOneWidget);
    expect(find.text('Bulbasaur'), findsOneWidget);
    expect(find.text('Charmander'), findsOneWidget);
    expect(find.text('3 matching'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'char');
    await settle(tester);
    expect(find.text('Bulbasaur'), findsNothing);
    expect(find.text('Charmander'), findsOneWidget);
    expect(find.text('1 matching'), findsOneWidget);
    expect(find.text('Clear filters'), findsWidgets);
  });

  testWidgets('no-match search shows an empty state with a way out', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(nav('Pokédex'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'zzzz');
    await settle(tester);
    expect(find.text('No Pokémon match'), findsOneWidget);
    expect(find.text('0 matching'), findsOneWidget);
  });

  testWidgets('favouriting from the grid updates the Favourites filter', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(nav('Pokédex'));
    await settle(tester);

    await tester.tap(
      find
          .descendant(
            of: find.byType(PokemonGridTile),
            matching: find.byIcon(Icons.favorite_border),
          )
          .first,
    );
    await tester.pump();
    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });

  testWidgets('system back from another tab returns to Discover first', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(nav('Lab'));
    await settle(tester);
    expect(find.text('Team Architect'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('RESEARCH DEVICE ONLINE'), findsOneWidget);
    expect(find.text('Team Architect').hitTestable(), findsNothing);
  });

  testWidgets('opening a dossier shows real data and logs the discovery', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(nav('Pokédex'));
    await settle(tester);
    await tester.tap(find.text('Pikachu'));
    await settle(tester);

    expect(find.text('Base stats'.toUpperCase()), findsOneWidget);
    expect(find.text('Stores electricity.'), findsOneWidget);
    expect(find.text('Electric'), findsWidgets);
    expect(find.text('Discovered'), findsWidgets);
  });

  testWidgets('network failure on the catalogue offers a retry', (
    tester,
  ) async {
    // An established install: the first-run introduction is out of scope here.
    SharedPreferences.setMockInitialValues({kOnboardingStorageKey: true});
    final prefs = await SharedPreferences.getInstance();
    final client = FakeApiClient({
      '$apiBase/pokemon?limit=1025&offset=0': const AppException(
        AppErrorKind.network,
        'down',
      ),
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          apiClientProvider.overrideWithValue(client),
          imageProviderFactoryProvider.overrideWithValue(
            (url) => MemoryImage(_png),
          ),
        ],
        child: const PokePodApp(splashDuration: Duration.zero),
      ),
    );
    await tester.tap(nav('Pokédex'));
    await settle(tester);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('Could not reach PokéAPI'), findsOneWidget);
  });

  group('swipe navigation', () {
    int selected(WidgetTester tester) =>
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

    double? page(WidgetTester tester) =>
        tester.widget<PageView>(find.byType(PageView)).controller?.page;

    testWidgets(
      'swiping left and right walks through all five sections in order',
      (tester) async {
        await pumpApp(tester);
        expect(selected(tester), 0);

        for (var expected = 1; expected <= 4; expected++) {
          await tester.fling(
            find.byType(PageView),
            const Offset(-700, 0),
            2000,
          );
          await settle(tester);
          await tester.pump(const Duration(milliseconds: 400));
          expect(
            selected(tester),
            expected,
            reason: 'after swipe left #$expected',
          );
          expect(page(tester), closeTo(expected.toDouble(), 0.01));
        }

        // Already on the last section: another swipe must not go anywhere.
        await tester.fling(find.byType(PageView), const Offset(-700, 0), 2000);
        await settle(tester);
        expect(selected(tester), 4);

        for (var expected = 3; expected >= 0; expected--) {
          await tester.fling(find.byType(PageView), const Offset(700, 0), 2000);
          await settle(tester);
          await tester.pump(const Duration(milliseconds: 400));
          expect(
            selected(tester),
            expected,
            reason: 'after swipe right to $expected',
          );
        }
      },
    );

    testWidgets('bottom bar taps move the pager and stay in sync with swipes', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(nav('Lab'));
      await settle(tester);
      expect(selected(tester), 2);
      expect(page(tester), closeTo(2, 0.01));
      expect(find.text('Team Architect'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(700, 0), 2000);
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(selected(tester), 1);
      expect(find.text('Search name or number'), findsOneWidget);

      await tester.tap(nav('Profile'));
      await settle(tester);
      expect(selected(tester), 4);
      expect(page(tester), closeTo(4, 0.01));
    });

    testWidgets('each section keeps its state while you swipe away and back', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(nav('Pokédex'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'char');
      await settle(tester);
      expect(find.text('1 matching'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(-700, 0), 2000);
      await settle(tester);
      await tester.fling(find.byType(PageView), const Offset(700, 0), 2000);
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 400));

      expect(selected(tester), 1);
      expect(find.text('1 matching'), findsOneWidget);
      expect(find.text('char'), findsOneWidget);
    });
  });

  group('Pokédex sorting', () {
    Future<void> openSort(WidgetTester tester) async {
      await tester.tap(find.text('SORT BY'));
      await settle(tester);
    }

    testWidgets(
      'the sort control is separate from the filters and shows order and direction',
      (tester) async {
        await pumpApp(tester);
        await tester.tap(nav('Pokédex'));
        await settle(tester);

        expect(find.text('FILTER'), findsOneWidget);
        expect(find.text('SORT BY'), findsOneWidget);
        expect(find.text('Pokédex number · Lowest first'), findsOneWidget);
        // Reset only appears once the order differs from the default.
        expect(find.byTooltip('Reset sort to Pokédex number'), findsNothing);
      },
    );

    testWidgets(
      'choosing a property and direction reorders results and keeps the search',
      (tester) async {
        await pumpApp(tester);
        await tester.tap(nav('Pokédex'));
        await settle(tester);

        double x(String name) => tester.getTopLeft(find.text(name)).dx;
        expect(x('Bulbasaur'), lessThan(x('Pikachu')));

        await openSort(tester);
        for (final group in ['IDENTITY', 'CLASSIFICATION', 'MEASUREMENTS']) {
          expect(find.text(group), findsOneWidget, reason: group);
        }
        await tester.tap(find.byKey(const ValueKey('sort-name')));
        await settle(tester);
        expect(find.text('Name · A → Z'), findsOneWidget);

        await tester.tap(find.text('Z → A'));
        await settle(tester);
        expect(find.text('Name · Z → A'), findsOneWidget);
        expect(x('Pikachu'), lessThan(x('Bulbasaur')));

        await tester.tap(find.text('Reset'));
        await settle(tester);
        expect(find.text('Pokédex number · Lowest first'), findsOneWidget);
        expect(x('Bulbasaur'), lessThan(x('Pikachu')));
      },
    );

    testWidgets('changing the sort does not reset search or filters', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(nav('Pokédex'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'char');
      await settle(tester);
      expect(find.text('1 matching'), findsOneWidget);

      await openSort(tester);
      await tester.tap(find.byKey(const ValueKey('sort-name')));
      await settle(tester);
      await tester.tap(find.text('Done'));
      await settle(tester);

      expect(find.text('1 matching'), findsOneWidget);
      expect(find.text('Charmander'), findsOneWidget);
      expect(find.text('char'), findsOneWidget);
      expect(find.text('Name · A → Z'), findsOneWidget);
    });
  });

  group('launch splash', () {
    testWidgets('shows the supplied wordmark, then the app', (tester) async {
      await pumpApp(tester, splash: const Duration(milliseconds: 1400));

      bool isAsset(Widget w, String name) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == name;

      expect(
        find.byWidgetPredicate(
          (w) => isAsset(w, 'assets/branding/pokepod_splash_text.png'),
        ),
        findsOneWidget,
      );
      expect(find.byType(NavigationBar), findsNothing);
      expect(
        find.byType(LinearProgressIndicator),
        findsNothing,
        reason: 'the splash has no loading bar',
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => isAsset(w, 'assets/branding/pokepod_splash_text.png'),
        ),
        findsNothing,
      );
    });

    testWidgets('the app appears only once the splash sound has finished', (
      tester,
    ) async {
      final sound = FakeSoundBackend(autoComplete: false);
      await pumpApp(
        tester,
        splash: const Duration(milliseconds: 300),
        soundBackend: sound,
      );

      // The minimum splash time has passed and the catalogue is ready, but
      // the splash sound is still running: the shell must not appear yet.
      await tester.pump(const Duration(seconds: 1));
      expect(sound.playedToCompletion, [Sfx.splash]);
      expect(
        find.byType(NavigationBar),
        findsNothing,
        reason: 'the main interface waits for the splash sound',
      );

      sound.finishSound(Sfx.splash);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(sound.playedToCompletion, [
        Sfx.splash,
      ], reason: 'the splash sound is requested exactly once');
      expect(
        sound.played,
        isEmpty,
        reason: 'the splash never uses the plain play path',
      );
      expect(sound.preloaded, containsAll([Sfx.game, Sfx.correct, Sfx.error]));
    });
  });

  group("Who's That Pokémon? entry sound", () {
    testWidgets('exiting stops it at once and re-entering plays it again', (
      tester,
    ) async {
      final sound = FakeSoundBackend();
      await pumpApp(tester, soundBackend: sound);
      await settle(tester);

      await tester.tap(find.text('Who\'s That Pokémon?'));
      await settle(tester);
      expect(sound.played, [Sfx.game]);
      expect(
        sound.isPlaying(Sfx.game),
        isTrue,
        reason: 'still playing on entry',
      );

      // Leave immediately, while the entry sound would still be running.
      await tester.pageBack();
      await settle(tester);
      expect(
        find.text('Who\'s That Pokémon?'),
        findsOneWidget,
        reason: 'back on Discover',
      );
      expect(sound.stopped, [Sfx.game]);
      expect(sound.isPlaying(Sfx.game), isFalse);

      // A second visit plays the entry sound again, even moments later.
      await tester.tap(find.text('Who\'s That Pokémon?'));
      await settle(tester);
      expect(sound.played, [Sfx.game, Sfx.game]);

      // Letting it finish first means the exit sends no extra audio commands.
      sound.finishSound(Sfx.game);
      await tester.pageBack();
      await settle(tester);
      expect(sound.stopped, [
        Sfx.game,
      ], reason: 'no stop for a sound that already ended');
    });
  });
}
