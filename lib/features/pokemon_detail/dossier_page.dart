import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_system/meta_badge.dart';
import '../../app/design_system/widgets.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/pokemon.dart';
import '../../data/providers.dart';
import '../../domain/generations.dart';
import '../../domain/research_rules.dart';
import '../analysis/compare_page.dart';
import '../collections/collections_controller.dart';
import '../evolution/constellation_page.dart';
import '../pokedex/pokemon_tiles.dart';
import '../research/research_controller.dart';
import '../shared/navigation.dart';
import '../trainer_profile/profile_controller.dart';

class DossierPage extends ConsumerStatefulWidget {
  const DossierPage({super.key, required this.id});

  final int id;

  @override
  ConsumerState<DossierPage> createState() => _DossierPageState();
}

class _DossierPageState extends ConsumerState<DossierPage> {
  bool _shiny = false;

  @override
  void initState() {
    super.initState();
    // Opening a dossier logs the discovery and the recent history. It never
    // advances research beyond "discovered".
    Future<void>.microtask(() {
      if (!mounted) {
        return;
      }
      ref.read(researchProvider.notifier).discover(widget.id);
      ref.read(recentProvider.notifier).touch(widget.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(pokemonDetailProvider(widget.id));
    final summary = ref.watch(catalogByIdProvider)[widget.id];
    final title =
        detail.valueOrNull?.displayName ??
        summary?.displayName ??
        dexNumber(widget.id);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(title),
        actions: [FavouriteButton(widget.id, size: 24)],
      ),
      body: detail.when(
        loading: () => const _DossierSkeleton(),
        error: (e, _) => ErrorRetry(
          error: e,
          onRetry: () => ref.invalidate(pokemonDetailProvider(widget.id)),
        ),
        data: (d) => _DossierBody(
          detail: d,
          shiny: _shiny,
          onToggleShiny: () => setState(() => _shiny = !_shiny),
        ),
      ),
    );
  }
}

class _DossierSkeleton extends StatelessWidget {
  const _DossierSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(Space.md),
      child: Column(
        children: [
          SkeletonBox(height: 240, radius: Radii.lg),
          SizedBox(height: Space.md),
          SkeletonBox(height: 20),
          SizedBox(height: Space.sm),
          SkeletonBox(height: 120),
        ],
      ),
    );
  }
}

class _DossierBody extends ConsumerWidget {
  const _DossierBody({
    required this.detail,
    required this.shiny,
    required this.onToggleShiny,
  });

  final PokemonDetail detail;
  final bool shiny;
  final VoidCallback onToggleShiny;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final species = ref.watch(speciesProvider(detail.id));
    final tint = detail.types.isEmpty
        ? scheme.primary
        : typeColor(detail.types.first);
    final gen = generationOf(detail.id);

