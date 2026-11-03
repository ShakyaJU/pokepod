import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_system/widgets.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/providers.dart';
import '../../domain/generations.dart';
import '../../domain/pokedex_filter.dart';
import '../../domain/type_chart.dart';
import 'measurements.dart';
import 'pokedex_controller.dart';
import 'pokemon_tiles.dart';

class PokedexPage extends ConsumerStatefulWidget {
  const PokedexPage({super.key});

  @override
  ConsumerState<PokedexPage> createState() => _PokedexPageState();
}

class _PokedexPageState extends ConsumerState<PokedexPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(pokedexProvider);
    final results = ref.watch(filteredPokedexProvider);
    final notifier = ref.read(pokedexProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    // Ask for the next page as the results approach their end.
    final items = results.valueOrNull;
    final itemCount = items?.length ?? 0;
    final shown = ui.visibleCount < itemCount ? ui.visibleCount : itemCount;
    final hasMore = items != null && shown < itemCount;

    // One scroll view for the whole screen: the header controls scroll with
    // the results instead of competing with them for a fixed height, which is
    // what used to overflow once the keyboard shrank the page.
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (hasMore && n.metrics.extentAfter < 700) {
          notifier.loadMore(itemCount, renderedCount: ui.visibleCount);
        }
        return false;
      },
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          key: const PageStorageKey('pokedex-scroll'),
          // Dragging the results dismisses the keyboard and returns its
          // height to the page — Flutter's own behaviour, not manual
          // keyboard handling.
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: PageHeader(
                title: 'Pokédex',
                subtitle: 'Catalogue',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: ui.livingDex
                          ? 'Show all artwork'
                          : 'Living Dex: silhouette unseen',
                      onPressed: notifier.toggleLivingDex,
                      icon: Icon(
                        ui.livingDex ? Icons.contrast : Icons.contrast_outlined,
                        color: ui.livingDex ? scheme.primary : null,
                      ),
                    ),
                    IconButton(
                      tooltip: ui.view == PokedexView.grid
                          ? 'Compact list'
                          : 'Grid',
                      onPressed: () => notifier.setView(
                        ui.view == PokedexView.grid
                            ? PokedexView.list
                            : PokedexView.grid,
                      ),
                      icon: Icon(
                        ui.view == PokedexView.grid
                            ? Icons.view_list_rounded
                            : Icons.grid_view_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: LiveStatusBanner()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.md),
                child: TextField(
                  controller: _search,
                  onChanged: notifier.setQuery,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search name or number',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: ui.filter.query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _search.clear();
                              notifier.setQuery('');
                            },
                          ),
                    filled: true,
                    fillColor: scheme.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.md),
                      borderSide: BorderSide(color: scheme.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.md),
                      borderSide: BorderSide(color: scheme.outlineVariant),
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: Space.sm)),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Space.md),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: Space.sm),
                      child: Center(
                        child: Text(
                          'FILTER',
                          style: readoutStyle(context, size: 10),
                        ),
                      ),
                    ),
                    _FilterButton(
                      label: ui.filter.type == null
                          ? 'Type'
                          : titleCase(ui.filter.type!),
                      active: ui.filter.type != null,
                      onTap: () => _pickType(context),
                    ),
                    _FilterButton(
                      label: ui.filter.generation == null
                          ? 'Generation'
                          : 'Gen ${kRomanNumerals[ui.filter.generation! - 1]}',
                      active: ui.filter.generation != null,
                      onTap: () => _pickGeneration(context),
                    ),
                    _FilterButton(
                      label: 'Favourites',
                      active: ui.filter.favouritesOnly,
                      icon: Icons.favorite_border,
                      onTap: notifier.toggleFavourites,
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.md,
                  Space.sm,
                  Space.md,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _SortButton(
                        filter: ui.filter,
                        onTap: () => _openSortSheet(context),
                      ),
                    ),
                    if (!ui.filter.isDefaultSort)
                      IconButton(
                        tooltip: 'Reset sort to Pokédex number',
                        icon: const Icon(Icons.restart_alt),
                        onPressed: notifier.resetSort,
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        results.valueOrNull == null
                            ? ''
                            : '${results.valueOrNull!.length} matching',
                        style: readoutStyle(context),
                      ),
                    ),
                    if (ui.filter.isActive)
                      TextButton(
                        onPressed: () {
                          _search.clear();
                          notifier.clearFilters();
                        },
                        child: const Text('Clear filters'),
                      ),
                  ],
                ),
              ),
            ),
            if (ui.filter.sortKey.needsFacts && items != null)
              SliverToBoxAdapter(
                child: _FactsBanner(
                  ids: [for (final p in items) p.id],
                  sortKey: ui.filter.sortKey,
                ),
              ),
            _Results(results: results, ui: ui),
          ],
        ),
      ),
    );
  }

  Future<void> _pickType(BuildContext context) async {
    final current = ref.read(pokedexProvider).filter.type;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              ChoiceChip(
                label: const Text('Any type'),
                selected: current == null,
                onSelected: (_) => Navigator.of(context).pop(''),
              ),
              for (final t in kTypes)
                ChoiceChip(
                  label: Text(titleCase(t)),
                  selected: current == t,
                  avatar: CircleAvatar(
                    backgroundColor: typeColor(t),
                    radius: 5,
                  ),
                  onSelected: (_) => Navigator.of(context).pop(t),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) {
      return;
    }
    ref.read(pokedexProvider.notifier).setType(picked.isEmpty ? null : picked);
  }

  Future<void> _pickGeneration(BuildContext context) async {
    final current = ref.read(pokedexProvider).filter.generation;
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              ChoiceChip(
                label: const Text('All generations'),
                selected: current == null,
                onSelected: (_) => Navigator.of(context).pop(0),
              ),
              for (var g = 1; g <= kGenerationRanges.length; g++)
                ChoiceChip(
                  label: Text(generationLabel(g)),
                  selected: current == g,
                  onSelected: (_) => Navigator.of(context).pop(g),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) {
      return;
    }
    ref
        .read(pokedexProvider.notifier)
        .setGeneration(picked == 0 ? null : picked);
  }

  Future<void> _openSortSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const _SortSheet(),
    );
  }
}

