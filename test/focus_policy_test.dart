import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokepod/app/focus_policy.dart';

import 'widget_test.dart' as wt;

/// Regression tests for the reported bug: the keyboard stayed up after
/// leaving the screen that raised it — visible in the user's screenshots on
/// Discover and Profile, where no text field exists at all.
///
/// The signal for "the keyboard is up" in widget tests is
/// [WidgetTester.testTextInput], which the framework shows whenever a text
/// field gains focus.
void main() {
  group('the keyboard belongs to the screen that raised it', () {
    testWidgets('switching tabs dismisses the keyboard', (tester) async {
      await wt.pumpApp(tester);
      await wt.settle(tester);
      await tester.tap(wt.nav('Pokédex'));
      await wt.settle(tester);

      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      expect(
        tester.testTextInput.isVisible,
        isTrue,
        reason: 'focusing the search field must raise the keyboard',
      );

      await tester.tap(wt.nav('Discover'));
      await wt.settle(tester);
      expect(
        tester.testTextInput.isVisible,
        isFalse,
        reason: 'a tab with no text field must not inherit the keyboard',
      );
    });

    testWidgets('system back from a focused search dismisses the keyboard', (
      tester,
    ) async {
      await wt.pumpApp(tester);
      await wt.settle(tester);
      await tester.tap(wt.nav('Pokédex'));
      await wt.settle(tester);

      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);

      // Android back from a non-Discover tab returns to Discover.
      await tester.binding.handlePopRoute();
      await wt.settle(tester);
      expect(
        tester.testTextInput.isVisible,
        isFalse,
        reason: 'leaving the tab must take the keyboard with it',
      );
      expect(wt.nav('Discover'), findsOneWidget);
    });
  });

  group('focus is never handed back to a field behind a route', () {
    testWidgets('popping a route releases the field it left behind', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [FocusReleaseObserver()],
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  const TextField(),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          body: Column(
                            children: [
                              const TextField(),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('pop'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    child: const Text('go'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      final before = FocusManager.instance.primaryFocus;
      expect(before, isNotNull);
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('pop'));
      await tester.pumpAndSettle();

      final after = FocusManager.instance.primaryFocus;
      expect(
        identical(after, before),
        isFalse,
        reason: 'the keyboard must not come back with the field that was left',
      );
      expect(
        tester.testTextInput.isVisible,
        isFalse,
        reason: 'no field behind the popped route may hold the keyboard',
      );
    });
  });
}
