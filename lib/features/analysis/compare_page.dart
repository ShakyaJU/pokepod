import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_system/widgets.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/pokemon.dart';
import '../../data/providers.dart';
import '../../domain/compare_logic.dart';
import '../../domain/type_chart.dart';
import '../shared/pokemon_picker.dart';

/// Side-by-side "DNA" comparison of two Pokémon using real base stats.
class ComparePage extends ConsumerStatefulWidget {
  const ComparePage({super.key, this.initialA, this.initialB});

  final int? initialA;
  final int? initialB;

  @override
  ConsumerState<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends ConsumerState<ComparePage> {
  int? _a;
  int? _b;

  @override
  void initState() {
    super.initState();
    _a = widget.initialA;
    _b = widget.initialB;
  }

  Future<void> _pick(bool first) async {
    final picked = await showPokemonPicker(
      context,
      title: first ? 'Specimen A' : 'Specimen B',
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (first) {
        _a = picked.id;
      } else {
        _b = picked.id;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final names = ref.watch(catalogByIdProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Pokémon DNA'),
        actions: [
          IconButton(
            tooltip: 'Swap',
            onPressed: _a == null && _b == null
                ? null
                : () => setState(() {
                    final t = _a;
                    _a = _b;
                    _b = t;
                  }),
            icon: const Icon(Icons.swap_horiz),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Space.md),
        children: [
          Row(
            children: [
              Expanded(
                child: _Slot(
                  id: _a,
                  name: names[_a ?? -1]?.displayName,
                  onTap: () => _pick(true),
                  accent: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: _Slot(
                  id: _b,
                  name: names[_b ?? -1]?.displayName,
                  onTap: () => _pick(false),
                  accent: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          if (_a == null || _b == null)
            const EmptyState(
              icon: Icons.biotech_outlined,
              title: 'Choose two specimens',
              message:
                  'Pick two Pokémon to compare their base stats, types and defences.',
            )
          else if (_a == _b)
            const EmptyState(
              icon: Icons.content_copy_outlined,
              title: 'Same Pokémon twice',
              message: 'Pick two different Pokémon to see a comparison.',
            )
          else
            _Analysis(aId: _a!, bId: _b!),
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.id,
    required this.name,
    required this.onTap,
    required this.accent,
  });

  final int? id;
  final String? name;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      borderColor: id == null ? null : accent,
      child: SizedBox(
        height: 130,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: id == null
                  ? Icon(Icons.add_circle_outline, size: 40, color: accent)
                  : PokemonArtwork(id: id!),
            ),
            Text(
              id == null ? 'Select' : (name ?? dexNumber(id!)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _Analysis extends ConsumerWidget {
  const _Analysis({required this.aId, required this.bId});

  final int aId;
  final int bId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(pokemonDetailProvider(aId));
    final b = ref.watch(pokemonDetailProvider(bId));
    final family = ref.watch(evolutionProvider(aId));

    final error = a.error ?? b.error;
    if (error != null) {
      return ErrorRetry(
        error: error,
        onRetry: () {
          ref.invalidate(pokemonDetailProvider(aId));
          ref.invalidate(pokemonDetailProvider(bId));
        },
      );
    }
    final da = a.valueOrNull;
    final db = b.valueOrNull;
    if (da == null || db == null) {
      return const Column(
        children: [
          SkeletonBox(height: 160),
          SizedBox(height: Space.md),
          SkeletonBox(height: 100),
        ],
      );
    }
    final sameFamily = family.valueOrNull?.memberIds.contains(bId) ?? false;
    return _AnalysisBody(a: da, b: db, sameFamily: sameFamily);
  }
}

class _AnalysisBody extends StatelessWidget {
  const _AnalysisBody({
    required this.a,
    required this.b,
    required this.sameFamily,
  });

  final PokemonDetail a;
  final PokemonDetail b;
  final bool sameFamily;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final diffs = compareStats(a, b);
    final notes = explainComparison(a, b, sameFamily: sameFamily);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Base stats'),
        for (final d in diffs)
          _DuelRow(
            label: statLabel(d.stat),
            a: d.a,
            b: d.b,
            colorA: scheme.primary,
            colorB: scheme.secondary,
          ),
        _DuelRow(
          label: 'Total',
          a: a.statTotal,
          b: b.statTotal,
          colorA: scheme.primary,
          colorB: scheme.secondary,
          max: 800,
        ),
        const SizedBox(height: Space.lg),
        const SectionLabel('Types'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final t in a.types) TypeChip(t)],
              ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final t in b.types) TypeChip(t)],
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.lg),
        const SectionLabel('Abilities'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _AbilityList(a)),
            const SizedBox(width: Space.sm),
            Expanded(child: _AbilityList(b)),
          ],
        ),
        const SizedBox(height: Space.lg),
        const SectionLabel('Defensive profile'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _DefenceList(a.types)),
            const SizedBox(width: Space.sm),
            Expanded(child: _DefenceList(b.types)),
          ],
        ),
        const SizedBox(height: Space.lg),
        const SectionLabel('Analysis'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final n in notes)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6, right: 8),
                        child: Icon(
                          Icons.circle,
                          size: 5,
                          color: scheme.primary,
                        ),
                      ),
                      Expanded(child: Text(n)),
                    ],
                  ),
                ),
              Text(
                'Derived from base stats and the type chart only. Base stats do not '
                'predict who wins a battle: movesets, items, levels and strategy matter.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DuelRow extends StatelessWidget {
  const _DuelRow({
    required this.label,
    required this.a,
    required this.b,
    required this.colorA,
    required this.colorB,
    this.max = 255,
  });

  final String label;
  final int a;
  final int b;
  final Color colorA;
  final Color colorB;
  final int max;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final diff = a - b;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '$a',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: a >= b ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                Text(
                  '${label.toUpperCase()}${diff == 0 ? '' : '  ${diff > 0 ? '+' : '−'}${diff.abs()}'}',
                  style: readoutStyle(
                    context,
                    size: 10,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: _HalfBar(
                        value: a,
                        max: max,
                        color: colorA,
                        alignment: Alignment.centerRight,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: _HalfBar(
                        value: b,
                        max: max,
                        color: colorB,
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            child: Text(
              '$b',
              style: TextStyle(
                fontWeight: b >= a ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HalfBar extends StatelessWidget {
  const _HalfBar({
    required this.value,
    required this.max,
    required this.color,
    required this.alignment,
  });

  final int value;
  final int max;
  final Color color;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: scheme.surfaceContainerHigh),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (value / max).clamp(0.0, 1.0)),
              duration: Motion.slow,
              curve: Motion.curve,
              builder: (context, v, _) => FractionallySizedBox(
                alignment: alignment,
                widthFactor: v,
                child: ColoredBox(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AbilityList extends StatelessWidget {
  const _AbilityList(this.p);

  final PokemonDetail p;

  @override
  Widget build(BuildContext context) {
    if (p.abilities.isEmpty) {
      return const Text('None reported');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final a in p.abilities)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(a.hidden ? '${a.displayName} (hidden)' : a.displayName),
          ),
      ],
    );
  }
}

class _DefenceList extends StatelessWidget {
  const _DefenceList(this.types);

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...group('WEAK TO', (m) => m > 1, scheme.error),
        ...group('RESISTS', (m) => m < 1 && m > 0, scheme.primary),
        ...group('IMMUNE', (m) => m == 0, AppColors.violet),
      ],
    );
  }
}