IconData _sortIcon(SortKey key) => switch (key) {
  SortKey.number => Icons.tag,
  SortKey.name => Icons.sort_by_alpha,
  SortKey.generation => Icons.history_toggle_off,
  SortKey.type => Icons.category_outlined,
  SortKey.special => Icons.workspace_premium_outlined,
  SortKey.favourite => Icons.favorite_border,
  SortKey.height => Icons.height,
  SortKey.weight => Icons.scale_outlined,
  SortKey.total => Icons.bar_chart,
  SortKey.hp => Icons.favorite_outline,
  SortKey.attack => Icons.flash_on_outlined,
  SortKey.defense => Icons.shield_outlined,
  SortKey.specialAttack => Icons.auto_awesome_outlined,
  SortKey.specialDefense => Icons.security_outlined,
  SortKey.speed => Icons.speed,
};

/// The dedicated sort control. It is deliberately styled differently from the
/// outlined filter buttons and always shows the property and direction.
class _SortButton extends StatelessWidget {
  const _SortButton({required this.filter, required this.onTap});

  final PokedexFilter filter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final changed = !filter.isDefaultSort;
    return Semantics(
      button: true,
      label: 'Sort by ${filter.sortSummary}. Opens sort options.',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: scheme.primary.withValues(alpha: changed ? 0.16 : 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(
            color: scheme.primary.withValues(alpha: changed ? 0.7 : 0.35),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.md,
                vertical: Space.sm,
              ),
              child: Row(
                children: [
                  Icon(Icons.swap_vert, color: scheme.primary),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'SORT BY',
                          style: readoutStyle(
                            context,
                            size: 9,
                            color: scheme.primary,
                          ),
                        ),
                        Text(
                          filter.sortSummary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    filter.ascending
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.expand_more, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet listing the sortable properties in groups, with a separate
/// ascending/descending control. Changes apply immediately.
class _SortSheet extends ConsumerWidget {
  const _SortSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(pokedexProvider.select((s) => s.filter));
    final notifier = ref.read(pokedexProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    Widget row(SortKey key) {
      final selected = key == filter.sortKey;
      return ListTile(
        key: ValueKey('sort-${key.name}'),
        selected: selected,
        selectedColor: scheme.primary,
        selectedTileColor: scheme.primary.withValues(alpha: 0.1),
        leading: Icon(_sortIcon(key)),
        title: Text(key.label),
        subtitle: key.needsFacts
            ? Text(
                key.needsSpecies
                    ? 'Uses saved species data'
                    : 'Uses saved Pokémon details',
                style: const TextStyle(fontSize: 11),
              )
            : null,
        trailing: selected ? const Icon(Icons.check) : null,
        onTap: () {
          if (key.needsFacts) {
            ref.read(measurementsProvider.notifier).refreshFromSaved();
          }
          notifier.setSortKey(key);
        },
      );
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: Space.md),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                0,
                Space.sm,
                Space.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sort by',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: filter.isDefaultSort ? null : notifier.resetSort,
                    child: const Text('Reset'),
                  ),
                  FilledButton.tonal(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                0,
                Space.md,
                Space.xs,
              ),
              child: Text(
                'ORDER · ${filter.sortKey.label.toUpperCase()}',
                style: readoutStyle(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: true,
                    icon: const Icon(Icons.arrow_upward, size: 16),
                    label: Text(
                      filter.sortKey.ascendingLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: const Icon(Icons.arrow_downward, size: 16),
                    label: Text(
                      filter.sortKey.descendingLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                selected: {filter.ascending},
                onSelectionChanged: (s) => notifier.setAscending(s.first),
              ),
            ),
            for (final group in SortGroup.values) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.md,
                  Space.md,
                  Space.md,
                  Space.xs,
                ),
                child: Text(
                  group.label.toUpperCase(),
                  style: readoutStyle(context),
                ),
              ),
              for (final key in SortKey.values)
                if (key.group == group) row(key),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                Space.md,
                Space.md,
                0,
              ),
              child: Text(
                'Searching and filtering stay as they are; sorting only changes the order. '
                'Where a property comes from details that are not saved on this device yet, '
                'those Pokémon are listed last until you load them.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Explains how complete a details-based sort is and lets the user load the
/// missing values for the current results.
class _FactsBanner extends ConsumerWidget {
  const _FactsBanner({required this.ids, required this.sortKey});

  final List<int> ids;
  final SortKey sortKey;

  static const int maxLoadable = 150;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(measurementsProvider);
    final scheme = Theme.of(context).colorScheme;
    final total = ids.length;
    final have = ids
        .where((id) => state.data[id]?.hasValueFor(sortKey) ?? false)
        .length;
    final missing = total - have;
    final name = sortKey.label;

    Widget body;
    if (state.loading) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Loading… ${state.loadingDone} of ${state.loadingTotal}'),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: state.loadingDone / state.loadingTotal,
            minHeight: 4,
          ),
        ],
      );
    } else if (total == 0 || missing == 0) {
      body = Text('Sorted by $name using all $total results.');
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sorted by $name. $have of $total results have this saved on this '
            'device; the other $missing are listed last.',
          ),
          if (state.failed > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${state.failed} could not be loaded last time.',
                style: TextStyle(color: scheme.error, fontSize: 12),
              ),
            ),
          const SizedBox(height: Space.sm),
          if (total <= maxLoadable)
            OutlinedButton.icon(
              onPressed: () => ref
                  .read(measurementsProvider.notifier)
                  .loadMissing(ids, sortKey),
              icon: const Icon(Icons.cloud_download_outlined, size: 18),
              label: Text('Load $missing missing'),
            )
          else
            Text(
              'Narrow the results to $maxLoadable or fewer (for example with a type or '
              'generation filter) to load the missing values.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 13),
          child: body,
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: Space.sm),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon ?? Icons.tune, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: active ? scheme.primary : scheme.onSurface,
          backgroundColor: active
              ? scheme.primary.withValues(alpha: 0.12)
              : null,
          side: BorderSide(
            color: active ? scheme.primary : scheme.outlineVariant,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.results, required this.ui});

