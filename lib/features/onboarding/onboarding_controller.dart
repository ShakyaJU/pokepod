import 'package:shared_preferences/shared_preferences.dart';

import '../notifications/notifications_controller.dart';

/// Versioned key the first-run introduction records itself under. The value is
/// never read — only its presence matters — so a future revision can keep
/// showing the guide without having to migrate anything.
const String kOnboardingStorageKey = 'onboarding.v1';

/// Whether the introduction has already been finished or skipped on this
/// device.
bool isOnboardingCompleted(SharedPreferences prefs) =>
    prefs.containsKey(kOnboardingStorageKey);

/// Records the introduction as seen, so a restart can never repeat it.
Future<void> markOnboardingCompleted(SharedPreferences prefs) =>
    prefs.setBool(kOnboardingStorageKey, true);

/// Whether this launch owes a brand-new user the introduction.
///
/// [firstLaunch] is [shouldShowNotificationOnboarding] as read **before** the
/// first-launch notification sheet ran. That sheet records itself as answered
/// the moment it appears, so reading it afterwards would make a returning user
/// and a first-time user identical — and every update that adds onboarding
/// would then push the whole existing audience through it.
///
/// [prefs] supplies the other half: whether this device has already finished
/// or skipped the guide, which is what stops a restart repeating it.
bool shouldShowAppOnboarding(
  SharedPreferences prefs, {
  required bool firstLaunch,
}) => firstLaunch && !isOnboardingCompleted(prefs);
