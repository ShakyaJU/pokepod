import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/storage/local_store.dart';
import '../../core/utils/formatters.dart';
import '../mystery/mystery_controller.dart';
import 'notification_service.dart';

/// The user's in-app notification choices. Deliberately separate from the OS
/// permission: a toggle can be on while Android permission is off (and the UI
/// must be able to say so).
class NotificationsPrefs {
  const NotificationsPrefs({
    this.enabled = false,
    this.streakReminder = true,
    this.asked = false,
  });

  /// Master preference: no notification of any kind without it.
  final bool enabled;

  /// The Who's That Pokémon? streak reminder toggle.
  final bool streakReminder;

  /// Whether the first-install explanation has been answered (either choice),
  /// so it is never shown again.
  final bool asked;

  NotificationsPrefs copyWith({
    bool? enabled,
    bool? streakReminder,
    bool? asked,
  }) => NotificationsPrefs(
    enabled: enabled ?? this.enabled,
    streakReminder: streakReminder ?? this.streakReminder,
    asked: asked ?? this.asked,
  );

  Map<String, Object> toJson() => {
    'enabled': enabled,
    'streakReminder': streakReminder,
    'asked': asked,
  };

  static NotificationsPrefs fromStored(Map<String, dynamic> json) {
    final enabled = json['enabled'];
    final reminder = json['streakReminder'];
    final asked = json['asked'];
    return NotificationsPrefs(
      enabled: enabled == true,
      streakReminder: reminder != false,
      asked: asked == true,
    );
  }
}

class NotificationsPrefsNotifier extends Notifier<NotificationsPrefs> {
  static const storageKey = 'notifications.v1';

  @override
  NotificationsPrefs build() {
    final json = readJsonMap(ref.watch(sharedPreferencesProvider), storageKey);
    return json == null
        ? const NotificationsPrefs()
        : NotificationsPrefs.fromStored(json);
  }

  void setEnabled(bool value) => _set(state.copyWith(enabled: value));

  void setStreakReminder(bool value) =>
      _set(state.copyWith(streakReminder: value));

  /// Records that the first-install explanation has been answered, whichever
  /// button was pressed.
  void markAsked() => _set(state.copyWith(asked: true));

  void _set(NotificationsPrefs next) {
    state = next;
    ref
        .read(sharedPreferencesProvider)
        .setString(storageKey, jsonEncode(next.toJson()));
  }
}

final notificationsPrefsProvider =
    NotifierProvider<NotificationsPrefsNotifier, NotificationsPrefs>(
      NotificationsPrefsNotifier.new,
    );

/// The platform notification layer. Overridden with a fake in tests.
final notificationServiceProvider = Provider<StreakReminderScheduler>(
  (ref) => FlutterStreakReminderScheduler(),
);

/// Storage keys that indicate the device already belongs to an existing user.
/// Someone who has never had any of these has a brand-new install and is the
/// only audience for the first-install explanation.
const List<String> kProgressStorageKeys = [
  'research.v1',
  'favourites.v1',
  'recent.v1',
  'notes.v1',
  'collections.v1',
  'teams.v1',
  'profile.v1',
  'mystery.v1',
];

bool hasAnyProgressData(SharedPreferences prefs) =>
    kProgressStorageKeys.any(prefs.containsKey);

/// The first-install explanation is shown only to brand-new installs that have
/// not answered it yet. Existing users (any progress data) never see it.
bool shouldShowNotificationOnboarding(
  SharedPreferences prefs,
  NotificationsPrefs notifications,
) => !notifications.asked && !hasAnyProgressData(prefs);

/// Pure eligibility rule for the streak reminder, extracted so every gate can
/// be unit-tested. [now] must be before [reminderTime] on the same day: once
/// the evening window has passed, arming a reminder for the past would only
/// produce noise.
bool streakReminderEligible({
  required bool masterEnabled,
  required bool reminderToggle,
  required int currentStreak,
  required bool completedToday,
  required bool permissionGranted,
  required DateTime now,
  required DateTime reminderTime,
}) =>
    masterEnabled &&
    reminderToggle &&
    currentStreak > 0 &&
    !completedToday &&
    permissionGranted &&
    now.isBefore(reminderTime);

/// Re-evaluates the single pending reminder from the current state.
///
/// Candidates are walked one challenge day at a time: today's slot while it is
/// still ahead of the clock and unplayed, otherwise tomorrow's, and so on.
/// Every slot sits exactly [kStreakReminderLead] before that day's local
/// midnight reset, so the notification, the challenge date and the streak can
/// never disagree about when the day ends.
///
/// Only a finished day and a slot whose moment has already passed are stepped
/// over. A missing streak, a switched-off reminder or a missing permission
/// ends the walk at once and cancels whatever is armed, instead of hunting for
/// a later slot that would fail the same gates. Because the plugin id is
/// stable, repeated calls converge on exactly one pending reminder, so an app
/// restart or a burst of state changes can never stack a second copy.
Future<void> refreshStreakReminder(ProviderContainer container) async {
  final service = container.read(notificationServiceProvider);
  final prefs = container.read(notificationsPrefsProvider);
  final streaks = container.read(mysteryStreaksProvider);
  final mystery = container.read(mysteryProvider);
  final now = container.read(clockProvider)();
  // A saved date that cannot be parsed must not stop the reminder: fall back
  // to today, which is the day the challenge would be on anyway.
  final storedDay = container.read(challengeDayProvider);
  final day = parseDateKey(storedDay) == null ? localDateKey(now) : storedDay;

  var granted = false;
  try {
    granted = prefs.enabled && await service.notificationsEnabled();
  } catch (error) {
    // Treated as "not allowed", which cancels — so a broken permission read
    // must be visible instead of looking like the user saying no.
    debugPrint('PokéPod: could not read notification permission: $error');
    granted = false;
  }

  try {
    var targetDay = day;
    for (var step = 0; step < kStreakReminderLookAheadDays; step++) {
      final when = streakReminderTimeFor(targetDay);
      final eligible = streakReminderEligible(
        masterEnabled: prefs.enabled,
        reminderToggle: prefs.streakReminder,
        currentStreak: streaks.current,
        completedToday: mystery.completed(targetDay),
        permissionGranted: granted,
        now: now,
        reminderTime: when,
      );
      if (eligible) {
        await service.schedule(
          when: when,
          title: streakReminderTitle(),
          body: streakReminderBody(),
          payload: kReminderPayloadMystery,
        );
        return;
      }
      // These gates cannot change between iterations, so nothing further
      // along the walk would satisfy them either.
      if (!granted || !prefs.streakReminder || streaks.current <= 0) {
        break;
      }
      targetDay = followingDayKey(targetDay);
    }
    await service.cancel();
  } catch (error) {
    // Scheduling is best-effort: a failure must never disturb the app, but
    // it must not be invisible either — a swallowed scheduling error is
    // exactly how "notifications do not arrive" goes unexplained.
    debugPrint('PokéPod: could not update the streak reminder: $error');
  }
}
