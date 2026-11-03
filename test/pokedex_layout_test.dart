import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' as wt;

/// Regression tests for the reported overflow: with the search focused and
/// no matches, the page threw "BOTTOM OVERFLOWED BY 62 PIXELS" (see the
/// user's screenshot). The page is now one [CustomScrollView], so nothing in
/// it has a fixed height that can exceed the space a keyboard leaves over.
void main() {
  testWidgets('the Pokédex never overflows at any viewport height', (
    tester,
  ) async {
    await wt.pumpApp(tester);
    await wt.settle(tester);
    await tester.tap(wt.nav('Pokédex'));
    await wt.settle(tester);

    // Heights from a tall phone down to a landscape-style strip.
    for (final height in [700, 450, 360, 320, 280]) {
      tester.view.physicalSize = Size(900, height.toDouble());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.takeException(),
        isNull,
        reason: 'viewport height $height px must not overflow',
      );
    }

    tester.view.resetPhysicalSize();
    await tester.pump();
  });

  testWidgets('the empty search state under a keyboard never overflows', (
    tester,
  ) async {
    await wt.pumpApp(tester);
    await wt.settle(tester);
    await tester.tap(wt.nav('Pokédex'));
    await wt.settle(tester);

    // The exact reported scenario: a query with no matches while the
    // keyboard is up.
    await tester.enterText(find.byType(TextField).first, 'jjj');
    await wt.settle(tester);
    expect(find.text('No Pokémon match'), findsOneWidget);

    tester.view.physicalSize = const Size(900, 700);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(() => tester.view.viewInsets = const FakeViewPadding());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester.takeException(),
      isNull,
      reason: 'search + empty state + keyboard must fit without overflow',
    );
    // The controls are still all there, just scrolled rather than clipped.
    expect(find.text('No Pokémon match'), findsOneWidget);
    expect(find.text('Clear filters'), findsWidgets);

    tester.view.resetPhysicalSize();
    await tester.pump();
  });
}
