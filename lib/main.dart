import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/startup_error.dart';
import 'core/storage/local_store.dart';
import 'features/notifications/notifications_controller.dart';
import 'features/widgets/specimen_widget_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local storage is essential, but it must never be able to leave the user
  // staring at a blank screen: `_loadPreferences` reports every failure and
  // returns null instead of throwing, and we fall back to a retryable error
  // screen rather than never calling [runApp].
  final (prefs, failure) = await _loadPreferences();
  if (prefs == null) {
    runApp(
      StartupErrorApp(
        error: failure ?? 'Local storage failed to load for an unknown reason.',
        onRetry: main,
      ),
    );
    return;
  }

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const PokePodApp(),
    ),
  );
}

/// Loads persisted preferences, retrying once so a transient I/O hiccup does
/// not take the whole app down.
///
/// Never throws: returns `(prefs, null)` on success or `(null, error)` with
/// every attempt written to the log, so a startup failure is always
/// diagnosable from `adb logcat -s flutter`.
Future<(SharedPreferences?, Object?)> _loadPreferences() async {
  Object? lastFailure;
  for (var attempt = 1; attempt <= 2; attempt++) {
    try {
      return (await SharedPreferences.getInstance(), null);
    } catch (error, stackTrace) {
      lastFailure = error;
      debugPrint(
        'PokéPod: SharedPreferences load failed (attempt $attempt/2): '
        '$error\n$stackTrace',
      );
    }
  }
  return (null, lastFailure);
}

/// Work performed by the brief headless engine the native daily alarm starts
/// shortly after local midnight: refresh today's Specimen of the Day into the
/// home-screen widgets and (re-)arm today's streak reminder. It reuses the
/// exact same Dart logic as the foreground app, so the widget can never
/// disagree with Discover.
final widgetBackgroundTaskProvider = FutureProvider<void>((ref) async {
  await refreshSpecimenWidget(ref);
  await refreshStreakReminder(ref.container);
});

/// Background entrypoint (`SpecimenWidgetProvider`'s daily alarm). Nothing UI
/// is built; the engine lives only long enough to update stored widget data
/// and re-arm the reminder, then the native side destroys it.
@pragma('vm:entry-point')
Future<void> widgetBackgroundMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  try {
    await container.read(widgetBackgroundTaskProvider.future);
  } catch (_) {
    // Best-effort: a failed refresh still leaves the previous widget data.
  } finally {
    container.dispose();
  }
  try {
    await const MethodChannel('pokepod/widget_bg').invokeMethod<void>('done');
  } catch (_) {
    // The native runner has its own timeout; nothing to do if it vanished.
  }
}
