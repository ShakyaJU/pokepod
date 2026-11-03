import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_system/widgets.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../data/providers.dart';
import '../../domain/team_analysis.dart';
import '../../domain/type_chart.dart';
import '../shared/navigation.dart';
import '../shared/pokemon_picker.dart';
import 'teams_controller.dart';

Future<String?> _askName(
  BuildContext context, {
  required String title,
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

/// List of saved teams.
class TeamListPage extends ConsumerWidget {
  const TeamListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teams = ref.watch(teamsProvider);
    final notifier = ref.read(teamsProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Team Architect'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final name = await _askName(context, title: 'New team');
          if (name == null || !context.mounted) {
            return;
          }
          final id = notifier.create(name);
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => TeamDetailPage(teamId: id)),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New team'),
      ),
      body: teams.isEmpty
          ? const EmptyState(
              icon: Icons.groups_outlined,
              title: 'No teams yet',
              message:
                  'Build a team of up to six and see its type coverage and weaknesses.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                Space.md,
                Space.md,
                Space.md,
                96,
              ),
              itemCount: teams.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: Space.sm),
              itemBuilder: (context, i) {
                final t = teams[i];
                return Panel(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TeamDetailPage(teamId: t.id),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Text(
                            '${t.members.length}/$kTeamSize',
                            style: readoutStyle(context),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'rename') {
                                final name = await _askName(
                                  context,
                                  title: 'Rename team',
                                  initial: t.name,
                                );
                                if (name != null) {
                                  notifier.rename(t.id, name);
                                }
                              } else if (v == 'duplicate') {
                                notifier.duplicate(t.id);
                              } else if (v == 'delete') {
                                notifier.delete(t.id);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'rename',
                                child: Text('Rename'),
                              ),
                              PopupMenuItem(
                                value: 'duplicate',
                                child: Text('Duplicate'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 48,
                        child: t.members.isEmpty
                            ? const Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Empty team'),
                              )
                            : ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  for (final m in t.members)
                                    PokemonArtwork(id: m, size: 48),
                                ],
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class TeamDetailPage extends ConsumerWidget {
  const TeamDetailPage({super.key, required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(
      teamsProvider.select(
        (list) => list.where((t) => t.id == teamId).firstOrNull,
      ),
    );
    if (team == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Team')),
        body: const EmptyState(
          icon: Icons.groups_outlined,
          title: 'Team not found',
          message: 'It may have been deleted.',
        ),
      );
    }
    final notifier = ref.read(teamsProvider.notifier);
    final names = ref.watch(catalogByIdProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(team.name),
        actions: [
          IconButton(
            tooltip: 'Rename',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final name = await _askName(
                context,
                title: 'Rename team',
                initial: team.name,
              );
              if (name != null) {
                notifier.rename(team.id, name);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Space.md),
        children: [
          SectionLabel(
            'Members',
            trailing: Text(
              '${team.members.length}/$kTeamSize',
              style: readoutStyle(context),
            ),
          ),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: Space.sm,
            crossAxisSpacing: Space.sm,
            childAspectRatio: 0.95,
            children: [
              for (final id in team.members)
                Panel(
                  padding: const EdgeInsets.all(Space.xs),
                  onTap: () => openDossier(context, id),
                  child: Stack(
                    children: [
                      Column(
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
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          tooltip: 'Remove',
                          iconSize: 18,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close),
                          onPressed: () => notifier.removeMember(team.id, id),
                        ),
                      ),
                    ],
                  ),
                ),
              if (team.members.length < kTeamSize)
                Panel(
                  onTap: () async {
                    final picked = await showPokemonPicker(
                      context,
                      title: 'Add to ${team.name}',
                      excluded: team.members.toSet(),
                    );
                    if (picked != null) {
                      notifier.addMember(team.id, picked.id);
                    }
                  },
                  child: const Center(child: Icon(Icons.add, size: 32)),
                ),
            ],
          ),
          const SizedBox(height: Space.lg),
          if (team.members.isEmpty)
            const EmptyState(
              icon: Icons.analytics_outlined,
              title: 'Add Pokémon to analyse',
              message:
                  'Coverage and weaknesses appear once the team has members.',
            )
          else
            _TeamAnalysisView(memberIds: team.members),
        ],
      ),
    );
  }
}

class _TeamAnalysisView extends ConsumerWidget {
  const _TeamAnalysisView({required this.memberIds});

  final List<int> memberIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final loaded = <List<String>>[];
    var pending = 0;
    var failed = 0;
    for (final id in memberIds) {
      final d = ref.watch(pokemonDetailProvider(id));
      final value = d.valueOrNull;
      if (value != null) {
        loaded.add(value.types);
      } else if (d.hasError) {
        failed++;
      } else {
        pending++;
      }
    }
    if (loaded.isEmpty && pending > 0) {
      return const SkeletonBox(height: 160);
    }
    if (loaded.isEmpty) {
      return ErrorRetry(
        error: const AppException(
          AppErrorKind.network,
          'Member data unavailable.',
        ),
        onRetry: () {
          for (final id in memberIds) {
            ref.invalidate(pokemonDetailProvider(id));
          }
        },
      );
    }
    final analysis = TeamAnalyzer.analyze(loaded);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pending > 0 || failed > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: Text(
              pending > 0
                  ? 'Loading $pending more member(s)…'
                  : '$failed member(s) could not be loaded and are left out of this analysis.',
              style: TextStyle(color: scheme.tertiary, fontSize: 12),
            ),
          ),
        Panel(
          child: Text(
            '${analysis.coveredTypes.length} of ${kTypes.length} types are hit super effectively '
            'by your members\' own types. '
            '${analysis.majorWeaknesses.isEmpty ? 'No major shared weaknesses.' : '${analysis.majorWeaknesses.length} major shared weakness(es).'}',
          ),
        ),
        const SizedBox(height: Space.lg),
        const SectionLabel('Defensive matrix'),
        Text(
          'Per attacking type: members weak (W), resisting (R) and immune (I).',
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in kTypes)
              _MatrixCell(
                type: t,
                weak: analysis.weakCounts[t]!,
                resist: analysis.resistCounts[t]!,
                immune: analysis.immuneCounts[t]!,
                major: analysis.majorWeaknesses.contains(t),
              ),
          ],
        ),
        const SizedBox(height: Space.lg),
        const SectionLabel('Offensive coverage (own types)'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in analysis.coveredTypes)
              Chip(
                label: Text(titleCase(t), style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: scheme.primary),
              ),
            for (final t in analysis.uncoveredTypes)
              Chip(
                label: Text(
                  titleCase(t),
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: Space.xs),
          child: Text(
            'Outlined types are hit super effectively by at least one member\'s own type. '
            'Actual movesets are not known, so this is STAB-based coverage only.',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: Space.lg),
        const SectionLabel('Suggestions'),
        if (analysis.suggestions.isEmpty)
          Text(
            'Nothing stands out. This team has no major shared weakness or coverage gap.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          )
        else
          for (final s in analysis.suggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Panel(child: Text(s)),
            ),
      ],
    );
  }
}

class _MatrixCell extends StatelessWidget {
  const _MatrixCell({
    required this.type,
    required this.weak,
    required this.resist,
    required this.immune,
    required this.major,
  });

  final String type;
  final int weak;
  final int resist;
  final int immune;
  final bool major;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 100,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: major ? scheme.error : scheme.outlineVariant),
        color: major ? scheme.error.withValues(alpha: 0.1) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TypeChip(type, dense: true),
          const SizedBox(height: 4),
          Text(
            'W$weak  R$resist  I$immune',
            style: readoutStyle(context, size: 10),
          ),
        ],
      ),
    );
  }
}
