import 'package:flutter/material.dart';

import '../../domain/achievements.dart';

/// Central rarity presentation: the single mapping from
/// [AchievementRarity] to colour. Nothing else in the app hardcodes rarity
/// colours. The names are PokéPod's own, inspired by Pokémon TCG terminology.
class RarityStyle {
  const RarityStyle({required this.color, required this.labelColor});

  /// Accent colour for borders, badge rings and progress accents. Works on
  /// both dark and light surfaces.
  final Color color;

  /// Readable variant for small text on the current theme's surface (the raw
  /// [color] is darkened automatically in the light theme so gold, green and
  /// coral stay legible on white).
  final Color labelColor;

  /// Faint tint for badge fills and locked-state accents.
  Color get fill => color.withValues(alpha: 0.16);
}

/// The nine tiers, from introductory to highest prestige. Every colour is
/// chosen to be clearly distinguishable from the others (Rare is a plain warm
/// yellow-gold, Epic is purple, Hyper Rare is a much deeper royal gold that
/// carries the metallic sheen from [kHyperRareGold]).
const Map<AchievementRarity, Color> kRarityColors = {
  AchievementRarity.common: Color(0xFF9AA5AD), // neutral silver
  AchievementRarity.uncommon: Color(0xFF4ADE80), // fresh green
  AchievementRarity.rare: Color(0xFFF4D03F), // warm yellow-gold
  AchievementRarity.epic: Color(0xFFA78BFA), // rich purple
  AchievementRarity.doubleRare: Color(0xFF4F8DFD), // deep electric blue
  AchievementRarity.ultraRare: Color(0xFF2CC9DC), // cyan / teal
  AchievementRarity.illustrationRare: Color(0xFFFF7E67), // coral
  AchievementRarity.specialIllustrationRare: Color(0xFFD6339C), // magenta
  AchievementRarity.hyperRare: Color(0xFFD08A1E), // deep royal gold
};

/// Hyper Rare's layered metallic-gold ramp: deep royal gold, bright metal,
/// warm champagne highlight. This is the top tier's signature — nothing else
/// in the app may invent its own version of "legendary gold".
const List<Color> kHyperRareGold = [
  Color(0xFFB8811A),
  Color(0xFFE5AC3E),
  Color(0xFFF9E7B8),
];

/// The same ramp anchored for light surfaces, where white paper needs a
/// deeper bronze-gold before it stays legible. Every stop keeps the layered
/// shine while clearing a readable contrast on white.
const List<Color> kHyperRareGoldOnLight = [
  Color(0xFF553A08),
  Color(0xFF7E5A0E),
  Color(0xFF966E14),
];

/// Metallic sheen for Hyper Rare's *filled* surfaces (badges, medals), or
/// null for tiers presented with a flat colour. Unlike [rarityGradient] this
/// always uses the bright ramp: it sits behind an icon rather than behind
/// text, so it reads as gold on light and dark themes alike.
LinearGradient? rarityFillGradient(AchievementRarity rarity) {
  if (rarity != AchievementRarity.hyperRare) {
    return null;
  }
  return const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: kHyperRareGold,
  );
}

/// Horizontal sheen for Hyper Rare's rarity *labels*, darkened for light
/// themes, or null when the tier uses its flat [kRarityColors] entry. This is
/// what makes "HYPER RARE" unmistakably different from plain Rare gold.
LinearGradient? rarityGradient(
  AchievementRarity rarity,
  Brightness brightness,
) {
  if (rarity != AchievementRarity.hyperRare) {
    return null;
  }
  final colors = brightness == Brightness.dark
      ? kHyperRareGold
      : kHyperRareGoldOnLight;
  return LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: colors,
  );
}

/// Palette order, handy for tests and legends.
List<AchievementRarity> get kRarityOrder => AchievementRarity.values;

/// Readable text variant for small labels on a surface of [brightness]: the
/// raw accent is darkened in the light theme so gold, green and coral stay
/// legible on white, and used as-is on dark surfaces.
Color rarityLabelColor(AchievementRarity rarity, Brightness brightness) {
  final color = kRarityColors[rarity] ?? const Color(0xFF9AA5AD);
  if (brightness == Brightness.light) {
    return Color.lerp(color, const Color(0xFF10161C), 0.42)!;
  }
  return color;
}

RarityStyle rarityStyle(BuildContext context, AchievementRarity rarity) {
  final color = kRarityColors[rarity] ?? const Color(0xFF9AA5AD);
  return RarityStyle(
    color: color,
    labelColor: rarityLabelColor(rarity, Theme.of(context).brightness),
  );
}
