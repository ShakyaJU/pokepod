import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokepod/features/notifications/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The delivery chain for a scheduled reminder crosses three layers this host
/// cannot execute: the manifest that has to register the plugin's receivers,
/// the Gradle desugaring its java.time scheduling needs, and the Dart side
/// that turns a local wall-clock time into the instant Android fires at.
///
/// None of it is reachable from a widget test, so the contract is pinned
/// directly here, the way `widget_layouts_test.dart` pins the home-screen
/// widget. The manifest checks are the important ones: without a declared
/// `ScheduledNotificationReceiver`, `zonedSchedule()` still succeeds, no
/// error surfaces anywhere in Dart, and the reminder simply never appears.
void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  final gradle = File('android/app/build.gradle.kts');

  group('Android manifest', () {
    test('declares the receiver that actually delivers the reminder', () {
      final xml = manifest.readAsStringSync();
      final receiver = RegExp(
        '<receiver[^>]*'
        'com\\.dexterous\\.flutterlocalnotifications\\.'
        'ScheduledNotificationReceiver[^>]*/>',
        multiLine: true,
      ).firstMatch(xml);

      expect(
        receiver,
        isNotNull,
        reason:
            'flutter_local_notifications schedules through an AlarmManager '
            'PendingIntent aimed at ScheduledNotificationReceiver, and its own '
            'manifest declares no receivers — without this entry the alarm '
            'fires at a component Android does not know and the notification '
            'never shows, with no error raised anywhere',
      );
      expect(
        receiver!.group(0),
        contains('android:exported="false"'),
        reason: 'it is a plugin-internal receiver, not one for other apps',
      );
    });

    test('re-arms pending reminders after a reboot or an app update', () {
      final xml = manifest.readAsStringSync();
      final receiver = RegExp(
        '<receiver[^>]*'
        'com\\.dexterous\\.flutterlocalnotifications\\.'
        'ScheduledNotificationBootReceiver[^>]*>'
        '.*?</receiver>',
        multiLine: true,
        dotAll: true,
      ).firstMatch(xml);

      expect(
        receiver,
        isNotNull,
        reason:
            'AlarmManager alarms do not survive a reboot, so the plugin needs '
            'its boot receiver to re-register whatever was still pending — '
            'the RECEIVE_BOOT_COMPLETED permission above only helps if this '
            'receiver exists to receive it',
      );
      final block = receiver!.group(0)!;
      expect(block, contains('android.intent.action.BOOT_COMPLETED'));
      expect(block, contains('android.intent.action.MY_PACKAGE_REPLACED'));
      expect(block, contains('android:exported="false"'));
    });

    test('declares the permissions the reminder path needs', () {
      final xml = manifest.readAsStringSync();
      expect(
        xml,
        contains('android.permission.POST_NOTIFICATIONS'),
        reason: 'Android 13+ will not show anything without it',
      );
      expect(
        xml,
        contains('android.permission.RECEIVE_BOOT_COMPLETED'),
        reason: 'the boot receivers above cannot run without it',
      );
    });

    test('asks for no exact-alarm access it does not use', () {
      final xml = manifest.readAsStringSync();
      // The reminder is armed with AndroidScheduleMode.inexactAllowWhileIdle,
      // which needs no special permission on any supported Android version —
      // so the manifest must not request one on the user's behalf.
      expect(xml, isNot(contains('SCHEDULE_EXACT_ALARM')));
      expect(xml, isNot(contains('USE_EXACT_ALARM')));
    });

    test('keeps the desugaring flutter_local_notifications depends on', () {
      expect(
        gradle.readAsStringSync(),
        contains('isCoreLibraryDesugaringEnabled = true'),
        reason: 'its java.time scheduling APIs below API 26 need it',
      );
    });

    test('every notification resource referenced from Dart exists', () {
      // A missing icon makes the plugin reject the schedule outright, and a
      // missing sound silently falls back to the default tone.
      const res = 'android/app/src/main/res';
      expect(
        File('$res/drawable/notification_icon.xml').existsSync(),
        isTrue,
        reason: 'AndroidInitializationSettings(@drawable/notification_icon)',
      );
      expect(
        File('$res/drawable/notification_flame.xml').existsSync(),
        isTrue,
        reason: 'the icon the reminder is posted with',
      );
      expect(
        File('$res/raw/notification.mp3').existsSync(),
        isTrue,
        reason: 'the sound the channel is configured with',
      );
    });
  });

  group('scheduled instant', () {
    setUpAll(tzdata.initializeTimeZones);

    test('the reminder fires at the configured hour of the user\'s zone', () {
      final zone = tz.getLocation('Asia/Kolkata');
      tz.setLocalLocation(zone);
      // The same shape refreshStreakReminder produces: a plain local DateTime
      // for 20:00 on the day in question.
      final when = DateTime.fromMillisecondsSinceEpoch(
        tz.TZDateTime(zone, 2026, 10, 30, kReminderHour).millisecondsSinceEpoch,
      );

      final instant = reminderInstant(when);

      expect(
        instant.millisecondsSinceEpoch,
        when.millisecondsSinceEpoch,
        reason: 'the moment asked for is the moment scheduled',
      );
      expect(instant.hour, kReminderHour, reason: 'in the user\'s own zone');
      expect(instant.location.name, 'Asia/Kolkata');
    });

    test('a device zone that cannot be read never shifts the fire time', () {
      // _initTimezone falls back to UTC when the device zone is unavailable.
      // The wall-clock string and the zone name travel together, so Android
      // recomputes exactly the instant that was asked for either way.
      tz.setLocalLocation(tz.getLocation('UTC'));
      final when = DateTime(2026, 10, 30, kReminderHour);

      final instant = reminderInstant(when);

      expect(instant.millisecondsSinceEpoch, when.millisecondsSinceEpoch);
      expect(instant.location.name, 'UTC');
    });
  });

  group('plugin initialization', () {
    setUp(() => debugNotificationsSupported = true);
    tearDown(() => debugNotificationsSupported = null);

    test('a failed setup is logged, not remembered, and tried again', () async {
      final plugin = _FailingPlugin();
      final scheduler = FlutterStreakReminderScheduler(plugin: plugin);

      await scheduler.init();
      expect(plugin.initializeCalls, 1, reason: 'the first attempt ran');

      await scheduler.init();
      expect(
        plugin.initializeCalls,
        2,
        reason:
            'marking setup as done before it succeeded would disable '
            'reminders for the rest of the session after one transient error',
      );
    });

    test('concurrent callers share a single setup', () async {
      final plugin = _RecordingPlugin();
      final scheduler = FlutterStreakReminderScheduler(plugin: plugin);

      await Future.wait([scheduler.init(), scheduler.init(), scheduler.init()]);

      expect(plugin.initializeCalls, 1);
    });

    test('a successful setup never repeats itself', () async {
      final plugin = _RecordingPlugin();
      final scheduler = FlutterStreakReminderScheduler(plugin: plugin);

      await scheduler.init();
      await scheduler.init();

      expect(plugin.initializeCalls, 1);
    });

    test('with the platform gate closed nothing reaches the plugin', () async {
      debugNotificationsSupported = false;
      final plugin = _RecordingPlugin();
      final scheduler = FlutterStreakReminderScheduler(plugin: plugin);

      await scheduler.init();
      await scheduler.schedule(
        when: DateTime(2026, 10, 30, kReminderHour),
        title: 'title',
        body: 'body',
        payload: kReminderPayloadMystery,
      );
      await scheduler.cancel();

      expect(plugin.calls, isEmpty);
      expect(await scheduler.notificationsEnabled(), isFalse);
      expect(await scheduler.requestPermission(), isFalse);
      expect(await scheduler.launchDetails(), isNull);
    });

    test(
      'the reminder is scheduled inexact, needing no special access',
      () async {
        final plugin = _RecordingPlugin();
        final scheduler = FlutterStreakReminderScheduler(plugin: plugin);
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
        final when = DateTime(2026, 10, 30, kReminderHour);

        await scheduler.schedule(
          when: when,
          title: 'Your streak needs you',
          body: 'Play today',
          payload: kReminderPayloadMystery,
        );

        expect(plugin.calls, contains('zonedSchedule'));
        expect(
          plugin.scheduledMode,
          AndroidScheduleMode.inexactAllowWhileIdle,
          reason:
              'an exact alarm would require SCHEDULE_EXACT_ALARM on Android '
              '12+, and a 20:00 nudge does not need minute precision',
        );
        expect(
          plugin.scheduledDate!.millisecondsSinceEpoch,
          when.millisecondsSinceEpoch,
          reason: 'the configured local hour is what Android fires at',
        );
        expect(
          plugin.matchedComponents,
          isNull,
          reason:
              'the reminder is re-evaluated from live streak data each day '
              'rather than repeated with stale copy',
        );
      },
    );
  });
}

