import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokepod/app/theme/app_theme.dart';
import 'package:pokepod/app/theme/tokens.dart';
import 'package:pokepod/features/help/help_content.dart';
import 'package:pokepod/features/help/help_page.dart';

String textOf(HelpTopic t) =>
    '${t.title} ${t.blocks.map((b) => b.searchText).join(' ')}';

void main() {
  HelpTopic topic(String id) => kHelpTopics.firstWhere((t) => t.id == id);

  group('Help content', () {
    test('every topic has a unique id and title and some content', () {
      expect(
        kHelpTopics.map((t) => t.id).toSet(),
        hasLength(kHelpTopics.length),
      );
      expect(
        kHelpTopics.map((t) => t.title).toSet(),
        hasLength(kHelpTopics.length),
      );
      for (final t in kHelpTopics) {
        expect(t.blocks, isNotEmpty, reason: t.id);
      }
    });

    test('trainer profile and backup topics exist with accurate titles', () {
      expect(topic('profile').title, 'Trainer profile');
      expect(topic('backup').title, 'Backing up and restoring your progress');
    });

    test(
      'backup help uses the labels that really exist and does not promise missing features',
      () {
        final text = textOf(topic('backup'));
        for (final label in [
          'Backup progress',
          'Restore from backup',
          'Check backup',
          'Replace my progress',
        ]) {
          expect(text, contains(label));
        }
        expect(text, contains('clipboard'));
        expect(text, contains('not saved as a file'));
        expect(text, contains('does not sync to the cloud'));
        expect(text.toLowerCase(), contains('uninstall'));
      },
    );

    test(
      'trainer profile help matches the editor and says data stays on the device',
      () {
        final text = textOf(topic('profile'));
        for (final label in ['Choose avatar', 'Save', 'Cancel']) {
          expect(text, contains(label));
        }
        expect(text, contains('only on this device'));
        expect(text, contains('Help & User Guide'));
      },
    );

    test('the guide never claims features that do not exist', () {
      final all = kHelpTopics.map(textOf).join(' ').toLowerCase();
      for (final phrase in [
        'share a trainer card',
        'share your trainer',
        'sign in',
        'log in',
        'sync across',
        'firebase',
        'mystery specimen',
        'living dex by generation',
        '00:00 utc',
      ]) {
        expect(
          all.contains(phrase),
          isFalse,
          reason: 'unexpected claim: "$phrase"',
        );
      }
    });

    test('the challenge rules in the guide match the game', () {
      final text = textOf(topic('mystery'));
      expect(text, contains('six guesses'));
      expect(text, contains('Game over'));
      expect(text, contains('cannot be replayed'));
      expect(text, contains('midnight'));
      expect(text, contains('all generations'));
    });
  });

  group('Help page', () {
    Future<void> pumpHelp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(Brightness.dark, AppColors.emerald),
          home: const HelpPage(),
        ),
      );
    }

    testWidgets('the table of contents lists the profile and backup topics', (
      tester,
    ) async {
      await pumpHelp(tester);
      await tester.tap(find.text('Table of contents'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Trainer profile'), findsWidgets);
      expect(find.text('Backing up and restoring your progress'), findsWidgets);
    });

    testWidgets(
      'searching finds the backup and profile topics and shows their steps',
      (tester) async {
        await pumpHelp(tester);
        await tester.enterText(find.byType(TextField), 'clipboard');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.text('Backing up and restoring your progress'),
          findsOneWidget,
        );
        expect(find.textContaining('Restore from backup'), findsWidgets);

        await tester.enterText(find.byType(TextField), 'avatar');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Trainer profile'), findsOneWidget);
        expect(find.textContaining('Choose avatar'), findsOneWidget);
      },
    );
  });
}
