import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_system/meta_badge.dart';
import '../../app/design_system/progress_ring.dart';
import '../../app/design_system/stat_readout.dart';
import '../../app/design_system/widgets.dart';
import '../../app/shell.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/providers.dart';
import '../../domain/generations.dart';
import '../collections/collections_controller.dart';
import '../mystery/mystery_controller.dart';
import '../research/research_controller.dart';
import '../shared/navigation.dart';
import '../shared/pokemon_picker.dart';
import '../team_builder/team_page.dart';
import '../team_builder/teams_controller.dart';
import 'achievements_page.dart';
import 'edit_trainer_sheet.dart';
import 'journal_page.dart';
import 'profile_controller.dart';
import 'profile_menu.dart';

/// Trainer landing page: a curated overview. Achievements, the journal,
/// settings, About and Help live behind the menu in the top-right corner.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final summary = ref.watch(researchSummaryProvider);
    final favourites = ref.watch(favouritesProvider);
    final collections = ref.watch(collectionsProvider);
    final teams = ref.watch(teamsProvider);
    final notes = ref.watch(notesProvider);
    final streaks = ref.watch(mysteryStreaksProvider);
    final scheme = Theme.of(context).colorScheme;

    final isFirstUse =
        summary.discovered == 0 &&
        favourites.isEmpty &&
        notes.isEmpty &&
        collections.isEmpty &&
        teams.isEmpty;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: Space.xl),
        children: [
          PageHeader(
            title: 'Trainer',
            subtitle: 'Profile',
            trailing: IconButton(
              tooltip: 'Open profile menu',
              iconSize: 28,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: () => showProfileMenu(context),
              icon: const Icon(Icons.menu),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TrainerCard(profile: profile, summary: summary),
                if (isFirstUse) ...[
                  const SizedBox(height: Space.md),
                  const _FirstUseCard(),
                ],
                const SizedBox(height: Space.lg),
                SectionLabel(
                  'Showcase',
                  trailing: profile.showcase.isEmpty
                      ? null
                      : TextButton(
                          onPressed: () =>
                              ref.read(navIndexProvider.notifier).state = 3,
                          child: const Text('Arrange'),
                        ),
                ),
                _Showcase(ids: profile.showcase),
                const SizedBox(height: Space.lg),
                const SectionLabel('Collection progress'),
                _ProgressCard(summary: summary),
                const SizedBox(height: Space.lg),
                const SectionLabel('Key statistics'),
                _KeyStats(
                  items: [
                    ('Studied', '${summary.studied}'),
                    ('Mastered', '${summary.mastered}'),
                    ('Favourites', '${favourites.length}'),
                    ('Best streak', '${streaks.best}'),
                  ],
                ),
                if (favourites.isNotEmpty) ...[
                  const SizedBox(height: Space.lg),
                  const SectionLabel('Favourite types'),
                  _FavouriteTypes(favourites: favourites),
                ],
                const SizedBox(height: Space.lg),
                const SectionLabel('Recent activity'),
                const _RecentActivity(),
                const SizedBox(height: Space.lg),
                const SectionLabel('Achievements'),
                const _AchievementsPreview(),
                const SizedBox(height: Space.lg),
                const SectionLabel('Research journal'),
                const _JournalPreview(),
                const SizedBox(height: Space.lg),
                Panel(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TeamListPage(),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.groups_outlined, color: scheme.primary),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Saved teams',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              teams.isEmpty
                                  ? 'No teams yet. Build one in the Team Architect.'
                                  : '${teams.length} saved: ${teams.map((t) => t.name).take(3).join(', ')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
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

class _TrainerCard extends ConsumerWidget {
  const _TrainerCard({required this.profile, required this.summary});

  final ProfileState profile;
  final ResearchSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: scheme.outlineVariant),
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 1.4,
          colors: [accent.withValues(alpha: 0.2), scheme.surfaceContainerLow],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surfaceContainerHigh,
              border: Border.all(color: accent, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: profile.avatarId == null
                ? Center(
                    child: Text(
                      profile.nickname.characters.first.toUpperCase(),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(4),
                    child: PokemonArtwork(id: profile.avatarId!),
                  ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  summary.discovered == 0
                      ? 'Research not started yet'
                      : '${summary.discovered} discovered · ${summary.mastered} mastered',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit trainer',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showEditTrainerSheet(context),
          ),
        ],
      ),
    );
  }
}

