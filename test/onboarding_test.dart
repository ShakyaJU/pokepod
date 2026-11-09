import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokepod/core/storage/local_store.dart';
import 'package:pokepod/features/notifications/notifications_controller.dart';
import 'package:pokepod/features/onboarding/onboarding_controller.dart';
import 'package:pokepod/features/onboarding/onboarding_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/support.dart';

/// Hosts the guide behind a button, the same way the app pushes it over
/// whatever screen the trainer happens to be on.
class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => showAppOnboarding(context),
        child: const Text('open'),
      ),
    ),
  );
}

/// Pumps the host and opens the introduction, returning the store it records
/// itself in.
Future<SharedPreferences> pumpGuide(WidgetTester tester) async {
  final prefs = await mockPrefs();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MaterialApp(home: _Host()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return prefs;
}

void main() {
  group('onboarding persistence', () {
    test('a fresh install has not been introduced yet', () async {
      final prefs = await mockPrefs();

      expect(isOnboardingCompleted(prefs), isFalse);
      expect(shouldShowAppOnboarding(prefs, firstLaunch: true), isTrue);
    });

    test('an established install is never pushed through it', () async {
      final prefs = await mockPrefs();
      await markOnboardingCompleted(prefs);

      expect(isOnboardingCompleted(prefs), isTrue);
      // The recorded flag wins even over a launch that looks brand new.
      expect(shouldShowAppOnboarding(prefs, firstLaunch: true), isFalse);
    });

    test(
      'someone who is not a first launch is not introduced either',
      () async {
        final prefs = await mockPrefs();

        expect(shouldShowAppOnboarding(prefs, firstLaunch: false), isFalse);
      },
    );

    test('the recorded flag is what a cold start reads back', () async {
      final prefs = await mockPrefs();
      await markOnboardingCompleted(prefs);

      // A cold start has none of the object above in memory: it reads the
      // persisted value straight out of the store.
      SharedPreferences.setMockInitialValues({kOnboardingStorageKey: true});
      final coldStart = await SharedPreferences.getInstance();

      expect(isOnboardingCompleted(coldStart), isTrue);
      expect(shouldShowAppOnboarding(coldStart, firstLaunch: true), isFalse);
    });

    test(
      'the first-run signal has to be read before the sheet answers',
      () async {
        final prefs = await mockPrefs();

        // Before anything claims the first run, a new install is recognisable.
        final before = shouldShowNotificationOnboarding(
          prefs,
          const NotificationsPrefs(),
        );
        expect(before, isTrue);
        expect(shouldShowAppOnboarding(prefs, firstLaunch: before), isTrue);

        // The moment the first-launch explanation has been answered it is not —
        // which is exactly why the introduction has to use the value read *before*
        // that sheet ran rather than measuring it afterwards.
        expect(
          shouldShowNotificationOnboarding(
            prefs,
            const NotificationsPrefs(asked: true),
          ),
          isFalse,
        );
        expect(shouldShowAppOnboarding(prefs, firstLaunch: false), isFalse);
      },
    );
  });

  group('the introduction itself', () {
    testWidgets('it opens on the welcome step with Back, Skip and Next', (
      tester,
    ) async {
      await pumpGuide(tester);

      expect(find.text('Welcome to PokéPod'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(
        find.text('Welcome to PokéPod'),
        findsOneWidget,
        reason: 'there is nowhere to go back to from the first step',
      );
    });

    testWidgets('every step is reachable forwards and backwards', (
      tester,
    ) async {
      await pumpGuide(tester);

      for (var i = 1; i < kOnboardingSteps.length; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(
          find.text(kOnboardingSteps[i].title),
          findsOneWidget,
          reason: 'step $i must be shown by tapping Next',
        );
      }

      expect(
        find.text('Next'),
        findsNothing,
        reason: 'the last step offers Get started instead',
      );
      expect(find.text('Get started'), findsOneWidget);
      expect(
        find.text('Skip'),
        findsNothing,
        reason: 'there is nothing left to skip past',
      );

      for (var i = kOnboardingSteps.length - 2; i >= 0; i--) {
        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();
        expect(
          find.text(kOnboardingSteps[i].title),
          findsOneWidget,
          reason: 'Back must retrace the steps it came down',
        );
      }
      expect(find.text('Welcome to PokéPod'), findsOneWidget);
    });

    testWidgets('Get started closes the guide and records it', (tester) async {
      final prefs = await pumpGuide(tester);
      expect(isOnboardingCompleted(prefs), isFalse);

      for (var i = 1; i < kOnboardingSteps.length; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome to PokéPod'), findsNothing);
      expect(
        find.text('open'),
        findsOneWidget,
        reason: 'the trainer is back in the app, not at step one again',
      );
      expect(isOnboardingCompleted(prefs), isTrue);
    });

    testWidgets('Skip records it without walking the whole guide', (
      tester,
    ) async {
      final prefs = await pumpGuide(tester);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('Make it yours'), findsNothing);
      expect(isOnboardingCompleted(prefs), isTrue);
    });

    testWidgets('leaving through the system back records it too', (
      tester,
    ) async {
      final prefs = await pumpGuide(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget);
      expect(
        isOnboardingCompleted(prefs),
        isTrue,
        reason: 'backing out is a decision too, and must not be repeated',
      );
    });
  });
}
