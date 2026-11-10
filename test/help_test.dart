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

    test('the Settings section documents the real Sound Effects toggle', () {
      final settings = topic('settings');
      final text = textOf(settings);
      expect(
        text,
        contains('Sound Effects'),
        reason: 'the toggle really exists on the Settings screen',
      );
      // The short entry the guide promises, in one piece.
      expect(
        text,
        contains(
          'You can enable or disable in-app sound effects using the Sound '
          'Effects toggle in Settings. Your preference is saved automatically.',
        ),
      );
      // Immediately below Notifications and above Backup, Progress & Restore.
      final items = [
        for (final block in settings.blocks)
          if (block.kind == HelpBlockKind.bullets) ...block.items,
      ];
      final index = items.indexWhere(
        (item) => item.startsWith('Sound Effects'),
      );
      expect(index, greaterThan(0), reason: 'it is an entry of its own');
      expect(
        index,
        lessThan(items.length - 1),
        reason: 'it is not the last entry',
      );
      expect(items[index - 1], startsWith('Notifications'));
      expect(
        items[index + 1],
        startsWith('Backup progress and Restore from backup'),
      );
      // And that the choice survives a restart.
      expect(text.toLowerCase(), contains('saved automatically'));
    });

    test('no help section still denies that the sound setting exists', () {
      for (final id in ['settings', 'troubleshooting', 'welcome']) {
        expect(
          textOf(topic(id)).toLowerCase(),
          isNot(contains('no in-app sound setting')),
          reason: id,
        );
      }
    });

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

  group('Help search', () {
    test('every acceptance query ranks its own topic first', () {
      const expectedTop = <String, String>{
        'Accent Color': 'Settings',
        'Theme Mode': 'Settings',
        'Notifications': 'Streak reminders and notifications',
        // Sound Effects is now documented in its own right under Settings, so
        // that is where the query should land; Troubleshooting still holds the
        // "what plays and when" answer for it.
        'Sound Effects': 'Settings',
        'Backup and Restore': 'Backing up and restoring',
        "Who's That Pokémon?": "Who's That Pokémon?",
        'Achievements': 'Achievements',
        'Living Dex': 'Living Dex and research',
        'Research Progress': 'Living Dex and research',
        'Collections': 'Collections and favourites',
        'Home-screen Widgets': 'Home-screen widgets',
        'Pokémon Comparison': 'Pokémon DNA',
        'Team Architect': 'Battle Lab',
      };

      for (final entry in expectedTop.entries) {
        final results = searchHelp(entry.key);
        expect(
          results,
          isNotEmpty,
          reason: '"${entry.key}" must find something',
        );
        expect(
          results.first.topic.title,
          contains(entry.value),
          reason: '"${entry.key}" must rank $entry.value first',
        );
      }
    });

    test('case, spacing, partial terms and junk are handled', () {
      expect(searchHelp('zzzzqq'), isEmpty);
      expect(searchHelp(''), hasLength(kHelpTopics.length));
      expect(searchHelp('accent color').first.topic.id, 'settings');
      expect(searchHelp('  ACCENT   COLOR  ').first.topic.id, 'settings');
      final ids = [for (final r in searchHelp('streak')) r.topic.id];
      expect(ids.toSet(), hasLength(ids.length), reason: 'no duplicates');
      // Partial words still hit.
      expect(searchHelp('restor').first.topic.id, 'backup');
      // The stop word "and" never drags in a section that only says "Android".
      expect(
        searchHelp('Backup and Restore').map((r) => r.topic.id),
        isNot(contains('troubleshooting')),
      );
    });

    test('an excerpt starts exactly where the match is', () {
      final first = searchHelp('Accent Color').first;
      expect(first.excerpt, isNotNull);
      expect(first.excerpt, contains('Accent Color'));
      // The window opens on the match itself; a leading ellipsis only marks
      // that there is earlier text in the topic.
      expect(first.excerpt!.replaceFirst('… ', ''), startsWith('Accent Color'));
    });

    test('matches() still agrees with the search', () {
      for (final topic in kHelpTopics) {
        expect(topic.matches(topic.title), isTrue, reason: topic.id);
      }
      expect(kHelpTopics.any((t) => t.matches('clipboard')), isTrue);
      expect(kHelpTopics.any((t) => t.matches('zzzzqq')), isFalse);
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
