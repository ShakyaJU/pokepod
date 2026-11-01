import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_system/meta_badge.dart';
import '../../app/design_system/widgets.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/pokemon.dart';
import '../../data/providers.dart';
import '../../domain/connections.dart';
import '../../domain/mystery_logic.dart';
import '../mystery/mystery_controller.dart';
import '../mystery/mystery_page.dart';
import '../research/research_controller.dart';
import '../shared/navigation.dart';
import '../trainer_profile/profile_controller.dart';

class DiscoverPage extends ConsumerWidget {
  const DiscoverPage({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) {
      return 'Late shift';
    }
    if (h < 12) {
      return 'Good morning';
    }
    if (h < 18) {
      return 'Good afternoon';
    }
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final today = ref.watch(todayKeyProvider);
    final summary = ref.watch(researchSummaryProvider);
    final recent = ref.watch(recentProvider);
    final achievements = ref.watch(achievementsProvider);
    final mystery = ref.watch(mysteryProvider);
    final streaks = ref.watch(mysteryStreaksProvider);
    final names = ref.watch(catalogByIdProvider);
    final scheme = Theme.of(context).colorScheme;
    final specimenId = specimenOfDayId(today);
    final specimen = ref.watch(pokemonDetailProvider(specimenId));
    final solvedToday = mystery.history[ref.watch(challengeDayProvider)];

    final inProgress = [
      for (final a in achievements)
        if (!a.unlocked) a,
    ]..sort((a, b) => (b.progress / b.target).compareTo(a.progress / a.target));
    final unlockedCount = achievements.where((a) => a.unlocked).length;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: Space.xl),
        children: [
          PageHeader(
            title: '${_greeting()}, ${profile.nickname}',
            subtitle: 'Research device online',
          ),
          const LiveStatusBanner(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Specimen of the day'),
                Panel(
                  onTap: () => openDossier(context, specimenId),
                  child: Row(
                    children: [
                      PokemonArtwork(id: specimenId, size: 112),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dexNumber(specimenId),
                              style: readoutStyle(context),
                            ),
                            Text(
                              names[specimenId]?.displayName ??
                                  specimen.valueOrNull?.displayName ??
                                  dexNumber(specimenId),
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: Space.sm),
                            specimen.when(
                              loading: () =>
                                  const SkeletonBox(width: 120, height: 24),
                              error: (e, _) => Text(
                                'Details need a connection.',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              data: (d) => Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final t in d.types)
                                    TypeChip(t, dense: true),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.lg),
                const SectionLabel('Daily challenge'),
                _DailyChallengeCard(
                  record: solvedToday,
                  streak: streaks.current,
                  best: streaks.best,
                ),
                const SizedBox(height: Space.lg),
                const SectionLabel('Research progress'),
                Panel(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 84,
                        height: 84,
                        child: CustomPaint(
                          painter: _RingPainter(
                            fraction: summary.discovered / kNationalDexSize,
                            color: scheme.primary,
                            track: scheme.surfaceContainerHigh,
                          ),
                          child: Center(
                            child: Text(
                              '${(summary.discovered * 100 / kNationalDexSize).floor()}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${summary.discovered} of $kNationalDexSize discovered',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${summary.studied} studied · ${summary.mastered} mastered',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                            if (summary.discovered == 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Open any Pokémon\'s dossier to log your first discovery.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.lg),
                const SectionLabel('Recently viewed'),
                if (recent.isEmpty)
                  const Panel(
                    child: Text(
                      'Nothing yet. Browse the Pokédex to start your log.',
                    ),
                  )
                else
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final id in recent.take(12))
                          GestureDetector(
                            onTap: () => openDossier(context, id),
                            child: Padding(
                              padding: const EdgeInsets.only(right: Space.sm),
                              child: Column(
                                children: [
                                  PokemonArtwork(id: id, size: 72),
                                  Text(
                                    names[id]?.displayName ?? dexNumber(id),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: Space.lg),
                const SectionLabel('Unexpected connections'),
                _Connections(baseId: specimenId, today: today),
                const SizedBox(height: Space.lg),
                SectionLabel(
                  'Milestones',
                  trailing: Text(
                    '$unlockedCount/${achievements.length}',
                    style: readoutStyle(context, color: scheme.primary),
                  ),
                ),
                for (final a in inProgress.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: Panel(
                      child: Row(
                        children: [
                          const Icon(Icons.flag_outlined),
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  a.rule,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${a.progress}/${a.target}',
                            style: readoutStyle(context),
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
    );
  }
}

/// Daily challenge card: the specimen status on the left, a separate and clearly
/// divided streak panel on the right.
class _DailyChallengeCard extends StatelessWidget {
  const _DailyChallengeCard({
    required this.record,
    required this.streak,
    required this.best,
  });

  final MysteryRecord? record;
  final int streak;
  final int best;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = record;
    final (statusLabel, statusIcon, statusColor) = r == null
        ? ('Ready to play', Icons.play_arrow_rounded, scheme.primary)
        : r.won
        ? ('Solved in ${r.guesses}', Icons.check_circle_outline, scheme.primary)
        : ('Missed today', Icons.cancel_outlined, scheme.error);
    final description = r == null
        ? 'Identify today\'s Pokémon from progressive clues.'
        : r.won
        ? 'Nice work. A new Pokémon arrives at midnight.'
        : 'A new Pokémon arrives at midnight.';

    return Panel(
      padding: EdgeInsets.zero,
      borderColor: r == null ? scheme.primary : null,
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const MysteryPage())),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(Space.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.primary.withValues(alpha: 0.14),
                          ),
                          child: Center(
                            child: Text(
                              '?',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                height: 1,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: Text(
                            'Who\'s That Pokémon?',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.sm),
                    Text(
                      description,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: Space.sm),
                    MetaBadge(
                      label: statusLabel,
                      icon: statusIcon,
                      color: statusColor,
                      dense: true,
                    ),
                  ],
                ),
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: scheme.outlineVariant,
            ),
            _StreakPanel(streak: streak, best: best),
          ],
        ),
      ),
    );
  }
}

class _StreakPanel extends StatelessWidget {
  const _StreakPanel({required this.streak, required this.best});

  final int streak;
  final int best;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = streak > 0;
    return Semantics(
      label:
          'Current streak: $streak ${streak == 1 ? 'day' : 'days'}. Best streak: $best.',
      excludeSemantics: true,
      child: Container(
        width: 112,
        padding: const EdgeInsets.symmetric(
          horizontal: Space.sm,
          vertical: Space.md,
        ),
        color: scheme.tertiary.withValues(alpha: active ? 0.12 : 0.05),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: active ? 1 : 0.45,
              child: const Text(
                '🔥',
                style: TextStyle(fontSize: 26, height: 1.1),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$streak',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.1,
                color: active ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'DAY STREAK',
              style: readoutStyle(context, size: 9, color: scheme.tertiary),
            ),
            const SizedBox(height: 6),
            Text(
              'Best $best',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.color,
    required this.track,
  });

  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, base);
    final sweep = math.pi * 2 * fraction.clamp(0.0, 1.0);
    if (sweep > 0) {
      canvas.drawArc(arcRect, -math.pi / 2, sweep, false, fill);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color || old.track != track;
}

/// Connections between the specimen of the day and a deterministic sample of
/// its type-mates and evolutionary relatives.
class _Connections extends ConsumerWidget {
  const _Connections({required this.baseId, required this.today});

  final int baseId;
  final String today;

  List<int> _candidates(Set<int> members) {
    final pool = (members.toList()..sort())
        .where((id) => id != baseId)
        .toList();
    if (pool.isEmpty) {
      return const [];
    }
    final picks = <int>[];
    for (var i = 0; i < 60 && picks.length < 6; i++) {
      final id = pool[stableHash('$today:$baseId:$i') % pool.length];
      if (!picks.contains(id)) {
        picks.add(id);
      }
    }
    return picks;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final base = ref.watch(pokemonDetailProvider(baseId));
    final baseDetail = base.valueOrNull;
    if (baseDetail == null) {
      return base.hasError
          ? Text(
              'Connections need the specimen\'s data, which is not available offline yet.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            )
          : const SkeletonBox(height: 90);
    }

    final family =
        ref.watch(evolutionProvider(baseId)).valueOrNull?.memberIds ?? <int>{};
    final ids = <int>{...family.where((id) => id != baseId)};
    if (baseDetail.types.isNotEmpty) {
      final members = ref.watch(typeMembersProvider(baseDetail.types.first));
      ids.addAll(_candidates(members.valueOrNull ?? const <int>{}));
    }
    if (ids.isEmpty) {
      return Text(
        'No related Pokémon could be loaded yet.',
        style: TextStyle(color: scheme.onSurfaceVariant),
      );
    }

    final details = <PokemonDetail>[];
    var pending = 0;
    for (final id in ids) {
      final d = ref.watch(pokemonDetailProvider(id));
      final v = d.valueOrNull;
      if (v != null) {
        details.add(v);
      } else if (!d.hasError) {
        pending++;
      }
    }
    final connections = findConnections(
      baseDetail,
      details,
      evolutionRelatives: family,
      limit: 3,
    );
    if (connections.isEmpty) {
      return pending > 0
          ? const SkeletonBox(height: 90)
          : Text(
              'No notable connections found for today\'s specimen.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            );
    }
    return Column(
      children: [
        for (final c in connections)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: Panel(
              onTap: () => openDossier(context, c.otherId),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PokemonArtwork(id: c.otherId, size: 56),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.title.toUpperCase(),
                          style: readoutStyle(
                            context,
                            size: 10,
                            color: scheme.primary,
                          ),
                        ),
                        Text(
                          c.explanation,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
