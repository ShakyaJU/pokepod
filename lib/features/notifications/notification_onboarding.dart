import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import 'notifications_controller.dart';

/// One-time, dismissible explanation shown on the first launch of a
/// brand-new install. It never triggers the Android permission dialog by
/// itself: the OS prompt appears only after the user explicitly taps
/// "Enable notifications". "Not now" (or simply dismissing the sheet) records
/// the decision and PokéPod never asks again; notifications can still be
/// turned on later in Settings.
Future<void> showNotificationOnboarding(BuildContext context, WidgetRef ref) {
  // Recorded the moment it appears: whatever the user does next (enable,
  // decline, or simply swipe it away) PokéPod never shows it again.
  ref.read(notificationsPrefsProvider.notifier).markAsked();
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: true,
    showDragHandle: true,
    builder: (context) => const _NotificationOnboardingSheet(),
  );
}

class _NotificationOnboardingSheet extends ConsumerWidget {
  const _NotificationOnboardingSheet();

  Future<void> _enable(BuildContext context, WidgetRef ref) async {
    final service = ref.read(notificationServiceProvider);
    final granted = await service.requestPermission();
    // The in-app preference follows the real answer; if permission was
    // denied, Settings will show the blocked state and how to change it.
    ref.read(notificationsPrefsProvider.notifier).setEnabled(granted);
    ref.read(notificationsPrefsProvider.notifier).markAsked();
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.lg,
          Space.sm,
          Space.lg,
          Space.lg,
        ),
        // Scrollable so a short or landscape screen (and large system text)
        // can still reach both buttons instead of overflowing.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary.withValues(alpha: 0.14),
                  ),
                  child: Icon(
                    Icons.notifications_active_outlined,
                    size: 32,
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: Space.md),
              Text(
                'Keep your streak alive',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Space.sm),
              Text(
                'Stay on top of your Pokémon journey! PokéPod can remind you '
                'when your Who\'s That Pokémon? streak is at risk, so you have '
                'a chance to keep it alive.\n\n'
                'Reminders are optional, arrive only while you have an active '
                'streak, and never leave your device.',
                style: TextStyle(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Space.lg),
              FilledButton.icon(
                onPressed: () => _enable(context, ref),
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Enable notifications'),
              ),
              const SizedBox(height: Space.sm),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
