import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_system/widgets.dart';
import '../../app/theme/tokens.dart';
import '../evolution/constellation_page.dart';
import '../shared/pokemon_picker.dart';
import '../team_builder/team_page.dart';
import '../team_builder/teams_controller.dart';
import 'compare_page.dart';

/// Hub for the analysis tools.
class LabPage extends ConsumerWidget {
  const LabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teams = ref.watch(teamsProvider);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: Space.xl),
        children: [
          const PageHeader(title: 'Lab', subtitle: 'Analysis instruments'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            child: Column(
              children: [
                _Tool(
                  icon: Icons.groups_outlined,
                  title: 'Team Architect',
                  description: teams.isEmpty
                      ? 'Build teams of up to six and inspect type coverage and weaknesses.'
                      : '${teams.length} saved team(s). Coverage, weaknesses and suggestions.',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TeamListPage(),
                    ),
                  ),
                ),
                const SizedBox(height: Space.sm),
                _Tool(
                  icon: Icons.biotech_outlined,
                  title: 'Pokémon DNA',
                  description:
                      'Compare base stats, types, abilities and defences of two Pokémon.',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ComparePage(),
                    ),
                  ),
                ),
                const SizedBox(height: Space.sm),
                _Tool(
                  icon: Icons.hub_outlined,
                  title: 'Evolution Constellation',
                  description:
                      'Explore a whole evolutionary family as a zoomable graph.',
                  onTap: () async {
                    final picked = await showPokemonPicker(
                      context,
                      title: 'Explore which family?',
                    );
                    if (picked == null || !context.mounted) {
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ConstellationPage(pokemonId: picked.id),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Panel(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 32, color: scheme.primary),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
