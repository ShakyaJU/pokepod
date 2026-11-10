// First-launch ordering (the introduction, then the notification explanation)
// and the Specimen of the Day widget route — the two things a brand-new
// installation sees in order, and the only ways PokéPod opens anywhere other
// than Discover.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokepod/app/app.dart';
import 'package:pokepod/app/design_system/widgets.dart';
import 'package:pokepod/core/storage/local_store.dart';
import 'package:pokepod/data/providers.dart';
import 'package:pokepod/domain/mystery_logic.dart';
import 'package:pokepod/features/mystery/mystery_controller.dart';
import 'package:pokepod/features/notifications/notification_service.dart';
import 'package:pokepod/features/notifications/notifications_controller.dart';
import 'package:pokepod/features/onboarding/onboarding_controller.dart';
import 'package:pokepod/features/pokemon_detail/dossier_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/support.dart';

const _routesChannel = MethodChannel('pokepod/routes');

/// The channel `MainActivity` answers `getPendingRoute` on; the cold-start
/// widget tap is read from here rather than from [_routesChannel].
const _platformChannel = MethodChannel('pokepod/platform');

/// The device-local date every case here is pinned to. It is injected into the
/// shell, so the expected specimen is computed the same way the app computes it.
const _day = '2026-10-21';

/// Platform notification layer, replaced wholesale: nothing in these tests may
/// reach the real plugin, and each case reads back what was asked and answered.
class _FakeScheduler implements StreakReminderScheduler {
  /// What Android currently reports.
  bool granted = false;

  int permissionRequests = 0;
  int enabledReads = 0;

  @override
  Future<bool> notificationsEnabled() async {
    enabledReads++;
    return granted;
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return granted;
  }

  @override
  Future<void> init() async {}

  @override
  Future<void> schedule({
    required DateTime when,
    required String title,
    required String body,
    required String payload,
  }) async {}

  @override
  Future<void> cancel() async {}

  @override
  Future<NotificationAppLaunchDetails?> launchDetails() async => null;

  @override
  set onOpened(void Function(String payload)? callback) {}
}

/// An install that has already answered both first-run screens.
const Map<String, Object> _answeredInstall = {
  kOnboardingStorageKey: true,
  NotificationsPrefsNotifier.storageKey:
      '{"enabled":true,"streakReminder":true,"asked":true}',
};

/// Skeletons and progress indicators animate forever, so pumpAndSettle would
/// never return.
Future<void> _settle(WidgetTester tester, {int frames = 8}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Builds the app around an already-loaded preference store, with the native
/// route channel answering [pendingRoute] for a cold-start widget tap.
Future<void> _build(
  WidgetTester tester,
  SharedPreferences prefs, {
  _FakeScheduler? scheduler,
  String? pendingRoute,
}) async {
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_platformChannel, (call) async {
    if (call.method == 'getPendingRoute') {
      return pendingRoute;
    }
    return null;
  });
  addTearDown(() {
    messenger.setMockMethodCallHandler(_platformChannel, null);
  });

  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiClientProvider.overrideWithValue(
          FakeApiClient({
            '$apiBase/pokemon?limit=1025&offset=0': catalogJson([
              (1, 'bulbasaur'),
              (4, 'charmander'),
              (25, 'pikachu'),
            ]),
            '$apiBase/pokemon/25': pokemonJson(),
            '$apiBase/pokemon-species/25': {
              'id': 25,
              'flavor_text_entries': [
                {
                  'flavor_text': 'Stores electricity.',
                  'language': {'name': 'en'},
                },
              ],
            },
          }),
        ),
        imageProviderFactoryProvider.overrideWithValue(
          (url) => MemoryImage(kTestPixel),
        ),
        todayKeyProvider.overrideWithValue(_day),
        notificationServiceProvider.overrideWithValue(
          scheduler ?? _FakeScheduler(),
        ),
      ],
      child: PokePodApp(splashDuration: Duration.zero),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

