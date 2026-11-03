import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' as wt;

/// The create/rename dialogs read their text straight from the field: the
/// field owns (and disposes) the controller it needs, so the dialog itself
/// never holds one. These tests keep that contract honest — typing, saving
/// and the resulting record must work exactly as they did before.
void main() {
  testWidgets('creating a collection saves the typed name', (tester) async {
    await wt.pumpApp(tester);
    await wt.settle(tester);
    await tester.tap(wt.nav('Collections'));
    await wt.settle(tester);

    await tester.tap(find.widgetWithText(TextButton, 'New'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final field = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    expect(field, findsOneWidget);

    await tester.enterText(field, 'Water squad');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Save'),
      ),
    );
    await wt.settle(tester);

    expect(find.text('Water squad'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('creating a team saves the typed name', (tester) async {
    await wt.pumpApp(tester);
    await wt.settle(tester);
    await tester.tap(wt.nav('Lab'));
    await wt.settle(tester);

    await tester.tap(find.text('Team Architect'));
    await wt.settle(tester);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'New team'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final field = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    expect(field, findsOneWidget);

    await tester.enterText(field, 'Rain squad');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Save'),
      ),
    );
    await wt.settle(tester);

    expect(find.byType(AlertDialog), findsNothing);
    // The new team's detail page opens with the name that was typed.
    expect(find.text('Rain squad'), findsOneWidget);
  });

  testWidgets('cancelling a dialog creates nothing', (tester) async {
    await wt.pumpApp(tester);
    await wt.settle(tester);
    await tester.tap(wt.nav('Collections'));
    await wt.settle(tester);

    await tester.tap(find.widgetWithText(TextButton, 'New'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Cancel'),
      ),
    );
    await wt.settle(tester);

    expect(find.byType(AlertDialog), findsNothing);
    // The list is still empty: cancelling creates nothing.
    expect(find.textContaining('Create a collection such as'), findsOneWidget);
  });
}
