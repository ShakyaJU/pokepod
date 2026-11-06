import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokepod/app/design_system/widgets.dart';
import 'package:pokepod/core/storage/local_store.dart';
import 'package:pokepod/core/utils/formatters.dart';
import 'package:pokepod/data/models/pokemon.dart';
import 'package:pokepod/data/providers.dart';
import 'package:pokepod/domain/generations.dart';
import 'package:pokepod/features/shared/pokemon_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/support.dart';

/// Opens the shared Pokémon picker over a catalogue holding the whole National
/// Pokédex, so a test can scroll, search and select exactly as the "Who's That
/// Pokémon?" guess flow does. [onOpen] receives the future the sheet resolves
/// with, so selection can be asserted end to end.
Future<void> _openPicker(
  WidgetTester tester, {
  Set<int> excluded = const {},
  void Function(Future<PokemonSummary?> result)? onOpen,
}) async {
  SharedPreferences.setMockInitialValues(const {});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiClientProvider.overrideWithValue(
          FakeApiClient({
            '$apiBase/pokemon?limit=$kNationalDexSize&offset=0': catalogJson([
              for (var id = 1; id <= kNationalDexSize; id++) (id, 'mon-$id'),
            ]),
          }),
        ),
        imageProviderFactoryProvider.overrideWithValue(
          (url) => MemoryImage(kTestPixel),
        ),
      ],
      child: MaterialApp(
        home: _PickerHost(excluded: excluded, onOpen: onOpen ?? _ignore),
      ),
    ),
  );
  await tester.pump();

  await tester.tap(find.text('Make a guess'));
  await tester.pump(); // the sheet starts opening
  await tester.pump(const Duration(milliseconds: 400)); // ...and lands
  await _waitFor(tester, find.byType(ListView));
}

void _ignore(Future<PokemonSummary?> result) {}

/// Pumps bounded frames until [finder] exists, so a build that never renders
/// fails fast instead of hanging the suite.
Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(finder, findsWidgets, reason: 'the picker never rendered its list.');
}

/// Drags the picker's list until [text] is on screen. Rows are built lazily,
/// so "found" means the row actually exists — an entry the list refuses to
/// reach is never built at all.
Future<void> _scrollTo(WidgetTester tester, String text) async {
  final target = find.text(text);
  final scrollable = find.descendant(
    of: find.byType(ListView),
    matching: find.byType(Scrollable),
  );
  for (var i = 0; i < 200 && target.evaluate().isEmpty; i++) {
    await tester.drag(scrollable, const Offset(0, -1000));
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(
    target,
    findsOneWidget,
    reason: '"$text" is never built while scrolling — the list stops early.',
  );
  await tester.ensureVisible(target);
  await tester.pump();
}

class _PickerHost extends StatelessWidget {
  const _PickerHost({required this.excluded, required this.onOpen});

  final Set<int> excluded;
  final void Function(Future<PokemonSummary?> result) onOpen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => onOpen(
            showPokemonPicker(context, title: 'Who is it?', excluded: excluded),
          ),
          child: const Text('Make a guess'),
        ),
      ),
    );
  }
}

void main() {
  group('the guess selection list offers the whole National Pokédex', () {
    testWidgets('every one of the 1,025 entries is on the list', (
      tester,
    ) async {
      await _openPicker(tester);

      final list = tester.widget<ListView>(find.byType(ListView));
      final delegate = list.childrenDelegate;
      expect(delegate, isA<SliverChildBuilderDelegate>());
      expect(
        (delegate as SliverChildBuilderDelegate).childCount,
        kNationalDexSize,
        reason: 'the list is built from the full catalogue, with no cap.',
      );
      expect(find.text('Mon 1'), findsOneWidget, reason: 'the dex starts here');

      // Lazy rendering: only the visible rows (plus a small cache) exist, so
      // offering all 1,025 does not mean building all 1,025.
      expect(
        find.byType(ListTile).evaluate().length,
        lessThan(60),
        reason: 'rows must still be built lazily.',
      );
    });

    testWidgets('scrolling reaches the final National Dex entry', (
      tester,
    ) async {
      await _openPicker(tester);
      expect(find.text('Mon 1025'), findsNothing, reason: 'it starts hidden');

      await _scrollTo(tester, 'Mon 1025');

      expect(find.text('Mon 1025'), findsOneWidget);
      expect(find.text(dexNumber(kNationalDexSize)), findsOneWidget);
    });

    testWidgets('scrolling reaches the middle of the dex as well', (
      tester,
    ) async {
      await _openPicker(tester);

      // First entry of Generation V, comfortably past any initial window.
      await _scrollTo(tester, 'Mon 494');

      expect(find.text('Mon 494'), findsOneWidget);
    });
  });

  group('searching the guess selection list', () {
    testWidgets('finds a Pokémon from every generation', (tester) async {
      await _openPicker(tester);
      final field = find.byType(TextField);

      final ids = [
        for (final (lo, _) in kGenerationRanges) lo,
        kNationalDexSize,
      ];
      expect(ids, hasLength(kGenerationRanges.length + 1));

      for (final id in ids) {
        await tester.enterText(field, '$id');
        await tester.pump();
        expect(
          find.text('Mon $id'),
          findsOneWidget,
          reason:
              '${generationLabel(generationOf(id)!)} (#$id) must be '
              'findable by its dex number.',
        );
      }
    });

    testWidgets('matches names and the #-prefixed number form', (tester) async {
      await _openPicker(tester);
      final field = find.byType(TextField);

      await tester.enterText(field, 'mon 905');
      await tester.pump();
      expect(find.text('Mon 905'), findsOneWidget, reason: 'spaced name');

      await tester.enterText(field, 'mon-1025');
      await tester.pump();
      expect(find.text('Mon 1025'), findsOneWidget, reason: 'hyphenated name');

      await tester.enterText(field, '#1025');
      await tester.pump();
      expect(find.text('Mon 1025'), findsOneWidget, reason: '#-prefixed id');
    });

    testWidgets('with no match shows an empty state, not a dead list', (
      tester,
    ) async {
      await _openPicker(tester);

      await tester.enterText(find.byType(TextField), 'not-a-pokemon');
      await tester.pump();

      expect(find.text('No matches'), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });
  });

  group('selecting from the guess list', () {
    testWidgets('returns the chosen Pokémon and closes the sheet', (
      tester,
    ) async {
      Future<PokemonSummary?>? pending;
      await _openPicker(tester, onOpen: (result) => pending = result);

      // A late entry, chosen only after it has been scrolled into view.
      await _scrollTo(tester, 'Mon 906');
      await tester.tap(find.text('Mon 906'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final picked = await pending;
      expect(picked, isNotNull);
      expect(picked!.id, 906);
      expect(picked.displayName, 'Mon 906');
      expect(find.byType(TextField), findsNothing, reason: 'sheet closed');
    });

    testWidgets('keeps already-guessed Pokémon out of the list', (
      tester,
    ) async {
      await _openPicker(tester, excluded: {906});

      await tester.enterText(find.byType(TextField), '906');
      await tester.pump();

      expect(find.text('Mon 906'), findsNothing);
      expect(find.text('No matches'), findsOneWidget);
    });
  });
}
