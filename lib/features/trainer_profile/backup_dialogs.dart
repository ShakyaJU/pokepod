import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_system/widgets.dart';
import '../../app/theme/tokens.dart';
import '../../core/storage/backup.dart';
import '../../core/storage/local_store.dart';
import '../collections/collections_controller.dart';
import '../mystery/mystery_controller.dart';
import '../research/research_controller.dart';
import '../team_builder/teams_controller.dart';
import 'profile_controller.dart';

/// Copies a backup of the user's progress to the clipboard and explains what to
/// do with it. Nothing leaves the device unless the user pastes it somewhere.
Future<void> exportBackup(BuildContext context, WidgetRef ref) async {
  final prefs = ref.read(sharedPreferencesProvider);
  final text = BackupService.export(prefs);
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) {
    return;
  }
  BackupSummary? summary;
  try {
    summary = BackupService.parse(text).summary;
  } on BackupException {
    summary = null; // nothing to back up yet
  }
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Backup copied'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your progress was copied to the clipboard as text. Paste it into a note, a '
            'message to yourself or an email, and keep it somewhere safe.',
          ),
          const SizedBox(height: Space.sm),
          if (summary == null || summary.lines.isEmpty)
            const Text('There is no progress to back up yet.')
          else ...[
            const Text('It contains:'),
            for (final line in summary.lines) Text('• $line'),
          ],
          const SizedBox(height: Space.sm),
          const Text(
            'The backup is not uploaded anywhere. To restore it later, use "Restore from backup".',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

Future<void> showRestoreDialog(BuildContext context, WidgetRef ref) async {
  final restored = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => const _RestoreDialog(),
  );
  if (restored == true && context.mounted) {
    showSnack(context, 'Progress restored.');
  }
}

class _RestoreDialog extends ConsumerStatefulWidget {
  const _RestoreDialog();

  @override
  ConsumerState<_RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends ConsumerState<_RestoreDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;
  ParsedBackup? _checked;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) {
      return;
    }
    setState(() {
      _controller.text = data?.text ?? '';
      _error = null;
      _checked = null;
    });
  }

  void _check() {
    try {
      final parsed = BackupService.parse(_controller.text);
      setState(() {
        _checked = parsed;
        _error = null;
      });
    } on BackupException catch (e) {
      setState(() {
        _checked = null;
        _error = e.message;
      });
    }
  }

  Future<void> _restore() async {
    final backup = _checked;
    if (backup == null) {
      return;
    }
    await BackupService.apply(ref.read(sharedPreferencesProvider), backup);
    // Every notifier reads storage when it is built, so rebuild them all.
    ref.invalidate(researchProvider);
    ref.invalidate(favouritesProvider);
    ref.invalidate(recentProvider);
    ref.invalidate(notesProvider);
    ref.invalidate(collectionsProvider);
    ref.invalidate(teamsProvider);
    ref.invalidate(profileProvider);
    ref.invalidate(mysteryProvider);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final checked = _checked;
    return AlertDialog(
      title: const Text('Restore from backup'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Paste the backup text you copied earlier.'),
          const SizedBox(height: Space.sm),
          TextField(
            controller: _controller,
            minLines: 3,
            maxLines: 6,
            onChanged: (_) => setState(() {
              _checked = null;
              _error = null;
            }),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: 'Paste backup here',
              errorText: _error,
              errorMaxLines: 4,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _paste,
              icon: const Icon(Icons.content_paste, size: 18),
              label: const Text('Paste from clipboard'),
            ),
          ),
          if (checked != null) ...[
            const SizedBox(height: Space.sm),
            const Text('This backup contains:'),
            for (final line in checked.summary.lines) Text('• $line'),
            const SizedBox(height: Space.sm),
            Container(
              padding: const EdgeInsets.all(Space.sm),
              decoration: BoxDecoration(
                color: scheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Radii.sm),
                border: Border.all(color: scheme.error.withValues(alpha: 0.5)),
              ),
              child: const Text(
                'Restoring replaces the progress on this device for everything listed above. '
                'This cannot be undone. Anything not in the backup is kept.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        if (checked == null)
          FilledButton(
            onPressed: _controller.text.trim().isEmpty ? null : _check,
            child: const Text('Check backup'),
          )
        else
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: _restore,
            child: const Text('Replace my progress'),
          ),
      ],
    );
  }
}
