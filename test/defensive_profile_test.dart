import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokepod/app/design_system/widgets.dart';
import 'package:pokepod/app/theme/app_theme.dart';
import 'package:pokepod/app/theme/tokens.dart';
import 'package:pokepod/features/shared/defensive_profile.dart';

import 'widget_test.dart' as wt;

/// Renders one profile on its own, so the maths can be checked without the
/// dossier around it.
Future<void> pumpProfile(WidgetTester tester, List<String> types) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(Brightness.dark, AppColors.emerald),
      home: Scaffold(body: DefensiveProfile(types)),
    ),
  );
}

/// The top edge of the section whose label reads [title]. [SectionLabel]
/// renders its text upper-cased, so the lookup matches that.
double sectionTop(WidgetTester tester, String title) {
  final label = find.ancestor(
    of: find.text(title.toUpperCase()),
    matching: find.byType(SectionLabel),
  );
  expect(label, findsOneWidget, reason: 'exactly one "$title" section');
  return tester.getTopLeft(label).dy;
}

void main() {
  group('DefensiveProfile', () {
    testWidgets('reads a single type straight off the type chart', (
      tester,
    ) async {
      await pumpProfile(tester, const ['fire']);

      expect(find.text('WEAK TO'), findsOneWidget);
      expect(find.text('RESISTS'), findsOneWidget);
      expect(
        find.text('IMMUNE'),
        findsNothing,
        reason: 'fire is immune to nothing',
      );

      expect(find.text('Water ×2'), findsOneWidget);
      expect(find.text('Ground ×2'), findsOneWidget);
      expect(find.text('Rock ×2'), findsOneWidget);
      expect(find.text('Fire ×½'), findsOneWidget);
      expect(find.text('Grass ×½'), findsOneWidget);
    });

    testWidgets('multiplies dual typings instead of listing them separately', (
      tester,
    ) async {
      // Fire/flying: rock hits both for 2×, ground cannot touch it at all,
      // and fighting/grass/bug are resisted twice over.
      await pumpProfile(tester, const ['fire', 'flying']);

      expect(find.text('Rock ×4'), findsOneWidget);
      expect(find.text('Water ×2'), findsOneWidget);
      expect(find.text('Electric ×2'), findsOneWidget);
      expect(find.text('Ground ×0'), findsOneWidget, reason: 'immune');
      expect(find.text('Fighting ×½'), findsOneWidget);
      expect(find.text('Grass ×¼'), findsOneWidget);
      expect(find.text('Bug ×¼'), findsOneWidget);
      expect(find.text('IMMUNE'), findsOneWidget);
    });

    testWidgets('says so honestly when PokéAPI reported no types', (
      tester,
    ) async {
      await pumpProfile(tester, const []);

      expect(
        find.text('No type information is available for this Pokémon.'),
        findsOneWidget,
      );
      expect(find.text('WEAK TO'), findsNothing);
    });
  });

  group('the dossier', () {
    testWidgets('carries a Defense Profile between Moves and Evolution', (
      tester,
    ) async {
      // Tall enough that the whole dossier is built, so the sections can be
      // compared by position rather than by chasing them through a scroll.
      await wt.pumpApp(tester);
      tester.view.physicalSize = const Size(900, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await wt.settle(tester);

      await tester.tap(wt.nav('Pokédex'));
      await wt.settle(tester);
      await tester.tap(find.text('Pikachu'));
      await wt.settle(tester);

      expect(find.byType(DefensiveProfile), findsOneWidget);
      expect(find.text('DEFENSE PROFILE'), findsOneWidget);

      final moves = sectionTop(tester, 'Moves');
      final defence = sectionTop(tester, 'Defense Profile');
      final evolution = sectionTop(tester, 'Evolution');

      expect(
        defence,
        greaterThan(moves),
        reason: 'the profile belongs after the stats and moves',
      );
      expect(
        evolution,
        greaterThan(defence),
        reason: 'and before the evolution family',
      );
    });
  });
}
