import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_system/progress_bar.dart';
import '../../app/design_system/rarity_label.dart';
import '../../app/design_system/widgets.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/rarity.dart';
import '../../app/theme/tokens.dart';
import '../../domain/achievements.dart';
import 'profile_controller.dart';

/// Presentation-only grouping and artwork for the achievement rules.
class _Category {
  const _Category(this.title, this.blurb, this.ids);

  final String title;
  final String blurb;
  final List<String> ids;
}

const List<_Category> _categories = [
  _Category('Discovery', 'Find Pokémon by opening their dossiers.', [
    'first_contact',
    'field_researcher',
    'cataloguer',
    'kanto_complete',
    'world_tour',
  ]),
  _Category('Research', 'Study, master and document what you learn.', [
    'scholar',
    'mastery',
    'journalist',
    'favourite_five',
  ]),
  _Category(
    'Collection and teams',
    'Organise Pokémon into collections and teams.',
    ['curator', 'team_architect'],
  ),
  _Category('Who\'s That Pokémon?', 'Prove yourself in the daily challenge.', [
    'first_solve',
    'streak_3',
    'streak_10',
    'streak_30',
    'streak_60',
    'streak_100',
    'streak_150',
    'streak_365',
    'mystery_50',
  ]),
];

/// Icon for each achievement id, shared by the badges here and the unlock
/// announcement in [AchievementUnlocks]. Ids without an entry fall back to
/// the trophy.
const Map<String, IconData> achievementIcons = {
  'first_contact': Icons.visibility_outlined,
  'field_researcher': Icons.explore_outlined,
  'cataloguer': Icons.menu_book_outlined,
  'kanto_complete': Icons.flag_outlined,
  'world_tour': Icons.public_outlined,
  'scholar': Icons.school_outlined,
  'mastery': Icons.workspace_premium,
  'curator': Icons.collections_bookmark_outlined,
  'team_architect': Icons.groups_outlined,
  'first_solve': Icons.lightbulb_outline,
  'streak_3': Icons.local_fire_department_outlined,
  'streak_10': Icons.bolt_outlined,
  'streak_30': Icons.calendar_month_outlined,
  'streak_60': Icons.search_outlined,
  'streak_100': Icons.military_tech,
  'streak_150': Icons.theater_comedy_outlined,
  'streak_365': Icons.auto_awesome,
  'mystery_50': Icons.emoji_events_outlined,
  'journalist': Icons.edit_note,
  'favourite_five': Icons.favorite_border,
};

/// The top three tiers get a subtle gradient fill on earned badges, so the
/// most prestigious achievements feel distinct without visual clutter.
const Set<AchievementRarity> _prestigeRarities = {
  AchievementRarity.illustrationRare,
  AchievementRarity.specialIllustrationRare,
  AchievementRarity.hyperRare,
};

