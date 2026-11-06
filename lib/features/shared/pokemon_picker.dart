import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_system/widgets.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/pokemon.dart';
import '../../data/providers.dart';
import '../../domain/pokedex_filter.dart';

/// Searchable bottom sheet for choosing a single Pokémon by name or number.
Future<PokemonSummary?> showPokemonPicker(
  BuildContext context, {
  String title = 'Select a Pokémon',
  Set<int> excluded = const {},
}) {
  return showModalBottomSheet<PokemonSummary>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _PickerSheet(title: title, excluded: excluded),
  );
}

class _PickerSheet extends ConsumerStatefulWidget {
  const _PickerSheet({required this.title, required this.excluded});

  final String title;
  final Set<int> excluded;

  @override
  ConsumerState<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends ConsumerState<_PickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final height = MediaQuery.of(context).size.height * 0.78;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Space.md),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search name or number',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: catalog.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorRetry(
                  error: e,
                  onRetry: () => ref.invalidate(catalogProvider),
                ),
                data: (all) {
                  final matches = [
                    for (final p in all)
                      if (!widget.excluded.contains(p.id) &&
                          matchesQuery(p, _query))
                        p,
                  ];
                  if (matches.isEmpty) {
                    return const EmptyState(
                      icon: Icons.search_off,
                      title: 'No matches',
                      message: 'Try another name or number.',
                    );
                  }
                  // Every match is offered, all the way to #1025. The list is
                  // built lazily, so only the rows on screen (plus a small
                  // cache) exist at any moment — no cap is needed to keep it
                  // smooth, and a cap here silently hid most of the Pokédex.
                  return ListView.builder(
                    itemCount: matches.length,
                    itemBuilder: (context, i) {
                      final p = matches[i];
                      return ListTile(
                        leading: PokemonArtwork(id: p.id, size: 44),
                        title: Text(p.displayName),
                        subtitle: Text(
                          dexNumber(p.id),
                          style: readoutStyle(context, size: 10),
                        ),
                        onTap: () => Navigator.of(context).pop(p),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
