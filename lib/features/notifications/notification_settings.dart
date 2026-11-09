import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_system/widgets.dart';
import '../trainer_profile/settings_page.dart';
import 'notification_service.dart';
import 'notifications_controller.dart';

/// The Notifications section of Settings: the master preference, the
/// Who's That Pokémon? streak reminder toggle, and a clear reading of the
/// real Android permission state with a route to the system settings screen.
class NotificationSettingsSection extends ConsumerStatefulWidget {
  const NotificationSettingsSection({super.key});

  @override
  ConsumerState<NotificationSettingsSection> createState() =>
      _NotificationSettingsSectionState();
}

class _NotificationSettingsSectionState
    extends ConsumerState<NotificationSettingsSection> {
  /// The OS permission state: null while unknown (or on platforms without
  /// notifications), true or false once checked.
  bool? _granted;

  @override
  void initState() {
    super.initState();
    _refreshPermission();
  }

  Future<void> _refreshPermission() async {
    if (!notificationsSupported) {
      return;
    }
    bool allowed;
    try {
      allowed = await ref
          .read(notificationServiceProvider)
          .notificationsEnabled();
    } catch (error) {
      debugPrint('PokéPod: could not read notification permission: $error');
      allowed = false;
    }
    if (mounted) {
      setState(() => _granted = allowed);
    }
  }

  /// Re-reads the real permission state and re-evaluates the reminder, so
  /// every change made from this page — or in Android's own settings screen,
  /// which is the usual way the permission moves — takes effect now instead
  /// of at the next launch.
  Future<void> _recheckAndRefresh() async {
    if (!mounted) {
      return;
    }
    await _refreshPermission();
    if (mounted) {
      await refreshStreakReminder(ProviderScope.containerOf(context));
    }
  }

  Future<void> _openSystemSettings() async {
    await openSystemNotificationSettings();
    if (mounted) {
      await _recheckAndRefresh();
    }
  }

  /// The master switch. Turning it off takes effect immediately; turning it
  /// on checks the real OS state first and, when notifications are not
  /// allowed yet, explains why PokéPod needs the permission before the
  /// system prompt can appear — the OS is only ever asked from that explicit
  /// choice, never on its own.
  Future<void> _setMaster(bool value) async {
    final notifier = ref.read(notificationsPrefsProvider.notifier);
    if (!value) {
      notifier.setEnabled(false);
      await _recheckAndRefresh();
      return;
    }
    if (await _osAllowsNotifications()) {
      notifier.setEnabled(true);
      await _recheckAndRefresh();
      return;
    }
    if (!mounted) {
      return;
    }
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Allow notifications?'),
        content: const Text(
          'PokéPod needs Android\'s notification permission to send your '
          'optional reminders. They stay on this device — nothing is '
          'uploaded — and you can turn them off whenever you like.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) {
      // Nothing was enabled and nothing was asked: the switch stays off.
      return;
    }
    // The preference goes on even when the system says no, so the blocked
    // notice below can point at the system settings instead of the switch
    // quietly hiding a state the user asked for.
    notifier.setEnabled(true);
    try {
      await ref.read(notificationServiceProvider).requestPermission();
    } catch (error) {
      debugPrint('PokéPod: could not request notification permission: $error');
    }
    await _recheckAndRefresh();
  }

  Future<bool> _osAllowsNotifications() async {
    try {
      return await ref.read(notificationServiceProvider).notificationsEnabled();
    } catch (error) {
      debugPrint('PokéPod: could not read notification permission: $error');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(notificationsPrefsProvider);
    final notifier = ref.read(notificationsPrefsProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final blocked = prefs.enabled && _granted == false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Notifications'),
        SettingsGroup(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('Notifications'),
              subtitle: Text(
                notificationsSupported
                    ? 'Allow optional local reminders. Nothing is uploaded; '
                          'there are no accounts.'
                    : 'Notifications are not available on this platform.',
              ),
              value: prefs.enabled,
              onChanged: notificationsSupported ? _setMaster : null,
            ),
            if (blocked) ...[
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.notifications_off_outlined,
                  color: scheme.error,
                ),
                title: const Text('Notifications are blocked'),
                subtitle: Text(
                  canOpenSystemNotificationSettings
                      ? 'PokéPod cannot send reminders while the system '
                            'permission is off. You can change that in '
                            'Android settings.'
                      : 'PokéPod cannot send reminders while the system '
                            'permission is off. Turn notifications on for '
                            'PokéPod in your system settings.',
                ),
                trailing: canOpenSystemNotificationSettings
                    ? TextButton(
                        onPressed: _openSystemSettings,
                        child: const Text('Open settings'),
                      )
                    : null,
              ),
            ],
            const Divider(height: 1),
            SwitchListTile(
              secondary: const Icon(Icons.local_fire_department_outlined),
              title: const Text('Who\'s That Pokémon? streak reminder'),
              subtitle: const Text(
                'Three hours before the daily reset, when you have an active '
                'streak and today\'s challenge is still unplayed.',
              ),
              value: prefs.streakReminder,
              onChanged:
                  notificationsSupported && prefs.enabled && (_granted ?? true)
                  ? notifier.setStreakReminder
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}
