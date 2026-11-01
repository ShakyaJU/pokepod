import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokepod/app/theme/app_theme.dart';
import 'package:pokepod/app/theme/tokens.dart';
import 'package:pokepod/core/storage/backup.dart';
import 'package:pokepod/core/storage/local_store.dart';
import 'package:pokepod/domain/research_rules.dart';
import 'package:pokepod/features/research/research_controller.dart';
import 'package:pokepod/features/trainer_profile/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/support.dart';

const _research = '{"1":1,"4":2,"7":3}';
const _favourites = '[25,6]';
const _mystery =
    '{"v":2,"history":{"2026-10-20":{"g":2,"w":true,"t":25}},"active":"2026-10-20","guesses":[1],"seen":"2026-10-20"}';

void main() {
  group('BackupService', () {
    test('exports only the user\'s progress, never cached API data', () async {
      final prefs = await mockPrefs({
        'research.v1': _research,
        'favourites.v1': _favourites,
        'mystery.v1': _mystery,
        'cache.v1.pokemon.25': '{"id":25}',
        'something.else': 'x',
      });
      final text = BackupService.export(
        prefs,
        now: DateTime.utc(2026, 10, 21, 8),
      );
      final json = jsonDecode(text) as Map<String, dynamic>;
      expect(json['app'], 'pokepod');
      expect(json['format'], 1);
      expect(json['exportedAt'], '2026-10-21T08:00:00.000Z');
      expect((json['data'] as Map<String, dynamic>).keys.toSet(), {
        'research.v1',
        'favourites.v1',
        'mystery.v1',
      });
      expect(text.contains('cache.v1'), isFalse);
    });

    test('a backup round-trips and summarises its contents', () async {
      final prefs = await mockPrefs({
        'research.v1': _research,
        'favourites.v1': _favourites,
        'notes.v1': '{"25":"likes apples"}',
        'collections.v1': '[{"id":"1","name":"A","ids":[1]}]',
        'teams.v1': '[]',
        'mystery.v1': _mystery,
        'profile.v1': '{"nick":"Ash"}',
      });
      final parsed = BackupService.parse(BackupService.export(prefs));
      expect(parsed.summary.discovered, 3);
      expect(parsed.summary.favourites, 2);
      expect(parsed.summary.notes, 1);
      expect(parsed.summary.collections, 1);
      expect(parsed.summary.challengeDays, 1);
      expect(parsed.summary.hasProfile, isTrue);
      expect(parsed.summary.lines, contains('3 discovered Pokémon'));

      final fresh = await mockPrefs({'cache.v1.keep': 'kept'});
      await BackupService.apply(fresh, parsed);
      expect(
        jsonDecode(fresh.getString('research.v1')!),
        jsonDecode(_research),
      );
      expect(jsonDecode(fresh.getString('mystery.v1')!), jsonDecode(_mystery));
      expect(
        fresh.getString('cache.v1.keep'),
        'kept',
        reason: 'unrelated data is untouched',
      );
    });

    test(
      'invalid input is rejected with a clear message and changes nothing',
      () async {
        void rejects(String text, String message) {
          expect(
            () => BackupService.parse(text),
            throwsA(
              isA<BackupException>().having(
                (e) => e.message,
                'message',
                contains(message),
              ),
            ),
            reason: text,
          );
        }

        rejects('', 'Paste a backup');
        rejects('not json', 'not a PokéPod backup');
        rejects('[1,2,3]', 'not a PokéPod backup');
        rejects('{"app":"other","format":1,"data":{}}', 'not a PokéPod backup');
        rejects('{"app":"pokepod","data":{}}', 'no version');
        rejects('{"app":"pokepod","format":99,"data":{}}', 'newer version');
        rejects('{"app":"pokepod","format":1}', 'no progress data');
        rejects(
          '{"app":"pokepod","format":1,"data":{"unknown.key":{"a":1}}}',
          'does not contain any',
        );
        rejects(
          '{"app":"pokepod","format":1,"data":{"research.v1":{"1":"x"}}}',
          'damaged',
        );
        rejects(
          '{"app":"pokepod","format":1,"data":{"favourites.v1":["a"]}}',
          'damaged',
        );
        rejects(
          '{"app":"pokepod","format":1,"data":{"notes.v1":{"abc":"x"}}}',
          'damaged',
        );
        rejects(
          '{"app":"pokepod","format":1,"data":{"teams.v1":[1]}}',
          'damaged',
        );
      },
    );

    test('unknown keys in a backup are ignored, not written', () async {
      final parsed = BackupService.parse(
        '{"app":"pokepod","format":1,"data":{"favourites.v1":[1,2],"evil.key":{"x":1}}}',
      );
      expect(parsed.data.keys, ['favourites.v1']);
    });

    test(
      'an empty install exports an empty backup that cannot be restored as progress',
      () async {
        final prefs = await mockPrefs();
        final text = BackupService.export(prefs);
        expect(
          () => BackupService.parse(text),
          throwsA(isA<BackupException>()),
        );
      },
    );
  });

  group('Settings backup screens', () {
    String? clipboard;

    setUp(() {
      clipboard = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboard =
                  (call.arguments as Map<dynamic, dynamic>)['text'] as String?;
              return null;
            }
            if (call.method == 'Clipboard.getData') {
              return <String, dynamic>{'text': clipboard};
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    Future<ProviderContainer> pumpSettings(
      WidgetTester tester,
      SharedPreferences prefs,
    ) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.build(Brightness.dark, AppColors.emerald),
            home: const SettingsPage(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      return container;
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('Backup progress copies a backup and says what is inside', (
      tester,
    ) async {
      final prefs = await mockPrefs({
        'research.v1': _research,
        'favourites.v1': _favourites,
      });
      await pumpSettings(tester, prefs);
      await tester.tap(find.text('Backup progress'));
      await settle(tester);

      expect(find.text('Backup copied'), findsOneWidget);
      expect(find.text('• 3 discovered Pokémon'), findsOneWidget);
      expect(find.text('• 2 favourites'), findsOneWidget);
      expect(clipboard, isNotNull);
      expect(BackupService.parse(clipboard!).summary.discovered, 3);
      expect(find.textContaining('not uploaded anywhere'), findsOneWidget);
    });

    testWidgets('the data section offers backup and restore only', (
      tester,
    ) async {
      final prefs = await mockPrefs();
      await pumpSettings(tester, prefs);

      expect(find.text('Backup progress'), findsOneWidget);
      expect(find.text('Restore from backup'), findsOneWidget);
      expect(
        find.text('Import favourites'),
        findsNothing,
        reason: 'the redundant import entry is gone',
      );
      expect(
        find.text('Back up progress'),
        findsNothing,
        reason: 'the label was reworded to Backup progress',
      );
    });

    testWidgets(
      'Restore rejects bad text, previews good text and only then replaces progress',
      (tester) async {
        final source = await mockPrefs({
          'research.v1': _research,
          'favourites.v1': _favourites,
        });
        final backup = BackupService.export(source);

        final prefs = await mockPrefs({'research.v1': '{"25":1}'});
        final container = await pumpSettings(tester, prefs);
        expect(container.read(researchProvider), hasLength(1));

        await tester.tap(find.text('Restore from backup'));
        await settle(tester);
        expect(find.text('Restore from backup'), findsWidgets);

        await tester.enterText(find.byType(TextField), 'hello');
        await tester.pump();
        await tester.tap(find.text('Check backup'));
        await settle(tester);
        expect(find.textContaining('not a PokéPod backup'), findsOneWidget);
        expect(
          prefs.getString('research.v1'),
          '{"25":1}',
          reason: 'nothing changed',
        );

        await tester.enterText(find.byType(TextField), backup);
        await tester.pump();
        await tester.tap(find.text('Check backup'));
        await settle(tester);
        expect(find.text('• 3 discovered Pokémon'), findsOneWidget);
        expect(find.textContaining('cannot be undone'), findsOneWidget);
        expect(
          prefs.getString('research.v1'),
          '{"25":1}',
          reason: 'still unchanged before confirming',
        );

        await tester.tap(find.text('Replace my progress'));
        await settle(tester);
        expect(container.read(researchProvider), hasLength(3));
        expect(
          container.read(researchProvider.notifier).stateOf(7),
          ResearchState.mastered,
        );
        expect(container.read(favouritesProvider), {25, 6});
        expect(find.text('Progress restored.'), findsOneWidget);
      },
    );

    testWidgets('Cancel leaves progress alone', (tester) async {
      final prefs = await mockPrefs({'research.v1': '{"25":1}'});
      final container = await pumpSettings(tester, prefs);
      await tester.tap(find.text('Restore from backup'));
      await settle(tester);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(container.read(researchProvider), hasLength(1));
    });
  });
}
