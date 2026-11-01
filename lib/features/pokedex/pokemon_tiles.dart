import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_system/widgets.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/pokemon.dart';
import '../../domain/research_rules.dart';
import '../research/research_controller.dart';
import '../shared/navigation.dart';

class FavouriteButton extends ConsumerWidget {
  const FavouriteButton(this.id, {super.key, this.size = 22});

  final int id;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(favouritesProvider.select((f) => f.contains(id)));
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: isFav ? 'Remove from favourites' : 'Add to favourites',
      visualDensity: VisualDensity.compact,
      iconSize: size,
      onPressed: () => ref.read(favouritesProvider.notifier).toggle(id),
      icon: Icon(
        isFav ? Icons.favorite : Icons.favorite_border,
        color: isFav ? scheme.error : scheme.onSurfaceVariant,
      ),
    );
  }
}

class PokemonGridTile extends ConsumerWidget {
  const PokemonGridTile({
    super.key,
    required this.pokemon,
    this.livingDex = false,
  });

  final PokemonSummary pokemon;
  final bool livingDex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      researchProvider.select((m) => m[pokemon.id] ?? ResearchState.unseen),
    );
    final scheme = Theme.of(context).colorScheme;
    return Panel(
      padding: EdgeInsets.zero,
      onTap: () => openDossier(context, pokemon.id),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(Space.sm),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    dexNumber(pokemon.id),
                    style: readoutStyle(context, size: 10),
                  ),
                ),
                Expanded(
                  child: PokemonArtwork(
                    id: pokemon.id,
                    fit: BoxFit.contain,
                    silhouette: livingDex && state == ResearchState.unseen,
                  ),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  pokemon.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Positioned(top: 4, right: 4, child: ResearchBadge(state, size: 14)),
          Positioned(
            bottom: 0,
            right: 0,
            child: FavouriteButton(pokemon.id, size: 18),
          ),
          if (state == ResearchState.mastered)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border.all(
                      color: scheme.tertiary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PokemonRowTile extends ConsumerWidget {
  const PokemonRowTile({
    super.key,
    required this.pokemon,
    this.livingDex = false,
    this.trailing,
  });

  final PokemonSummary pokemon;
  final bool livingDex;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      researchProvider.select((m) => m[pokemon.id] ?? ResearchState.unseen),
    );
    return Panel(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.sm,
        vertical: Space.xs,
      ),
      onTap: () => openDossier(context, pokemon.id),
      child: Row(
        children: [
          PokemonArtwork(
            id: pokemon.id,
            size: 52,
            silhouette: livingDex && state == ResearchState.unseen,
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dexNumber(pokemon.id),
                  style: readoutStyle(context, size: 10),
                ),
                Text(
                  pokemon.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          ResearchBadge(state),
          trailing ?? FavouriteButton(pokemon.id),
        ],
      ),
    );
  }
}