  final PokedexResults results;
  final PokedexUiState ui;

  /// The results as a single sliver, so they scroll together with the header
  /// controls: no fixed-height column is left to overflow the page.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return results.when(
      loading: () => const _SkeletonGrid(),
      error: (error, _) => SliverFillRemaining(
        hasScrollBody: false,
        child: ErrorRetry(
          error: error,
          onRetry: () {
            ref.invalidate(catalogProvider);
            final type = ui.filter.type;
            if (type != null) {
              ref.invalidate(typeMembersProvider(type));
            }
          },
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          // Fills whatever height is left, and scrolls with the page when
          // the keyboard has left none.
          return SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.search_off,
              title: 'No Pokémon match',
              message: ui.filter.favouritesOnly && ui.filter.query.isEmpty
                  ? 'Favourite a Pokémon with the heart to see it here.'
                  : 'Try a different name, number or filter.',
              action: ui.filter.isActive
                  ? OutlinedButton(
                      onPressed: () =>
                          ref.read(pokedexProvider.notifier).clearFilters(),
                      child: const Text('Clear filters'),
                    )
                  : null,
            ),
          );
        }
        final shown = ui.visibleCount < items.length
            ? ui.visibleCount
            : items.length;
        final visible = items.sublist(0, shown);

        return SliverPadding(
          padding: const EdgeInsets.all(Space.md),
          sliver: ui.view == PokedexView.grid
              ? SliverGrid(
                  gridDelegate: _gridDelegate,
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => PokemonGridTile(
                      key: ValueKey(visible[i].id),
                      pokemon: visible[i],
                      livingDex: ui.livingDex,
                    ),
                    childCount: visible.length,
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate((_, i) {
                    if (i.isEven) {
                      final pokemon = visible[i ~/ 2];
                      return PokemonRowTile(
                        key: ValueKey(pokemon.id),
                        pokemon: pokemon,
                        livingDex: ui.livingDex,
                      );
                    }
                    // The same gap `ListView.separated` used to insert.
                    return const SizedBox(height: Space.sm);
                  }, childCount: visible.length * 2 - 1),
                ),
        );
      },
    );
  }
}

/// The one grid geometry shared by the results and the loading skeleton.
const _gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 180,
  mainAxisSpacing: Space.sm,
  crossAxisSpacing: Space.sm,
  childAspectRatio: 0.82,
);

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.all(Space.md),
      sliver: SliverGrid(
        gridDelegate: _gridDelegate,
        delegate: SliverChildBuilderDelegate(
          (_, _) => const SkeletonBox(height: 100, radius: Radii.md),
          childCount: 12,
        ),
      ),
    );
  }
}