/// Starts the app on a genuinely new installation unless [values] say otherwise.
Future<SharedPreferences> _pumpInstall(
  WidgetTester tester, {
  Map<String, Object>? values,
  _FakeScheduler? scheduler,
  String? pendingRoute,
}) async {
  SharedPreferences.setMockInitialValues(values ?? const <String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  await _build(tester, prefs, scheduler: scheduler, pendingRoute: pendingRoute);
  return prefs;
}

/// Tears the whole tree down and builds it again over the same store — what a
/// process restart looks like to the app.
Future<void> _relaunch(
  WidgetTester tester,
  SharedPreferences prefs, {
  _FakeScheduler? scheduler,
  String? pendingRoute,
}) async {
  await tester.pumpWidget(const SizedBox());
  await _build(tester, prefs, scheduler: scheduler, pendingRoute: pendingRoute);
}

/// Delivers a widget tap exactly as MainActivity does once the app is already
/// alive (a warm start, or a tap while it is in the foreground).
void _tapWidget(WidgetTester tester) {
  final message = const StandardMethodCodec().encodeMethodCall(
    const MethodCall('openRoute', 'specimen'),
  );
  // Deliberately not awaited: the Dart handler is asynchronous and these tests
  // run in a FakeAsync zone, where awaiting it would hang the test.
  unawaited(
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      _routesChannel.name,
      message,
      (_) {},
    ),
  );
}

Map<String, dynamic> _storedNotifications(SharedPreferences prefs) =>
    jsonDecode(prefs.getString(NotificationsPrefsNotifier.storageKey)!)
        as Map<String, dynamic>;

