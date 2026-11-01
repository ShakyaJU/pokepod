import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Stable id for the one reminder PokéPod can send. Reusing a single id means
/// a new schedule always replaces the previous one, so a duplicate
/// notification is impossible by construction.
const int kStreakReminderId = 7331;

const String kStreakReminderChannelId = 'pokepod_streak_reminders';
const String kStreakReminderChannelName = 'Who\'s That Pokémon? reminders';
const String kStreakReminderChannelDescription =
    'A friendly nudge when your Who\'s That Pokémon? streak is at risk '
    'because today\'s challenge is still unplayed.';

/// Payload carried by the reminder; tapping it opens the game.
const String kReminderPayloadMystery = 'mystery';

/// Local hour of the evening reminder (a few hours before the local-midnight
/// deadline, so there is a real chance to play before the streak can end).
const int kReminderHour = 20;

String streakReminderTitle() => 'Your Pokémon streak needs you! 🔥';

String streakReminderBody(int streak) =>
    'Your $streak-day streak is waiting. Play today\'s challenge before it expires!';

/// Abstraction over the platform notification plugin, mirroring the app's
/// [SoundBackend] pattern: all logic can be tested with a fake, and tests
/// never touch platform channels.
abstract class StreakReminderScheduler {
  /// Prepares timezone data and the Android channel. Safe to call more than
  /// once; never throws on an unsupported platform.
  Future<void> init();

  /// Whether the OS currently allows notifications (the real Android
  /// permission state, not the in-app preference).
  Future<bool> notificationsEnabled();

  /// Asks for the OS permission (Android 13+). Older versions grant it by
  /// default. Returns whether notifications are allowed afterwards.
  Future<bool> requestPermission();

  /// Arms (or replaces) the single reminder at [when]. Failures are the
  /// caller's to observe; this implementation never throws for scheduling
  /// problems on unsupported platforms.
  Future<void> schedule({
    required DateTime when,
    required String title,
    required String body,
    required String payload,
  });

  /// Removes the reminder if it is still pending.
  Future<void> cancel();

  /// Details of the notification the app was launched from, if any.
  Future<NotificationAppLaunchDetails?> launchDetails();

  /// Called when the user taps a delivered notification.
  set onOpened(void Function(String payload)? callback);
}

/// Real implementation backed by flutter_local_notifications.
class FlutterStreakReminderScheduler implements StreakReminderScheduler {
  FlutterStreakReminderScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  void Function(String payload)? _onOpened;

  @override
  set onOpened(void Function(String payload)? callback) => _onOpened = callback;

  @override
  Future<void> init() async {
    if (_initialized || !notificationsSupported) {
      return;
    }
    _initialized = true;
    await _initTimezone();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/notification_icon'),
        // request*Permission is false everywhere: the OS is only ever asked
        // when the user taps "Enable notifications" or flips the switch in
        // Settings, never just because PokéPod started. (Without these two
        // blocks the plugin throws on iOS/macOS and reminders silently stop
        // working there.)
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) {
          _onOpened?.call(payload);
        }
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            kStreakReminderChannelId,
            kStreakReminderChannelName,
            description: kStreakReminderChannelDescription,
            importance: Importance.high,
          ),
        );
  }

  /// Timezone database plus the device's IANA zone, so scheduled times follow
  /// the user's local clock and daylight-saving changes.
  Future<void> _initTimezone() async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // A missing zone name only affects exotic devices; scheduling below
      // then falls back to the current UTC offset.
    }
  }

  @override
  Future<bool> notificationsEnabled() async {
    if (!notificationsSupported) {
      return false;
    }
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.areNotificationsEnabled() ?? true;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return (await ios.checkPermissions())?.isEnabled ?? true;
      }
      final mac = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (mac != null) {
        return (await mac.checkPermissions())?.isEnabled ?? true;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!notificationsSupported) {
      return false;
    }
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.requestNotificationsPermission() ??
            await notificationsEnabled();
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            await notificationsEnabled();
      }
      final mac = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (mac != null) {
        return await mac.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            await notificationsEnabled();
      }
      return await notificationsEnabled();
    } catch (_) {
      return false;
    }
  }

  NotificationDetails get _details => const NotificationDetails(
    android: AndroidNotificationDetails(
      kStreakReminderChannelId,
      kStreakReminderChannelName,
      channelDescription: kStreakReminderChannelDescription,
      icon: '@drawable/notification_flame',
      sound: RawResourceAndroidNotificationSound('notification'),
      priority: Priority.high,
      importance: Importance.high,
    ),
  );

  @override
  Future<void> schedule({
    required DateTime when,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (!notificationsSupported) {
      return;
    }
    await init();
    await _plugin.zonedSchedule(
      id: kStreakReminderId,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: _details,
      // Inexact by design: the OS batches it near the requested time, which
      // respects battery policies and needs no exact-alarm permission.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  @override
  Future<void> cancel() async {
    if (!notificationsSupported) {
      return;
    }
    try {
      await _plugin.cancel(id: kStreakReminderId);
    } catch (_) {
      // Nothing pending is a success.
    }
  }

  @override
  Future<NotificationAppLaunchDetails?> launchDetails() async {
    if (!notificationsSupported) {
      return null;
    }
    try {
      await init();
      return await _plugin.getNotificationAppLaunchDetails();
    } catch (_) {
      return null;
    }
  }
}

/// False on web and on desktop hosts (including test hosts), where no
/// notification platform exists. Kept as a function so tests can reason about
/// it independently of any plugin channel.
bool get notificationsSupported =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

/// Whether PokéPod can actually jump to the system notification settings.
/// Only Android is wired up for that (through `pokepod/platform`); on iOS and
/// macOS the permission has to be changed by hand in the system Settings app,
/// so Settings never offers a button that would do nothing.
bool get canOpenSystemNotificationSettings => !kIsWeb && Platform.isAndroid;

/// Opens the app's page in Android's system notification settings, so the
/// user can grant or revoke the permission that PokéPod itself cannot change.
Future<void> openSystemNotificationSettings() async {
  if (!canOpenSystemNotificationSettings) {
    return;
  }
  try {
    await const MethodChannel(
      'pokepod/platform',
    ).invokeMethod('openNotificationSettings');
  } catch (_) {
    // Settings are a convenience; failing to open them must not crash.
  }
}
