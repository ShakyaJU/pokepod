import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_system/widgets.dart';
import '../../app/theme/tokens.dart';
import '../../core/audio/sound_service.dart';
import '../../data/providers.dart';
import '../notifications/notification_settings.dart';
import 'backup_dialogs.dart';
import 'edit_trainer_sheet.dart';
import 'profile_controller.dart';

/// Every setting here is backed by existing app behaviour. Nothing is shown
/// for features the app does not have.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final notifier = ref.read(profileProvider.notifier);
    final live = ref.watch(liveStatusProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.xl),
        children: [
          const SectionLabel('Appearance'),
          SettingsGroup(
            children: [
              _Row(
                title: 'Theme',
                description: 'Choose light or dark, or follow your device.',
                control: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                    ),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                  ],
                  selected: {profile.themeMode},
                  onSelectionChanged: (s) => notifier.setThemeMode(s.first),
                ),
              ),
              const Divider(height: 1),
              _Row(
                title: 'Accent Color',
                description: 'Used for highlights across the app.',
                control: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Shows the color the app is actually using, read from the same
                    // provider as the theme, so it cannot lag behind the picker.
                    _AccentIndicator(name: kAccentNames[profile.accentIndex]),
                    const SizedBox(height: Space.sm),
                    Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.sm,
                      children: [
                        for (var i = 0; i < kAccents.length; i++)
                          Semantics(
                            button: true,
                            selected: i == profile.accentIndex,
                            label: '${kAccentNames[i]} accent',
                            excludeSemantics: true,
                            onTap: () => notifier.setAccent(i),
                            child: GestureDetector(
                              key: Key('accent-$i'),
                              onTap: () => notifier.setAccent(i),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: kAccents[i],
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: i == profile.accentIndex
                                        ? scheme.onSurface
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: i == profile.accentIndex
                                    ? const Icon(
                                        Icons.check,
                                        color: AppColors.obsidian,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          const SectionLabel('Trainer'),
          SettingsGroup(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(profile.nickname),
                subtitle: const Text('Edit your nickname and avatar'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showEditTrainerSheet(context),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          const NotificationSettingsSection(),
          const SizedBox(height: Space.lg),
          const SoundSettingsSection(),
          const SizedBox(height: Space.lg),
          const SectionLabel('Data'),
          SettingsGroup(
            children: [
              ListTile(
                leading: const Icon(Icons.save_alt_outlined),
                title: const Text('Backup progress'),
                subtitle: const Text(
                  'Copy a backup of your progress to the clipboard',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => exportBackup(context, ref),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.restore_outlined),
                title: const Text('Restore from backup'),
                subtitle: const Text(
                  'Paste a backup to replace the progress on this device',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showRestoreDialog(context, ref),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(switch (live) {
                  LiveState.live => Icons.cloud_done_outlined,
                  LiveState.offline => Icons.cloud_off_outlined,
                  LiveState.unknown => Icons.cloud_queue,
                }),
                title: const Text('Connection to PokéAPI'),
                subtitle: Text(switch (live) {
                  LiveState.live =>
                    'Connected. Data is loaded on demand and saved on this device.',
                  LiveState.offline =>
                    'Offline. Only data already saved on this device is available.',
                  LiveState.unknown =>
                    'No request has been made yet this session.',
                }),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          const SectionLabel('Storage and privacy'),
          Panel(
            child: Text(
              'Research progress, favourites, collections, teams, notes, your trainer profile and '
              'Who\'s That Pokémon? history are stored only on this device. There are no accounts, '
              'no cloud backup and no analytics. Uninstalling the app or clearing its data erases '
              'this progress, so use "Backup progress" and keep the copied text somewhere safe.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Sound Effects setting: one switch between the Notifications section and
/// Data. It only writes [soundEffectsPrefsProvider] — [soundServiceProvider]
/// is what enforces the choice, so every current and future effect in the app
/// obeys this one switch rather than each screen deciding for itself.
class SoundSettingsSection extends ConsumerWidget {
  const SoundSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(soundEffectsPrefsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Sound Effects'),
        SettingsGroup(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.volume_up_outlined),
              title: const Text('Sound Effects'),
              subtitle: const Text(
                'Enable or disable sound effects throughout PokéPod.',
              ),
              value: enabled,
              onChanged: (value) => ref
                  .read(soundEffectsPrefsProvider.notifier)
                  .setEnabled(value),
            ),
          ],
        ),
      ],
    );
  }
}

/// Visual group card used by the Settings sections (shared with the
/// Notifications section).
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Material so the ListTiles inside can paint their ink and background.
    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.description,
    required this.control,
  });

  final String title;
  final String description;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            description,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Space.sm),
          control,
        ],
      ),
    );
  }
}

class _AccentIndicator extends StatelessWidget {
  const _AccentIndicator({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: 'Current accent color: $name',
      excludeSemantics: true,
      child: Row(
        key: const Key('accent-indicator'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const Key('accent-indicator-dot'),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          const SizedBox(width: Space.sm),
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
