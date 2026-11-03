import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_system/expandable_section.dart';
import '../../app/design_system/progress_ring.dart';
import '../../app/design_system/widgets.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/pokemon.dart';
import '../../data/providers.dart';
import '../../domain/generations.dart';
import '../../domain/research_rules.dart';
import '../../domain/type_chart.dart';
import '../pokedex/pokemon_tiles.dart';
import '../research/research_controller.dart';
import '../shared/navigation.dart';
import '../shared/pokemon_picker.dart';
import '../trainer_profile/profile_controller.dart';
import 'collections_controller.dart';

PokemonSummary _summaryFor(Map<int, PokemonSummary> names, int id) =>
    names[id] ?? PokemonSummary(id: id, name: dexNumber(id));

Future<String?> _askText(
  BuildContext context,
  String title, {
  String initial = '',
}) {
  // The field owns its text (TextFormField disposes the controller it makes),
  // so this helper never holds one it would have to dispose itself.
  var text = initial;
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextFormField(
        initialValue: initial,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Name'),
        onChanged: (v) => text = v,
        onFieldSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

class CollectionsPage extends ConsumerStatefulWidget {
  const CollectionsPage({super.key});

  @override
  ConsumerState<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends ConsumerState<CollectionsPage> {
  @override
  Widget build(BuildContext context) {
    final collections = ref.watch(collectionsProvider);
    final profile = ref.watch(profileProvider);
    final favourites = ref.watch(favouritesProvider);
    final recent = ref.watch(recentProvider);
    final summary = ref.watch(researchSummaryProvider);
    final names = ref.watch(catalogByIdProvider);
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: Space.xl),
        children: [
          const PageHeader(
            title: 'Collections',
            subtitle: "Collector's Atelier",
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(
                  'Showcase',
                  trailing: TextButton.icon(
                    onPressed: () async {
                      final picked = await showPokemonPicker(
                        context,
                        title: 'Add to showcase',
                        excluded: profile.showcase.toSet(),
                      );
                      if (picked == null || !context.mounted) {
                        return;
                      }
                      final ok = ref
                          .read(profileProvider.notifier)
                          .toggleShowcase(picked.id);
                      if (!ok) {
                        showSnack(
                          context,
                          'Showcase is full ($kShowcaseSize).',
                        );
                      }
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add'),
                  ),
                ),
                if (profile.showcase.isEmpty)
                  const Panel(
                    child: Text(
                      'Feature up to six Pokémon here. Drag to rearrange. '
                      'You can also pin from any dossier.',
                    ),
                  )
                else
                  SizedBox(
                    height: 120,
                    child: ReorderableListView.builder(
                      scrollDirection: Axis.horizontal,
                      buildDefaultDragHandles: true,
                      itemCount: profile.showcase.length,
                      // onReorderItem already adjusts the target index for the removed item,
                      // while reorderShowcase expects the raw ReorderableListView index.
                      onReorderItem: (oldIndex, newIndex) => ref
                          .read(profileProvider.notifier)
                          .reorderShowcase(
                            oldIndex,
                            newIndex > oldIndex ? newIndex + 1 : newIndex,
                          ),
                      itemBuilder: (context, i) {
                        final id = profile.showcase[i];
                        return Padding(
                          key: ValueKey('showcase-$id'),
                          padding: const EdgeInsets.only(right: Space.sm),
                          child: SizedBox(
                            width: 96,
                            child: Panel(
                              padding: const EdgeInsets.all(Space.xs),
                              onTap: () => openDossier(context, id),
                              child: Column(
                                children: [
                                  Expanded(child: PokemonArtwork(id: id)),
                                  Text(
                                    _summaryFor(names, id).displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: Space.lg),
                SectionLabel(
                  'Pinned favourites',
                  trailing: Text(
                    '${favourites.length}',
                    style: readoutStyle(context),
                  ),
                ),
                if (favourites.isEmpty)
                  const Panel(
                    child: Text('Tap the heart on any Pokémon to pin it here.'),
                  )
                else
                  SizedBox(
                    height: 76,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final id in (favourites.toList()..sort()).take(30))
                          GestureDetector(
                            onTap: () => openDossier(context, id),
                            child: Padding(
                              padding: const EdgeInsets.only(right: Space.sm),
                              child: PokemonArtwork(id: id, size: 72),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: Space.lg),
                SectionLabel(
                  'My collections',
                  trailing: TextButton.icon(
                    onPressed: () async {
                      final name = await _askText(context, 'New collection');
                      if (name == null) {
                        return;
                      }
                      ref.read(collectionsProvider.notifier).create(name);
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New'),
                  ),
                ),
                if (collections.isEmpty)
                  const Panel(
                    child: Text(
                      'Create a collection such as "Water team ideas" or "Pocket favourites", '
                      'then add Pokémon from any dossier.',
                    ),
                  )
                else
                  for (final c in collections)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.sm),
                      child: Panel(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                CollectionDetailPage(collectionId: c.id),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  Text(
                                    '${c.ids.where(summary.discoveredIds.contains).length} of ${c.ids.length} discovered',
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'rename') {
                                  final name = await _askText(
                                    context,
                                    'Rename collection',
                                    initial: c.name,
                                  );
                                  if (name != null) {
                                    ref
                                        .read(collectionsProvider.notifier)
                                        .rename(c.id, name);
                                  }
                                } else {
                                  ref
                                      .read(collectionsProvider.notifier)
                                      .delete(c.id);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'rename',
                                  child: Text('Rename'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                const SizedBox(height: Space.lg),
                const SectionLabel('Generation Dex Progress'),
                const _GenerationProgress(),
                const SizedBox(height: Space.lg),
                ExpandableSection(
                  title: 'Research by type',
                  subtitle:
                      'Discovered Pokémon per type. Tap to open or close.',
                  leading: const Icon(Icons.donut_small_outlined),
                  child: _TypeProgress(discovered: summary.discoveredIds),
                ),
                const SizedBox(height: Space.lg),
                const SectionLabel('Recent research'),
                if (recent.isEmpty)
                  const Panel(child: Text('Dossiers you open appear here.'))
                else
                  SizedBox(
                    height: 96,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final id in recent)
                          GestureDetector(
                            onTap: () => openDossier(context, id),
                            child: Padding(
                              padding: const EdgeInsets.only(right: Space.sm),
                              child: Column(
                                children: [
                                  PokemonArtwork(id: id, size: 72),
                                  Text(
                                    _summaryFor(names, id).displayName,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _padDex(int id) => id.toString().padLeft(4, '0');

/// Pick a generation and see how much of it you have discovered, studied and
/// mastered. Choosing a generation only changes what is shown; it never edits
/// your progress.
class _GenerationProgress extends ConsumerStatefulWidget {
  const _GenerationProgress();

  @override
  ConsumerState<_GenerationProgress> createState() =>
      _GenerationProgressState();
}

class _GenerationProgressState extends ConsumerState<_GenerationProgress> {
  int? _selected;

  /// The first generation that is not fully discovered yet (or Generation I).
  int _defaultGeneration(Set<int> discovered) {
    for (var g = 1; g <= kGenerationRanges.length; g++) {
      final (lo, hi) = kGenerationRanges[g - 1];
      var count = 0;
      for (final id in discovered) {
        if (id >= lo && id <= hi) {
          count++;
        }
      }
      if (count < hi - lo + 1) {
        return g;
      }
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final research = ref.watch(researchProvider);
    final names = ref.watch(catalogByIdProvider);
    final scheme = Theme.of(context).colorScheme;

    final generation = _selected ?? _defaultGeneration(research.keys.toSet());
    final (lo, hi) = kGenerationRanges[generation - 1];
    final total = hi - lo + 1;
    var discovered = 0;
    var studied = 0;
    var mastered = 0;
    research.forEach((id, state) {
      if (id < lo || id > hi) {
        return;
      }
      discovered++;
      if (state.index >= ResearchState.studied.index) {
        studied++;
      }
      if (state == ResearchState.mastered) {
        mastered++;
      }
    });
    final fraction = total == 0 ? 0.0 : discovered / total;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('GENERATION', style: readoutStyle(context, size: 10)),
          const SizedBox(height: 6),
          Semantics(
            container: true,
            label:
                'Generation selector. ${generationLabel(generation)} selected.',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: generation,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(Radii.md),
                  dropdownColor: scheme.surfaceContainerHigh,
                  items: [
                    for (var g = 1; g <= kGenerationRanges.length; g++)
                      DropdownMenuItem<int>(
                        value: g,
                        child: Text(
                          '${generationLabel(g)} · #${_padDex(kGenerationRanges[g - 1].$1)}–#${_padDex(kGenerationRanges[g - 1].$2)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selected = value);
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              ProgressRing(
                fraction: fraction,
                size: 72,
                strokeWidth: 7,
                label: '${(fraction * 100).floor()}%',
                semanticsLabel:
                    '${(fraction * 100).floor()} percent of ${generationLabel(generation)} discovered',
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$discovered of $total discovered',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$studied studied · $mastered mastered',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          SizedBox(
            height: 100,
            child: ListView.builder(
              key: ValueKey('generation-strip-$generation'),
              scrollDirection: Axis.horizontal,
              itemCount: total,
              itemBuilder: (context, i) {
                final id = lo + i;
                return Padding(
                  padding: const EdgeInsets.only(right: Space.sm),
                  child: _GenerationTile(id: id, name: names[id]?.displayName),
                );
              },
            ),
          ),
          const SizedBox(height: Space.sm),
          Text(
            'Progress is the Pokémon you have discovered in this generation out of all of them. '
            'Undiscovered Pokémon show as silhouettes.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Space.sm),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    GenerationCollectionPage(generation: generation),
              ),
            ),
            icon: const Icon(Icons.grid_view_rounded, size: 18),
            label: Text('Open all $total as a grid'),
          ),
        ],
      ),
    );
  }
}

class _GenerationTile extends ConsumerWidget {
  const _GenerationTile({required this.id, required this.name});

  final int id;
  final String? name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      researchProvider.select((m) => m[id] ?? ResearchState.unseen),
    );
    return GestureDetector(
      onTap: () => openDossier(context, id),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            PokemonArtwork(
              id: id,
              size: 60,
              silhouette: state == ResearchState.unseen,
            ),
            const SizedBox(height: 2),
            Text(
              name ?? dexNumber(id),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10),
            ),
            ResearchBadge(state, size: 12),
          ],
        ),
      ),
    );
  }
}

class _TypeProgress extends ConsumerWidget {
  const _TypeProgress({required this.discovered});

  final Set<int> discovered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final t in kTypes)
          ref
              .watch(typeMembersProvider(t))
              .when(
                loading: () => const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: SkeletonBox(height: 22),
                ),
                error: (e, _) => Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => ref.invalidate(typeMembersProvider(t)),
                    child: Text('${titleCase(t)}: retry'),
                  ),
                ),
                data: (members) {
                  final count = members.where(discovered.contains).length;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        SizedBox(width: 92, child: TypeChip(t, dense: true)),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: members.isEmpty
                                  ? 0
                                  : count / members.length,
                              minHeight: 6,
                              color: typeColor(t),
                              backgroundColor: scheme.surfaceContainerHigh,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 64,
                          child: Text(
                            '$count/${members.length}',
                            textAlign: TextAlign.right,
                            style: readoutStyle(context, size: 10),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ],
    );
  }
}

class CollectionDetailPage extends ConsumerWidget {
  const CollectionDetailPage({super.key, required this.collectionId});

  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = ref.watch(
      collectionsProvider.select(
        (l) => l.where((c) => c.id == collectionId).firstOrNull,
      ),
    );
    final names = ref.watch(catalogByIdProvider);
    final discovered = ref.watch(researchSummaryProvider).discoveredIds;
    if (collection == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Collection')),
        body: const EmptyState(
          icon: Icons.collections_bookmark_outlined,
          title: 'Collection not found',
          message: 'It may have been deleted.',
        ),
      );
    }
    final done = collection.ids.where(discovered.contains).length;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(collection.name),
        actions: [
          IconButton(
            tooltip: 'Add Pokémon',
            icon: const Icon(Icons.add),
            onPressed: () async {
              final picked = await showPokemonPicker(
                context,
                title: 'Add to ${collection.name}',
                excluded: collection.ids.toSet(),
              );
              if (picked != null) {
                ref
                    .read(collectionsProvider.notifier)
                    .add(collection.id, picked.id);
              }
            },
          ),
        ],
      ),
      body: collection.ids.isEmpty
          ? const EmptyState(
              icon: Icons.add_circle_outline,
              title: 'Empty collection',
              message: 'Use + to add Pokémon, or add them from a dossier.',
            )
          : ListView(
              padding: const EdgeInsets.all(Space.md),
              children: [
                Text(
                  '$done of ${collection.ids.length} discovered',
                  style: readoutStyle(context),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: done / collection.ids.length,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: Space.md),
                for (final id in collection.ids)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: PokemonRowTile(
                      pokemon: _summaryFor(names, id),
                      trailing: IconButton(
                        tooltip: 'Remove from collection',
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => ref
                            .read(collectionsProvider.notifier)
                            .remove(collection.id, id),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class GenerationCollectionPage extends ConsumerWidget {
  const GenerationCollectionPage({super.key, required this.generation});

  final int generation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('${generationLabel(generation)} · Dex Progress'),
      ),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(
          error: e,
          onRetry: () => ref.invalidate(catalogProvider),
        ),
        data: (all) {
          final members = [
            for (final p in all)
              if (inGeneration(p.id, generation)) p,
          ];
          return GridView.builder(
            padding: const EdgeInsets.all(Space.md),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 150,
              mainAxisSpacing: Space.sm,
              crossAxisSpacing: Space.sm,
              childAspectRatio: 0.82,
            ),
            itemCount: members.length,
            itemBuilder: (context, i) => PokemonGridTile(
              key: ValueKey(members[i].id),
              pokemon: members[i],
              livingDex: true,
            ),
          );
        },
      ),
    );
  }
}
