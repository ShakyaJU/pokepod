import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/utils/formatters.dart';

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

/// How long before the daily reset the streak reminder fires.
///
/// The challenge resets at local midnight — the same boundary the challenge
/// date and the streak are counted on — so the reminder is exactly this much
/// earlier on the device's own clock. No hour of the day is hard-coded: three
/// hours before midnight is whatever instant that turns out to be, including
/// on a day the clocks move.
const Duration kStreakReminderLead = Duration(hours: 3);

/// How many consecutive challenge days the reminder walk steps over looking
/// for a slot that can still be delivered. One step covers a normal evening
/// launch; the rest absorb a device whose clock or challenge date has moved,
/// without ever risking an unbounded loop.
const int kStreakReminderLookAheadDays = 8;

/// The instant the daily challenge resets after [now]: the next local
/// midnight. This is the single source of truth the reminder is measured
/// against, so the notification can never disagree with the challenge date.
DateTime nextDailyReset(DateTime now) =>
    DateTime(now.year, now.month, now.day + 1);

/// When the reminder for challenge day [day] fires: exactly
/// [kStreakReminderLead] before that day's reset.
///
/// An unrecognised day key falls back to the epoch, so the caller steps over
/// it instead of arming a reminder for a moment that does not exist.
DateTime streakReminderTimeFor(String day) {
  final date = parseDateKey(day);
  if (date == null) {
    return DateTime.utc(1970);
  }
  return DateTime(
    date.year,
    date.month,
    date.day + 1,
  ).subtract(kStreakReminderLead);
}

/// The challenge day after [day], as a `YYYY-MM-DD` key.
///
/// An unrecognised key is returned unchanged, which ends the caller's walk
/// rather than letting it loop forever on data that cannot be parsed.
String followingDayKey(String day) {
  final date = parseDateKey(day);
  if (date == null) {
    return day;
  }
  return utcDateKey(date.add(const Duration(days: 1)));
}

String streakReminderTitle() => 'Your PokéPod streak is at risk!';

/// The body states the deadline the schedule actually guarantees: the alarm is
/// always [kStreakReminderLead] ahead of the reset, so the wording is derived
/// from that constant and can never drift away from it.
String streakReminderBody() =>
    'Your daily challenge resets in ${kStreakReminderLead.inHours} hours. '
    'Play Who\'s That Pokémon? to keep your streak alive!';

/// The absolute instant Android should fire at for the local moment [when].
///
/// The device's zone only decides how that instant is *written down*: the
/// wall-clock string and the zone name sent to the plugin always come from
/// the same [tz.TZDateTime], so they always agree and the moment itself
/// never moves — even when the zone fell back to UTC because the device's
/// zone could not be read.
tz.TZDateTime reminderInstant(DateTime when) =>
    tz.TZDateTime.from(when, tz.local);

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

  /// The one in-flight setup, shared by concurrent callers (bootstrap, launch
  /// details, scheduling) and cleared when it finishes so a failure can be
  /// retried rather than remembered.
  Future<void>? _initializing;
  void Function(String payload)? _onOpened;

  @override
  set onOpened(void Function(String payload)? callback) => _onOpened = callback;

  @override
  Future<void> init() {
    if (_initialized || !notificationsSupported) {
      return Future.value();
    }
    return _initializing ??= _setup();
  }

  /// Prepares timezone data, the plugin and the channel. It never throws:
  /// every caller treats setup as best-effort, and a failure is logged and
  /// left un-initialised — marking the work as done before it happened would
  /// disable reminders for the rest of the session after one transient error,
  /// which is exactly how scheduling gets skipped without a trace.
  Future<void> _setup() async {
    try {
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
              // Android 8+ plays the channel's sound and ignores the
              // per-notification one, so the bundled reminder sound has to live
              // here to be heard. A channel already created is immutable, so
              // installs that have one keep the sound they started with.
              sound: RawResourceAndroidNotificationSound('notification'),
            ),
          );
      _initialized = true;
    } catch (error) {
      // Logged, not rethrown: _initialized stays false, so the next
      // evaluation runs setup again instead of believing it already happened.
      debugPrint('PokéPod: notification setup failed (will retry): $error');
    } finally {
      _initializing = null;
    }
  }

  /// Timezone database plus the device's IANA zone, so scheduled times follow
  /// the user's local clock and daylight-saving changes.
  Future<void> _initTimezone() async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (error) {
      // Scheduling below still fires at the right instant — the wall-clock
      // string and the zone name sent to Android always come from the same
      // TZDateTime — but a zone that cannot be read is worth seeing in the
      // log rather than passing as success.
      debugPrint('PokéPod: device timezone unavailable ($error)');
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
    } catch (error) {
      // Read as "notifications are off", which cancels rather than arms, so
      // the failure is logged instead of passing as a plain denial.
      debugPrint('PokéPod: could not read notification permission: $error');
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
    } catch (error) {
      // Answered with "no", which leaves reminders off — logged so a broken
      // permission path is not mistaken for the user declining.
      debugPrint('PokéPod: could not request notification permission: $error');
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
      scheduledDate: reminderInstant(when),
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
    } catch (error) {
      // A cancel that cannot reach the platform leaves a stale reminder
      // armed for a situation that no longer holds, so it is logged rather
      // than passed off as "nothing pending".
      debugPrint('PokéPod: could not cancel the streak reminder: $error');
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
    } catch (error) {
      // Without launch details a tap on a delivered reminder cannot open the
      // game, which is worth seeing in the log.
      debugPrint('PokéPod: could not read the launch details: $error');
      return null;
    }
  }
}

/// False on web and on desktop hosts (including test hosts), where no
/// notification platform exists. Kept as a function so tests can reason about
/// it independently of any plugin channel.
///
/// [debugNotificationsSupported] overrides it so tests can walk the
/// Android-only permission flow on any host; production never sets it.
@visibleForTesting
bool? debugNotificationsSupported;

bool get notificationsSupported =>
    debugNotificationsSupported ??
    (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS));

/// Whether PokéPod can actually jump to the system notification settings.
/// Only Android is wired up for that (through `pokepod/platform`); on iOS and
/// macOS the permission has to be changed by hand in the system Settings app,
/// so Settings never offers a button that would do nothing.
///
/// [debugCanOpenSystemNotificationSettings] overrides it for the same reason
/// as [debugNotificationsSupported].
@visibleForTesting
bool? debugCanOpenSystemNotificationSettings;

bool get canOpenSystemNotificationSettings =>
    debugCanOpenSystemNotificationSettings ?? (!kIsWeb && Platform.isAndroid);

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
  } catch (error) {
    // Settings are a convenience: failing to open them must not crash, but
    // it does mean the user is stuck, so it is logged.
    debugPrint('PokéPod: could not open the notification settings: $error');
  }
}