void main() {
  tearDown(() => debugNotificationsSupported = null);

  group('first-launch order', () {
    testWidgets(
      'a fresh install shows the introduction before the notification explanation',
      (tester) async {
        debugNotificationsSupported = true;
        await _pumpInstall(tester, scheduler: _FakeScheduler());
        await _settle(tester);

        expect(
          find.text('Welcome to PokéPod'),
          findsOneWidget,
          reason:
              'the introduction is the first screen a brand-new install sees',
        );
        expect(
          find.text('Keep your streak alive'),
          findsNothing,
          reason: 'the explanation waits until the introduction is handled',
        );
        expect(find.text('Enable notifications'), findsNothing);
        expect(find.text('Not now'), findsNothing);
      },
    );

    testWidgets('skipping the introduction leads to the explanation', (
      tester,
    ) async {
      debugNotificationsSupported = true;
      await _pumpInstall(tester, scheduler: _FakeScheduler());
      await _settle(tester);

      await tester.tap(find.text('Skip'));
      await _settle(tester);

      expect(find.text('Welcome to PokéPod'), findsNothing);
      expect(
        find.text('Keep your streak alive'),
        findsOneWidget,
        reason: 'a skipped introduction still gets its notification turn',
      );
    });

    testWidgets('walking every page to Get started leads to the explanation', (
      tester,
    ) async {
      debugNotificationsSupported = true;
      await _pumpInstall(tester, scheduler: _FakeScheduler());
      await _settle(tester);

      for (var i = 0; i < 12; i++) {
        final next = find.text('Next');
        if (next.evaluate().isEmpty) {
          break;
        }
        await tester.tap(next);
        await _settle(tester, frames: 4);
      }

      expect(find.text('Get started'), findsOneWidget);
      await tester.tap(find.text('Get started'));
      await _settle(tester);

      expect(
        find.text('Keep your streak alive'),
        findsOneWidget,
        reason: 'a finished introduction still gets its notification turn',
      );
    });

    testWidgets(
      'declining opens the app, records both answers separately and never asks Android',
      (tester) async {
        debugNotificationsSupported = true;
        final scheduler = _FakeScheduler();
        final prefs = await _pumpInstall(tester, scheduler: scheduler);
        await _settle(tester);

        await tester.tap(find.text('Skip'));
        await _settle(tester);
        await tester.tap(find.text('Not now'));
        await _settle(tester);

        expect(find.byType(NavigationBar), findsOneWidget);
        expect(
          find.text('RESEARCH DEVICE ONLINE'),
          findsOneWidget,
          reason: 'a decline never blocks entry to the app',
        );
        expect(scheduler.permissionRequests, 0);
        expect(scheduler.enabledReads, 0);

        expect(prefs.containsKey(kOnboardingStorageKey), isTrue);
        expect(
          prefs.containsKey(NotificationsPrefsNotifier.storageKey),
          isTrue,
          reason: 'the two answers live in two different places',
        );
        final stored = _storedNotifications(prefs);
        expect(stored['asked'], isTrue);
        expect(stored['enabled'], isFalse, reason: 'not reported as granted');
      },
    );

    testWidgets(
      'enabling when Android already allows notifications never re-prompts',
      (tester) async {
        debugNotificationsSupported = true;
        final scheduler = _FakeScheduler()..granted = true;
        final prefs = await _pumpInstall(tester, scheduler: scheduler);
        await _settle(tester);

        await tester.tap(find.text('Skip'));
        await _settle(tester);
        await tester.tap(find.text('Enable notifications'));
        await _settle(tester);

        expect(scheduler.enabledReads, greaterThan(0), reason: 'status first');
        expect(
          scheduler.permissionRequests,
          0,
          reason: 'an already-granted permission is never requested again',
        );
        expect(find.byType(NavigationBar), findsOneWidget);
        final stored = _storedNotifications(prefs);
        expect(stored['enabled'], isTrue);
        expect(stored['asked'], isTrue);
      },
    );

    testWidgets(
      'an outstanding permission is asked once, a denial is not granted, and nothing repeats on relaunch',
      (tester) async {
        debugNotificationsSupported = true;
        final scheduler = _FakeScheduler()..granted = false;
        final prefs = await _pumpInstall(tester, scheduler: scheduler);
        await _settle(tester);

        await tester.tap(find.text('Skip'));
        await _settle(tester);
        await tester.tap(find.text('Enable notifications'));
        await _settle(tester);

        expect(scheduler.permissionRequests, 1);
        expect(find.byType(NavigationBar), findsOneWidget);
        final stored = _storedNotifications(prefs);
        expect(stored['asked'], isTrue);
        expect(stored['enabled'], isFalse, reason: 'denied is not enabled');

        await _relaunch(tester, prefs, scheduler: scheduler);
        await _settle(tester);

        expect(find.text('Welcome to PokéPod'), findsNothing);
        expect(
          find.text('Keep your streak alive'),
          findsNothing,
          reason: 'neither screen comes back on a later launch',
        );
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(scheduler.permissionRequests, 1, reason: 'never re-asked');
      },
    );

    testWidgets('an established install goes straight to the app', (
      tester,
    ) async {
      debugNotificationsSupported = true;
      final scheduler = _FakeScheduler();
      await _pumpInstall(
        tester,
        values: _answeredInstall,
        scheduler: scheduler,
      );
      await _settle(tester);

      expect(find.text('Welcome to PokéPod'), findsNothing);
      expect(find.text('Keep your streak alive'), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(scheduler.permissionRequests, 0);
    });

    testWidgets(
      'a recorded introduction alone does not silently answer the explanation',
      (tester) async {
        debugNotificationsSupported = true;
        await _pumpInstall(tester, values: const {kOnboardingStorageKey: true});
        await _settle(tester);

        expect(find.text('Welcome to PokéPod'), findsNothing);
        expect(
          find.text('Keep your streak alive'),
          findsOneWidget,
          reason: 'the notification introduction has its own persisted state',
        );
      },
    );
  });

  group('Specimen of the Day widget route', () {
    testWidgets(
      'a cold-start tap opens today\'s specimen dossier over Discover',
      (tester) async {
        debugNotificationsSupported = true;
        await _pumpInstall(
          tester,
          values: _answeredInstall,
          pendingRoute: 'specimen',
        );
        await _settle(tester);

        final dossier = tester.widget<DossierPage>(find.byType(DossierPage));
        expect(dossier.id, specimenOfDayId(_day), reason: "today's specimen");

        final bar = tester.widget<NavigationBar>(
          find.byType(NavigationBar, skipOffstage: false),
        );
        expect(
          bar.selectedIndex,
          0,
          reason: 'Discover sits underneath, so back behaves normally',
        );

        await tester.pageBack();
        await _settle(tester);
        expect(find.byType(DossierPage), findsNothing);
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.text('RESEARCH DEVICE ONLINE'), findsOneWidget);
      },
    );

    testWidgets(
      'a tap held through the first-launch screens opens the dossier once they close',
      (tester) async {
        debugNotificationsSupported = true;
        await _pumpInstall(
          tester,
          scheduler: _FakeScheduler(),
          pendingRoute: 'specimen',
        );
        await _settle(tester);

        expect(find.text('Welcome to PokéPod'), findsOneWidget);
        expect(
          find.byType(DossierPage),
          findsNothing,
          reason: 'the request is held, not honoured, while the guide runs',
        );

        await tester.tap(find.text('Skip'));
        await _settle(tester);

        expect(find.text('Keep your streak alive'), findsOneWidget);
        expect(
          find.byType(DossierPage),
          findsNothing,
          reason: 'and still held while the explanation is up',
        );
        // A second tap while the first is still queued must not queue a
        // second dossier.
        _tapWidget(tester);
        await _settle(tester);
        expect(find.byType(DossierPage), findsNothing);

        await tester.tap(find.text('Not now'));
        await _settle(tester);

        expect(
          find.byType(DossierPage),
          findsOneWidget,
          reason: 'honoured the moment both screens are handled',
        );
        expect(
          tester.widget<DossierPage>(find.byType(DossierPage)).id,
          specimenOfDayId(_day),
        );

        await tester.pageBack();
        await _settle(tester);
        expect(
          find.byType(DossierPage),
          findsNothing,
          reason: 'one back returns to Discover, not to a stacked copy',
        );
      },
    );

    testWidgets(
      'a tap while the app is already open opens the dossier without stacking',
      (tester) async {
        debugNotificationsSupported = true;
        await _pumpInstall(tester, values: _answeredInstall);
        await _settle(tester);
        expect(find.byType(DossierPage), findsNothing);

        _tapWidget(tester);
        await _settle(tester);
        expect(find.byType(DossierPage), findsOneWidget);
        expect(
          tester.widget<DossierPage>(find.byType(DossierPage)).id,
          specimenOfDayId(_day),
        );

        // A duplicate delivery (foreground tap plus the stored copy) must not
        // stack a second route on top of the first.
        _tapWidget(tester);
        await _settle(tester);

        await tester.pageBack();
        await _settle(tester);
        expect(
          find.byType(DossierPage),
          findsNothing,
          reason: 'one back is enough: no duplicate navigation was created',
        );
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.text('RESEARCH DEVICE ONLINE'), findsOneWidget);
      },
    );

    testWidgets('a normal launcher launch still opens Discover', (
      tester,
    ) async {
      debugNotificationsSupported = true;
      await _pumpInstall(tester, values: _answeredInstall);
      await _settle(tester);

      expect(find.byType(DossierPage), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      expect(find.text('RESEARCH DEVICE ONLINE'), findsOneWidget);
    });

    testWidgets('an unknown route is ignored and Discover stays put', (
      tester,
    ) async {
      debugNotificationsSupported = true;
      await _pumpInstall(tester, values: _answeredInstall);
      await _settle(tester);

      final message = const StandardMethodCodec().encodeMethodCall(
        const MethodCall('openRoute', 'somewhere-else'),
      );
      unawaited(
        tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          _routesChannel.name,
          message,
          (_) {},
        ),
      );
      await _settle(tester);

      expect(find.byType(DossierPage), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });
}