    return ListView(
      padding: const EdgeInsets.only(bottom: Space.xl),
      children: [
        // Hero: artwork lit by the primary type colour.
        Container(
          height: 280,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [tint.withValues(alpha: 0.28), Colors.transparent],
              radius: 0.8,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Hero(
                  tag: 'artwork-${detail.id}-$shiny',
                  child: PokemonArtwork(id: detail.id, size: 240, shiny: shiny),
                ),
              ),
              Positioned(
                left: Space.md,
                top: 0,
                child: Text(
                  dexNumber(detail.id),
                  style: readoutStyle(context, size: 13),
                ),
              ),
              Positioned(
                right: Space.md,
                top: 0,
                child: FilterChip(
                  label: const Text('Shiny'),
                  selected: shiny,
                  onSelected: (_) => onToggleShiny(),
                  avatar: const Icon(Icons.auto_awesome, size: 16),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(detail.displayName, style: theme.textTheme.headlineLarge),
              species.maybeWhen(
                data: (s) => s.genus == null
                    ? const SizedBox.shrink()
                    : Text(
                        s.genus!,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: Space.sm),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final t in detail.types) TypeChip(t),
                  if (gen != null)
                    MetaBadge(label: generationLabel(gen), icon: Icons.public),
                  ...species.maybeWhen<List<Widget>>(
                    data: (s) => [
                      if (s.isLegendary)
                        MetaBadge(
                          label: 'Legendary',
                          icon: Icons.workspace_premium,
                          color: scheme.tertiary,
                        ),
                      if (s.isMythical)
                        const MetaBadge(
                          label: 'Mythical',
                          icon: Icons.auto_awesome,
                          color: AppColors.violet,
                        ),
                    ],
                    orElse: () => const <Widget>[],
                  ),
                ],
              ),
              const SizedBox(height: Space.lg),
              const SectionLabel('Field description'),
              species.when(
                loading: () => const SkeletonBox(height: 60),
                error: (e, _) => Text(
                  'Species notes are unavailable right now.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                data: (s) => Text(
                  s.flavorText ??
                      'PokéAPI has no English description for this species.',
                ),
              ),
              const SizedBox(height: Space.lg),
              const SectionLabel('Measurements'),
              Row(
                children: [
                  Expanded(
                    child: _Readout(
                      label: 'Height',
                      value: '${detail.heightM.toStringAsFixed(1)} m',
                    ),
                  ),
                  Expanded(
                    child: _Readout(
                      label: 'Weight',
                      value: '${detail.weightKg.toStringAsFixed(1)} kg',
                    ),
                  ),
                  Expanded(
                    child: _Readout(
                      label: 'Base EXP',
                      value: detail.baseExperience?.toString() ?? 'n/a',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.lg),
              SectionLabel(
                'Base stats',
                trailing: Text(
                  'TOTAL ${detail.statTotal}',
                  style: readoutStyle(context, color: scheme.primary),
                ),
              ),
              if (detail.stats.isEmpty)
                Text(
                  'No base stats reported.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                )
              else
                for (final s in detail.stats)
                  StatBar(
                    label: statLabel(s.name),
                    value: s.value,
                    color: tint,
                  ),
              const SizedBox(height: Space.lg),
              const SectionLabel('Abilities'),
              if (detail.abilities.isEmpty)
                Text(
                  'No abilities reported.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                )
              else
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    for (final a in detail.abilities)
                      Chip(
                        label: Text(
                          a.hidden
                              ? '${a.displayName} (hidden)'
                              : a.displayName,
                        ),
                        avatar: a.hidden
                            ? const Icon(
                                Icons.visibility_off_outlined,
                                size: 14,
                              )
                            : null,
                      ),
                  ],
                ),
              const SizedBox(height: Space.lg),
              SectionLabel(
                'Moves',
                trailing: Text(
                  '${detail.moveCount} LEARNABLE',
                  style: readoutStyle(context),
                ),
              ),
              if (detail.moves.isEmpty)
                Text(
                  'No moves reported.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                )
              else ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final m in detail.moves)
                      Chip(
                        label: Text(titleCase(m)),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: Space.xs),
                  child: Text(
                    'A sample of the first ${detail.moves.length} moves alphabetically; not a full move list.',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: Space.lg),
              const SectionLabel('Evolution'),
              _EvolutionPreview(id: detail.id),
              const SizedBox(height: Space.lg),
              const SectionLabel('Research log'),
              _ResearchControls(id: detail.id),
              const SizedBox(height: Space.md),
              _NoteEditor(id: detail.id),
              const SizedBox(height: Space.lg),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _addToCollection(context, ref),
                    icon: const Icon(Icons.collections_bookmark_outlined),
                    label: const Text('Add to collection'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ComparePage(initialA: detail.id),
                      ),
                    ),
                    icon: const Icon(Icons.compare_arrows),
                    label: const Text('Compare'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      final added = ref
                          .read(profileProvider.notifier)
                          .toggleShowcase(detail.id);
                      showSnack(
                        context,
                        added
                            ? 'Showcase updated.'
                            : 'Showcase is full (6). Remove one first.',
                      );
                    },
                    icon: const Icon(Icons.push_pin_outlined),
                    label: const Text('Pin to showcase'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _addToCollection(BuildContext context, WidgetRef ref) async {
    final collections = ref.read(collectionsProvider);
    final nameController = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          Space.md,
          0,
          Space.md,
          MediaQuery.of(sheetContext).viewInsets.bottom + Space.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add to collection',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: Space.sm),
            for (final c in collections)
              ListTile(
                title: Text(c.name),
                subtitle: Text('${c.ids.length} Pokémon'),
                trailing: c.ids.contains(detail.id)
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop('existing:${c.id}'),
              ),
            const SizedBox(height: Space.sm),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Or create a new collection',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) {
                  Navigator.of(sheetContext).pop('new:${v.trim()}');
                }
              },
            ),
            const SizedBox(height: Space.sm),
            FilledButton(
              onPressed: () {
                final v = nameController.text.trim();
                if (v.isNotEmpty) {
                  Navigator.of(sheetContext).pop('new:$v');
                }
              },
              child: const Text('Create and add'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !context.mounted) {
      return;
    }
    final notifier = ref.read(collectionsProvider.notifier);
    if (result.startsWith('new:')) {
      final id = notifier.create(result.substring(4));
      notifier.add(id, detail.id);
      showSnack(context, 'Added to new collection.');
    } else {
      final id = result.substring('existing:'.length);
      final added = notifier.add(id, detail.id);
      showSnack(
        context,
        added ? 'Added to collection.' : 'Already in that collection.',
      );
    }
  }
}

class _Readout extends StatelessWidget {
  const _Readout({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: readoutStyle(context, size: 10)),
        const SizedBox(height: 2),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _EvolutionPreview extends ConsumerWidget {
  const _EvolutionPreview({required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chain = ref.watch(evolutionProvider(id));
    final scheme = Theme.of(context).colorScheme;
    return chain.when(
      loading: () => const SkeletonBox(height: 90),
      error: (e, _) => Row(
        children: [
          Expanded(
            child: Text(
              describeErrorShort(e),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () => ref.invalidate(evolutionProvider(id)),
            child: const Text('Retry'),
          ),
        ],
      ),
      data: (c) {
        final nodes = c.allNodes;
        return Panel(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ConstellationPage(pokemonId: id),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (c.isSingle)
                Text(
                  'This species does not evolve and has no evolutions.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                )
              else
                SizedBox(
                  height: 84,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: nodes.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: Space.sm),
                    itemBuilder: (context, i) {
                      final n = nodes[i];
                      return GestureDetector(
                        onTap: n.id == id
                            ? null
                            : () => openDossier(context, n.id),
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: n.id == id
                                      ? scheme.primary
                                      : scheme.outlineVariant,
                                  width: n.id == id ? 2 : 1,
                                ),
                              ),
                              child: PokemonArtwork(id: n.id, size: 56),
                            ),
                            Text(
                              n.displayName,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: Space.sm),
              Row(
                children: [
                  Icon(Icons.hub_outlined, size: 16, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Open Evolution Constellation',
                    style: TextStyle(color: scheme.primary),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

String describeErrorShort(Object e) =>
    'Evolution data is unavailable right now.';

class _ResearchControls extends ConsumerWidget {
  const _ResearchControls({required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      researchProvider.select((m) => m[id] ?? ResearchState.unseen),
    );
    final next = ResearchRules.next(state);
    final scheme = Theme.of(context).colorScheme;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ResearchBadge(state, size: 22),
              const SizedBox(width: Space.sm),
              Text(state.label, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(switch (state) {
            ResearchState.unseen => 'Not yet logged.',
            ResearchState.discovered =>
              'Discovered by opening this dossier. Mark it Studied once you have read through it.',
            ResearchState.studied =>
              'Studied. Mark Mastered when you know it well.',
            ResearchState.mastered =>
              'Mastered. You can step back down if you want to revisit it.',
          }, style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            children: [
              if (next != null && next != ResearchState.unseen)
                FilledButton(
                  onPressed: () =>
                      ref.read(researchProvider.notifier).transition(id, next),
                  child: Text('Mark ${next.label}'),
                ),
              if (state.index > ResearchState.discovered.index)
                OutlinedButton(
                  onPressed: () => ref
                      .read(researchProvider.notifier)
                      .transition(id, ResearchState.values[state.index - 1]),
                  child: const Text('Step back'),
                ),
              if (state != ResearchState.unseen)
                TextButton(
                  onPressed: () => ref
                      .read(researchProvider.notifier)
                      .transition(id, ResearchState.unseen),
                  child: const Text('Reset to unseen'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoteEditor extends ConsumerStatefulWidget {
  const _NoteEditor({required this.id});

  final int id;

  @override
  ConsumerState<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends ConsumerState<_NoteEditor> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(notesProvider)[widget.id] ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      minLines: 2,
      maxLines: 6,
      onChanged: (v) => ref.read(notesProvider.notifier).setNote(widget.id, v),
      decoration: const InputDecoration(
        labelText: 'Research notes',
        hintText: 'Your own observations (saved on this device)',
        border: OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
    );
  }
}
