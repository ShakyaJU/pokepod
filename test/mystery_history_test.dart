import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokepod/app/design_system/widgets.dart';
import 'package:pokepod/app/theme/app_theme.dart';
import 'package:pokepod/app/theme/tokens.dart';
import 'package:pokepod/core/storage/local_store.dart';
import 'package:pokepod/core/utils/formatters.dart';
import 'package:pokepod/data/providers.dart';
import 'package:pokepod/domain/mystery_logic.dart';
import 'package:pokepod/features/mystery/mystery_controller.dart';
import 'package:pokepod/features/mystery/mystery_history.dart';
import 'package:pokepod/features/mystery/mystery_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/support.dart';

const _today = '2026-10-21';
final int _answer = mysteryAnswerId(_today);

/// A finished day: [won] days take [guesses] guesses, lost days always use the
/// full allowance, and every record carries its answer like real data does.
MysteryRecord _record({required bool won, int? guesses, int target = 25}) =>
    MysteryRecord(
      guesses: guesses ?? (won ? 2 : kMysteryMaxGuesses),
      won: won,
      target: target,
    );

/// [count] finished days ending on 2026-10-20 and walking backwards.
Map<String, MysteryRecord> _days(int count, {bool won = true}) => {
  for (var i = 0; i < count; i++)
    localDateKey(DateTime.utc(2026, 10, 20).subtract(Duration(days: i))):
        _record(won: won),
};

Future<void> _pump(
  WidgetTester tester,
  Map<String, MysteryRecord> history, {
  Brightness brightness = Brightness.dark,
  Size size = const Size(400, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(brightness, AppColors.emerald),
      // The section sits at the bottom of the game's scroll view, so the test
      // hosts it the same way.
      home: Scaffold(
        body: ListView(children: [MysteryHistory(history: history)]),
      ),
    ),
  );
  await tester.pump();
}

Finder get _header => find.text('History');
Finder get _showMore => find.textContaining('Show ');
Finder get _allShown => find.textContaining('days shown');

