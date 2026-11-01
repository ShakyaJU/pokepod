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
    final enabled = await ref
        .read(notificationServiceProvider)
        .notificationsEnabled();
    if (mounted) {
      setState(() => _granted = enabled);
    }
  }

  Future<void> _openSystemSettings() async {
    await openSystemNotificationSettings();
    if (mounted) {
      await _refreshPermission();
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
              onChanged: notificationsSupported
                  ? (value) {
                      notifier.setEnabled(value);
                      _refreshPermission();
                    }
                  : null,
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
                'A nudge in the evening when you have an active streak and '
                'today\'s challenge is still unplayed.',
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
