import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokepod/app/theme/app_theme.dart';
import 'package:pokepod/app/theme/tokens.dart';
import 'package:pokepod/features/mystery/mystery_controller.dart';
import 'package:pokepod/features/notifications/notification_onboarding.dart';
import 'package:pokepod/features/notifications/notification_service.dart';
import 'package:pokepod/features/notifications/notification_settings.dart';
import 'package:pokepod/features/notifications/notifications_controller.dart';

import 'support/support.dart';

/// A fixed afternoon, so "today" and the reminder window are known in every
/// test below. The slot for 2026-10-30 opens at 21:00 — three hours before
/// that day's local-midnight reset.
final DateTime kAfternoon = DateTime(2026, 10, 30, 14, 30);
const String kToday = '2026-10-30';
const String kTomorrow = '2026-10-31';
const String kYesterday = '2026-10-29';

/// Records every call instead of touching platform channels.
class FakeScheduler implements StreakReminderScheduler {
  int initCalls = 0;
  int permissionRequests = 0;
  int scheduleCalls = 0;
  int cancelCalls = 0;

  /// How many reminders are outstanding; scheduling replaces, cancelling clears.
  int pending = 0;

  bool enabled = true;
  bool permissionGranted = true;
  bool failScheduling = false;

  DateTime? scheduledAt;
  String? scheduledTitle;
  String? scheduledBody;
  String? scheduledPayload;
  void Function(String payload)? onOpenedCallback;

  @override
  Future<void> init() async => initCalls++;

  @override
  Future<bool> notificationsEnabled() async => enabled;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    // A real answer changes what the permission check reports from then on,
    // so the fake does too: granted means areNotificationsEnabled() is now
    // true, denied means it stays false.
    enabled = permissionGranted;
    return permissionGranted;
  }

  @override
  Future<void> schedule({
    required DateTime when,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (failScheduling) {
      throw StateError('the alarm system is unavailable');
    }
    scheduleCalls++;
    pending = 1;
    scheduledAt = when;
    scheduledTitle = title;
    scheduledBody = body;
    scheduledPayload = payload;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    pending = 0;
    scheduledAt = null;
  }

  @override
  Future<NotificationAppLaunchDetails?> launchDetails() async => null;

  @override
  set onOpened(void Function(String payload)? callback) =>
      onOpenedCallback = callback;
}

/// Seeds yesterday's win so there is an active streak to remind about.
Map<String, Object> progressPrefs({
  bool wonYesterday = true,
  bool wonToday = false,
}) {
  final history = <String, Object>{};
  if (wonYesterday) {
    history[kYesterday] = {'g': 1, 'w': true, 't': 25};
  }
  if (wonToday) {
    history[kToday] = {'g': 1, 'w': true, 't': 25};
  }
  return {
    'mystery.v1': jsonEncode({'v': 2, 'history': history}),
    'notifications.v1': jsonEncode({
      'enabled': true,
      'streakReminder': true,
      'asked': true,
    }),
  };
}

/// Opens the first-install explanation the way Discover does.
class _SheetHost extends ConsumerWidget {
  const _SheetHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => showNotificationOnboarding(context, ref),
          child: const Text('Open the reminder sheet'),
        ),
      ),
    );
  }
}

