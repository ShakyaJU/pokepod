import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokepod/app/theme/app_theme.dart';
import 'package:pokepod/app/theme/tokens.dart';
import 'package:pokepod/core/audio/sound_service.dart';
import 'package:pokepod/features/trainer_profile/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/support.dart';

/// The Sound Effects row. Its section label renders in capitals, so the two
/// can be told apart by the finder below.
Finder soundSwitch() => find.byWidgetPredicate(
  (widget) =>
      widget is SwitchListTile &&
      widget.title is Text &&
      (widget.title as Text).data == 'Sound Effects',
);

Finder soundToggle() =>
    find.descendant(of: soundSwitch(), matching: find.byType(Switch));

void main() {
  group('sound-effects preference', () {
    test('a fresh installation has sound effects on', () async {
      final prefs = await mockPrefs();
      final container = makeContainer(prefs);

      expect(container.read(soundEffectsPrefsProvider), isTrue);
      expect(container.read(soundServiceProvider).isEnabled, isTrue);
      expect(
        prefs.getBool(SoundEffectsNotifier.storageKey),
        isNull,
        reason: 'the default is a default, not a value written to storage',
      );
    });

    test('the stored choice comes back after a restart', () async {
      final prefs = await mockPrefs();
      makeContainer(
        prefs,
      ).read(soundEffectsPrefsProvider.notifier).setEnabled(false);
      expect(prefs.getBool(SoundEffectsNotifier.storageKey), isFalse);

      // A new container stands in for a fresh process: only the stored value
      // is left to re-establish the choice.
      final restarted = makeContainer(prefs);
      expect(restarted.read(soundEffectsPrefsProvider), isFalse);
      expect(
        restarted.read(soundServiceProvider).isEnabled,
        isFalse,
        reason:
            'the service is built from the stored choice, so no sound can '
            'slip out before the preference is known',
      );
    });
  });

  group('SoundService enforces the choice', () {
    test('a muted service never reaches the platform', () async {
      final backend = FakeSoundBackend();
      final service = SoundService(backend, enabled: false);

      await service.play(Sfx.game);
      await service.playToCompletion(Sfx.splash);

      expect(backend.played, isEmpty, reason: 'no plain playback');
      expect(
        backend.playedToCompletion,
        isEmpty,
        reason: 'no gated playback either, so the splash stays silent',
      );
      expect(backend.isPlaying(Sfx.game), isFalse);
      expect(backend.isPlaying(Sfx.splash), isFalse);
    });

    test(
      'warming assets still happens while muted, so re-enabling is instant',
      () async {
        final backend = FakeSoundBackend();
        final service = SoundService(backend, enabled: false);

        await service.preload([Sfx.game, Sfx.correct]);

        expect(backend.preloaded, [
          Sfx.game,
          Sfx.correct,
        ], reason: 'preloading is silent, so it costs nothing while muted');
      },
    );

    test('disabling stops what is already audible', () async {
      final backend = FakeSoundBackend();
      final service = SoundService(backend);
      await service.play(Sfx.game);
      expect(backend.isPlaying(Sfx.game), isTrue);

      await service.setEnabled(false);

      expect(service.isEnabled, isFalse);
      expect(
        backend.isPlaying(Sfx.game),
        isFalse,
        reason: 'the sound stops the moment the choice changes',
      );
    });

    test(
      'a play still reaching the platform is silenced by the mute',
      () async {
        final backend = FakeSoundBackend(
          playDelay: const Duration(milliseconds: 60),
        );
        final service = SoundService(backend);

        final playing = service.play(Sfx.game);
        await service.setEnabled(false);
        await playing;

        expect(backend.played, [Sfx.game], reason: 'it did reach the platform');
        expect(
          backend.isPlaying(Sfx.game),
          isFalse,
          reason: 'then was stopped, so it never plays after the request',
        );
      },
    );

    test(
      'turning sound off releases a caller waiting for a sound to finish',
      () async {
        final backend = FakeSoundBackend(autoComplete: false);
        final service = SoundService(backend);

        final playing = service.playToCompletion(Sfx.splash);
        expect(backend.isPlaying(Sfx.splash), isTrue, reason: 'held open');

        await service.setEnabled(false);
        await playing;

        expect(backend.isPlaying(Sfx.splash), isFalse);
        expect(
          backend.stopped,
          contains(Sfx.splash),
          reason: 'resolved at once rather than running out the timeout',
        );
      },
    );

    test('a burst of toggles leaves the last choice in charge', () async {
      final backend = FakeSoundBackend();
      final service = SoundService(backend);
      await service.play(Sfx.game);

      await service.setEnabled(false);
      await service.setEnabled(true);
      await service.setEnabled(false);

      expect(service.isEnabled, isFalse);
      expect(backend.isPlaying(Sfx.game), isFalse);

      await service.play(Sfx.game);
      expect(backend.played, [
        Sfx.game,
      ], reason: 'nothing new plays after the final "off"');
    });

    test('turning sound back on lets every effect play again', () async {
      final backend = FakeSoundBackend();
      final service = SoundService(backend, enabled: false);

      await service.play(Sfx.correct);
      expect(backend.played, isEmpty, reason: 'still muted');

      await service.setEnabled(true);
      await service.play(Sfx.correct);

      expect(service.isEnabled, isTrue);
      expect(backend.played, [
        Sfx.correct,
      ], reason: 'the first mute never poisoned the repeat window');
    });
  });

  group('Settings: Sound Effects', () {
    Future<ProviderContainer> pumpSettings(
      WidgetTester tester,
      SharedPreferences prefs, {
      Brightness brightness = Brightness.dark,
      Color accent = AppColors.emerald,
      SoundBackend? backend,
    }) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = makeContainer(
        prefs,
        overrides: [
          if (backend != null) soundBackendProvider.overrideWithValue(backend),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.build(brightness, accent),
            home: const SettingsPage(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      return container;
    }

    testWidgets('sits between the Notifications section and Data', (
      tester,
    ) async {
      await pumpSettings(tester, await mockPrefs());

      expect(find.text('NOTIFICATIONS'), findsOneWidget);
      expect(
        find.text('Sound Effects'),
        findsOneWidget,
        reason: 'the row itself',
      );
      expect(
        find.text('Enable or disable sound effects throughout PokéPod.'),
        findsOneWidget,
      );
      expect(find.text('DATA'), findsOneWidget);

      final notifications = tester.getTopLeft(find.text('NOTIFICATIONS')).dy;
      final label = tester.getTopLeft(find.text('SOUND EFFECTS')).dy;
      final row = tester.getTopLeft(find.text('Sound Effects')).dy;
      final data = tester.getTopLeft(find.text('DATA')).dy;

      expect(notifications, lessThan(label), reason: 'Notifications first');
      expect(label, lessThan(row), reason: 'then the Sound Effects section');
      expect(row, lessThan(data), reason: 'Data last');
    });

    testWidgets('starts on and stores what the user chooses', (tester) async {
      final prefs = await mockPrefs();
      final container = await pumpSettings(tester, prefs);

      expect(tester.widget<Switch>(soundToggle()).value, isTrue);

      await tester.tap(soundToggle());
      await tester.pump();

      expect(tester.widget<Switch>(soundToggle()).value, isFalse);
      expect(prefs.getBool(SoundEffectsNotifier.storageKey), isFalse);
      expect(container.read(soundEffectsPrefsProvider), isFalse);
    });

    testWidgets('a stored "off" is shown as off and actually enforced', (
      tester,
    ) async {
      final prefs = await mockPrefs({SoundEffectsNotifier.storageKey: false});
      final backend = FakeSoundBackend();
      final container = await pumpSettings(tester, prefs, backend: backend);

      expect(tester.widget<Switch>(soundToggle()).value, isFalse);

      final sound = container.read(soundServiceProvider);
      await sound.play(Sfx.game);
      await sound.playToCompletion(Sfx.splash);

      expect(
        backend.played,
        isEmpty,
        reason: 'the stored choice is enforced, not merely displayed',
      );
      expect(backend.playedToCompletion, isEmpty);
    });

    testWidgets('switching off silences what is playing and what comes next', (
      tester,
    ) async {
      final prefs = await mockPrefs();
      final backend = FakeSoundBackend();
      final container = await pumpSettings(tester, prefs, backend: backend);

      final sound = container.read(soundServiceProvider);
      await sound.play(Sfx.game);
      expect(
        backend.isPlaying(Sfx.game),
        isTrue,
        reason: 'the entry sound is playing while the user is in Settings',
      );

      await tester.tap(soundToggle());
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        backend.isPlaying(Sfx.game),
        isFalse,
        reason: 'currently playing audio stops immediately',
      );
      expect(container.read(soundEffectsPrefsProvider), isFalse);

      await sound.play(Sfx.correct);
      await sound.playToCompletion(Sfx.error);
      expect(backend.played, [
        Sfx.game,
      ], reason: 'later requests are ignored while the switch is off');
      expect(backend.playedToCompletion, isEmpty);
    });

    testWidgets('adapts to light and dark themes and to the chosen accent', (
      tester,
    ) async {
      final prefs = await mockPrefs();
      final cases = <(Brightness, Color, String)>[
        (Brightness.dark, AppColors.emerald, 'dark + emerald'),
        (Brightness.dark, AppColors.violet, 'dark + violet'),
        (Brightness.light, AppColors.rose, 'light + rose'),
      ];
      final primaries = <Color>[];

      for (final (brightness, accent, label) in cases) {
        await pumpSettings(
          tester,
          prefs,
          brightness: brightness,
          accent: accent,
        );

        final toggle = tester.widget<Switch>(soundToggle());
        expect(
          toggle.value,
          isTrue,
          reason: '$label still shows the stored choice',
        );
        expect(
          toggle.trackColor,
          isNull,
          reason: '$label: no colour of its own, so the theme decides',
        );
        expect(
          toggle.thumbColor,
          isNull,
          reason: '$label: no colour of its own, so the theme decides',
        );

        final scheme = Theme.of(tester.element(soundSwitch())).colorScheme;
        expect(scheme.brightness, brightness, reason: label);
        expect(
          scheme.primary,
          isNot(scheme.secondary),
          reason:
              '$label: the switch paints from the accent, not the fixed '
              'cyan the theme uses for secondary',
        );
        primaries.add(scheme.primary);
      }

      expect(
        primaries[0],
        isNot(primaries[1]),
        reason: 'changing the accent changes the colour the switch paints with',
      );
    });
  });
}
