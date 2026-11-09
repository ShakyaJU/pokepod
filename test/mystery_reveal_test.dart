import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokepod/app/design_system/widgets.dart';
import 'package:pokepod/app/theme/app_theme.dart';
import 'package:pokepod/app/theme/tokens.dart';
import 'package:pokepod/core/storage/local_store.dart';
import 'package:pokepod/data/providers.dart';
import 'package:pokepod/features/mystery/mystery_controller.dart';
import 'package:pokepod/features/mystery/mystery_page.dart';
import 'package:pokepod/features/mystery/reveal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/support.dart';
import 'package:pokepod/domain/mystery_logic.dart';

const _today = '2026-10-21';
final int _answer = mysteryAnswerId(_today);

/// [n] guesses that are not the answer.
List<int> _wrong(int n) => [
  for (var i = 1; i <= n + 1; i++)
    if (i != _answer) i,
].take(n).toList();

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
}

Future<void> _pumpPage(WidgetTester tester, {String? stored}) async {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({
    if (stored != null) 'mystery.v1': stored,
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        todayKeyProvider.overrideWithValue(_today),
        apiClientProvider.overrideWithValue(
          FakeApiClient({
            '$apiBase/pokemon?limit=1025&offset=0': catalogJson([
              (5, 'charmeleon'),
              (6, 'charizard'),
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
  await _settle(tester);
}

Finder get _question => find.byKey(const ValueKey('mystery-question'));
Finder get _silhouette =>
    find.byKey(const ValueKey('mystery-picture-silhouette'));
Finder get _colour => find.byKey(const ValueKey('mystery-picture-colour'));
Finder get _final => find.byKey(const ValueKey('mystery-final'));

String _active(List<int> guesses) =>
    '{"v":2,"history":{},"active":"$_today","target":$_answer,"guesses":[${guesses.join(',')}],"seen":"$_today"}';

void main() {
  group('revealStageFor', () {
    test(
      'nothing is shown before the first guess, then it only gets clearer',
      () {
        expect(revealStageFor(0).showImage, isFalse);

        final sigmas = [
          for (var n = 1; n <= 4; n++) revealStageFor(n).blurSigma,
        ];
        expect(sigmas, [22, 13, 6, 0]);
        for (var n = 1; n <= 4; n++) {
          expect(revealStageFor(n).showImage, isTrue);
          expect(
            revealStageFor(n).colour,
            isFalse,
            reason: 'stages 1-4 are silhouettes',
          );
        }

        final last = revealStageFor(5);
        expect(last.colour, isTrue);
        expect(last.blurSigma, lessThan(revealStageFor(3).blurSigma));
        expect(last.saturation, inExclusiveRange(0, 1));
      },
    );

    test(
      'out-of-range guess counts are clamped, never beyond the last attempt',
      () {
        expect(revealStageFor(-3).index, 0);
        expect(revealStageFor(9).index, 5);
        expect(revealStageFor(6).index, 5);
      },
    );

    test('stage indexes are consecutive', () {
      expect(
        [for (var n = 0; n <= 5; n++) revealStageFor(n).index],
        [0, 1, 2, 3, 4, 5],
      );
    });

    test('saturation matrix: 1 keeps colours, 0 gives luminance greyscale', () {
      final same = saturationMatrix(1);
      expect(same.sublist(0, 5), [1, 0, 0, 0, 0]);
      final grey = saturationMatrix(0);
      expect(grey[0], closeTo(0.2126, 1e-9));
      expect(grey[5], closeTo(0.2126, 1e-9));
      expect(grey[10], closeTo(0.2126, 1e-9));
      expect(grey.length, 20);
    });
  });

  group('the picture on the page', () {
    testWidgets('starts as a plain "?" and does not load or show any artwork', (
      tester,
    ) async {
      await _pumpPage(tester);
      expect(_question, findsOneWidget);
      expect(_silhouette, findsNothing);
      expect(_colour, findsNothing);
      expect(_final, findsNothing);
      expect(find.byType(ImageFiltered), findsNothing);
      expect(find.text('6 GUESSES LEFT'), findsOneWidget);
    });

    testWidgets(
      'each wrong guess advances the picture and reopening does not advance it further',
      (tester) async {
        await _pumpPage(tester, stored: _active(_wrong(2)));
        expect(_question, findsNothing);
        expect(_silhouette, findsOneWidget);
        expect(
          find.byType(ImageFiltered),
          findsOneWidget,
          reason: 'stage 2 is still blurred',
        );
        expect(find.text('4 GUESSES LEFT'), findsOneWidget);

        // Rebuilding the same state shows the same stage.
        await _pumpPage(tester, stored: _active(_wrong(2)));
        expect(_silhouette, findsOneWidget);
        expect(_colour, findsNothing);
      },
    );

    testWidgets('the fourth wrong guess is a sharp silhouette', (tester) async {
      await _pumpPage(tester, stored: _active(_wrong(4)));
      expect(_silhouette, findsOneWidget);
      expect(
        find.byType(ImageFiltered),
        findsNothing,
        reason: 'no blur at stage 4',
      );
    });

    testWidgets(
      'the last attempt shows the artwork in muted colour and says one guess is left',
      (tester) async {
        await _pumpPage(tester, stored: _active(_wrong(5)));
        expect(_colour, findsOneWidget);
        expect(_silhouette, findsNothing);
        expect(_final, findsNothing, reason: 'the day is not over yet');
        expect(find.text('1 GUESS LEFT'), findsOneWidget);
        expect(find.text('Make a guess'), findsOneWidget);
      },
    );

    testWidgets(
      'a won day shows the result, the full artwork and no way to keep playing',
      (tester) async {
        await _pumpPage(
          tester,
          stored:
              '{"v":2,"history":{"$_today":{"g":3,"w":true,"t":$_answer}},"active":"$_today","target":$_answer,"guesses":[${_wrong(2).join(',')},$_answer],"seen":"$_today"}',
        );
        expect(_final, findsOneWidget);
        expect(_question, findsNothing);
        expect(_silhouette, findsNothing);
        expect(find.text('?'), findsNothing);
        expect(find.text('Solved in 3 guesses!'), findsOneWidget);
        expect(find.text('Make a guess'), findsNothing);
        expect(find.text('COMPLETE'), findsOneWidget);
      },
    );

    testWidgets(
      'a lost day is game over: the answer is revealed and guessing is disabled',
      (tester) async {
        await _pumpPage(
          tester,
          stored:
              '{"v":2,"history":{"$_today":{"g":6,"w":false,"t":$_answer}},"active":"$_today","target":$_answer,"guesses":[${_wrong(6).join(',')}],"seen":"$_today"}',
        );
        expect(find.text('Game over'), findsOneWidget);
        expect(find.textContaining('You used all 6 guesses'), findsOneWidget);
        expect(
          find.textContaining('Testmon'),
          findsOneWidget,
          reason: 'the answer is shown after a loss',
        );
        expect(_final, findsOneWidget);
        expect(find.text('Make a guess'), findsNothing);
        expect(
          find.textContaining('new Pokémon arrives at midnight'),
          findsOneWidget,
        );
        expect(find.text('COMPLETE'), findsOneWidget);
      },
    );

    testWidgets('a new day starts hidden again even if yesterday had guesses', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        stored:
            '{"v":2,"history":{},"active":"2026-10-20","target":5,"guesses":[1,2,3,4,5],"seen":"2026-10-20"}',
      );
      expect(_question, findsOneWidget);
      expect(_colour, findsNothing);
      expect(find.text('6 GUESSES LEFT'), findsOneWidget);
    });

    testWidgets('nothing before the answer is earned names the Pokémon', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpPage(tester, stored: _active(_wrong(1)));
      expect(find.textContaining('Testmon'), findsNothing);
      expect(find.textContaining('testmon'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('Mystery Pokémon, stage 1 of 5')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('testmon', caseSensitive: false)),
        findsNothing,
      );
      handle.dispose();
    });

    testWidgets('the page uses the new name', (tester) async {
      await _pumpPage(tester);
      expect(find.text('Who\'s That Pokémon?'), findsOneWidget);
      expect(find.text('Mystery Specimen'), findsNothing);
    });

    testWidgets(
      'opening the page saves today\'s answer so it cannot change later',
      (tester) async {
        await _pumpPage(tester);
        final stored = (await SharedPreferences.getInstance()).getString(
          'mystery.v1',
        );
        expect(stored, isNotNull);
        expect(stored, contains('"target":$_answer'));
        expect(stored, contains('"seen":"$_today"'));
      },
    );
  });

  group('the order of the game', () {
    testWidgets('Make a guess sits above the clues it unlocks', (tester) async {
      await _pumpPage(tester);
      // Tall enough to build the whole page, so the order can be read off the
      // positions rather than by chasing sections through a scroll.
      tester.view.physicalSize = const Size(900, 4000);
      tester.view.devicePixelRatio = 1.0;
      await tester.pump();

      final reveal = find.byType(MysteryReveal);
      final guess = find.text('Make a guess');
      // SectionLabel upper-cases whatever it is given.
      final clues = find.text('CLUES');
      final record = find.text('YOUR RECORD');

      expect(reveal, findsOneWidget);
      expect(guess, findsOneWidget);
      expect(clues, findsOneWidget);
      expect(record, findsOneWidget);

      final order = [
        tester.getTopLeft(reveal).dy,
        tester.getTopLeft(guess).dy,
        tester.getTopLeft(clues).dy,
        tester.getTopLeft(record).dy,
      ];

      expect(
        order,
        [...order]..sort(),
        reason:
            'the silhouette, then the guess control, then the clues it '
            'unlocks, and the record last',
      );
    });
  });
}
