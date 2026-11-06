import 'package:flutter/material.dart';

/// Full-screen fallback shown when PokéPod cannot read its local storage.
///
/// Every persisted feature (favourites, streaks, theme, cached Pokédex) hangs
/// off `sharedPreferencesProvider`, so without a loaded instance none of the
/// app's providers can run. Rather than leaving the user on a permanently
/// blank screen, this explains what happened and offers a retry.
///
/// It deliberately depends on nothing outside the Flutter framework — no
/// providers, no saved theme, no plugins — so it can render no matter which
/// part of startup failed.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({
    super.key,
    required this.error,
    required this.onRetry,
  });

  /// The storage failure, surfaced so the user can report it verbatim.
  final Object error;

  /// Re-runs the startup sequence; wired to the retry button.
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return Scaffold(
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.storage_rounded,
                        size: 56,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'PokéPod could not start',
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your progress is stored on this device and could not be '
                        'read. Nothing has been deleted — please try again.',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '$error',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 8,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 28),
                      FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