/// Expands the section. The first frame after a tap only starts the reveal
/// ticker (it sets the animation's start time), so a second frame is what
/// actually finishes it — without it the body stays clipped to zero height,
/// which also hides it from hit testing and semantics.
Future<void> _expand(WidgetTester tester) async {
  await tester.tap(_header);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _collapse(WidgetTester tester) async {
  await tester.tap(_header);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Pages the list one step further, scrolling the control into view first so
/// long histories can be walked through exactly like a user would.
Future<void> _pageFurther(WidgetTester tester) async {
  final control = _showMore;
  await tester.ensureVisible(control);
  await tester.pump();
  await tester.tap(control);
  await tester.pump();
}

void main() {
  group('MysteryHistory', () {
    testWidgets('an empty record shows only a quiet summary line', (
      tester,
    ) async {
      await _pump(tester, const {});
      expect(_header, findsOneWidget);
      expect(find.text('No days recorded yet.'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
      expect(_showMore, findsNothing);
    });

    testWidgets('collapsed by default: the summary, never the whole list', (
      tester,
    ) async {
      await _pump(tester, _days(12));

      expect(_header, findsOneWidget);
      expect(
        find.byType(ListTile),
        findsNothing,
        reason: 'no result rows are built until the user asks for them',
      );
      expect(
        find.text('12 days · 12 solved · last: solved in 2'),
        findsOneWidget,
      );
      // The expand affordance is present and announced as such.
      expect(find.byKey(const ValueKey('expandable-chevron')), findsOneWidget);
    });

    testWidgets('the summary counts come straight from the records', (
      tester,
    ) async {
      final history = <String, MysteryRecord>{
        '2026-10-20': _record(won: true),
        '2026-10-19': _record(won: false),
        '2026-10-18': _record(won: true),
      };
      await _pump(tester, history);

      expect(
        find.text('3 days · 2 solved · last: solved in 2'),
        findsOneWidget,
      );
      // Nothing here rewrites the tally: the map is untouched.
      expect(history, hasLength(3));
    });

    testWidgets('a single day expands to exactly that day, with no paging', (
      tester,
    ) async {
      await _pump(tester, _days(1));

      expect(find.text('1 day · 1 solved · last: solved in 2'), findsOneWidget);
      await _expand(tester);

      expect(find.byType(ListTile), findsOneWidget);
      expect(find.text('2026-10-20'), findsOneWidget);
      expect(_showMore, findsNothing, reason: 'nothing older to load');
      expect(_allShown, findsNothing, reason: 'no paging ever happened');
    });

    testWidgets('five or fewer entries need no paging control at all', (
      tester,
    ) async {
      await _pump(tester, _days(3));
      await _expand(tester);

      expect(find.byType(ListTile), findsNWidgets(3));
      expect(_showMore, findsNothing);
      expect(_allShown, findsNothing);
    });

    testWidgets('more than five entries load in fives, newest first', (
      tester,
    ) async {
      await _pump(tester, _days(12));
      await _expand(tester);

      expect(find.byType(ListTile), findsNWidgets(kMysteryHistoryPageSize));
      expect(find.text('Show 7 older days'), findsOneWidget);

      await _pageFurther(tester);
      expect(find.byType(ListTile), findsNWidgets(10));
      expect(find.text('Show 2 older days'), findsOneWidget);

      await _pageFurther(tester);
      expect(find.byType(ListTile), findsNWidgets(12));
      expect(_showMore, findsNothing);
      expect(
        find.text('All 12 days shown'),
        findsOneWidget,
        reason: 'the end of a paged list says so',
      );
    });

    testWidgets('the newest entries are listed first whatever the order', (
      tester,
    ) async {
      final history = <String, MysteryRecord>{
        '2026-10-01': _record(won: true),
        '2026-10-19': _record(won: false),
        '2026-10-05': _record(won: true),
        '2026-10-20': _record(won: true),
      };
      await _pump(tester, history);
      await _expand(tester);

      expect(
        tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList(),
        containsAllInOrder([
          '2026-10-20',
          '2026-10-19',
          '2026-10-05',
          '2026-10-01',
        ]),
      );
    });

    testWidgets('solved and unsolved days are told apart', (tester) async {
      final handle = tester.ensureSemantics();
      final theme = AppTheme.build(Brightness.dark, AppColors.emerald);
      final history = <String, MysteryRecord>{
        '2026-10-20': _record(won: true, guesses: 3),
        '2026-10-19': _record(won: false),
      };
      await _pump(tester, history);
      await _expand(tester);

      final solved = tester.widget<Icon>(
        find.byIcon(Icons.check_circle_outline),
      );
      expect(solved.color, theme.colorScheme.primary);
      expect(
        find.bySemanticsLabel(RegExp(r'^Solved\n2026-10-20\n3/6$')),
        findsOneWidget,
        reason: 'the row is announced as one tappable result',
      );

      final missed = tester.widget<Icon>(find.byIcon(Icons.cancel_outlined));
      expect(missed.color, theme.colorScheme.error);
      expect(
        find.bySemanticsLabel(RegExp(r'^Not solved\n2026-10-19\n6/6$')),
        findsOneWidget,
      );

      expect(find.text('3/6'), findsOneWidget);
      expect(find.text('6/6'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a record without a stored answer is listed but not tappable', (
      tester,
    ) async {
      final history = <String, MysteryRecord>{
        '2026-10-20': MysteryRecord(guesses: 2, won: true),
        '2026-10-19': _record(won: true, target: 25),
      };
      await _pump(tester, history);
      await _expand(tester);

      final rows = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      expect(rows, hasLength(2));
      expect(rows[0].onTap, isNull, reason: 'legacy record: no answer stored');
      expect(rows[1].onTap, isNotNull, reason: 'opens that day\'s dossier');
    });

    testWidgets('collapsing hides the list; reopening keeps the paging', (
      tester,
    ) async {
      await _pump(tester, _days(12));
      await _expand(tester);
      await _pageFurther(tester);
      expect(find.byType(ListTile), findsNWidgets(10));

      await _collapse(tester);
      expect(find.byType(ListTile), findsNothing);

      await _expand(tester);
      expect(
        find.byType(ListTile),
        findsNWidgets(10),
        reason: 'the entries the user asked for are not thrown away',
      );
    });

    testWidgets('a very long history stays compact and stays reachable', (
      tester,
    ) async {
      final history = _days(250);
      await _pump(tester, history);

      expect(find.byType(ListTile), findsNothing);
      expect(
        find.text('250 days · 250 solved · last: solved in 2'),
        findsOneWidget,
      );

      await _expand(tester);
      expect(find.byType(ListTile), findsNWidgets(kMysteryHistoryPageSize));

      var guard = 0;
      while (_showMore.evaluate().isNotEmpty && guard < 60) {
        await _pageFurther(tester);
        guard++;
      }
      expect(
        find.byType(ListTile),
        findsNWidgets(250),
        reason: 'every stored day can be paged through',
      );
      expect(find.text('All 250 days shown'), findsOneWidget);
      expect(history, hasLength(250), reason: 'nothing was dropped');
    });

    testWidgets('the records themselves are never modified', (tester) async {
      final history = <String, MysteryRecord>{
        '2026-10-20': _record(won: true, guesses: 1, target: 7),
        '2026-10-19': _record(won: false, target: 8),
        '2026-10-18': MysteryRecord(guesses: 5, won: true),
      };
      final before = {
        for (final e in history.entries)
          e.key: (e.value.guesses, e.value.won, e.value.target),
      };

      await _pump(tester, history);
      await _expand(tester);
      await _collapse(tester);
      await _expand(tester);

      final after = {
        for (final e in history.entries)
          e.key: (e.value.guesses, e.value.won, e.value.target),
      };
      expect(after, before);
      expect(history, hasLength(3));
    });

    testWidgets('it renders in both light and dark themes', (tester) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        final theme = AppTheme.build(brightness, AppColors.emerald);
        await _pump(tester, _days(2), brightness: brightness);

        expect(_header, findsOneWidget);
        expect(
          find.text('2 days · 2 solved · last: solved in 2'),
          findsOneWidget,
        );

        await _expand(tester);
        final solved = tester.widget<Icon>(
          find.byIcon(Icons.check_circle_outline).first,
        );
        expect(
          solved.color,
          theme.colorScheme.primary,
          reason: 'the accent follows the active theme',
        );
        await _collapse(tester);
      }
    });

    testWidgets('a small screen shows the section without overflowing', (
      tester,
    ) async {
      await _pump(
        tester,
        _days(12),
        brightness: Brightness.light,
        size: const Size(320, 640),
      );
      await _expand(tester);

      // A RenderFlex overflow would have failed the test already.
      expect(find.byType(ListTile), findsNWidgets(kMysteryHistoryPageSize));
      expect(find.text('Show 7 older days'), findsOneWidget);
    });
  });

  group('the game screen', () {
    Future<void> pumpGame(WidgetTester tester, String stored) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'mystery.v1': stored});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            todayKeyProvider.overrideWithValue(_today),
            apiClientProvider.overrideWithValue(
              FakeApiClient({
                '$apiBase/pokemon?limit=1025&offset=0': catalogJson([
                  (25, 'pikachu'),
                  (_answer, 'testmon'),
                ]),
                '$apiBase/pokemon/$_answer': pokemonJson(
                  id: _answer,
                  name: 'testmon',
                ),
              }),
            ),
            imageProviderFactoryProvider.overrideWithValue(
              (url) => MemoryImage(kTestPixel),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.build(Brightness.dark, AppColors.emerald),
            home: const MysteryPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
    }

    String storedFor(int count) => jsonEncode({
      'v': 2,
      'history': {
        for (var i = 0; i < count; i++)
          localDateKey(DateTime.utc(2026, 10, 20).subtract(Duration(days: i))):
              {'g': 2, 'w': true, 't': 25},
      },
      'active': _today,
      'target': _answer,
      'guesses': <int>[],
      'seen': _today,
    });

    testWidgets('the history starts collapsed instead of filling the screen', (
      tester,
    ) async {
      await pumpGame(tester, storedFor(12));

      expect(find.text('History'), findsOneWidget);
      expect(
        find.byType(ListTile),
        findsNothing,
        reason: 'the screen is about today\'s challenge, not the backlog',
      );
      expect(
        find.text('12 days · 12 solved · last: solved in 2'),
        findsOneWidget,
      );
      // The rest of the screen is untouched. (SectionLabel uppercases.)
      expect(find.text('YOUR RECORD'), findsOneWidget);
      expect(find.text('Make a guess'), findsOneWidget);
    });

    testWidgets('every stored day survives using the section', (tester) async {
      final stored = storedFor(12);
      await pumpGame(tester, stored);

      await tester.tap(find.text('History'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ListTile), findsNWidgets(kMysteryHistoryPageSize));

      final prefs = await SharedPreferences.getInstance();
      final saved =
          jsonDecode(prefs.getString('mystery.v1')!) as Map<String, dynamic>;
      final history = (saved['history'] as Map<String, dynamic>);
      expect(
        history.keys,
        jsonDecode(stored)['history'].keys,
        reason: 'every day is still on disk, unchanged',
      );
      expect(history['2026-10-20'], {'g': 2, 'w': true, 't': 25});
    });

    testWidgets('a day still in progress is not listed as a result', (
      tester,
    ) async {
      // Only yesterday is finished; today is open, so the list must not show
      // today as a result and the summary counts only what is recorded.
      await pumpGame(tester, storedFor(1));

      expect(find.text('History'), findsOneWidget);
      expect(find.text('1 day · 1 solved · last: solved in 2'), findsOneWidget);
      await tester.tap(find.text('History'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final rows = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      expect(rows, hasLength(1), reason: 'today is still being played');
      expect(
        (rows.single.title! as Text).data,
        '2026-10-20',
        reason: 'only finished days are results',
      );
    });
  });
}
