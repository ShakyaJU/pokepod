import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_system/stat_readout.dart';
import '../../app/design_system/widgets.dart';
import '../../app/shell.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/pokemon.dart';
import '../../data/providers.dart';
import '../../domain/pokedex_filter.dart';
import '../../domain/research_rules.dart';
import '../research/research_controller.dart';
import '../shared/navigation.dart';

enum _JournalFilter { all, withNotes, withoutNotes }

/// Field notebook: every Pokémon you have opened or written about.
///
/// PokéPod does not record a date for journal entries, so entries are ordered
/// by most recently opened first, then by Pokédex number.
class JournalPage extends ConsumerStatefulWidget {
  const JournalPage({super.key});

  @override
  ConsumerState<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends ConsumerState<JournalPage> {
  final TextEditingController _search = TextEditingController();
  _JournalFilter _filter = _JournalFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final research = ref.watch(researchProvider);
    final notes = ref.watch(notesProvider);
    final recent = ref.watch(recentProvider);
    final names = ref.watch(catalogByIdProvider);
    final scheme = Theme.of(context).colorScheme;

    final all = <int>{...research.keys, ...notes.keys};
    final ordered = <int>[
      ...recent.where(all.contains),
      ...(all.toList()..sort()).where((id) => !recent.contains(id)),
    ];

    PokemonSummary summaryOf(int id) =>
        names[id] ?? PokemonSummary(id: id, name: dexNumber(id));

    final query = _search.text.trim().toLowerCase();
    final entries = [
      for (final id in ordered)
        if (_matches(id, summaryOf(id), notes[id], query)) id,
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Research Journal'),
      ),
      body: all.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(Space.md),
              child: EmptyState(
                icon: Icons.menu_book_outlined,
                title: 'Your journal is empty',
                message:
                    'Open a Pokémon from the Pokédex to log it here. Then add your own '
                    'observations in its dossier or from this page.',
                action: FilledButton.icon(
                  onPressed: () {
                    ref.read(navIndexProvider.notifier).state = 1;
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.grid_view_rounded),
                  label: const Text('Open the Pokédex'),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                0,
                Space.md,
                Space.xl,
              ),
              children: [
                Text(
                  'Pokémon you have opened or written about, most recently opened first. '
                  'Dates are not recorded for entries.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: Space.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: StatReadout(
                        label: 'Entries',
                        value: '${all.length}',
                      ),
                    ),
                    Expanded(
                      child: StatReadout(
                        label: 'With notes',
                        value: '${notes.length}',
                      ),
                    ),
                    Expanded(
                      child: StatReadout(
                        label: 'Without notes',
                        value:
                            '${all.length - all.where(notes.containsKey).length}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search names, numbers or notes',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(_search.clear),
                          ),
                    filled: true,
                    fillColor: scheme.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.md),
                      borderSide: BorderSide(color: scheme.outlineVariant),
                    ),
                  ),
                ),
                const SizedBox(height: Space.sm),
                Wrap(
                  spacing: Space.sm,
                  children: [
                    for (final f in _JournalFilter.values)
                      ChoiceChip(
                        label: Text(switch (f) {
                          _JournalFilter.all => 'All',
                          _JournalFilter.withNotes => 'With notes',
                          _JournalFilter.withoutNotes => 'Without notes',
                        }),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                  ],
                ),
                const SizedBox(height: Space.md),
                if (entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: Space.xl),
                    child: EmptyState(
                      icon: Icons.search_off,
                      title: 'No entries match',
                      message: 'Try a different search or filter.',
                    ),
                  )
                else
                  for (final id in entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.sm),
                      child: _EntryTile(
                        summary: summaryOf(id),
                        note: notes[id],
                        state: research[id] ?? ResearchState.unseen,
                      ),
                    ),
              ],
            ),
    );
  }

  bool _matches(int id, PokemonSummary summary, String? note, String query) {
    final hasNote = note != null && note.trim().isNotEmpty;
    if (_filter == _JournalFilter.withNotes && !hasNote) {
      return false;
    }
    if (_filter == _JournalFilter.withoutNotes && hasNote) {
      return false;
    }
    if (query.isEmpty) {
      return true;
    }
    return matchesQuery(summary, query) ||
        (note?.toLowerCase().contains(query) ?? false);
  }
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({
    required this.summary,
    required this.note,
    required this.state,
  });

  final PokemonSummary summary;
  final String? note;
  final ResearchState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final hasNote = note != null && note!.trim().isNotEmpty;
    return Panel(
      padding: const EdgeInsets.fromLTRB(
        Space.sm,
        Space.sm,
        Space.xs,
        Space.sm,
      ),
      borderColor: hasNote ? scheme.primary.withValues(alpha: 0.4) : null,
      onTap: () => openDossier(context, summary.id),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PokemonArtwork(id: summary.id, size: 60),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      dexNumber(summary.id),
                      style: readoutStyle(context, size: 10),
                    ),
                    const SizedBox(width: 6),
                    ResearchBadge(state, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      state.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Text(
                  summary.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                if (hasNote)
                  Text(note!, maxLines: 4, overflow: TextOverflow.ellipsis)
                else
                  Text(
                    'No notes yet',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: hasNote
                ? 'Edit note for ${summary.displayName}'
                : 'Write note for ${summary.displayName}',
            icon: Icon(hasNote ? Icons.edit_note : Icons.add_comment_outlined),
            onPressed: () => showNoteEditor(context, summary),
          ),
        ],
      ),
    );
  }
}

/// Bottom-sheet note editor with explicit Save and Cancel actions.
Future<void> showNoteEditor(BuildContext context, PokemonSummary summary) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _NoteEditorSheet(summary: summary),
  );
}

class _NoteEditorSheet extends ConsumerStatefulWidget {
  const _NoteEditorSheet({required this.summary});

  final PokemonSummary summary;

  @override
  ConsumerState<_NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends ConsumerState<_NoteEditorSheet> {
  late final TextEditingController _controller;
  late final bool _hadNote;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(notesProvider)[widget.summary.id] ?? '';
    _hadNote = existing.trim().isNotEmpty;
    _controller = TextEditingController(text: existing);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    ref
        .read(notesProvider.notifier)
        .setNote(widget.summary.id, _controller.text);
    Navigator.of(context).pop();
    showSnack(context, 'Note saved.');
  }

  void _delete() {
    ref.read(notesProvider.notifier).setNote(widget.summary.id, '');
    Navigator.of(context).pop();
    showSnack(context, 'Note deleted.');
  }

  @override
  Widget build(BuildContext context) {
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
            Row(
              children: [
                PokemonArtwork(id: widget.summary.id, size: 48),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dexNumber(widget.summary.id),
                        style: readoutStyle(context, size: 10),
                      ),
                      Text(
                        widget.summary.displayName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 4,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Research notes',
                hintText: 'What did you observe? (saved on this device)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: Space.sm),
            Row(
              children: [
                if (_hadNote)
                  TextButton(
                    onPressed: _delete,
                    child: Text(
                      'Delete',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const Spacer(),
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
