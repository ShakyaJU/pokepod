import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/utils/formatters.dart';
import '../../domain/type_chart.dart';

/// Weaknesses, resistances and immunities for one Pokémon's typing.
///
/// The single implementation behind both the comparison's "Defensive profile"
/// and the dossier's Defense Profile, so the two can never drift apart. It is
/// built straight from [TypeChart.defensiveProfile] — the same table every
/// matchup note in the app uses — so it is never a second opinion about type
/// effectiveness.
class DefensiveProfile extends StatelessWidget {
  const DefensiveProfile(this.types, {super.key});

  /// The Pokémon's type list. An empty list means PokéAPI reported no types,
  /// which is shown honestly rather than as "neutral against everything".
  final List<String> types;

  @override
  Widget build(BuildContext context) {
    final profile = TypeChart.defensiveProfile(types);
    final scheme = Theme.of(context).colorScheme;

    List<Widget> group(String title, bool Function(double) test, Color color) {
      final entries = [
        for (final t in kTypes)
          if (test(profile[t]!)) t,
      ];
      if (entries.isEmpty) {
        return const [];
      }
      return [
        Text(title, style: readoutStyle(context, size: 10, color: color)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final t in entries)
              Chip(
                label: Text(
                  '${titleCase(t)} ${formatMultiplier(profile[t]!)}',
                  style: const TextStyle(fontSize: 11),
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                side: BorderSide(color: typeColor(t).withValues(alpha: 0.7)),
              ),
          ],
        ),
        const SizedBox(height: Space.sm),
      ];
    }

    final groups = [
      ...group('WEAK TO', (m) => m > 1, scheme.error),
      ...group('RESISTS', (m) => m < 1 && m > 0, scheme.primary),
      ...group('IMMUNE', (m) => m == 0, AppColors.violet),
    ];

    if (groups.isEmpty) {
      return Text(
        types.isEmpty
            ? 'No type information is available for this Pokémon.'
            : 'This typing takes neutral damage from every type.',
        style: TextStyle(color: scheme.onSurfaceVariant),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups,
    );
  }
}