class _FirstUseCard extends ConsumerWidget {
  const _FirstUseCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    Widget step(String n, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(n, style: readoutStyle(context, color: scheme.primary)),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
    return Panel(
      borderColor: scheme.primary.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Start your collection',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: Space.sm),
          step(
            '01',
            'Open the Pokédex and tap any Pokémon. Opening a dossier logs it as discovered.',
          ),
          step(
            '02',
            'Tap the heart to favourite it, or pin it to your showcase.',
          ),
          step('03', 'Mark Pokémon as Studied or Mastered as you learn them.'),
          const SizedBox(height: Space.sm),
          FilledButton.icon(
            onPressed: () => ref.read(navIndexProvider.notifier).state = 1,
            icon: const Icon(Icons.grid_view_rounded),
            label: const Text('Browse the Pokédex'),
          ),
        ],
      ),
    );
  }
}

class _Showcase extends ConsumerWidget {
  const _Showcase({required this.ids});

  final List<int> ids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(catalogByIdProvider);
    final scheme = Theme.of(context).colorScheme;
    if (ids.isEmpty) {
      return Panel(
        onTap: () async {
          final picked = await showPokemonPicker(
            context,
            title: 'Pin to showcase',
          );
          if (picked != null) {
            ref.read(profileProvider.notifier).toggleShowcase(picked.id);
          }
        },
        child: Row(
          children: [
            Icon(Icons.push_pin_outlined, color: scheme.primary),
            const SizedBox(width: Space.md),
            const Expanded(
              child: Text(
                'Pin up to six Pokémon to feature them here. Tap to choose one.',
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ids.length,
        separatorBuilder: (context, index) => const SizedBox(width: Space.sm),
        itemBuilder: (context, i) {
          final id = ids[i];
          return SizedBox(
            width: 104,
            child: Panel(
              padding: const EdgeInsets.all(Space.xs),
              onTap: () => openDossier(context, id),
              child: Column(
                children: [
                  Expanded(child: PokemonArtwork(id: id)),
                  Text(
                    names[id]?.displayName ?? dexNumber(id),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProgressCard extends ConsumerWidget {
  const _ProgressCard({required this.summary});

  final ResearchSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final percent = (summary.discovered * 100 / kNationalDexSize).floor();
    return Panel(
      onTap: () => ref.read(navIndexProvider.notifier).state = 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProgressRing(
                fraction: summary.discovered / kNationalDexSize,
                label: '$percent%',
                semanticsLabel: '$percent percent of the Pokédex discovered',
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${summary.discovered} of $kNationalDexSize discovered',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${summary.studied} studied · ${summary.mastered} mastered',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          Text('BY GENERATION', style: readoutStyle(context, size: 10)),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var g = 1; g <= kGenerationRanges.length; g++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: g == kGenerationRanges.length ? 0 : 4,
                    ),
                    child: _GenBar(
                      generation: g,
                      discovered: summary.discoveredIds,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GenBar extends StatelessWidget {
  const _GenBar({required this.generation, required this.discovered});

  final int generation;
  final Set<int> discovered;

  @override
  Widget build(BuildContext context) {
    final (lo, hi) = kGenerationRanges[generation - 1];
    var count = 0;
    for (final id in discovered) {
      if (id >= lo && id <= hi) {
        count++;
      }
    }
    final fraction = count / generationSize(generation);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label:
          '${generationLabel(generation)}: $count of ${generationSize(generation)} discovered',
      excludeSemantics: true,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(value: fraction, minHeight: 6),
          ),
          const SizedBox(height: 4),
          Text(
            kRomanNumerals[generation - 1],
            style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Four statistics, each in its own tile. Four across when every tile can be
/// comfortably wide, otherwise a balanced two-by-two grid, never a squeezed row.
class _KeyStats extends StatelessWidget {
  const _KeyStats({required this.items});

  final List<(String, String)> items;

  static const double _gap = Space.sm;
  static const double _minTileWidth = 104;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final minTile = _minTileWidth * (textScale < 1 ? 1 : textScale);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tiles = [
          for (final (label, value) in items)
            _StatTile(label: label, value: value),
        ];
        final fourAcross =
            constraints.maxWidth >=
            items.length * minTile + (items.length - 1) * _gap;
        if (fourAcross) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) const SizedBox(width: _gap),
                  Expanded(child: tiles[i]),
                ],
              ],
            ),
          );
        }
        Widget row(int start) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tiles[start]),
              const SizedBox(width: _gap),
              Expanded(child: tiles[start + 1]),
            ],
          ),
        );
        return Column(
          children: [
            row(0),
            const SizedBox(height: _gap),
            row(2),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.sm,
        vertical: Space.md,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Center(
        child: StatReadout(label: label, value: value),
      ),
    );
  }
}

/// Counts the types of the user's favourites (looking at up to 20 of them).
class _FavouriteTypes extends ConsumerWidget {
  const _FavouriteTypes({required this.favourites});

  final Set<int> favourites;

  static const int maxSampled = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final ids = (favourites.toList()..sort()).take(maxSampled).toList();
    final counts = <String, int>{};
    var loaded = 0;
    var pending = 0;
    for (final id in ids) {
      final d = ref.watch(pokemonDetailProvider(id));
      final detail = d.valueOrNull;
      if (detail != null) {
        loaded++;
        for (final t in detail.types) {
          counts[t] = (counts[t] ?? 0) + 1;
        }
      } else if (!d.hasError) {
        pending++;
      }
    }
    if (loaded == 0) {
      return pending > 0
          ? const SkeletonBox(height: 32)
          : Text(
              'Type details for your favourites are not available right now.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            );
    }
    final top = counts.entries.toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final e in top.take(5))
              MetaBadge(
                label: '${titleCase(e.key)} ×${e.value}',
                color: typeColor(e.key),
                dot: true,
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Based on $loaded favourite${loaded == 1 ? '' : 's'}'
          '${favourites.length > maxSampled ? ' (first $maxSampled by number)' : ''}.',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _RecentActivity extends ConsumerWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentProvider);
    final names = ref.watch(catalogByIdProvider);
    if (recent.isEmpty) {
      return const Panel(child: Text('Dossiers you open will appear here.'));
    }
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recent.take(8).length,
        separatorBuilder: (context, index) => const SizedBox(width: Space.sm),
        itemBuilder: (context, i) {
          final id = recent[i];
          return GestureDetector(
            onTap: () => openDossier(context, id),
            child: SizedBox(
              width: 76,
              child: Column(
                children: [
                  PokemonArtwork(id: id, size: 68),
                  Text(
                    names[id]?.displayName ?? dexNumber(id),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AchievementsPreview extends ConsumerWidget {
  const _AchievementsPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final achievements = ref.watch(achievementsProvider);
    final unlocked = achievements.where((a) => a.unlocked).length;
    final next = [
      for (final a in achievements)
        if (!a.unlocked && a.target > 0) a,
    ]..sort((a, b) => (b.progress / b.target).compareTo(a.progress / a.target));
    return Panel(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const AchievementsPage())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_outlined, color: scheme.tertiary),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  '$unlocked of ${achievements.length} earned',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text('View all', style: TextStyle(color: scheme.primary)),
              Icon(Icons.chevron_right, color: scheme.primary),
            ],
          ),
          if (next.isNotEmpty) ...[
            const SizedBox(height: Space.sm),
            Text('NEXT UP', style: readoutStyle(context, size: 10)),
            const SizedBox(height: 4),
            for (final a in next.take(2))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(a.title)),
                    Text(
                      '${a.progress}/${a.target}',
                      style: readoutStyle(context, size: 10),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _JournalPreview extends ConsumerWidget {
  const _JournalPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final notes = ref.watch(notesProvider);
    final recent = ref.watch(recentProvider);
    final names = ref.watch(catalogByIdProvider);
    final withNotes = [
      ...recent.where(notes.containsKey),
      ...(notes.keys.toList()..sort()).where((id) => !recent.contains(id)),
    ].take(2).toList();

    return Panel(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const JournalPage())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_outlined, color: scheme.primary),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  notes.isEmpty
                      ? 'No notes yet'
                      : '${notes.length} note${notes.length == 1 ? '' : 's'} written',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text('Open', style: TextStyle(color: scheme.primary)),
              Icon(Icons.chevron_right, color: scheme.primary),
            ],
          ),
          if (withNotes.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Space.sm),
              child: Text(
                'Write notes in any Pokémon dossier and they are collected in your journal.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            )
          else
            for (final id in withNotes)
              Padding(
                padding: const EdgeInsets.only(top: Space.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PokemonArtwork(id: id, size: 36),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            names[id]?.displayName ?? dexNumber(id),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            notes[id] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
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