void main() {
  group('reminder copy', () {
    test('the title is the wording PokéPod promised', () {
      expect(streakReminderTitle(), 'Your PokéPod streak is at risk!');
    });

    test('the body states the deadline and the game to play', () {
      final body = streakReminderBody();
      expect(body, contains('resets in 3 hours'));
      expect(body, contains('Who\'s That Pokémon?'));
      expect(body, contains('keep your streak alive'));
    });

    test('the deadline in the copy is the deadline in the schedule', () {
      // The body derives its number from the same constant the alarm is set
      // with, so the wording can never drift away from the real reminder time.
      expect(kStreakReminderLead, const Duration(hours: 3));
      expect(
        streakReminderBody(),
        contains('${kStreakReminderLead.inHours} hours'),
      );
      expect(kStreakReminderId, greaterThan(0));
      expect(kReminderPayloadMystery, 'mystery');
    });
  });

  group('when the reminder fires', () {
    test('it is exactly three hours before the daily reset', () {
      final reset = nextDailyReset(kAfternoon);
      expect(reset, DateTime(2026, 10, 31));
      expect(
        reset.difference(streakReminderTimeFor(kToday)),
        kStreakReminderLead,
        reason: 'the gap between the alarm and the reset is the promise',
      );
    });

    test('the reset is the same local midnight the challenge date uses', () {
      // 23:30 on the 30th still belongs to the 30th; only after local
      // midnight does the reset (and the next reminder slot) move.
      final lateNight = DateTime(2026, 10, 30, 23, 30);
      expect(nextDailyReset(lateNight), DateTime(2026, 10, 31));
      expect(
        nextDailyReset(lateNight.subtract(const Duration(hours: 1))),
        DateTime(2026, 10, 31),
      );
    });

    test('it is21:00 local on an ordinary day, and always in the future', () {
      final when = streakReminderTimeFor(kToday);
      expect(when, DateTime(2026, 10, 30, 21));
      expect(when.isAfter(kAfternoon), isTrue);
      expect(when.isBefore(nextDailyReset(kAfternoon)), isTrue);
    });

    test('the day after a day key always advances by one calendar day', () {
      expect(followingDayKey(kYesterday), kToday);
      expect(followingDayKey(kToday), kTomorrow);
      expect(followingDayKey(kTomorrow), '2026-11-01');
      expect(
        followingDayKey('not-a-date'),
        'not-a-date',
        reason: 'unparseable data ends the walk instead of looping forever',
      );
    });

    test('an unrecognised day key can never be armed', () {
      expect(
        streakReminderTimeFor('not-a-date'),
        DateTime.utc(1970),
        reason: 'a moment in the past the walk steps straight over',
      );
    });
  });

  group('streakReminderEligible', () {
    final now = DateTime(2026, 10, 30, 14);
    final reminderTime = DateTime(2026, 10, 30, 21);

    bool check({
      bool masterEnabled = true,
      bool reminderToggle = true,
      int currentStreak = 4,
      bool completedToday = false,
      bool permissionGranted = true,
      DateTime? at,
    }) => streakReminderEligible(
      masterEnabled: masterEnabled,
      reminderToggle: reminderToggle,
      currentStreak: currentStreak,
      completedToday: completedToday,
      permissionGranted: permissionGranted,
      now: at ?? now,
      reminderTime: reminderTime,
    );

    test('a live streak, an unplayed day and permission all arm it', () {
      expect(check(), isTrue);
    });

    test('every single gate can hold the reminder back on its own', () {
      expect(check(masterEnabled: false), isFalse, reason: 'master switch');
      expect(check(reminderToggle: false), isFalse, reason: 'its own toggle');
      expect(check(currentStreak: 0), isFalse, reason: 'no streak to protect');
      expect(check(completedToday: true), isFalse, reason: 'already played');
      expect(check(permissionGranted: false), isFalse, reason: 'OS permission');
      expect(
        check(at: DateTime(2026, 10, 30, 21)),
        isFalse,
        reason: 'the window closes three hours before the reset',
      );
    });

    test('21:00 exactly is already too late, an hour earlier is not', () {
      expect(check(at: DateTime(2026, 10, 30, 21)), isFalse);
      expect(check(at: DateTime(2026, 10, 30, 20, 59)), isTrue);
    });
  });

  group('refreshStreakReminder', () {
    test('arms one reminder three hours before the reset', () async {
      final fake = FakeScheduler();
      final container = makeContainer(
        await mockPrefs(progressPrefs()),
        overrides: [
          notificationServiceProvider.overrideWithValue(fake),
          clockProvider.overrideWithValue(() => kAfternoon),
        ],
      );

      await refreshStreakReminder(container);

      expect(fake.scheduleCalls, 1);
      expect(fake.pending, 1);
      expect(fake.scheduledAt, DateTime(2026, 10, 30, 21));
      expect(
        fake.scheduledAt!.difference(nextDailyReset(kAfternoon)),
        -kStreakReminderLead,
        reason: 'exactly three hours before the challenge resets',
      );
      expect(fake.scheduledTitle, 'Your PokéPod streak is at risk!');
      expect(fake.scheduledBody, contains('resets in 3 hours'));
      expect(fake.scheduledPayload, kReminderPayloadMystery);
    });

    test(
      're-arming replaces the reminder instead of stacking a second one',
      () async {
        final fake = FakeScheduler();
        final container = makeContainer(
          await mockPrefs(progressPrefs()),
          overrides: [
            notificationServiceProvider.overrideWithValue(fake),
            clockProvider.overrideWithValue(() => kAfternoon),
          ],
        );

        await refreshStreakReminder(container);
        await refreshStreakReminder(container);
        await refreshStreakReminder(container);

        expect(fake.scheduleCalls, 3);
        expect(fake.pending, 1, reason: 'one stable id, one pending reminder');
        expect(fake.cancelCalls, 0);
      },
    );

    test('completing today suppresses its slot and arms tomorrow\'s', () async {
      final fake = FakeScheduler();
      final container = makeContainer(
        await mockPrefs(progressPrefs(wonToday: true)),
        overrides: [
          notificationServiceProvider.overrideWithValue(fake),
          clockProvider.overrideWithValue(() => kAfternoon),
        ],
      );

      await refreshStreakReminder(container);

      expect(
        fake.scheduledAt,
        isNot(DateTime(2026, 10, 30, 21)),
        reason: 'a day that is already finished must never be reminded',
      );
      expect(
        fake.scheduledAt,
        DateTime(2026, 10, 31, 21),
        reason: 'the next unplayed period is covered straight away',
      );
      expect(fake.pending, 1);
      expect(fake.cancelCalls, 0);
    });

    test(
      'a slot whose moment has passed is stepped over, never armed',
      () async {
        // 23:30 on the 31st: that day's slot closed at 21:00, so the walk must
        // land on the next period rather than schedule an instant in the past.
        // The win on the 30th keeps the streak alive across the move.
        final lateNight = DateTime(2026, 10, 31, 23, 30);
        final fake = FakeScheduler();
        final container = makeContainer(
          await mockPrefs(progressPrefs(wonToday: true)),
          overrides: [
            notificationServiceProvider.overrideWithValue(fake),
            clockProvider.overrideWithValue(() => lateNight),
          ],
        );

        await refreshStreakReminder(container);

        expect(fake.scheduleCalls, 1);
        expect(fake.scheduledAt, DateTime(2026, 11, 1, 21));
        expect(fake.scheduledAt!.isAfter(lateNight), isTrue);
        expect(fake.pending, 1);
      },
    );

    test('losing the streak withdraws the reminder', () async {
      final fake = FakeScheduler();
      final container = makeContainer(
        await mockPrefs(progressPrefs(wonYesterday: false)),
        overrides: [
          notificationServiceProvider.overrideWithValue(fake),
          clockProvider.overrideWithValue(() => kAfternoon),
        ],
      );

      await refreshStreakReminder(container);

      expect(fake.scheduleCalls, 0);
      expect(fake.cancelCalls, 1);
    });

    test('switching notifications off withdraws the reminder', () async {
      final fake = FakeScheduler();
      final container = makeContainer(
        await mockPrefs(progressPrefs()),
        overrides: [
          notificationServiceProvider.overrideWithValue(fake),
          clockProvider.overrideWithValue(() => kAfternoon),
        ],
      );

      await refreshStreakReminder(container);
      expect(fake.pending, 1);

      container.read(notificationsPrefsProvider.notifier).setEnabled(false);
      await refreshStreakReminder(container);

      expect(fake.pending, 0);
      expect(fake.cancelCalls, 1);
    });

    test('revoking the system permission withdraws the reminder', () async {
      final fake = FakeScheduler()..enabled = false;
      final container = makeContainer(
        await mockPrefs(progressPrefs()),
        overrides: [
          notificationServiceProvider.overrideWithValue(fake),
          clockProvider.overrideWithValue(() => kAfternoon),
        ],
      );

      await refreshStreakReminder(container);

      expect(fake.scheduleCalls, 0);
      expect(fake.cancelCalls, 1);
    });

    test('a stored challenge date that cannot be parsed fails safe', () async {
      // `challengeDay` comes from the saved game. Corrupted data must never
      // crash the refresh or arm a reminder at a moment that does not exist;
      // the streak calculation cannot vouch for a day it cannot read, so the
      // safe outcome is to withdraw rather than guess.
      final fake = FakeScheduler();
      final container = makeContainer(
        await mockPrefs({
          'mystery.v1': jsonEncode({
            'v': 2,
            'history': {
              kYesterday: {'g': 1, 'w': true, 't': 25},
            },
            'seen': 'not-a-date',
          }),
          'notifications.v1': jsonEncode({
            'enabled': true,
            'streakReminder': true,
            'asked': true,
          }),
        }),
        overrides: [
          notificationServiceProvider.overrideWithValue(fake),
          clockProvider.overrideWithValue(() => kAfternoon),
        ],
      );

      await refreshStreakReminder(container);

      expect(fake.scheduleCalls, 0);
      expect(fake.cancelCalls, 1);
      expect(fake.pending, 0);
    });

    test('a broken alarm system never disturbs the app', () async {
      final fake = FakeScheduler()..failScheduling = true;
      final container = makeContainer(
        await mockPrefs(progressPrefs()),
        overrides: [
          notificationServiceProvider.overrideWithValue(fake),
          clockProvider.overrideWithValue(() => kAfternoon),
        ],
      );

      await refreshStreakReminder(container);

      expect(fake.scheduleCalls, 0);
    });
  });

  group('notification preferences', () {
    test('a missing entry means off, with the reminder switch ready', () {
      const prefs = NotificationsPrefs();
      expect(prefs.enabled, isFalse);
      expect(prefs.streakReminder, isTrue);
      expect(prefs.asked, isFalse);
    });

    test(
      'stored json round-trips, and only an explicit false switches off',
      () {
        final decoded = NotificationsPrefs.fromStored({
          'enabled': true,
          'streakReminder': false,
          'asked': true,
        });
        expect(decoded.enabled, isTrue);
        expect(decoded.streakReminder, isFalse);
        expect(decoded.asked, isTrue);

        final defaults = NotificationsPrefs.fromStored(const {});
        expect(defaults.enabled, isFalse);
        expect(defaults.streakReminder, isTrue);
        expect(defaults.asked, isFalse);
      },
    );

    test('every change is persisted under one versioned key', () async {
      final prefs = await mockPrefs();
      final container = makeContainer(prefs);
      final notifier = container.read(notificationsPrefsProvider.notifier);

      notifier.setEnabled(true);
      notifier.setStreakReminder(false);
      notifier.markAsked();

      final raw = prefs.getString(NotificationsPrefsNotifier.storageKey);
      expect(raw, isNotNull);
      final stored = NotificationsPrefs.fromStored(
        Map<String, dynamic>.from(jsonDecode(raw!) as Map<String, dynamic>),
      );
      expect(stored.enabled, isTrue);
      expect(stored.streakReminder, isFalse);
      expect(stored.asked, isTrue);
      expect(container.read(notificationsPrefsProvider).enabled, isTrue);
    });
  });

  group('first-install explanation', () {
    test('a brand-new install that has not answered sees it once', () async {
      final prefs = await mockPrefs();
      expect(
        shouldShowNotificationOnboarding(prefs, const NotificationsPrefs()),
        isTrue,
      );
    });

    test('existing progress is never asked again', () async {
      final prefs = await mockPrefs({'mystery.v1': '{"v":2,"history":{}}'});
      expect(
        shouldShowNotificationOnboarding(prefs, const NotificationsPrefs()),
        isFalse,
      );
      expect(hasAnyProgressData(prefs), isTrue);
    });

    test('answering it in any way hides it for good', () async {
      final prefs = await mockPrefs();
      final answered = const NotificationsPrefs().copyWith(asked: true);
      expect(shouldShowNotificationOnboarding(prefs, answered), isFalse);
    });

    test(
      'every progress key an existing user would have is recognised',
      () async {
        for (final key in kProgressStorageKeys) {
          final prefs = await mockPrefs({key: 'x'});
          expect(hasAnyProgressData(prefs), isTrue, reason: key);
        }
        expect(hasAnyProgressData(await mockPrefs()), isFalse);
      },
    );
  });

  /// Pumps the Notifications section of Settings against a fake scheduler.
  /// [now] fixes the clock so the reminder window (three hours before the
  /// reset) is always open, and [withStreak] seeds yesterday's win so there is
  /// a streak worth protecting.
  Future<(ProviderContainer, FakeScheduler)> pumpSection(
    WidgetTester tester, {
    bool masterOn = false,
    bool streakReminderOn = true,
    bool osAllows = false,
    bool permissionGranted = true,
    bool withStreak = false,
    DateTime? now,
  }) async {
    final fake = FakeScheduler()
      ..enabled = osAllows
      ..permissionGranted = permissionGranted;
    final preferences = await mockPrefs({
      // Yesterday's win, so there is a live streak worth reminding about.
      if (withStreak)
        'mystery.v1': jsonEncode({
          'v': 2,
          'history': {
            kYesterday: {'g': 1, 'w': true, 't': 25},
          },
        }),
      'notifications.v1': jsonEncode({
        'enabled': masterOn,
        'streakReminder': streakReminderOn,
        'asked': true,
      }),
    });
    final container = makeContainer(
      preferences,
      overrides: [
        notificationServiceProvider.overrideWithValue(fake),
        // Fixed to the afternoon, so the reminder window is always open.
        clockProvider.overrideWithValue(() => now ?? kAfternoon),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.build(Brightness.dark, AppColors.emerald),
          home: const Scaffold(body: NotificationSettingsSection()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return (container, fake);
  }

  group('Settings: Notifications section', () {
    testWidgets('it renders both switches with the stored choices', (
      tester,
    ) async {
      final (container, _) = await pumpSection(
        tester,
        masterOn: true,
        streakReminderOn: false,
      );

      final switches = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .toList();
      expect(switches, hasLength(2));
      expect(find.text('Notifications'), findsWidgets);
      expect(find.text('Who\'s That Pokémon? streak reminder'), findsOneWidget);
      expect(switches[0].value, isTrue, reason: 'master switch');
      expect(switches[1].value, isFalse, reason: 'streak reminder switch');
      expect(
        container.read(notificationsPrefsProvider).streakReminder,
        isFalse,
      );
    });

    testWidgets('the reminder switch stays locked until the master is on', (
      tester,
    ) async {
      await pumpSection(tester, masterOn: false);
      final switches = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .toList();
      expect(switches[1].onChanged, isNull);
    });

    testWidgets('the platform gate is honest about what this device can do', (
      tester,
    ) async {
      await pumpSection(tester, masterOn: true, osAllows: false);
      final switches = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .toList();

      expect(
        switches[0].onChanged,
        notificationsSupported ? isNotNull : isNull,
        reason: 'only real notification platforms may toggle',
      );
      expect(
        find.text('Notifications are blocked'),
        notificationsSupported ? findsOneWidget : findsNothing,
        reason: 'the OS says notifications are off',
      );
      expect(
        find.text('Open settings'),
        notificationsSupported && canOpenSystemNotificationSettings
            ? findsOneWidget
            : findsNothing,
        reason: 'only Android has a deep link that actually works',
      );
    });
  });

  group('first-install sheet', () {
    Future<(ProviderContainer, FakeScheduler)> openSheet(
      WidgetTester tester, {
      bool granted = true,
      bool answered = false,
      bool hasProgress = false,
    }) async {
      final fake = FakeScheduler()..permissionGranted = granted;
      final preferences = await mockPrefs({
        if (hasProgress) 'mystery.v1': '{"v":2,"history":{}}',
        'notifications.v1': jsonEncode({
          'enabled': false,
          'streakReminder': true,
          'asked': answered,
        }),
      });
      final container = makeContainer(
        preferences,
        overrides: [notificationServiceProvider.overrideWithValue(fake)],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.build(Brightness.dark, AppColors.emerald),
            home: const _SheetHost(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open the reminder sheet'));
      await tester.pumpAndSettle();
      return (container, fake);
    }

    /// The sheet scrolls, so a button below the fold has to be brought into
    /// view before it can be tapped.
    Future<void> tapInSheet(WidgetTester tester, String label) async {
      final button = find.text(label);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    testWidgets('showing the sheet never asks the system for permission', (
      tester,
    ) async {
      final (container, fake) = await openSheet(tester);

      expect(find.text('Keep your streak alive'), findsOneWidget);
      expect(find.textContaining('never leave your device'), findsOneWidget);
      expect(fake.permissionRequests, 0);
      expect(container.read(notificationsPrefsProvider).enabled, isFalse);
    });

    testWidgets('"Not now" records the decision and closes the sheet', (
      tester,
    ) async {
      final (container, fake) = await openSheet(tester);

      await tapInSheet(tester, 'Not now');

      expect(find.text('Keep your streak alive'), findsNothing);
      expect(container.read(notificationsPrefsProvider).asked, isTrue);
      expect(container.read(notificationsPrefsProvider).enabled, isFalse);
      expect(fake.permissionRequests, 0);

      // Answered for good: the app has no reason to ask again.
      expect(
        shouldShowNotificationOnboarding(
          await mockPrefs(),
          container.read(notificationsPrefsProvider),
        ),
        isFalse,
      );
    });

    testWidgets('dismissing the sheet without choosing also records it', (
      tester,
    ) async {
      final (container, _) = await openSheet(tester);

      // Tap the scrim above the sheet: a plain dismissal.
      await tester.tapAt(const Offset(400, 20));
      await tester.pumpAndSettle();

      expect(find.text('Keep your streak alive'), findsNothing);
      expect(container.read(notificationsPrefsProvider).asked, isTrue);
    });

    testWidgets('"Enable notifications" is what triggers the permission', (
      tester,
    ) async {
      final (container, fake) = await openSheet(tester, granted: true);

      await tapInSheet(tester, 'Enable notifications');

      expect(fake.permissionRequests, 1);
      expect(find.text('Keep your streak alive'), findsNothing);
      expect(container.read(notificationsPrefsProvider).enabled, isTrue);
      expect(container.read(notificationsPrefsProvider).asked, isTrue);
    });

    testWidgets('a denied permission turns the preference off, not a crash', (
      tester,
    ) async {
      final (container, fake) = await openSheet(tester, granted: false);

      await tapInSheet(tester, 'Enable notifications');

      expect(fake.permissionRequests, 1);
      expect(container.read(notificationsPrefsProvider).enabled, isFalse);
      expect(container.read(notificationsPrefsProvider).asked, isTrue);
    });
  });

  group('Settings: turning notifications on', () {
    // The permission flow only exists on real notification platforms, so the
    // two platform gates are opened for this group and closed afterwards.
    setUp(() {
      debugNotificationsSupported = true;
      debugCanOpenSystemNotificationSettings = true;
    });
    tearDown(() {
      debugNotificationsSupported = null;
      debugCanOpenSystemNotificationSettings = null;
    });

    testWidgets('the system is explained to before it is ever asked', (
      tester,
    ) async {
      final (container, fake) = await pumpSection(tester, withStreak: true);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      // The explanation is on screen and the OS has not been asked yet.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Allow notifications?'), findsOneWidget);
      expect(find.textContaining('stay on this device'), findsOneWidget);
      expect(fake.permissionRequests, 0);
      expect(container.read(notificationsPrefsProvider).enabled, isFalse);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(fake.permissionRequests, 1);
      expect(container.read(notificationsPrefsProvider).enabled, isTrue);
      expect(
        fake.scheduleCalls,
        1,
        reason: 'a granted permission arms the reminder immediately',
      );
      expect(find.text('Notifications are blocked'), findsNothing);
    });

    testWidgets('"Not now" asks nothing and leaves everything off', (
      tester,
    ) async {
      final (container, fake) = await pumpSection(tester, withStreak: true);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(fake.permissionRequests, 0);
      expect(container.read(notificationsPrefsProvider).enabled, isFalse);
      expect(fake.scheduleCalls, 0);
      expect(fake.pending, 0);
    });

    testWidgets('a denial records the choice and shows the way to fix it', (
      tester,
    ) async {
      final (container, fake) = await pumpSection(
        tester,
        withStreak: true,
        permissionGranted: false,
      );

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(fake.permissionRequests, 1);
      expect(
        container.read(notificationsPrefsProvider).enabled,
        isTrue,
        reason: 'the choice is recorded; the notice explains the rest',
      );
      expect(find.text('Notifications are blocked'), findsOneWidget);
      expect(find.text('Open settings'), findsOneWidget);
      expect(
        fake.scheduleCalls,
        0,
        reason: 'nothing can be delivered without the system permission',
      );
      expect(fake.pending, 0);
    });

    testWidgets('when the system already allows it, no prompt appears', (
      tester,
    ) async {
      final (container, fake) = await pumpSection(
        tester,
        withStreak: true,
        osAllows: true,
      );

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(
        fake.permissionRequests,
        0,
        reason: 'there is nothing left to ask for',
      );
      expect(container.read(notificationsPrefsProvider).enabled, isTrue);
    });

    testWidgets('granting in Android settings arms the reminder on return', (
      tester,
    ) async {
      final (container, fake) = await pumpSection(
        tester,
        masterOn: true,
        withStreak: true,
        osAllows: false,
      );
      expect(find.text('Notifications are blocked'), findsOneWidget);
      expect(fake.scheduleCalls, 0);

      // The user grants the permission in Android's own settings screen and
      // comes back: no in-app preference moves, so only re-checking the real
      // state here can arm the reminder without waiting for a restart.
      fake.enabled = true;
      // The deep link crosses a platform channel that only the real Android
      // side answers; stand in for MainActivity here.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('pokepod/platform'),
        (call) async => true,
      );
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();

      expect(find.text('Notifications are blocked'), findsNothing);
      expect(
        fake.scheduleCalls,
        1,
        reason: 'the granted permission is acted on straight away',
      );
      expect(fake.pending, 1);
      expect(container.read(notificationsPrefsProvider).enabled, isTrue);
    });

    testWidgets('switching notifications off withdraws the reminder', (
      tester,
    ) async {
      final (container, fake) = await pumpSection(
        tester,
        masterOn: true,
        withStreak: true,
        osAllows: true,
      );

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(container.read(notificationsPrefsProvider).enabled, isFalse);
      expect(fake.cancelCalls, greaterThanOrEqualTo(1));
      expect(fake.pending, 0);
      expect(fake.scheduleCalls, 0);
    });
  });
}