/// Records what the scheduler asks of the platform so the setup bookkeeping
/// and the scheduling options can be asserted without a notification platform
/// on the host. The plugin's own constructor is a private factory returning a
/// singleton, so the interface is implemented rather than extended and
/// anything these tests do not model fails loudly through [noSuchMethod].
class _RecordingPlugin implements FlutterLocalNotificationsPlugin {
  final List<String> calls = [];

  int get initializeCalls => calls.length;

  AndroidScheduleMode? scheduledMode;
  tz.TZDateTime? scheduledDate;
  DateTimeComponents? matchedComponents;

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    calls.add('initialize');
    return true;
  }

  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() => null;

  @override
  Future<void> zonedSchedule({
    required int id,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? title,
    String? body,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    calls.add('zonedSchedule');
    scheduledMode = androidScheduleMode;
    this.scheduledDate = scheduledDate;
    matchedComponents = matchDateTimeComponents;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw PlatformException(
    code: 'unimplemented',
    message: 'the fake does not model $invocation',
  );
}

/// A plugin whose initialization always fails, standing in for the transient
/// platform errors real devices produce.
class _FailingPlugin extends _RecordingPlugin {
  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    calls.add('initialize');
    throw PlatformException(code: 'unavailable', message: 'simulated failure');
  }
}
