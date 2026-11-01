import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_system/widgets.dart';
import '../../app/theme/tokens.dart';
import '../shared/pokemon_picker.dart';
import 'profile_controller.dart';

/// Bottom sheet for editing the trainer nickname and avatar. Changes are
/// applied only when "Save" is pressed.
Future<void> showEditTrainerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _EditTrainerSheet(),
  );
}

class _EditTrainerSheet extends ConsumerStatefulWidget {
  const _EditTrainerSheet();

  @override
  ConsumerState<_EditTrainerSheet> createState() => _EditTrainerSheetState();
}

class _EditTrainerSheetState extends ConsumerState<_EditTrainerSheet> {
  late final TextEditingController _nickname;
  int? _avatarId;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    _nickname = TextEditingController(text: profile.nickname);
    _avatarId = profile.avatarId;
  }

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  void _save() {
    // Remove control characters and extra spaces; a name is required.
    final cleaned = _nickname.text
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), '')
        .trim();
    if (cleaned.isEmpty) {
      setState(() => _nameError = 'Enter a name (1–20 characters).');
      return;
    }
    final notifier = ref.read(profileProvider.notifier);
    notifier.setNickname(cleaned);
    notifier.setAvatar(_avatarId);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.md,
        0,
        Space.md,
        MediaQuery.of(context).viewInsets.bottom + Space.md,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit trainer', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Space.md),
            Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.surfaceContainerHigh,
                    border: Border.all(color: scheme.primary, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _avatarId == null
                      ? Icon(
                          Icons.person_outline,
                          size: 36,
                          color: scheme.onSurfaceVariant,
                        )
                      : Padding(
                          padding: const EdgeInsets.all(4),
                          child: PokemonArtwork(id: _avatarId!),
                        ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Wrap(
                    spacing: Space.sm,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showPokemonPicker(
                            context,
                            title: 'Choose avatar',
                          );
                          if (picked != null && mounted) {
                            setState(() => _avatarId = picked.id);
                          }
                        },
                        icon: const Icon(Icons.face_outlined),
                        label: const Text('Choose avatar'),
                      ),
                      if (_avatarId != null)
                        TextButton(
                          onPressed: () => setState(() => _avatarId = null),
                          child: const Text('Remove'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            TextField(
              controller: _nickname,
              maxLength: 20,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              onChanged: (_) {
                if (_nameError != null) {
                  setState(() => _nameError = null);
                }
              },
              decoration: InputDecoration(
                labelText: 'Trainer nickname',
                border: const OutlineInputBorder(),
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: Space.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: Space.sm),
                FilledButton(onPressed: _save, child: const Text('Save')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