class AchievementsPage extends ConsumerWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(achievementsProvider);
    final scheme = Theme.of(context).colorScheme;
    final byId = {for (final a in achievements) a.id: a};
    final grouped = {
      for (final c in _categories)
        for (final id in c.ids) id,
    };
    final others = [
      for (final a in achievements)
        if (!grouped.contains(a.id)) a,
    ];
    final earned = achievements.where((a) => a.unlocked).length;
    final total = achievements.length;
    final complete = total > 0 && earned == total;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Achievements'),
      ),
      body: total == 0
          ? const EmptyState(
              icon: Icons.emoji_events_outlined,
              title: 'No achievements available',
              message: 'Achievements will appear here once they are defined.',
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
                  'Milestones from your research. Each one unlocks automatically from what '
                  'you do in the app.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: Space.md),
                Panel(
                  borderColor: complete ? scheme.tertiary : null,
                  child: Row(
                    children: [
                      Icon(
                        complete
                            ? Icons.military_tech
                            : Icons.emoji_events_outlined,
                        size: 40,
                        color: scheme.tertiary,
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              complete
                                  ? 'Research complete'
                                  : '$earned of $total earned',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              complete
                                  ? 'Every achievement is unlocked. Well done, researcher.'
                                  : '${(earned * 100 / total).round()}% complete',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: Space.sm),
                            AppProgressBar(value: earned / total),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                for (final c in _categories)
                  ..._section(context, c.title, c.blurb, [
                    for (final id in c.ids)
                      if (byId[id] != null) byId[id]!,
                  ]),
                if (others.isNotEmpty) ..._section(context, 'More', '', others),
              ],
            ),
    );
  }

  List<Widget> _section(
    BuildContext context,
    String title,
    String blurb,
    List<Achievement> items,
  ) {
    if (items.isEmpty) {
      return const [];
    }
    final scheme = Theme.of(context).colorScheme;
    final done = items.where((a) => a.unlocked).length;
    return [
      const SizedBox(height: Space.lg),
      SectionLabel(
        title,
        trailing: Text('$done/${items.length}', style: readoutStyle(context)),
      ),
      if (blurb.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.sm),
          child: Text(
            blurb,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ),
      for (final a in items)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.sm),
          child: _AchievementTile(achievement: a),
        ),
    ];
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final scheme = Theme.of(context).colorScheme;
    final style = rarityStyle(context, a.rarity);
    final hasProgress = a.target > 0;
    final accent = a.unlocked ? style.color : scheme.outline;

    return Semantics(
      button: true,
      label:
          '${a.title}. ${a.unlocked ? 'Earned' : 'Locked'}. ${a.rule}'
          '${hasProgress ? ' Progress ${a.progress} of ${a.target}.' : ''}',
      excludeSemantics: true,
      onTap: () => _showDetails(context),
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(
            color: a.unlocked
                ? accent.withValues(alpha: 0.6)
                : scheme.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showDetails(context),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(Space.md),
                    child: Row(
                      children: [
                        _Badge(achievement: a, color: accent),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      a.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: a.unlocked
                                            ? scheme.onSurface
                                            : scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  RarityLabel(
                                    rarity: a.rarity,
                                    size: 9,
                                    uppercase: true,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                a.rule,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              if (!a.unlocked && hasProgress) ...[
                                const SizedBox(height: Space.sm),
                                Row(
                                  children: [
                                    Expanded(
                                      child: AppProgressBar(
                                        value: a.fraction,
                                        height: 6,
                                      ),
                                    ),
                                    const SizedBox(width: Space.sm),
                                    Text(
                                      '${a.progress}/${a.target}',
                                      style: readoutStyle(context, size: 10),
                                    ),
                                  ],
                                ),
                              ],
                              if (a.unlocked)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 14,
                                        color: accent,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Earned',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: accent,
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _AchievementDetails(achievement: achievement),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.achievement,
    required this.color,
    this.size = 48,
  });

  final Achievement achievement;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unlocked = achievement.unlocked;
    final gradient = unlocked && _prestigeRarities.contains(achievement.rarity);
    // Hyper Rare earns the full metallic ramp; the other prestige tiers keep
    // their subtle accent-to-shadow sheen.
    final sheen = rarityFillGradient(achievement.rarity);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient
            ? (sheen ??
                  LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color,
                      Color.lerp(color, const Color(0xFF0A0E12), 0.35)!,
                    ],
                  ))
            : null,
        color: unlocked && !gradient ? color.withValues(alpha: 0.16) : null,
        border: Border.all(
          color: unlocked ? color : scheme.outlineVariant,
          width: unlocked ? 2 : 1,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            achievementIcons[achievement.id] ?? Icons.emoji_events_outlined,
            size: size * 0.5,
            color: unlocked
                ? (gradient ? const Color(0xFF0A0E12) : color)
                : scheme.outline,
          ),
          if (!unlocked)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock,
                  size: size * 0.24,
                  color: scheme.outline,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AchievementDetails extends StatelessWidget {
  const _AchievementDetails({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final scheme = Theme.of(context).colorScheme;
    final style = rarityStyle(context, a.rarity);
    final hasProgress = a.target > 0;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Badge(
              achievement: a,
              color: a.unlocked ? style.color : scheme.outline,
              size: 84,
            ),
            const SizedBox(height: Space.md),
            Text(
              a.title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RarityLabel(rarity: a.rarity, uppercase: true),
                Text(
                  ' · ${a.unlocked ? 'EARNED' : 'LOCKED'}',
                  style: readoutStyle(context, color: style.labelColor),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            Text(a.rule, textAlign: TextAlign.center),
            const SizedBox(height: Space.md),
            if (hasProgress) ...[
              AppProgressBar(value: a.fraction, height: 8),
              const SizedBox(height: 6),
              Text(
                a.unlocked
                    ? 'Completed: ${a.target} of ${a.target}'
                    : 'Progress: ${a.progress} of ${a.target}',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ] else
              Text(
                'Progress is not available for this achievement.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            const SizedBox(height: Space.sm),
            Text(
              'Rarity reflects how challenging this achievement is to earn. '
              'The tiers are PokéPod\'s own system, inspired by Pokémon card rarity names.',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
